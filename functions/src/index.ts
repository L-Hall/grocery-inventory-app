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
import {formatInventoryItem, formatGroceryList} from "./utils/formatters";
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
      await applyInventoryUpdatesForUser(req.user.uid, updates);

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
      await applyInventoryUpdatesForUser(req.user.uid, updates);

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
