/**
 * Firebase Functions for Grocery Inventory App
 * 
 * Provides REST API endpoints for the Flutter app to interact with Firestore
 * Uses the same logic as the MCP server for consistency
 */

import * as functions from 'firebase-functions';
import * as admin from 'firebase-admin';
import express from 'express';
import cors from 'cors';
import { GroceryParser } from './ai-parser';

// Initialize Firebase Admin SDK
admin.initializeApp();
const db = admin.firestore();
const auth = admin.auth();

const app = express();

// Configure CORS for Flutter app
app.use(cors({ 
  origin: true,  // Allow all origins for development
  credentials: true 
}));

app.use(express.json());

// Middleware to verify Firebase Auth token
const authenticate = async (req: any, res: any, next: any) => {
  try {
    const authHeader = req.headers.authorization;
    if (!authHeader || !authHeader.startsWith('Bearer ')) {
      return res.status(401).json({ 
        error: 'Unauthorized', 
        message: 'Missing or invalid authorization header' 
      });
    }

    const token = authHeader.split('Bearer ')[1];
    const decodedToken = await auth.verifyIdToken(token);
    req.user = decodedToken;
    next();
  } catch (error: any) {
    console.error('Authentication error:', error);
    res.status(401).json({ 
      error: 'Unauthorized', 
      message: 'Invalid token',
      details: error.message 
    });
  }
};

// Health check endpoint
app.get('/health', (req, res) => {
  res.json({ 
    status: 'healthy', 
    timestamp: new Date().toISOString(),
    service: 'grocery-inventory-api'
  });
});

// GET /inventory - List all inventory items with optional filters
app.get('/inventory', authenticate, async (req, res) => {
  try {
    const { category, location, lowStockOnly, search } = req.query;
    let query: any = db.collection(`users/${req.user.uid}/inventory`);
    
    // Apply filters
    if (category) {
      query = query.where('category', '==', category);
    }
    
    if (location) {
      query = query.where('location', '==', location);
    }
    
    // Order by last updated
    query = query.orderBy('lastUpdated', 'desc');
    
    const snapshot = await query.get();
    const items: any[] = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      
      // Apply search filter
      if (search && !data.name.toLowerCase().includes((search as string).toLowerCase())) {
        return;
      }
      
      // Apply low stock filter
      if (lowStockOnly === 'true') {
        if (data.quantity <= (data.lowStockThreshold || 1)) {
          items.push({ id: doc.id, ...data });
        }
      } else {
        items.push({ id: doc.id, ...data });
      }
    });
    
    res.json({ 
      success: true,
      items,
      count: items.length 
    });
  } catch (error: any) {
    console.error('Error listing inventory:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    });
  }
});

// POST /inventory/update - Update inventory items
app.post('/inventory/update', authenticate, async (req, res) => {
  try {
    const { updates } = req.body;
    
    if (!Array.isArray(updates)) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Updates must be an array'
      });
    }
    
    const results: any[] = [];
    
    for (const update of updates) {
      try {
        // Validate required fields
        if (!update.name || update.quantity === undefined || !update.action) {
          results.push({
            name: update.name || 'unknown',
            success: false,
            error: 'Missing required fields: name, quantity, action'
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
          // Create new item
          const newItem = {
            name: update.name,
            quantity: update.quantity,
            unit: update.unit || 'unit',
            category: update.category || 'uncategorized',
            location: update.location || 'pantry',
            lowStockThreshold: update.lowStockThreshold || 1,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            ...(update.brand && { brand: update.brand }),
            ...(update.notes && { notes: update.notes })
          };
          
          const docRef = await db.collection(`users/${req.user.uid}/inventory`).add(newItem);
          
          results.push({
            id: docRef.id,
            name: update.name,
            success: true,
            action: 'created',
            quantity: update.quantity,
            message: `Added ${update.name}: ${update.quantity} ${update.unit || 'unit'}`
          });
        } else {
          // Update existing item
          const currentData = existingDoc.data();
          let newQuantity = currentData.quantity || 0;
          
          switch (update.action) {
            case 'add':
              newQuantity += update.quantity;
              break;
            case 'subtract':
              newQuantity = Math.max(0, newQuantity - update.quantity);
              break;
            case 'set':
              newQuantity = update.quantity;
              break;
            default:
              throw new Error(`Invalid action: ${update.action}`);
          }
          
          const updateData: any = {
            quantity: newQuantity,
            lastUpdated: admin.firestore.FieldValue.serverTimestamp()
          };
          
          // Update optional fields if provided
          if (update.unit) updateData.unit = update.unit;
          if (update.category) updateData.category = update.category;
          if (update.location) updateData.location = update.location;
          if (update.brand) updateData.brand = update.brand;
          if (update.notes) updateData.notes = update.notes;
          if (update.lowStockThreshold !== undefined) updateData.lowStockThreshold = update.lowStockThreshold;
          
          await existingDoc.ref.update(updateData);
          
          const actionText = update.action === 'add' ? 'Added' : 
                            update.action === 'subtract' ? 'Used' : 'Set';
          
          results.push({
            id: existingDoc.id,
            name: update.name,
            success: true,
            action: 'updated',
            quantity: newQuantity,
            message: `${actionText} ${update.name}: now ${newQuantity} ${currentData.unit || 'unit'}`
          });
        }
      } catch (error: any) {
        results.push({
          name: update.name,
          success: false,
          error: error.message
        });
      }
    }
    
    const successCount = results.filter(r => r.success).length;
    const failureCount = results.filter(r => !r.success).length;
    
    res.json({ 
      success: failureCount === 0,
      results,
      summary: {
        total: results.length,
        successful: successCount,
        failed: failureCount
      }
    });
  } catch (error: any) {
    console.error('Error updating inventory:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    });
  }
});

// POST /inventory/parse - Parse natural language input using OpenAI
app.post('/inventory/parse', authenticate, async (req, res) => {
  try {
    const { text, openaiApiKey } = req.body;
    
    if (!text || typeof text !== 'string') {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'Text field is required and must be a string'
      });
    }
    
    // Use OpenAI API key from request or environment
    const apiKey = openaiApiKey || functions.config().openai?.apikey || process.env.OPENAI_API_KEY;
    
    if (!apiKey) {
      return res.status(400).json({
        error: 'Bad Request',
        message: 'OpenAI API key is required. Provide it in the request body or set OPENAI_API_KEY environment variable.'
      });
    }
    
    // Initialize the grocery parser
    const parser = new GroceryParser(apiKey);
    
    // Parse the text
    const parseResult = await parser.parseGroceryText(text);
    
    // Validate and clean the items
    const validatedItems = parser.validateItems(parseResult.items);
    
    const response = {
      success: true,
      parsed: {
        ...parseResult,
        items: validatedItems
      },
      message: parseResult.error ? 
        'Parsed using fallback method. Please review carefully.' :
        parseResult.needsReview ? 
          'Text parsed successfully. Please review the items before confirming.' :
          'Text parsed successfully with high confidence.'
    };
    
    res.json(response);
  } catch (error: any) {
    console.error('Error parsing text:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    });
  }
});

// GET /inventory/low-stock - Get low stock items
app.get('/inventory/low-stock', authenticate, async (req, res) => {
  try {
    const { includeOutOfStock = 'true' } = req.query;
    
    const snapshot = await db.collection(`users/${req.user.uid}/inventory`)
      .orderBy('category')
      .get();
    
    const lowStock: any[] = [];
    
    snapshot.forEach(doc => {
      const data = doc.data();
      const threshold = data.lowStockThreshold || 1;
      
      if (data.quantity <= threshold) {
        if (includeOutOfStock === 'false' && data.quantity === 0) {
          return; // Skip out of stock items if not requested
        }
        lowStock.push({ id: doc.id, ...data });
      }
    });
    
    res.json({ 
      success: true,
      items: lowStock,
      count: lowStock.length 
    });
  } catch (error: any) {
    console.error('Error getting low stock items:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    });
  }
});

// POST /grocery-lists - Create a new grocery list
app.post('/grocery-lists', authenticate, async (req, res) => {
  try {
    const { name = 'Shopping List', fromLowStock = true, customItems = [] } = req.body;
    
    const listItems: any[] = [];
    
    // Add low stock items if requested
    if (fromLowStock) {
      const snapshot = await db.collection(`users/${req.user.uid}/inventory`)
        .orderBy('category')
        .get();
      
      snapshot.forEach(doc => {
        const data = doc.data();
        if (data.quantity <= (data.lowStockThreshold || 1)) {
          listItems.push({
            name: data.name,
            quantity: (data.lowStockThreshold || 1) - data.quantity + 1,
            unit: data.unit,
            category: data.category,
            checked: false,
            notes: data.quantity === 0 ? 'Out of stock' : 'Running low'
          });
        }
      });
    }
    
    // Add custom items
    for (const item of customItems) {
      listItems.push({
        name: item.name,
        quantity: item.quantity,
        unit: item.unit || 'unit',
        category: item.category || 'uncategorized',
        checked: false,
        notes: item.notes || ''
      });
    }
    
    if (listItems.length === 0) {
      return res.json({
        success: true,
        message: 'No items to add to grocery list. Everything is well stocked!',
        list: null
      });
    }
    
    // Create the grocery list in database
    const docRef = await db.collection(`users/${req.user.uid}/grocery_lists`).add({
      name,
      status: 'active',
      items: listItems,
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    
    res.json({ 
      success: true,
      list: {
        id: docRef.id,
        name,
        status: 'active',
        items: listItems,
        itemCount: listItems.length
      },
      message: `Created grocery list "${name}" with ${listItems.length} items`
    });
  } catch (error: any) {
    console.error('Error creating grocery list:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    });
  }
});

// GET /grocery-lists - Get all grocery lists for user
app.get('/grocery-lists', authenticate, async (req, res) => {
  try {
    const { status } = req.query;
    
    let query: any = db.collection(`users/${req.user.uid}/grocery_lists`)
      .orderBy('createdAt', 'desc');
    
    if (status) {
      query = query.where('status', '==', status);
    }
    
    const snapshot = await query.get();
    const lists: any[] = [];
    
    snapshot.forEach(doc => {
      lists.push({ id: doc.id, ...doc.data() });
    });
    
    res.json({ 
      success: true,
      lists,
      count: lists.length 
    });
  } catch (error: any) {
    console.error('Error getting grocery lists:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    });
  }
});

// GET /categories - Get all categories for user
app.get('/categories', authenticate, async (req, res) => {
  try {
    const snapshot = await db.collection(`users/${req.user.uid}/categories`)
      .orderBy('sortOrder')
      .get();
    
    const categories: any[] = [];
    
    snapshot.forEach(doc => {
      categories.push({ id: doc.id, ...doc.data() });
    });
    
    res.json({ 
      success: true,
      categories,
      count: categories.length 
    });
  } catch (error: any) {
    console.error('Error getting categories:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    });
  }
});

// POST /user/initialize - Initialize user data (first time setup)
app.post('/user/initialize', authenticate, async (req, res) => {
  try {
    const userId = req.user.uid;
    const userEmail = req.user.email;
    
    // Check if user already exists
    const userDoc = await db.doc(`users/${userId}`).get();
    
    if (userDoc.exists) {
      return res.json({
        success: true,
        message: 'User already initialized',
        existing: true
      });
    }
    
    // Create user document
    await db.doc(`users/${userId}`).set({
      email: userEmail,
      name: req.user.name || 'User',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      settings: {
        lowStockThreshold: 2,
        notifications: true,
        preferredUnits: {
          milk: 'gallon',
          bread: 'loaf',
          eggs: 'dozen'
        }
      }
    });
    
    // Create default categories
    const categories = [
      { id: 'dairy', name: 'Dairy', color: '#FFE4B5', icon: '🥛' },
      { id: 'produce', name: 'Produce', color: '#90EE90', icon: '🥬' },
      { id: 'meat', name: 'Meat & Poultry', color: '#FFB6C1', icon: '🥩' },
      { id: 'pantry', name: 'Pantry', color: '#DEB887', icon: '🥫' },
      { id: 'frozen', name: 'Frozen', color: '#B0E0E6', icon: '❄️' },
      { id: 'beverages', name: 'Beverages', color: '#FFFFE0', icon: '🧃' },
      { id: 'snacks', name: 'Snacks', color: '#F0E68C', icon: '🍿' },
      { id: 'bakery', name: 'Bakery', color: '#FFDAB9', icon: '🍞' }
    ];
    
    const batch = db.batch();
    
    for (const category of categories) {
      const categoryRef = db.doc(`users/${userId}/categories/${category.id}`);
      batch.set(categoryRef, {
        ...category,
        sortOrder: categories.indexOf(category),
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    
    await batch.commit();
    
    res.json({
      success: true,
      message: 'User initialized successfully',
      existing: false,
      categoriesCreated: categories.length
    });
  } catch (error: any) {
    console.error('Error initializing user:', error);
    res.status(500).json({ 
      error: 'Internal Server Error',
      message: error.message 
    });
  }
});

// Export the Express app as a Firebase Function
export const api = functions.https.onRequest(app);