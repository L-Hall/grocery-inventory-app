/**
 * Firebase Functions for Grocery Inventory App
 *
 * Provides REST API endpoints for the Flutter app to interact with Firestore
 * Uses the same logic as the MCP server for consistency
 */

import * as functions from "firebase-functions";
import * as admin from "firebase-admin";
import express from "express";
import cors from "cors";
import * as logger from "firebase-functions/logger";
import {GroceryParser} from "./ai-parser";
import {getSecret, SECRETS, runtimeOpts} from "./secrets";
import {randomUUID} from "crypto";
import {
  processGroceryRequest,
  updateInventoryWithConfirmation,
  runIngestionAgent,
  ToolInvocationRecord,
} from "./agents";
import {
  formatInventoryItem,
  formatGroceryList,
  formatLocation,
  formatUserPreferences,
  formatSavedSearch,
  formatCustomView,
} from "./utils/formatters";
import * as XLSX from "xlsx";
import {createAuthenticateMiddleware} from "./middleware/authenticate";
import {
  UploadStatus,
  UploadJobStatus,
  sanitizeUploadFilename,
  buildUploadStoragePath,
  generateSignedUploadUrl,
  getUploadDocRef,
  UploadSourceType,
  getUploadsBucketName,
} from "./utils/uploads";
import {applyInventoryUpdatesForUser} from "./services/inventory";
import {recordAgentInteraction} from "./metrics/agent-metrics";

// Initialize Firebase Admin SDK
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();
const auth = admin.auth();

const app = express();

const DEFAULT_QUERY_LIMIT = 100;
const MAX_QUERY_LIMIT = 500;
const MAX_UPLOAD_SIZE_BYTES = 25 * 1024 * 1024; // 25MB hard cap for async uploads
const MAX_INGEST_TEXT_LENGTH = 6000;
const VALID_UPLOAD_SOURCES: Record<string, UploadSourceType> = {
  pdf: "pdf",
  text: "text",
  receipt: "image_receipt",
  image: "image_receipt",
  photo: "image_receipt",
  image_receipt: "image_receipt",
  image_list: "image_list",
  list: "image_list",
};

const IngestJobStatus = {
  pending: "pending",
  processing: "processing",
  completed: "completed",
  failed: "failed",
} as const;

const LATENCY_BUCKETS = [
  {key: "lt_2s", max: 2000},
  {key: "2s_5s", max: 5000},
  {key: "gt_5s", max: Number.POSITIVE_INFINITY},
];

const CONFIDENCE_BUCKETS = [
  {key: "low", max: 0.5},
  {key: "medium", max: 0.8},
  {key: "high", max: 1},
];

const parseLimit = (value: any): number => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return DEFAULT_QUERY_LIMIT;
  }
  return Math.min(Math.floor(numeric), MAX_QUERY_LIMIT);
};

const ensureArrayPayload = (payload: any, field: string) => {
  if (!Array.isArray(payload)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `${field} must be an array`,
    );
  }
};

const HEX_COLOR_REGEX = /^#[0-9A-Fa-f]{6}$/;

const normalizeUploadSourceType = (value: any): UploadSourceType => {
  if (typeof value !== "string") {
    return "unknown";
  }
  const normalized = value.trim().toLowerCase();
  return VALID_UPLOAD_SOURCES[normalized] ?? "unknown";
};

const parseUploadSizeBytes = (value: any): number | null => {
  if (value === null || value === undefined || value === "") {
    return null;
  }
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric < 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "sizeBytes must be a positive number.",
    );
  }
  if (numeric > MAX_UPLOAD_SIZE_BYTES) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `File too large. Maximum size is ${MAX_UPLOAD_SIZE_BYTES} bytes.`,
    );
  }
  return Math.floor(numeric);
};

const sanitizeJobMetadata = (value: any) => {
  if (
    !value ||
    typeof value !== "object" ||
    Array.isArray(value)
  ) {
    return {};
  }

  try {
    return JSON.parse(JSON.stringify(value));
  } catch (error) {
    logger.warn("Failed to sanitize ingestion metadata", {
      error: error instanceof Error ? error.message : error,
    });
    return {};
  }
};

interface AgentPipelineExecution {
  success: boolean;
  agentResponse: string | null;
  summary: string;
  error?: string | null;
  toolInvocations: ToolInvocationRecord[];
  usedFallback: boolean;
  fallbackDetails?: Record<string, any> | null;
  latencyMs: number;
}

const didAgentApplyInventoryUpdates = (
  toolInvocations: ToolInvocationRecord[],
) => {
  return toolInvocations.some(
    (invocation) => invocation.name === "apply_inventory_updates",
  );
};

const buildFallbackSummary = (
  summary: {total: number; successful: number; failed: number},
) => {
  return `Fallback parser applied ${summary.successful}/${summary.total} updates (${summary.failed} failed).`;
};

const runFallbackParserAndApply = async (
  userId: string,
  text: string,
) => {
  const apiKey = await getSecret(SECRETS.OPENAI_API_KEY) ?? "";
  const parser = new GroceryParser(apiKey);
  const parseResult = await parser.parseGroceryText(text);
  const items = parser.validateItems(parseResult.items ?? []);

  if (!items.length) {
    throw new Error("Fallback parser did not detect any updates to apply.");
  }

  const applyResult = await applyInventoryUpdatesForUser(
    userId,
    items,
    "inventory_agent",
  );

  return {
    summary: buildFallbackSummary(applyResult.summary),
    parsedItems: items,
    applyResult,
    parser: {
      confidence: parseResult.confidence ?? null,
      needsReview: parseResult.needsReview ?? false,
    },
  };
};

const executeAgentIngestionPipeline = async ({
  userId,
  text,
  metadata,
}: {
  userId: string;
  text: string;
  metadata?: Record<string, any> | null;
}): Promise<AgentPipelineExecution> => {
  const agentResult = await runIngestionAgent({
    userId,
    text,
    metadata: metadata ?? undefined,
  });

  const toolInvocations = agentResult.toolInvocations ?? [];
  const originalResponse = agentResult.response ?? null;
  let summary = originalResponse ?? "Ingestion completed.";
  let success = agentResult.success;
  let error = agentResult.error ?? null;
  let usedFallback = false;
  let fallbackDetails: Record<string, any> | null = null;
  let totalLatency = agentResult.latencyMs;

  const shouldFallback =
    !agentResult.success ||
    !didAgentApplyInventoryUpdates(toolInvocations);

  if (shouldFallback) {
    usedFallback = true;
    const fallbackStarted = Date.now();
    try {
      const fallbackResult = await runFallbackParserAndApply(userId, text);
      fallbackDetails = fallbackResult;
      const fallbackSummary = buildFallbackSummary(
        fallbackResult.applyResult.summary,
      );
      summary = originalResponse ?
        `${originalResponse}\n\n${fallbackSummary}` :
        fallbackSummary;
      success = true;
      error = null;
    } catch (fallbackError: any) {
      error = fallbackError instanceof Error ?
        fallbackError.message :
        String(fallbackError);
      summary = originalResponse ?? error;
      success = false;
      fallbackDetails = {error};
    } finally {
      totalLatency += Date.now() - fallbackStarted;
    }
  }

  await recordAgentInteraction({
    userId,
    input: text,
    agent: "grocery_ingest",
    success,
    usedFallback,
    latencyMs: totalLatency,
    metadata: {
      metadata: metadata ?? {},
      toolInvocations,
      fallbackDetails,
    },
    error: success ? null : error ?? "Unknown error",
  });

  return {
    success,
    agentResponse: summary ?? null,
    summary,
    error,
    toolInvocations,
    usedFallback,
    fallbackDetails,
    latencyMs: totalLatency,
  };
};

const getLatencyBucketKey = (latencyMs: number) => {
  for (const bucket of LATENCY_BUCKETS) {
    if (latencyMs < bucket.max) {
      return bucket.key;
    }
  }
  return LATENCY_BUCKETS[LATENCY_BUCKETS.length - 1].key;
};

const getConfidenceBucketKey = (confidence: number) => {
  for (const bucket of CONFIDENCE_BUCKETS) {
    if (confidence <= bucket.max) {
      return bucket.key;
    }
  }
  return CONFIDENCE_BUCKETS[CONFIDENCE_BUCKETS.length - 1].key;
};

const formatDateKey = (date: Date) => {
  return date.toISOString().slice(0, 10); // YYYY-MM-DD
};

const TEXT_CONTENT_TYPES = [
  "text/plain",
  "text/csv",
  "application/json",
  "application/xml",
];

const IMAGE_CONTENT_TYPES = [
  "image/jpeg",
  "image/png",
  "image/heic",
  "image/heif",
  "image/webp",
  "image/jpg",
];

const PDF_CONTENT_TYPES = ["application/pdf"];

type ExtractionParams = {
  userId: string;
  uploadId: string;
  bucket: string | undefined;
  storagePath: string;
  contentType: string | undefined;
  sourceType: UploadSourceType | undefined;
};

type TextExtractionResult = {
  text: string;
  preview: string;
  metadata: Record<string, any>;
};

const sanitizeExtractedText = (value: string, limit = 240) => {
  const collapsed = value.replace(/\s+/g, " ").trim();
  if (collapsed.length <= limit) {
    return collapsed;
  }
  return `${collapsed.slice(0, limit).trim()}...`;
};

const isTextLike = (contentType?: string) => {
  if (!contentType) return false;
  return TEXT_CONTENT_TYPES.some((type) => contentType.includes(type));
};

const isPdfLike = (contentType?: string, path?: string) => {
  if (contentType && PDF_CONTENT_TYPES.some((type) => contentType.includes(type))) {
    return true;
  }
  if (!path) return false;
  return path.toLowerCase().endsWith(".pdf");
};

const isImageLike = (contentType?: string, sourceType?: UploadSourceType) => {
  if (sourceType === "image_receipt" || sourceType === "image_list") {
    return true;
  }
  if (!contentType) return false;
  return IMAGE_CONTENT_TYPES.some((type) => contentType.includes(type));
};

const isSpreadsheetLike = (contentType?: string, path?: string) => {
  if (contentType && contentType.includes("spreadsheet")) {
    return true;
  }
  if (!path) return false;
  return path.toLowerCase().endsWith(".xlsx");
};

const extractTextFromPdfBuffer = async (buffer: Buffer) => {
  // Try structured PDF parsing first (handles binary streams and mixed content).
  try {
    const pdfParse = (await import("pdf-parse")).default;
    const {text} = await pdfParse(buffer);
    const cleaned = text.replace(/\s+/g, " ").trim();
    if (cleaned) return cleaned;
  } catch (error) {
    logger.warn("Structured PDF parse failed, falling back to regex extraction", {
      error: error instanceof Error ? error.message : String(error),
    });
  }

  // Fallback: naive text pull from stringified PDF contents.
  const raw = buffer.toString("latin1");
  const matches = raw.match(/\(([^)]+)\)/g) ?? [];
  const cleaned = matches
    .map((segment) =>
      segment
        .slice(1, -1)
        .replace(/\\\)/g, ")")
        .replace(/\\\(/g, "(")
        .replace(/\\\\/g, "\\"),
    )
    .filter((segment) => /[A-Za-z0-9]/.test(segment));

  return cleaned.join(" ").trim();
};

const convertItemsToNarrative = (items: any[]) => {
  if (!Array.isArray(items) || items.length === 0) {
    return "";
  }

  const statements = items.map((item) => {
    const quantity = Number.isFinite(item.quantity) ? item.quantity : 1;
    const unit = item.unit || "count";
    const name = item.name || "item";
    const action = item.action || "add";
    let verb = "bought";
    if (action === "subtract") {
      verb = "used";
    } else if (action === "set") {
      verb = "have";
    }
    return `${verb} ${quantity} ${unit} ${name}`;
  });

  return statements.join("\n");
};

const convertSpreadsheetToText = (buffer: Buffer) => {
  const workbook = XLSX.read(buffer, {type: "buffer"});
  if (!workbook.SheetNames.length) {
    throw new Error("Spreadsheet does not contain any sheets.");
  }
  const sheetName = workbook.SheetNames[0];
  const sheet = workbook.Sheets[sheetName];
  const rows = XLSX.utils.sheet_to_json(sheet, {
    header: 1,
    blankrows: false,
  }) as any[][];

  const normalizedRows = rows
    .map((row) => {
      const cells = (row || [])
        .map((cell) => String(cell ?? "").trim())
        .filter((cell) => cell.length > 0);
      return cells.join(", ");
    })
    .filter((line) => line.length > 0);

  const text = normalizedRows.join("\n").trim();
  if (!text) {
    throw new Error("Spreadsheet did not contain any readable cells.");
  }

  const columnCount = rows.reduce(
    (max, row) => Math.max(max, Array.isArray(row) ? row.length : 0),
    0,
  );

  return {
    text,
    preview: sanitizeExtractedText(text),
    metadata: {
      method: "spreadsheet",
      sheetName,
      sheetNames: workbook.SheetNames,
      rowCount: rows.length,
      columnCount,
    },
  };
};

const extractTextFromUpload = async ({
  userId,
  uploadId,
  bucket,
  storagePath,
  contentType,
  sourceType,
}: ExtractionParams): Promise<TextExtractionResult> => {
  if (!storagePath) {
    throw new Error("Upload is missing storagePath.");
  }

  const bucketName = bucket?.trim() || getUploadsBucketName();
  const file = admin.storage().bucket(bucketName).file(storagePath);
  const [buffer] = await file.download();

  if (buffer.length === 0) {
    throw new Error("Uploaded file is empty.");
  }

  if (isTextLike(contentType)) {
    const text = buffer.toString("utf8");
    if (!text.trim()) {
      throw new Error("Text file did not contain any content.");
    }
    return {
      text,
      preview: sanitizeExtractedText(text),
      metadata: {method: "text/plain"},
    };
  }

  if (isPdfLike(contentType, storagePath)) {
    const extracted = await extractTextFromPdfBuffer(buffer);
    if (!extracted) {
      throw new Error("Could not extract text from PDF.");
    }
    return {
      text: extracted,
      preview: sanitizeExtractedText(extracted),
      metadata: {method: "pdf"},
    };
  }

  if (isImageLike(contentType, sourceType)) {
    const apiKey = await getSecret(SECRETS.OPENAI_API_KEY);
    if (!apiKey) {
      throw new Error("OpenAI API key is required for image ingestion.");
    }

    const parser = new GroceryParser(apiKey);
    const base64 = buffer.toString("base64");
    const imageType = sourceType === "image_list" ? "list" : "receipt";
    const parseResult = await parser.parseGroceryImage(base64, imageType);
    const validatedItems = parser.validateItems(parseResult.items ?? []);

    if (!validatedItems.length) {
      throw new Error("Vision parser returned no items.");
    }

    const narrative = convertItemsToNarrative(validatedItems);
    if (!narrative.trim()) {
      throw new Error("Parsed items could not be converted to text.");
    }

    return {
      text: narrative,
      preview: sanitizeExtractedText(narrative),
      metadata: {
        method: "image_vision",
        itemCount: validatedItems.length,
        averageConfidence:
          validatedItems.reduce((sum: number, item: any) => sum + (item.confidence ?? 0), 0) /
          validatedItems.length,
      },
    };
  }

  if (isSpreadsheetLike(contentType, storagePath)) {
    const spreadsheet = convertSpreadsheetToText(buffer);
    return spreadsheet;
  }

  throw new Error(
    `Unsupported upload type: ${contentType || "unknown"} (sourceType=${sourceType ?? "unknown"})`,
  );
};

const sanitizeDocumentId = (value: any, maxLength = 120) => {
  if (typeof value !== "string") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Document identifier must be a string.",
    );
  }

  const trimmed = value.trim();
  if (!trimmed) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Document identifier cannot be empty.",
    );
  }

  if (trimmed.length > maxLength) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      `Document identifier must be ${maxLength} characters or fewer.`,
    );
  }

  if (!/^[A-Za-z0-9_-]+$/.test(trimmed)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Document identifier may only contain letters, numbers, hyphen, or underscore.",
    );
  }

  return trimmed;
};

const sanitizeLocationPayload = (
  payload: any,
  existing: FirebaseFirestore.DocumentData | null,
) => {
  const base = existing ?? {};
  const combined = {
    ...base,
    ...(payload ?? {}),
  };

  const name = typeof combined.name === "string" ? combined.name.trim() : "";
  const color = typeof combined.color === "string" ? combined.color.trim() : "";
  const icon = typeof combined.icon === "string" ? combined.icon.trim() : "";

  if (!name || name.length > 80) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Location name must be 1-80 characters.",
    );
  }

  if (!HEX_COLOR_REGEX.test(color)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Location color must be a 6-digit hex string.",
    );
  }

  if (!icon || icon.length > 60) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Location icon must be a non-empty string up to 60 characters.",
    );
  }

  let temperature: string | null = null;
  if (combined.temperature === null || combined.temperature === undefined) {
    temperature = null;
  } else if (typeof combined.temperature === "string") {
    const trimmed = combined.temperature.trim();
    if (trimmed.length > 30) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Location temperature must be 30 characters or fewer.",
      );
    }
    temperature = trimmed;
  } else {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Location temperature must be a string or null.",
    );
  }

  let sortOrder: number | undefined;
  if (combined.sortOrder !== undefined && combined.sortOrder !== null) {
    const parsed = Number(combined.sortOrder);
    if (!Number.isFinite(parsed) || parsed < 0 || parsed > 1000) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "Location sortOrder must be between 0 and 1000.",
      );
    }
    sortOrder = parsed;
  } else if (typeof base.sortOrder === "number") {
    sortOrder = base.sortOrder;
  }

  return {
    name,
    color,
    icon,
    temperature,
    sortOrder,
  };
};

const sanitizePreferencesSettingsPayload = (payload: any) => {
  if (!payload || typeof payload !== "object") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Preferences payload must be an object.",
    );
  }

  const data: Record<string, any> = {};

  if (payload.defaultView !== undefined) {
    if (
      typeof payload.defaultView !== "string" ||
      payload.defaultView.trim().length === 0 ||
      payload.defaultView.trim().length > 60
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "defaultView must be a non-empty string up to 60 characters.",
      );
    }
    data.defaultView = payload.defaultView.trim();
  }

  if (payload.searchHistory !== undefined) {
    if (!Array.isArray(payload.searchHistory)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "searchHistory must be an array of strings.",
      );
    }
    if (payload.searchHistory.length > 25) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "searchHistory can contain at most 25 entries.",
      );
    }
    data.searchHistory = payload.searchHistory.map((entry: any) => {
      if (typeof entry !== "string" || entry.length > 120) {
        throw new functions.https.HttpsError(
          "invalid-argument",
          "Each searchHistory entry must be a string up to 120 characters.",
        );
      }
      return entry;
    });
  }

  if (payload.exportPreferences !== undefined) {
    if (
      payload.exportPreferences === null ||
      typeof payload.exportPreferences !== "object" ||
      Array.isArray(payload.exportPreferences)
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "exportPreferences must be an object.",
      );
    }
    data.exportPreferences = payload.exportPreferences;
  }

  if (payload.bulkOperationHistory !== undefined) {
    if (!Array.isArray(payload.bulkOperationHistory)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "bulkOperationHistory must be an array.",
      );
    }
    if (payload.bulkOperationHistory.length > 100) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "bulkOperationHistory can contain at most 100 entries.",
      );
    }
    data.bulkOperationHistory = payload.bulkOperationHistory;
  }

  if (Object.keys(data).length === 0) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "At least one supported preference field must be provided.",
    );
  }

  return data;
};

const sanitizeSavedSearchPayload = (payload: any) => {
  if (!payload || typeof payload !== "object") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Saved search payload must be an object.",
    );
  }

  const name =
    typeof payload.name === "string" ? payload.name.trim() : "";
  if (!name || name.length > 80) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Saved search name must be 1-80 characters.",
    );
  }

  if (
    payload.config === null ||
    typeof payload.config !== "object" ||
    Array.isArray(payload.config)
  ) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Saved search config must be an object.",
    );
  }

  const sanitized: Record<string, any> = {
    name,
    config: payload.config,
  };

  if (payload.fuzzyMatch !== undefined) {
    sanitized.config = {
      ...sanitized.config,
      fuzzyMatch: Boolean(payload.fuzzyMatch),
    };
  }

  if (payload.searchFields !== undefined) {
    if (!Array.isArray(payload.searchFields)) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "searchFields must be an array of strings.",
      );
    }
    sanitized.config = {
      ...sanitized.config,
      searchFields: payload.searchFields.map((field: any) => {
        if (typeof field !== "string") {
          throw new functions.https.HttpsError(
            "invalid-argument",
            "Each search field must be a string.",
          );
        }
        return field;
      }),
    };
  }

  return sanitized;
};

const sanitizeCustomViewPayload = (payload: any) => {
  if (!payload || typeof payload !== "object") {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Custom view payload must be an object.",
    );
  }

  const name =
    typeof payload.name === "string" ? payload.name.trim() : "";
  if (!name || name.length > 80) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Custom view name must be 1-80 characters.",
    );
  }

  const type =
    typeof payload.type === "string" ? payload.type.trim() : "";
  const allowedTypes = [
    "location",
    "lowStock",
    "custom",
    "category",
    "expiration",
  ];
  if (!allowedTypes.includes(type)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Unsupported custom view type.",
    );
  }

  if (!Array.isArray(payload.filters)) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Custom view filters must be an array.",
    );
  }
  if (payload.filters.length > 100) {
    throw new functions.https.HttpsError(
      "invalid-argument",
      "Custom view filters can contain at most 100 entries.",
    );
  }

  const sanitized: Record<string, any> = {
    name,
    type,
    filters: payload.filters,
  };

  if (payload.sortConfig !== undefined) {
    if (
      payload.sortConfig === null ||
      typeof payload.sortConfig !== "object" ||
      Array.isArray(payload.sortConfig)
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "sortConfig must be an object.",
      );
    }
    sanitized.sortConfig = payload.sortConfig;
  }

  if (payload.groupBy !== undefined) {
    if (
      payload.groupBy !== null &&
      typeof payload.groupBy !== "string"
    ) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "groupBy must be a string or null.",
      );
    }
    sanitized.groupBy = payload.groupBy;
  }

  if (payload.isDefault !== undefined) {
    sanitized.isDefault = Boolean(payload.isDefault);
  }

  return sanitized;
};

type ParsePayload = {
  text?: string;
  image?: string;
  imageType?: string;
};

async function handleParseInventoryRequest(
  req: functions.Request & {user: {uid: string}},
  res: functions.Response,
  payload: ParsePayload,
) {
  try {
    const {text, image, imageType} = payload;

    if (!text && !image) {
      return res.status(400).json({
        error: "Bad Request",
        message: "Either text or image field is required",
      });
    }

    if (text && image) {
      return res.status(400).json({
        error: "Bad Request",
        message: "Provide either text or image, not both",
      });
    }

    if (text && typeof text !== "string") {
      return res.status(400).json({
        error: "Bad Request",
        message: "Text field must be a string",
      });
    }

    if (image && typeof image !== "string") {
      return res.status(400).json({
        error: "Bad Request",
        message: "Image field must be a base64 encoded string",
      });
    }

    const apiKey = await getSecret(SECRETS.OPENAI_API_KEY);

    if (!apiKey) {
      if (text) {
        logger.warn("OPENAI_API_KEY missing - using fallback parser", {
          uid: req.user.uid,
        });
        const parser = new GroceryParser("");
        const parseResult = await parser.parseGroceryText(text);

        const validatedItems = parser.validateItems(parseResult.items);
        const warnings: string[] = [
          "Using basic parser. Configure OPENAI_API_KEY for better results.",
        ];
        if (parseResult.needsReview) {
          warnings.push("Review recommended before applying updates.");
        }
        if (parseResult.error) {
          warnings.push(parseResult.error);
        }

        return res.json({
          success: true,
          updates: validatedItems,
          confidence: parseResult.confidence ?? 0,
          warnings: warnings.join(" "),
          usedFallback: true,
          originalText: parseResult.originalText,
          needsReview: parseResult.needsReview,
          message:
            "Using basic parser. Configure OPENAI_API_KEY for better results.",
        });
      }

      return res.status(500).json({
        error: "Configuration Error",
        message: "Image processing requires OpenAI API key to be configured",
      });
    }

    const parser = new GroceryParser(apiKey);

    let parseResult;
    if (text) {
      parseResult = await parser.parseGroceryText(text);
    } else {
      parseResult = await parser.parseGroceryImage(
        image as string,
        imageType || "receipt",
      );
    }

    const validatedItems = parser.validateItems(parseResult.items);

    const warnings: string[] = [];
    if (parseResult.needsReview) {
      warnings.push("Review recommended before applying updates.");
    }
    if (parseResult.error) {
      warnings.push(parseResult.error);
    }

    res.json({
      success: true,
      updates: validatedItems,
      confidence: parseResult.confidence ?? 0,
      warnings: warnings.length > 0 ? warnings.join(" ") : undefined,
      usedFallback: Boolean(parseResult.error),
      originalText: parseResult.originalText,
      needsReview: parseResult.needsReview,
      message: parseResult.error ?
        "Parsed using fallback method. Please review carefully." :
        parseResult.needsReview ?
          "Text parsed successfully. Please review the items before confirming." :
          "Text parsed successfully with high confidence.",
    });
  } catch (error: any) {
    logger.error("Error parsing inventory text", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
}

// Configure CORS for Flutter app
app.use(cors({
  origin: true, // Allow all origins for development
  credentials: true,
}));

app.use(express.json());

// Middleware to verify Firebase Auth token
const authenticate = createAuthenticateMiddleware(auth);

// Health check endpoint
app.get("/health", (req, res) => {
  res.json({
    status: "healthy",
    timestamp: new Date().toISOString(),
    service: "grocery-inventory-api",
  });
});

// GET /inventory - List all inventory items with optional filters
app.get("/inventory", authenticate, async (req, res) => {
  try {
    const {category, location, lowStockOnly, search} = req.query;
    const searchTerm = typeof search === "string" ? search.trim().toLowerCase() : "";
    const wantsSearch = searchTerm.length > 0;

    let query: FirebaseFirestore.Query = db
      .collection(`users/${req.user.uid}/inventory`)
      .orderBy("lastUpdated", "desc");

    if (category) {
      query = query.where("category", "==", category);
    }

    if (location) {
      query = query.where("location", "==", location);
    }

    if (wantsSearch) {
      // Firestore doesn't support native LIKE queries; we approximate by filtering on an exact match field.
      // Consider maintaining a searchKeywords array per document for more sophisticated matching.
      query = query.where("searchKeywords", "array-contains", searchTerm);
    }

    const limit = parseLimit(req.query.limit);
    query = query.limit(limit);

    const snapshot = await query.get();
    const items: any[] = [];

    snapshot.forEach((doc) => {
      const item = formatInventoryItem(doc);

      if (lowStockOnly === "true") {
        if (item.quantity <= item.lowStockThreshold) {
          items.push(item);
        }
      } else {
        items.push(item);
      }
    });

    logger.info("Inventory fetch complete", {
      uid: req.user.uid,
      params: {
        category,
        location,
        lowStockOnly,
        search: search ? "provided" : "not_provided",
        limit,
      },
      itemCount: items.length,
    });

    res.json({
      success: true,
      items,
      count: items.length,
    });
  } catch (error: any) {
    logger.error("Error listing inventory", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// POST /inventory/update - Update inventory items (legacy endpoint)
app.post("/inventory/update", authenticate, async (req, res) => {
  try {
    const {updates} = req.body;
    ensureArrayPayload(updates, "updates");

    const {results, summary, validationErrors} =
      await applyInventoryUpdatesForUser(
        req.user.uid,
        updates,
        "inventory_update",
      );

    logger.info("Inventory update processed", {
      uid: req.user.uid,
      summary,
    });

    res.json({
      success: validationErrors.length === 0,
      results,
      summary,
      validationErrors,
    });
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      return res.status(400).json({
        error: "Bad Request",
        message: error.message,
      });
    }

    logger.error("Error updating inventory", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// POST /inventory/apply - Apply parsed inventory updates with validation feedback
app.post("/inventory/apply", authenticate, async (req, res) => {
  try {
    const {updates} = req.body;
    ensureArrayPayload(updates, "updates");

    const {results, summary, validationErrors} =
      await applyInventoryUpdatesForUser(
        req.user.uid,
        updates,
        "inventory_apply",
      );

    logger.info("Inventory apply processed", {
      uid: req.user.uid,
      summary,
      validationErrors,
    });

    res.json({
      success: validationErrors.length === 0,
      results,
      summary,
      validationErrors,
    });
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      return res.status(400).json({
        error: "Bad Request",
        message: error.message,
      });
    }

    logger.error("Error applying inventory updates", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// POST /inventory/parse/text - Parse natural language grocery text
app.post("/inventory/parse/text", authenticate, async (req, res) => {
  await handleParseInventoryRequest(req as any, res, {
    text: req.body?.text,
  });
});

// POST /inventory/parse/image - Parse grocery content from an image
app.post("/inventory/parse/image", authenticate, async (req, res) => {
  await handleParseInventoryRequest(req as any, res, {
    image: req.body?.image,
    imageType: req.body?.imageType,
  });
});

// POST /inventory/parse - Backwards compatible combined endpoint
app.post("/inventory/parse", authenticate, async (req, res) => {
  await handleParseInventoryRequest(req as any, res, {
    text: req.body?.text,
    image: req.body?.image,
    imageType: req.body?.imageType,
  });
});

// POST /inventory/ingest - Asynchronous ingestion job for agent pipeline
app.post("/inventory/ingest", authenticate, async (req, res) => {
  try {
    const {text, metadata, uploadId} = req.body ?? {};

    if (text !== undefined && typeof text !== "string") {
      return res.status(400).json({
        error: "Bad Request",
        message: "Text must be a string.",
      });
    }

    if (!text && typeof uploadId !== "string") {
      return res.status(400).json({
        error: "Bad Request",
        message: "Provide text or uploadId for ingestion.",
      });
    }

    const trimmedText = typeof text === "string" ? text.trim() : "";
    if (!trimmedText && !uploadId) {
      return res.status(400).json({
        error: "Bad Request",
        message: "Text cannot be empty.",
      });
    }

    if (trimmedText.length > MAX_INGEST_TEXT_LENGTH) {
      return res.status(400).json({
        error: "Bad Request",
        message: `Text exceeds ${MAX_INGEST_TEXT_LENGTH} character limit.`,
      });
    }

    const jobId = randomUUID();
    const jobRef = db.doc(`users/${req.user.uid}/ingestion_jobs/${jobId}`);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const sanitizedMetadata = sanitizeJobMetadata(metadata);

    await jobRef.set({
      userId: req.user.uid,
      status: IngestJobStatus.pending,
      text: trimmedText || null,
      textLength: trimmedText.length,
      uploadId: typeof uploadId === "string" ? uploadId : null,
      metadata: sanitizedMetadata,
      agentResponse: null,
      lastError: null,
      resultSummary: null,
      toolInvocations: [],
      fallbackApplied: false,
      fallbackDetails: null,
      createdAt: timestamp,
      updatedAt: timestamp,
    });

    res.json({
      success: true,
      jobId,
      status: IngestJobStatus.pending,
      jobPath: `users/${req.user.uid}/ingestion_jobs/${jobId}`,
    });
  } catch (error: any) {
    logger.error("Error creating ingestion job", {
      uid: req.user?.uid,
      error: error?.message ?? error,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error?.message ?? "Failed to create ingestion job",
    });
  }
});

// POST /uploads - Create metadata + signed URL for large uploads
app.post("/uploads", authenticate, async (req, res) => {
  try {
    const {filename, contentType, sizeBytes, sourceType} = req.body ?? {};

    if (typeof filename !== "string" || !filename.trim()) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "filename is required",
      );
    }

    if (typeof contentType !== "string" || !contentType.trim()) {
      throw new functions.https.HttpsError(
        "invalid-argument",
        "contentType is required",
      );
    }

    const sanitizedFilename = sanitizeUploadFilename(filename);
    const normalizedSourceType = normalizeUploadSourceType(sourceType);
    const parsedSize = parseUploadSizeBytes(sizeBytes);
    const uploadId = randomUUID();
    const storagePath = buildUploadStoragePath(req.user.uid, uploadId, sanitizedFilename);
    const bucketName = getUploadsBucketName();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const uploadRef = getUploadDocRef(req.user.uid, uploadId);

    await uploadRef.set({
      filename: sanitizedFilename,
      originalFilename: filename,
      contentType,
      sizeBytes: parsedSize,
      sourceType: normalizedSourceType,
      bucket: bucketName,
      storagePath,
      status: UploadStatus.awaitingUpload,
      createdAt: timestamp,
      updatedAt: timestamp,
      lastError: null,
      processingJobId: null,
      processingStage: "awaiting_upload",
    });

    let signedUrlData;
    try {
      signedUrlData = await generateSignedUploadUrl(
        storagePath,
        contentType,
        undefined,
        bucketName,
      );
    } catch (error: any) {
      await uploadRef.update({
        status: UploadStatus.failed,
        lastError: error?.message ?? String(error),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      throw error;
    }

    res.json({
      success: true,
      uploadId,
      bucket: signedUrlData.bucket,
      storagePath,
      uploadUrl: signedUrlData.uploadUrl,
      uploadUrlExpiresAt: signedUrlData.expiresAt,
      status: UploadStatus.awaitingUpload,
    });
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      return res.status(400).json({
        error: "Bad Request",
        message: error.message,
      });
    }

    logger.error("Error creating upload metadata", {
      uid: req.user?.uid,
      error: error?.message ?? error,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error?.message ?? "Failed to create upload metadata",
    });
  }
});

// GET /uploads/:uploadId - Fetch upload metadata/status
app.get("/uploads/:uploadId", authenticate, async (req, res) => {
  try {
    const uploadId = sanitizeDocumentId(req.params.uploadId, 120);
    const uploadRef = getUploadDocRef(req.user.uid, uploadId);
    const snapshot = await uploadRef.get();

    if (!snapshot.exists) {
      return res.status(404).json({
        error: "Not Found",
        message: "Upload not found",
      });
    }

    res.json({
      success: true,
      upload: {
        id: uploadId,
        ...snapshot.data(),
      },
    });
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      return res.status(400).json({
        error: "Bad Request",
        message: error.message,
      });
    }

    logger.error("Error fetching upload metadata", {
      uid: req.user?.uid,
      uploadId: req.params.uploadId,
      error: error?.message ?? error,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error?.message ?? "Failed to fetch upload",
    });
  }
});

// POST /uploads/:uploadId/queue - Queue upload for async processing
app.post("/uploads/:uploadId/queue", authenticate, async (req, res) => {
  try {
    const uploadId = sanitizeDocumentId(req.params.uploadId, 120);
    const uploadRef = getUploadDocRef(req.user.uid, uploadId);
    const jobRef = db.collection("upload_jobs").doc();
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    await db.runTransaction(async (tx) => {
      const snapshot = await tx.get(uploadRef);
      if (!snapshot.exists) {
        throw new functions.https.HttpsError(
          "not-found",
          "Upload not found",
        );
      }

      const uploadData = snapshot.data() ?? {};
      const currentStatus = uploadData.status ?? UploadStatus.awaitingUpload;

      if (
        currentStatus === UploadStatus.processing ||
        currentStatus === UploadStatus.completed
      ) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Upload is already being processed",
        );
      }

      if (!uploadData.storagePath || !uploadData.bucket || !uploadData.contentType) {
        throw new functions.https.HttpsError(
          "failed-precondition",
          "Upload metadata is incomplete",
        );
      }

      tx.update(uploadRef, {
        status: UploadStatus.queued,
        updatedAt: timestamp,
        processingJobId: jobRef.id,
        lastError: null,
        processingStage: "queued",
      });

      tx.set(jobRef, {
        uploadId,
        userId: req.user.uid,
        storagePath: uploadData.storagePath,
        bucket: uploadData.bucket,
        contentType: uploadData.contentType,
        sourceType: uploadData.sourceType ?? "unknown",
        status: UploadJobStatus.queued,
        attempts: 0,
        createdAt: timestamp,
        updatedAt: timestamp,
      });
    });

    res.json({
      success: true,
      jobId: jobRef.id,
      status: UploadJobStatus.queued,
    });
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      return res.status(error.code === "not-found" ? 404 : 400).json({
        error: error.code === "not-found" ? "Not Found" : "Bad Request",
        message: error.message,
      });
    }

    logger.error("Error queueing upload", {
      uid: req.user?.uid,
      uploadId: req.params.uploadId,
      error: error?.message ?? error,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error?.message ?? "Failed to queue upload",
    });
  }
});

// GET /inventory/low-stock - Get low stock items
app.get("/inventory/low-stock", authenticate, async (req, res) => {
  try {
    const {includeOutOfStock = "true"} = req.query;
    const limit = parseLimit(req.query.limit);

    const snapshot = await db.collection(`users/${req.user.uid}/inventory`)
      .orderBy("category")
      .limit(limit)
      .get();

    const lowStock: any[] = [];

    snapshot.forEach((doc) => {
      const item = formatInventoryItem(doc);

      if (item.quantity <= item.lowStockThreshold) {
        if (includeOutOfStock === "false" && item.quantity === 0) {
          return; // Skip out of stock items if not requested
        }
        lowStock.push(item);
      }
    });

    logger.info("Low stock fetch complete", {
      uid: req.user.uid,
      includeOutOfStock,
      limit,
      count: lowStock.length,
    });

    res.json({
      success: true,
      items: lowStock,
      count: lowStock.length,
    });
  } catch (error: any) {
    logger.error("Error getting low stock items", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// POST /grocery-lists - Create a new grocery list
app.post("/grocery-lists", authenticate, async (req, res) => {
  try {
    const {name = "Shopping List", fromLowStock = true, customItems = []} = req.body;

    const listItems: any[] = [];

    // Add low stock items if requested
    if (fromLowStock) {
      const snapshot = await db.collection(`users/${req.user.uid}/inventory`)
        .orderBy("category")
        .get();

      snapshot.forEach((doc) => {
        const item = formatInventoryItem(doc);
        if (item.quantity <= item.lowStockThreshold) {
          listItems.push({
            id: randomUUID(),
            name: item.name,
            quantity: Math.max(item.lowStockThreshold - item.quantity + 1, 1),
            unit: item.unit,
            category: item.category,
            isChecked: false,
            notes: item.quantity === 0 ? "Out of stock" : "Running low",
            addedAt: admin.firestore.FieldValue.serverTimestamp(),
          });
        }
      });
    }

    // Add custom items
    for (const item of customItems) {
      listItems.push({
        id: randomUUID(),
        name: item.name,
        quantity: item.quantity,
        unit: item.unit || "unit",
        category: item.category || "uncategorized",
        isChecked: false,
        notes: item.notes || "",
        addedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    if (listItems.length === 0) {
      return res.json({
        success: true,
        message: "No items to add to grocery list. Everything is well stocked!",
        list: null,
      });
    }

    // Create the grocery list in database
    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const docRef = await db.collection(`users/${req.user.uid}/grocery_lists`).add({
      name,
      status: "active",
      items: listItems,
      notes: "",
      createdAt: timestamp,
      updatedAt: timestamp,
    });

    const createdDoc = await docRef.get();
    const formattedList = formatGroceryList(createdDoc);

    res.json({
      success: true,
      list: formattedList,
      itemCount: formattedList.items.length,
      message: `Created grocery list "${name}" with ${listItems.length} items`,
    });
  } catch (error: any) {
    logger.error("Error creating grocery list", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// GET /grocery-lists - Get all grocery lists for user
app.get("/grocery-lists", authenticate, async (req, res) => {
  try {
    const {status} = req.query;
    const limit = parseLimit(req.query.limit);

    let query: any = db.collection(`users/${req.user.uid}/grocery_lists`)
      .orderBy("createdAt", "desc");

    if (status) {
      query = query.where("status", "==", status);
    }

    query = query.limit(limit);

    const snapshot = await query.get();
    const lists: any[] = [];

    snapshot.forEach((doc) => {
      lists.push(formatGroceryList(doc));
    });

    logger.info("Grocery lists fetched", {
      uid: req.user.uid,
      status: status ?? "all",
      limit,
      count: lists.length,
    });

    res.json({
      success: true,
      lists,
      count: lists.length,
    });
  } catch (error: any) {
    logger.error("Error getting grocery lists", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// GET /categories - Get all categories for user
app.get("/categories", authenticate, async (req, res) => {
  try {
    const snapshot = await db.collection(`users/${req.user.uid}/categories`)
      .orderBy("sortOrder")
      .get();

    const categories: any[] = [];

    snapshot.forEach((doc) => {
      categories.push({id: doc.id, ...doc.data()});
    });

    res.json({
      success: true,
      categories,
      count: categories.length,
    });
  } catch (error: any) {
    logger.error("Error getting categories", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// Locations endpoints
app.get("/locations", authenticate, async (req, res) => {
  try {
    const snapshot = await db.collection(`users/${req.user.uid}/locations`)
      .orderBy("sortOrder")
      .get();

    const locations = snapshot.docs.map((doc) => formatLocation(doc));

    res.json({
      success: true,
      locations,
      count: locations.length,
    });
  } catch (error: any) {
    logger.error("Error getting locations", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

app.put("/locations/:locationId", authenticate, async (req, res) => {
  try {
    const locationId = sanitizeDocumentId(req.params.locationId, 80);
    const docRef = db.doc(`users/${req.user.uid}/locations/${locationId}`);
    const existingDoc = await docRef.get();

    const sanitizedPayload = sanitizeLocationPayload(
      req.body,
      existingDoc.exists ? existingDoc.data() ?? null : null,
    );

    const timestamp = admin.firestore.FieldValue.serverTimestamp();
    const dataToWrite: Record<string, any> = {
      name: sanitizedPayload.name,
      color: sanitizedPayload.color,
      icon: sanitizedPayload.icon,
      temperature: sanitizedPayload.temperature,
      updatedAt: timestamp,
    };

    if (sanitizedPayload.sortOrder !== undefined && sanitizedPayload.sortOrder !== null) {
      dataToWrite.sortOrder = sanitizedPayload.sortOrder;
    }

    if (!existingDoc.exists) {
      dataToWrite.createdAt = timestamp;
    }

    await docRef.set(dataToWrite, {merge: true});

    const savedDoc = await docRef.get();
    res.json({
      success: true,
      location: formatLocation(savedDoc),
    });
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      return res.status(400).json({
        error: "Bad Request",
        message: error.message,
      });
    }

    logger.error("Error saving location", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

app.delete("/locations/:locationId", authenticate, async (req, res) => {
  try {
    const locationId = sanitizeDocumentId(req.params.locationId, 80);
    const docRef = db.doc(`users/${req.user.uid}/locations/${locationId}`);
    await docRef.delete();

    res.json({
      success: true,
      message: `Location ${locationId} deleted`,
    });
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      return res.status(400).json({
        error: "Bad Request",
        message: error.message,
      });
    }

    logger.error("Error deleting location", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// User preferences endpoints
app.get("/user/preferences", authenticate, async (req, res) => {
  try {
    const preferencesRef = db.doc(
      `users/${req.user.uid}/user_preferences/preferences`,
    );

    const [
      settingsDoc,
      savedSearchesSnapshot,
      customViewsSnapshot,
    ] = await Promise.all([
      preferencesRef.get(),
      preferencesRef.collection("saved_searches").get(),
      preferencesRef.collection("custom_views").get(),
    ]);

    const settings = settingsDoc.exists ?
      formatUserPreferences(settingsDoc) :
      null;

    const savedSearches = savedSearchesSnapshot.docs.map((doc) =>
      formatSavedSearch(doc),
    );
    const customViews = customViewsSnapshot.docs.map((doc) =>
      formatCustomView(doc),
    );

    res.json({
      success: true,
      settings,
      savedSearches,
      customViews,
    });
  } catch (error: any) {
    logger.error("Error fetching user preferences", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

app.put("/user/preferences/settings", authenticate, async (req, res) => {
  try {
    const preferencesRef = db.doc(
      `users/${req.user.uid}/user_preferences/preferences`,
    );
    const existingDoc = await preferencesRef.get();

    const sanitized = sanitizePreferencesSettingsPayload(req.body);
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    await preferencesRef.set(
      {
        ...sanitized,
        updatedAt: timestamp,
        ...(existingDoc.exists ? {} : {createdAt: timestamp}),
      },
      {merge: true},
    );

    const savedDoc = await preferencesRef.get();
    res.json({
      success: true,
      settings: formatUserPreferences(savedDoc),
    });
  } catch (error: any) {
    if (error instanceof functions.https.HttpsError) {
      return res.status(400).json({
        error: "Bad Request",
        message: error.message,
      });
    }

    logger.error("Error updating user preferences", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

app.put(
  "/user/preferences/saved-searches/:searchId",
  authenticate,
  async (req, res) => {
    try {
      const searchId = sanitizeDocumentId(req.params.searchId, 80);
      const preferencesRef = db.doc(
        `users/${req.user.uid}/user_preferences/preferences`,
      );
      const searchRef = preferencesRef.collection("saved_searches").doc(searchId);
      const existingDoc = await searchRef.get();

      const sanitized = sanitizeSavedSearchPayload(req.body);
      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      await searchRef.set(
        {
          ...sanitized,
          updatedAt: timestamp,
          ...(existingDoc.exists ? {} : {createdAt: timestamp}),
        },
        {merge: true},
      );

      const savedDoc = await searchRef.get();
      res.json({
        success: true,
        savedSearch: formatSavedSearch(savedDoc),
      });
    } catch (error: any) {
      if (error instanceof functions.https.HttpsError) {
        return res.status(400).json({
          error: "Bad Request",
          message: error.message,
        });
      }

      logger.error("Error saving saved search", {
        uid: req.user?.uid,
        error: error.message,
      });
      res.status(500).json({
        error: "Internal Server Error",
        message: error.message,
      });
    }
  },
);

app.delete(
  "/user/preferences/saved-searches/:searchId",
  authenticate,
  async (req, res) => {
    try {
      const searchId = sanitizeDocumentId(req.params.searchId, 80);
      const preferencesRef = db.doc(
        `users/${req.user.uid}/user_preferences/preferences`,
      );
      await preferencesRef.collection("saved_searches").doc(searchId).delete();

      res.json({
        success: true,
        message: `Saved search ${searchId} deleted`,
      });
    } catch (error: any) {
      if (error instanceof functions.https.HttpsError) {
        return res.status(400).json({
          error: "Bad Request",
          message: error.message,
        });
      }

      logger.error("Error deleting saved search", {
        uid: req.user?.uid,
        error: error.message,
      });
      res.status(500).json({
        error: "Internal Server Error",
        message: error.message,
      });
    }
  },
);

app.put(
  "/user/preferences/custom-views/:viewId",
  authenticate,
  async (req, res) => {
    try {
      const viewId = sanitizeDocumentId(req.params.viewId, 80);
      const preferencesRef = db.doc(
        `users/${req.user.uid}/user_preferences/preferences`,
      );
      const viewRef = preferencesRef.collection("custom_views").doc(viewId);
      const existingDoc = await viewRef.get();

      const sanitized = sanitizeCustomViewPayload(req.body);
      const timestamp = admin.firestore.FieldValue.serverTimestamp();

      await viewRef.set(
        {
          ...sanitized,
          updatedAt: timestamp,
          ...(existingDoc.exists ? {} : {createdAt: timestamp}),
        },
        {merge: true},
      );

      const savedDoc = await viewRef.get();
      res.json({
        success: true,
        customView: formatCustomView(savedDoc),
      });
    } catch (error: any) {
      if (error instanceof functions.https.HttpsError) {
        return res.status(400).json({
          error: "Bad Request",
          message: error.message,
        });
      }

      logger.error("Error saving custom view", {
        uid: req.user?.uid,
        error: error.message,
      });
      res.status(500).json({
        error: "Internal Server Error",
        message: error.message,
      });
    }
  },
);

app.delete(
  "/user/preferences/custom-views/:viewId",
  authenticate,
  async (req, res) => {
    try {
      const viewId = sanitizeDocumentId(req.params.viewId, 80);
      const preferencesRef = db.doc(
        `users/${req.user.uid}/user_preferences/preferences`,
      );
      await preferencesRef.collection("custom_views").doc(viewId).delete();

      res.json({
        success: true,
        message: `Custom view ${viewId} deleted`,
      });
    } catch (error: any) {
      if (error instanceof functions.https.HttpsError) {
        return res.status(400).json({
          error: "Bad Request",
          message: error.message,
        });
      }

      logger.error("Error deleting custom view", {
        uid: req.user?.uid,
        error: error.message,
      });
      res.status(500).json({
        error: "Internal Server Error",
        message: error.message,
      });
    }
  },
);

// POST /user/initialize - Initialize user data (first time setup)
app.post("/user/initialize", authenticate, async (req, res) => {
  try {
    const userId = req.user.uid;
    const userEmail = req.user.email;

    // Check if user already exists
    const userDoc = await db.doc(`users/${userId}`).get();

    if (userDoc.exists) {
      return res.json({
        success: true,
        message: "User already initialized",
        existing: true,
      });
    }

    // Create user document
    await db.doc(`users/${userId}`).set({
      email: userEmail,
      name: req.user.name || "User",
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      settings: {
        lowStockThreshold: 2,
        notifications: true,
        preferredUnits: {
          milk: "gallon",
          bread: "loaf",
          eggs: "dozen",
        },
      },
    });

    // Create default categories
    const categories = [
      {id: "dairy", name: "Dairy", color: "#FFE4B5", icon: "🥛"},
      {id: "produce", name: "Produce", color: "#90EE90", icon: "🥬"},
      {id: "meat", name: "Meat & Poultry", color: "#FFB6C1", icon: "🥩"},
      {id: "pantry", name: "Pantry", color: "#DEB887", icon: "🥫"},
      {id: "frozen", name: "Frozen", color: "#B0E0E6", icon: "❄️"},
      {id: "beverages", name: "Beverages", color: "#FFFFE0", icon: "🧃"},
      {id: "snacks", name: "Snacks", color: "#F0E68C", icon: "🍿"},
      {id: "bakery", name: "Bakery", color: "#FFDAB9", icon: "🍞"},
    ];

    const batch = db.batch();

    for (const category of categories) {
      const categoryRef = db.doc(`users/${userId}/categories/${category.id}`);
      batch.set(categoryRef, {
        ...category,
        sortOrder: categories.indexOf(category),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
    }

    await batch.commit();

    res.json({
      success: true,
      message: "User initialized successfully",
      existing: false,
      categoriesCreated: categories.length,
    });
  } catch (error: any) {
    logger.error("Error initializing user document", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// ============== OpenAI Agent Endpoints ==============

// POST /agent/parse - Parse inventory updates with confirmation
app.post("/agent/parse", authenticate, async (req, res) => {
  try {
    const {text} = req.body;

    if (!text) {
      return res.status(400).json({
        error: "Bad Request",
        message: "Text is required",
      });
    }

    const result = await updateInventoryWithConfirmation(req.user.uid, text);

    res.json(result);
  } catch (error: any) {
    logger.error("Error in agent parsing", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// POST /agent/process - Process any grocery-related request
app.post("/agent/process", authenticate, async (req, res) => {
  try {
    const {message, context} = req.body;

    if (!message) {
      return res.status(400).json({
        error: "Bad Request",
        message: "Message is required",
      });
    }

    const result = await processGroceryRequest(
      req.user.uid,
      message,
      context
    );

    res.json(result);
  } catch (error: any) {
    logger.error("Error processing agent request", {
      uid: req.user?.uid,
      error: error.message,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error.message,
    });
  }
});

// POST /agent/ingest - Use the ingestion agent to parse & apply updates directly
app.post("/agent/ingest", authenticate, async (req, res) => {
  try {
    const {text, metadata} = req.body ?? {};

    if (typeof text !== "string" || !text.trim()) {
      return res.status(400).json({
        error: "Bad Request",
        message: "Text is required for ingestion.",
      });
    }

    const pipelineResult = await executeAgentIngestionPipeline({
      userId: req.user.uid,
      text: text.trim(),
      metadata: sanitizeJobMetadata(metadata),
    });

    if (!pipelineResult.success) {
      return res.status(500).json({
        error: "Agent Error",
        message: pipelineResult.error ?? "Ingestion agent failed",
      });
    }

    res.json({
      success: true,
      response: pipelineResult.agentResponse,
      summary: pipelineResult.summary,
      usedFallback: pipelineResult.usedFallback,
      toolInvocations: pipelineResult.toolInvocations,
    });
  } catch (error: any) {
    logger.error("Error running ingestion agent", {
      uid: req.user?.uid,
      error: error?.message ?? error,
    });
    res.status(500).json({
      error: "Internal Server Error",
      message: error?.message ?? "Failed to run ingestion agent",
    });
  }
});

// Firestore trigger to acknowledge queued upload jobs
export const processUploadJobs = functions
  .runWith(runtimeOpts)
  .firestore.document("upload_jobs/{jobId}")
  .onCreate(async (snapshot, context) => {
    const data = snapshot.data() ?? {};
    const jobId = context.params.jobId;
    const uploadId = data.uploadId;
    const userId = data.userId;
    const logContext = {
      jobId,
      uploadId,
      userId,
    };

    if (!uploadId || !userId) {
      logger.error("Upload job missing identifiers", logContext);
      await snapshot.ref.update({
        status: UploadJobStatus.failed,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: "Missing uploadId or userId",
      });
      return;
    }

    const uploadRef = getUploadDocRef(userId, uploadId);

    try {
      const uploadSnap = await uploadRef.get();
      if (!uploadSnap.exists) {
        logger.error("Upload metadata missing for job", logContext);
        await snapshot.ref.update({
          status: UploadJobStatus.failed,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          error: "Upload metadata missing",
        });
        return;
      }

      const uploadData = uploadSnap.data() ?? {};
      const extraction = await extractTextFromUpload({
        userId,
        uploadId,
        bucket: uploadData.bucket,
        storagePath: uploadData.storagePath,
        contentType: uploadData.contentType,
        sourceType: uploadData.sourceType,
      });

      const ingestionJobRef = db
        .collection(`users/${userId}/ingestion_jobs`)
        .doc();

      await ingestionJobRef.set({
        text: extraction.text,
        metadata: {
          source: "upload",
          uploadId,
          storagePath: uploadData.storagePath ?? null,
          contentType: uploadData.contentType ?? null,
          sourceType: uploadData.sourceType ?? null,
          extraction: extraction.metadata,
        },
        status: IngestJobStatus.pending,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      await snapshot.ref.update({
        status: UploadJobStatus.completed,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        ingestionJobId: ingestionJobRef.id,
      });

      await uploadRef.update({
        status: UploadStatus.processing,
        processingJobId: jobId,
        processingStage: "ingestion_job_created",
        ingestionJobId: ingestionJobRef.id,
        textPreview: extraction.preview,
        lastError: null,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });

      logger.info("Upload job converted to ingestion job", {
        ...logContext,
        ingestionJobId: ingestionJobRef.id,
      });
    } catch (error: any) {
      logger.error("Error handling upload job", {
        ...logContext,
        error: error?.message ?? error,
      });

      await snapshot.ref.update({
        status: UploadJobStatus.failed,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        error: error?.message ?? "Unknown error",
      });

      await uploadRef.set({
        status: UploadStatus.failed,
        lastError: error?.message ?? "Failed to process upload job",
        processingStage: "failed",
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      }, {merge: true});
    }
  });


export const processIngestionJobs = functions
  .runWith(runtimeOpts)
  .firestore.document("users/{userId}/ingestion_jobs/{jobId}")
  .onCreate(async (snapshot, context) => {
    const {userId, jobId} = context.params;
    const data = snapshot.data() ?? {};
    const text = typeof data.text === "string" ? data.text : "";
    const metadata = typeof data.metadata === "object" ? data.metadata : {};
    const timestamp = admin.firestore.FieldValue.serverTimestamp();

    if (!text) {
      logger.error("Ingestion job missing text payload", {userId, jobId});
      await snapshot.ref.update({
        status: IngestJobStatus.failed,
        updatedAt: timestamp,
        lastError: "No text payload provided for ingestion.",
      });
      return;
    }

    try {
      await snapshot.ref.update({
        status: IngestJobStatus.processing,
        updatedAt: timestamp,
        lastError: null,
      });

      const pipelineResult = await executeAgentIngestionPipeline({
        userId,
        text,
        metadata,
      });

      if (pipelineResult.success) {
        await snapshot.ref.update({
          status: IngestJobStatus.completed,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          completedAt: admin.firestore.FieldValue.serverTimestamp(),
          agentResponse: pipelineResult.agentResponse ?? null,
          resultSummary: pipelineResult.summary,
          lastError: null,
          toolInvocations: pipelineResult.toolInvocations ?? [],
          fallbackApplied: pipelineResult.usedFallback,
          fallbackDetails: pipelineResult.fallbackDetails ?? null,
        });
      } else {
        await snapshot.ref.update({
          status: IngestJobStatus.failed,
          updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          lastError: pipelineResult.error ?? "Agent ingestion failed",
          toolInvocations: pipelineResult.toolInvocations ?? [],
          fallbackApplied: pipelineResult.usedFallback,
          fallbackDetails: pipelineResult.fallbackDetails ?? null,
        });
      }
    } catch (error: any) {
      logger.error("Error running ingestion job", {
        userId,
        jobId,
        error: error?.message ?? error,
      });
      await snapshot.ref.update({
        status: IngestJobStatus.failed,
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
        lastError: error?.message ?? "Failed to process ingestion job",
      });
    }
  });

export const agentInteractionMetrics = functions
  .runWith(runtimeOpts)
  .firestore.document("agent_interactions/{interactionId}")
  .onCreate(async (snapshot) => {
    const data = snapshot.data() ?? {};
    const eventDate = data.createdAt?.toDate ?
      data.createdAt.toDate() :
      new Date();

    const dailyRef = db.doc(`agent_metrics/daily/${formatDateKey(eventDate)}`);
    const globalRef = db.doc("agent_metrics/global");

    await Promise.all([
      updateAgentMetricsDoc(dailyRef, data, eventDate),
      updateAgentMetricsDoc(globalRef, data, eventDate),
    ]);
  });

// Export the Express app as a Firebase Function with secrets
export const api = functions
  .runWith(runtimeOpts)
  .https.onRequest(app);

export {app};

async function updateAgentMetricsDoc(
  docRef: FirebaseFirestore.DocumentReference,
  data: FirebaseFirestore.DocumentData,
  eventDate: Date,
) {
  await db.runTransaction(async (tx) => {
    const snapshot = await tx.get(docRef);
    const increment = admin.firestore.FieldValue.increment;
    const updates: Record<string, any> = {
      totalCount: increment(1),
      successCount: increment(data.success ? 1 : 0),
      fallbackCount: increment(data.usedFallback ? 1 : 0),
      updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      lastEventAt: admin.firestore.Timestamp.fromDate(eventDate),
    };

    const latency = Number.isFinite(data.latencyMs) ? Number(data.latencyMs) : null;
    if (latency !== null) {
      updates.sumLatencyMs = increment(latency);
      updates.latencySamples = increment(1);
      updates[`latencyBuckets.${getLatencyBucketKey(latency)}`] = increment(1);
    }

    const confidence = Number.isFinite(data.confidence) ? Number(data.confidence) : null;
    if (confidence !== null) {
      updates.sumConfidence = increment(confidence);
      updates.confidenceSamples = increment(1);
      updates[`confidenceBuckets.${getConfidenceBucketKey(confidence)}`] = increment(1);
    }

    if (typeof data.agent === "string" && data.agent) {
      updates[`perAgent.${data.agent}.count`] = increment(1);
      updates[`perAgent.${data.agent}.success`] = increment(data.success ? 1 : 0);
      updates[`perAgent.${data.agent}.fallback`] = increment(data.usedFallback ? 1 : 0);
    }

    tx.set(docRef, {
      ...(snapshot.exists ? {} : {createdAt: admin.firestore.FieldValue.serverTimestamp()}),
      ...updates,
    }, {merge: true});
  });
}
