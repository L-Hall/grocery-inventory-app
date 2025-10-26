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
import {processGroceryRequest, updateInventoryWithConfirmation} from "./agents";
import {
  formatInventoryItem,
  formatGroceryList,
  formatLocation,
  formatUserPreferences,
  formatSavedSearch,
  formatCustomView,
} from "./utils/formatters";
import {generateSearchKeywords} from "./utils/search";
import {createAuthenticateMiddleware} from "./middleware/authenticate";

// Initialize Firebase Admin SDK
if (admin.apps.length === 0) {
  admin.initializeApp();
}
const db = admin.firestore();
const auth = admin.auth();

const app = express();

const DEFAULT_QUERY_LIMIT = 100;
const MAX_QUERY_LIMIT = 500;

const parseLimit = (value: any): number => {
  const numeric = Number(value);
  if (!Number.isFinite(numeric) || numeric <= 0) {
    return DEFAULT_QUERY_LIMIT;
  }
  return Math.min(Math.floor(numeric), MAX_QUERY_LIMIT);
};

const normalizeExpirationDateValue = (
  value: any,
): string | null | undefined => {
  if (value === undefined) {
    return undefined;
  }
  if (value === null || value === "") {
    return null;
  }

  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
    throw new Error(
      `Invalid expiration date: "${value}" (expected ISO 8601 format)`,
    );
  }

  if (typeof value === "number") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
    throw new Error(
      "Invalid expiration date: numeric value could not be parsed",
    );
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (value?.seconds) {
    const milliseconds = value.seconds * 1000 + (value.nanoseconds ?? 0) / 1e6;
    const parsed = new Date(milliseconds);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }

  if (value?._seconds) {
    const milliseconds =
      value._seconds * 1000 + (value._nanoseconds ?? 0) / 1e6;
    const parsed = new Date(milliseconds);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }

  throw new Error(
    "Invalid expiration date format: provide ISO string or timestamp",
  );
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

async function recordInventoryAuditLog(
  uid: string,
  data: {
    action: "inventory_update" | "inventory_apply";
    updates: any[];
    results: Record<string, any>[];
    summary: {total: number; successful: number; failed: number};
    validationErrors: string[];
  },
) {
  try {
    if (!Array.isArray(data.results) || data.results.length === 0) {
      return;
    }

    const successfulItemIds = data.results
      .filter(
        (result) => result.success && typeof result.id === "string" && result.id,
      )
      .map((result) => result.id as string)
      .slice(0, 100);

    const truncatedResults = data.results.slice(0, 50).map((result) => ({
      id: result.id ?? null,
      name: result.name ?? null,
      success: Boolean(result.success),
      action: result.action ?? null,
      quantity:
        typeof result.quantity === "number" ?
          result.quantity :
          Number.isFinite(Number(result.quantity)) ?
            Number(result.quantity) :
            null,
      message: result.message ?? null,
      error: result.error ?? null,
    }));

    const truncatedRequestedUpdates = Array.isArray(data.updates) ?
      data.updates.slice(0, 50).map((update) => ({
        name: typeof update?.name === "string" ? update.name : null,
        action: typeof update?.action === "string" ? update.action : null,
        quantity:
          typeof update?.quantity === "number" ?
            update.quantity :
            Number.isFinite(Number(update?.quantity)) ?
              Number(update?.quantity) :
              null,
        unit: typeof update?.unit === "string" ? update.unit : null,
        category: typeof update?.category === "string" ? update.category : null,
      })) :
      [];

    const description = `Processed ${data.summary.successful}/${data.summary.total} inventory updates (${data.action})`;

    await db.collection(`users/${uid}/audit_logs`).add({
      action: data.action,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      userId: uid,
      itemIds: successfulItemIds,
      description: description.slice(0, 500),
      metadata: {
        summary: data.summary,
        validationErrors: data.validationErrors,
        results: truncatedResults,
        requestedUpdates: truncatedRequestedUpdates,
      },
    });
  } catch (error: any) {
    logger.error("Failed to record audit log entry", {
      uid,
      error: error?.message ?? String(error),
    });
  }
}

async function processInventoryUpdate(
  uid: string,
  update: Record<string, any>,
): Promise<Record<string, any>> {
  if (!update || typeof update !== "object") {
    return {
      name: update?.name ?? "unknown",
      success: false,
      error: "Invalid update payload",
    };
  }

  const name = String(update.name ?? "").trim();
  const providedQuantity = update.quantity;
  const action = String(update.action ?? "").toLowerCase();

  if (!name || providedQuantity === undefined || !action) {
    return {
      name: name || update.name || "unknown",
      success: false,
      error: "Missing required fields: name, quantity, action",
    };
  }

  if (!["add", "subtract", "set"].includes(action)) {
    return {
      name,
      success: false,
      error: `Invalid action "${action}". Use add, subtract, or set.`,
    };
  }

  const quantity = Number(providedQuantity);
  if (!Number.isFinite(quantity) || quantity < 0) {
    return {
      name,
      success: false,
      error: "Quantity must be a non-negative number",
    };
  }

  let normalizedExpiration: string | null | undefined;
  try {
    normalizedExpiration = normalizeExpirationDateValue(
      update.expirationDate ?? update.expiryDate,
    );
  } catch (error: any) {
    return {
      name,
      success: false,
      error: error.message ?? "Invalid expiration date",
    };
  }

  const inventoryCollection = db.collection(`users/${uid}/inventory`);
  const snapshot = await inventoryCollection.get();

  let existingDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  for (const doc of snapshot.docs) {
    const docName = String(doc.data().name ?? "").toLowerCase();
    if (docName === name.toLowerCase()) {
      existingDoc = doc;
      break;
    }
  }

  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  if (!existingDoc) {
    const newItem: Record<string, any> = {
      name,
      quantity,
      unit: update.unit ?? "unit",
      category: update.category ?? "uncategorized",
      location: update.location ?? null,
      lowStockThreshold:
        Number.isFinite(Number(update.lowStockThreshold)) ?
          Number(update.lowStockThreshold) :
          1,
      notes: update.notes ?? null,
      brand: update.brand ?? null,
      size: update.size ?? null,
      expirationDate: normalizedExpiration ?? null,
      searchKeywords: generateSearchKeywords(name),
      createdAt: timestamp,
      updatedAt: timestamp,
      lastUpdated: timestamp,
    };

    const docRef = await inventoryCollection.add(newItem);

    return {
      id: docRef.id,
      name,
      success: true,
      action: "created",
      quantity,
      expirationDate: newItem.expirationDate,
      message: `Added ${name}: ${quantity} ${newItem.unit}`,
    };
  }

  const currentData = existingDoc.data();
  let newQuantity = Number(currentData.quantity ?? 0);

  switch (action) {
  case "add":
    newQuantity += quantity;
    break;
  case "subtract":
    newQuantity = Math.max(0, newQuantity - quantity);
    break;
  case "set":
    newQuantity = quantity;
    break;
  default:
    newQuantity = quantity;
  }

  const updateData: Record<string, any> = {
    quantity: newQuantity,
    updatedAt: timestamp,
    lastUpdated: timestamp,
    searchKeywords: generateSearchKeywords(name),
  };

  if (update.unit !== undefined) updateData.unit = update.unit;
  if (update.category !== undefined) updateData.category = update.category;
  if (update.location !== undefined) updateData.location = update.location;
  if (update.brand !== undefined) updateData.brand = update.brand;
  if (update.notes !== undefined) updateData.notes = update.notes;
  if (update.size !== undefined) updateData.size = update.size;
  if (update.lowStockThreshold !== undefined) {
    updateData.lowStockThreshold = Number(update.lowStockThreshold);
  }
  if (normalizedExpiration !== undefined) {
    updateData.expirationDate = normalizedExpiration;
  }

  await existingDoc.ref.update(updateData);

  const actionText =
    action === "add" ?
      "Added" :
      action === "subtract" ?
        "Used" :
        "Set";

  return {
    id: existingDoc.id,
    name,
    success: true,
    action: "updated",
    quantity: newQuantity,
    expirationDate:
      updateData.expirationDate ??
      normalizeExpirationDateValue(currentData.expirationDate) ??
      null,
    message: `${actionText} ${name}: now ${newQuantity} ${update.unit ?? currentData.unit ?? "unit"}`,
  };
}

async function applyInventoryUpdatesForUser(
  uid: string,
  updates: any[],
  actionType: "inventory_update" | "inventory_apply" = "inventory_update",
): Promise<{
  results: Record<string, any>[];
  summary: {total: number; successful: number; failed: number};
  validationErrors: string[];
}> {
  const results: Record<string, any>[] = [];

  for (const update of updates) {
    try {
      const result = await processInventoryUpdate(uid, update);
      results.push(result);
    } catch (error: any) {
      results.push({
        name: update?.name ?? "unknown",
        success: false,
        error: error.message ?? "Failed to process update",
      });
    }
  }

  const successful = results.filter((r) => r.success).length;
  const failed = results.length - successful;
  const validationErrors = results
    .filter((r) => !r.success && r.error)
    .map((r) => `${r.name}: ${r.error}`);

  await recordInventoryAuditLog(uid, {
    action: actionType,
    updates,
    results,
    summary: {
      total: results.length,
      successful,
      failed,
    },
    validationErrors,
  });

  return {
    results,
    summary: {
      total: results.length,
      successful,
      failed,
    },
    validationErrors,
  };
}

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


// Export the Express app as a Firebase Function with secrets
export const api = functions
  .runWith(runtimeOpts)
  .https.onRequest(app);

export {app};
