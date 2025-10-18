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
    let query: any = db.collection(`users/${req.user.uid}/inventory`);

    // Apply filters
    if (category) {
      query = query.where("category", "==", category);
    }

    if (location) {
      query = query.where("location", "==", location);
    }

    // Order by last updated and apply limit for performance
    query = query.orderBy("lastUpdated", "desc");
    const limit = parseLimit(req.query.limit);
    query = query.limit(limit);

    const snapshot = await query.get();
    const items: any[] = [];

    snapshot.forEach((doc) => {
      const item = formatInventoryItem(doc);

      if (search && !item.name.toLowerCase().includes((search as string).toLowerCase())) {
        return;
      }

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

// POST /inventory/update - Update inventory items
app.post("/inventory/update", authenticate, async (req, res) => {
  try {
    const {updates} = req.body;

    if (!Array.isArray(updates)) {
      return res.status(400).json({
        error: "Bad Request",
        message: "Updates must be an array",
      });
    }

    const results: any[] = [];

    for (const update of updates) {
      try {
        // Validate required fields
        if (!update.name || update.quantity === undefined || !update.action) {
          results.push({
            name: update.name || "unknown",
            success: false,
            error: "Missing required fields: name, quantity, action",
          });
          continue;
        }

        // Search for existing item by name (case-insensitive)
        const query = await db.collection(`users/${req.user.uid}/inventory`).get();

        let existingDoc = null;
        for (const doc of query.docs) {
          if (doc.data().name.toLowerCase() === update.name.toLowerCase()) {
            existingDoc = doc;
            break;
          }
        }

        if (!existingDoc) {
          const timestamp = admin.firestore.FieldValue.serverTimestamp();

          // Create new item
          const newItem = {
            name: update.name,
            quantity: update.quantity,
            unit: update.unit ?? "unit",
            category: update.category ?? "uncategorized",
            location: update.location ?? "pantry",
            lowStockThreshold: update.lowStockThreshold ?? 1,
            notes: update.notes ?? null,
            brand: update.brand ?? null,
            size: update.size ?? null,
            expirationDate: update.expirationDate ?? null,
            createdAt: timestamp,
            updatedAt: timestamp,
            lastUpdated: timestamp,
          };

          const docRef = await db.collection(`users/${req.user.uid}/inventory`).add(newItem);

          results.push({
            id: docRef.id,
            name: update.name,
            success: true,
            action: "created",
            quantity: update.quantity,
            message: `Added ${update.name}: ${update.quantity} ${update.unit || "unit"}`,
          });
        } else {
          // Update existing item
          const currentData = existingDoc.data();
          let newQuantity = currentData.quantity || 0;

          switch (update.action) {
          case "add":
            newQuantity += update.quantity;
            break;
          case "subtract":
            newQuantity = Math.max(0, newQuantity - update.quantity);
            break;
          case "set":
            newQuantity = update.quantity;
            break;
          default:
            throw new Error(`Invalid action: ${update.action}`);
          }

          const updateData: any = {
            quantity: newQuantity,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          updateData.lastUpdated = updateData.updatedAt;

          // Update optional fields if provided
          if (update.unit !== undefined) updateData.unit = update.unit;
          if (update.category !== undefined) updateData.category = update.category;
          if (update.location !== undefined) updateData.location = update.location;
          if (update.brand !== undefined) updateData.brand = update.brand;
          if (update.notes !== undefined) updateData.notes = update.notes;
          if (update.size !== undefined) updateData.size = update.size;
          if (update.expirationDate !== undefined) updateData.expirationDate = update.expirationDate;
          if (update.lowStockThreshold !== undefined) updateData.lowStockThreshold = update.lowStockThreshold;

          await existingDoc.ref.update(updateData);

          const actionText = update.action === "add" ? "Added" :
            update.action === "subtract" ? "Used" : "Set";

          results.push({
            id: existingDoc.id,
            name: update.name,
            success: true,
            action: "updated",
            quantity: newQuantity,
            message: `${actionText} ${update.name}: now ${newQuantity} ${update.unit ?? currentData.unit ?? "unit"}`,
          });
        }
      } catch (error: any) {
        results.push({
          name: update.name,
          success: false,
          error: error.message,
        });
      }
    }

    const successCount = results.filter((r) => r.success).length;
    const failureCount = results.filter((r) => !r.success).length;

    res.json({
      success: failureCount === 0,
      results,
      summary: {
        total: results.length,
        successful: successCount,
        failed: failureCount,
      },
    });
  } catch (error: any) {
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

// POST /inventory/parse - Parse natural language input or image using OpenAI
app.post("/inventory/parse", authenticate, async (req, res) => {
  try {
    const {text, image, imageType} = req.body;

    // Validate input - must have either text or image
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

    // Get OpenAI API key from Secret Manager (never from client)
    const apiKey = await getSecret(SECRETS.OPENAI_API_KEY);

    if (!apiKey) {
      // If no API key configured, use fallback parser for text only
      if (text) {
        logger.warn("OPENAI_API_KEY missing - using fallback parser", {
          uid: req.user.uid,
        });
        const parser = new GroceryParser("");
        const parseResult = await parser.parseGroceryText(text);

        const validatedItems = parser.validateItems(parseResult.items);
        const warnings: string[] = ["Using basic parser. Configure OPENAI_API_KEY for better results."];
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
          message: "Using basic parser. Configure OPENAI_API_KEY for better results.",
        });
      } else {
        return res.status(500).json({
          error: "Configuration Error",
          message: "Image processing requires OpenAI API key to be configured",
        });
      }
    }

    // Initialize the grocery parser with server-side API key
    const parser = new GroceryParser(apiKey);

    // Parse based on input type
    let parseResult;
    if (text) {
      parseResult = await parser.parseGroceryText(text);
    } else {
      // Parse image using GPT-4V
      parseResult = await parser.parseGroceryImage(image, imageType || "receipt");
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
