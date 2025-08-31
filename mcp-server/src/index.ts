#!/usr/bin/env node

/**
 * Grocery Inventory MCP Server
 * 
 * This server provides Claude with tools to interact with your grocery inventory
 * Replicates the functionality of your Airtable MCP setup but with Firebase backend
 */

import { Server } from '@modelcontextprotocol/sdk/server/index.js';
import { StdioServerTransport } from '@modelcontextprotocol/sdk/server/stdio.js';
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from '@modelcontextprotocol/sdk/types.js';
import { initializeApp, cert, ServiceAccount } from 'firebase-admin/app';
import { getFirestore, Firestore } from 'firebase-admin/firestore';
import { readFileSync } from 'fs';
import { fileURLToPath } from 'url';
import { dirname, join } from 'path';
import dotenv from 'dotenv';

// Load environment variables
dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = dirname(__filename);

// Initialize Firebase Admin
let db: Firestore;

try {
  const serviceAccountPath = process.env.FIREBASE_CREDENTIALS_PATH!;
  const serviceAccount = JSON.parse(readFileSync(serviceAccountPath, 'utf8')) as ServiceAccount;
  
  initializeApp({
    credential: cert(serviceAccount),
    projectId: process.env.FIREBASE_PROJECT_ID
  });
  
  db = getFirestore();
  console.error('✅ Firebase initialized successfully');
} catch (error) {
  console.error('❌ Failed to initialize Firebase:', error);
  process.exit(1);
}

const USER_ID = process.env.USER_ID || 'demo-user-123';

// Create MCP Server
const server = new Server(
  {
    name: 'grocery-inventory',
    version: '1.0.0',
  },
  {
    capabilities: {
      tools: {},
    },
  }
);

// Define available tools (matching your Airtable MCP workflow)
server.setRequestHandler(ListToolsRequestSchema, async () => ({
  tools: [
    {
      name: 'list_inventory',
      description: 'List all items in your grocery inventory with optional filters',
      inputSchema: {
        type: 'object',
        properties: {
          category: { 
            type: 'string',
            description: 'Filter by category (dairy, produce, meat, pantry, frozen, beverages, snacks, bakery)'
          },
          location: { 
            type: 'string',
            description: 'Filter by location (fridge, freezer, pantry, counter)'
          },
          lowStockOnly: { 
            type: 'boolean',
            description: 'Only show items that are low or out of stock'
          },
          search: {
            type: 'string',
            description: 'Search for items by name'
          }
        }
      }
    },
    {
      name: 'update_inventory',
      description: 'Update quantities of items in inventory after grocery shopping or consumption',
      inputSchema: {
        type: 'object',
        properties: {
          updates: {
            type: 'array',
            description: 'Array of items to update',
            items: {
              type: 'object',
              properties: {
                name: { 
                  type: 'string',
                  description: 'Item name (e.g., "milk", "bread", "eggs")'
                },
                quantity: { 
                  type: 'number',
                  description: 'Quantity to add, subtract, or set'
                },
                action: { 
                  type: 'string',
                  enum: ['add', 'subtract', 'set'],
                  description: 'How to modify the quantity: add (bought items), subtract (consumed items), set (exact amount)'
                },
                unit: { 
                  type: 'string',
                  description: 'Unit of measurement (gallon, loaf, dozen, count, bag, etc.)'
                },
                category: { 
                  type: 'string',
                  description: 'Category for new items (dairy, produce, meat, etc.)'
                },
                location: { 
                  type: 'string',
                  description: 'Storage location (fridge, freezer, pantry, counter)'
                },
                brand: {
                  type: 'string',
                  description: 'Brand name or specific variety'
                },
                notes: {
                  type: 'string',
                  description: 'Additional notes about the item'
                }
              },
              required: ['name', 'quantity', 'action']
            }
          }
        },
        required: ['updates']
      }
    },
    {
      name: 'get_low_stock',
      description: 'Get all items that are running low or completely out of stock',
      inputSchema: {
        type: 'object',
        properties: {
          includeOutOfStock: {
            type: 'boolean',
            description: 'Include items that are completely out of stock (quantity = 0)',
            default: true
          }
        }
      }
    },
    {
      name: 'search_inventory',
      description: 'Search for specific items in your inventory',
      inputSchema: {
        type: 'object',
        properties: {
          searchTerm: {
            type: 'string',
            description: 'Search term to find items'
          },
          maxResults: {
            type: 'number',
            description: 'Maximum number of results to return',
            default: 20
          }
        },
        required: ['searchTerm']
      }
    },
    {
      name: 'create_grocery_list',
      description: 'Create a new grocery shopping list from low stock items or custom items',
      inputSchema: {
        type: 'object',
        properties: {
          name: {
            type: 'string',
            description: 'Name for the grocery list (e.g., "Weekly Shopping", "Quick Trip")'
          },
          fromLowStock: {
            type: 'boolean',
            description: 'Generate list from current low stock items',
            default: true
          },
          customItems: {
            type: 'array',
            description: 'Custom items to add to the list',
            items: {
              type: 'object',
              properties: {
                name: { type: 'string' },
                quantity: { type: 'number' },
                unit: { type: 'string' },
                notes: { type: 'string' }
              },
              required: ['name', 'quantity']
            }
          }
        }
      }
    }
  ],
}));

// Implement tool handlers
server.setRequestHandler(CallToolRequestSchema, async (request) => {
  const { name, arguments: args } = request.params;

  try {
    switch (name) {
      case 'list_inventory':
        return await handleListInventory(args as any);
      
      case 'update_inventory':
        return await handleUpdateInventory(args as any);
      
      case 'get_low_stock':
        return await handleGetLowStock(args as any);
      
      case 'search_inventory':
        return await handleSearchInventory(args as any);
      
      case 'create_grocery_list':
        return await handleCreateGroceryList(args as any);
      
      default:
        throw new Error(`Unknown tool: ${name}`);
    }
  } catch (error: any) {
    return {
      content: [{
        type: 'text',
        text: `Error: ${error.message}`
      }]
    };
  }
});

// Handler functions
async function handleListInventory(args: any) {
  let query = db.collection(`users/${USER_ID}/inventory`);
  
  // Apply filters
  if (args.category) {
    query = query.where('category', '==', args.category);
  }
  
  if (args.location) {
    query = query.where('location', '==', args.location);
  }
  
  // Order by last updated
  query = query.orderBy('lastUpdated', 'desc');
  
  const snapshot = await query.get();
  const items: any[] = [];
  
  snapshot.forEach(doc => {
    const data = doc.data();
    
    // Apply search filter
    if (args.search && !data.name.toLowerCase().includes(args.search.toLowerCase())) {
      return;
    }
    
    // Apply low stock filter
    if (args.lowStockOnly) {
      if (data.quantity <= (data.lowStockThreshold || 1)) {
        items.push({ id: doc.id, ...data });
      }
    } else {
      items.push({ id: doc.id, ...data });
    }
  });
  
  // Format as text for Claude
  if (items.length === 0) {
    return {
      content: [{
        type: 'text',
        text: 'No items found matching your criteria.'
      }]
    };
  }
  
  let response = `📦 Inventory Items (${items.length} total)\n\n`;
  
  // Group by category for better readability
  const groupedItems = items.reduce((acc, item) => {
    const category = item.category || 'uncategorized';
    if (!acc[category]) acc[category] = [];
    acc[category].push(item);
    return acc;
  }, {} as Record<string, any[]>);
  
  for (const [category, categoryItems] of Object.entries(groupedItems)) {
    response += `**${category.toUpperCase()}:**\n`;
    for (const item of categoryItems) {
      const stockStatus = item.quantity <= (item.lowStockThreshold || 1) ? 
        (item.quantity === 0 ? '🔴 OUT' : '🟡 LOW') : '✅';
      
      response += `  ${stockStatus} ${item.name}: ${item.quantity} ${item.unit}`;
      if (item.location) response += ` (${item.location})`;
      if (item.brand) response += ` - ${item.brand}`;
      if (item.notes) response += ` [${item.notes}]`;
      response += '\n';
    }
    response += '\n';
  }
  
  return {
    content: [{
      type: 'text',
      text: response
    }]
  };
}

async function handleUpdateInventory(args: any) {
  const { updates } = args;
  const results: string[] = [];
  
  for (const update of updates) {
    try {
      // Search for existing item by name (case-insensitive)
      const query = await db.collection(`users/${USER_ID}/inventory`)
        .get();
      
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
          lowStockThreshold: 1,
          lastUpdated: new Date(),
          createdAt: new Date(),
          ...(update.brand && { brand: update.brand }),
          ...(update.notes && { notes: update.notes })
        };
        
        await db.collection(`users/${USER_ID}/inventory`).add(newItem);
        results.push(`✅ Added ${update.name}: ${update.quantity} ${update.unit || 'unit'}`);
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
        }
        
        const updateData: any = {
          quantity: newQuantity,
          lastUpdated: new Date()
        };
        
        // Update optional fields if provided
        if (update.unit) updateData.unit = update.unit;
        if (update.category) updateData.category = update.category;
        if (update.location) updateData.location = update.location;
        if (update.brand) updateData.brand = update.brand;
        if (update.notes) updateData.notes = update.notes;
        
        await existingDoc.ref.update(updateData);
        
        const actionText = update.action === 'add' ? 'Added' : 
                          update.action === 'subtract' ? 'Used' : 'Set';
        results.push(`✅ ${actionText} ${update.name}: now ${newQuantity} ${currentData.unit || 'unit'}`);
      }
    } catch (error: any) {
      results.push(`❌ Failed to update ${update.name}: ${error.message}`);
    }
  }
  
  return {
    content: [{
      type: 'text',
      text: results.join('\n')
    }]
  };
}

async function handleGetLowStock(args: any = {}) {
  const snapshot = await db.collection(`users/${USER_ID}/inventory`)
    .orderBy('category')
    .get();
  
  const lowStock: any[] = [];
  
  snapshot.forEach(doc => {
    const data = doc.data();
    const threshold = data.lowStockThreshold || 1;
    
    if (data.quantity <= threshold) {
      if (!args.includeOutOfStock && data.quantity === 0) {
        return; // Skip out of stock items if not requested
      }
      lowStock.push({ id: doc.id, ...data });
    }
  });
  
  if (lowStock.length === 0) {
    return {
      content: [{
        type: 'text',
        text: '🎉 All items are well stocked! Nothing needs to be added to your grocery list right now.'
      }]
    };
  }
  
  let response = `🛒 Items needing attention (${lowStock.length} items):\n\n`;
  
  // Group by category
  const groupedItems = lowStock.reduce((acc, item) => {
    const category = item.category || 'uncategorized';
    if (!acc[category]) acc[category] = [];
    acc[category].push(item);
    return acc;
  }, {} as Record<string, any[]>);
  
  for (const [category, items] of Object.entries(groupedItems)) {
    response += `**${category.toUpperCase()}:**\n`;
    for (const item of items) {
      const status = item.quantity === 0 ? '🔴 OUT OF STOCK' : '🟡 RUNNING LOW';
      response += `  ${status}: ${item.name} (${item.quantity}/${item.lowStockThreshold || 1} ${item.unit})\n`;
    }
    response += '\n';
  }
  
  response += '💡 Use "create_grocery_list" to generate a shopping list from these items.';
  
  return {
    content: [{
      type: 'text',
      text: response
    }]
  };
}

async function handleSearchInventory(args: any) {
  const { searchTerm, maxResults = 20 } = args;
  
  const snapshot = await db.collection(`users/${USER_ID}/inventory`).get();
  const matches: any[] = [];
  
  snapshot.forEach(doc => {
    const data = doc.data();
    const searchText = `${data.name} ${data.brand || ''} ${data.notes || ''}`.toLowerCase();
    
    if (searchText.includes(searchTerm.toLowerCase())) {
      matches.push({ id: doc.id, ...data });
    }
  });
  
  // Sort by relevance (exact matches first)
  matches.sort((a, b) => {
    const aExact = a.name.toLowerCase() === searchTerm.toLowerCase() ? 1 : 0;
    const bExact = b.name.toLowerCase() === searchTerm.toLowerCase() ? 1 : 0;
    return bExact - aExact;
  });
  
  const results = matches.slice(0, maxResults);
  
  if (results.length === 0) {
    return {
      content: [{
        type: 'text',
        text: `No items found matching "${searchTerm}".`
      }]
    };
  }
  
  let response = `🔍 Search results for "${searchTerm}" (${results.length} found):\n\n`;
  
  for (const item of results) {
    const stockStatus = item.quantity <= (item.lowStockThreshold || 1) ? 
      (item.quantity === 0 ? '🔴' : '🟡') : '✅';
    
    response += `${stockStatus} ${item.name}: ${item.quantity} ${item.unit}`;
    if (item.brand) response += ` (${item.brand})`;
    if (item.location) response += ` - ${item.location}`;
    response += '\n';
  }
  
  return {
    content: [{
      type: 'text',
      text: response
    }]
  };
}

async function handleCreateGroceryList(args: any) {
  const { name = 'Shopping List', fromLowStock = true, customItems = [] } = args;
  
  const listItems: any[] = [];
  
  // Add low stock items if requested
  if (fromLowStock) {
    const snapshot = await db.collection(`users/${USER_ID}/inventory`)
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
    return {
      content: [{
        type: 'text',
        text: 'No items to add to grocery list. Everything is well stocked!'
      }]
    };
  }
  
  // Create the grocery list in database
  const docRef = await db.collection(`users/${USER_ID}/grocery_lists`).add({
    name,
    status: 'active',
    items: listItems,
    createdAt: new Date()
  });
  
  let response = `📝 Created grocery list "${name}" (${listItems.length} items):\n\n`;
  
  // Group by category
  const groupedItems = listItems.reduce((acc, item) => {
    const category = item.category || 'uncategorized';
    if (!acc[category]) acc[category] = [];
    acc[category].push(item);
    return acc;
  }, {} as Record<string, any[]>);
  
  for (const [category, items] of Object.entries(groupedItems)) {
    response += `**${category.toUpperCase()}:**\n`;
    for (const item of items) {
      response += `  ☐ ${item.name}: ${item.quantity} ${item.unit}`;
      if (item.notes) response += ` (${item.notes})`;
      response += '\n';
    }
    response += '\n';
  }
  
  response += `💾 List saved with ID: ${docRef.id}`;
  
  return {
    content: [{
      type: 'text',
      text: response
    }]
  };
}

// Start the server
async function main() {
  try {
    const transport = new StdioServerTransport();
    await server.connect(transport);
    console.error('🚀 Grocery Inventory MCP Server running on stdio');
  } catch (error) {
    console.error('❌ Failed to start MCP server:', error);
    process.exit(1);
  }
}

// Graceful shutdown
process.on('SIGINT', () => {
  console.error('🛑 Shutting down MCP server...');
  process.exit(0);
});

main().catch(console.error);