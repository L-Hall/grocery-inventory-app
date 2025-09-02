/**
 * Properly implemented OpenAI Agents for Grocery Inventory App
 * Following the official OpenAI Agents SDK patterns
 */

import { Agent, tool, run } from '@openai/agents';
import { z } from 'zod';
import * as admin from 'firebase-admin';

const db = admin.firestore();

// ============= Tool Definitions =============

/**
 * Tool to parse natural language inventory updates
 */
const parseInventoryTool = tool({
  name: 'parse_inventory',
  description: 'Parse natural language text into structured inventory updates',
  parameters: z.object({
    text: z.string().describe('Natural language text describing inventory changes'),
  }),
  execute: async ({ text }) => {
    // Parse common patterns
    const patterns = {
      bought: /(?:bought|purchased|got|added)\s+(\d+)\s*([a-z]+)?\s+(?:of\s+)?(.+)/i,
      used: /(?:used|consumed|ate|finished)\s+(\d+)\s*([a-z]+)?\s+(?:of\s+)?(.+)/i,
      set: /(?:have|got|down to)\s+(\d+)\s*([a-z]+)?\s+(?:of\s+)?(.+)\s+(?:left|remaining)/i,
    };

    const items = [];
    
    for (const [action, pattern] of Object.entries(patterns)) {
      const match = text.match(pattern);
      if (match) {
        const [, quantity, unit, name] = match;
        items.push({
          name: name.trim(),
          quantity: parseFloat(quantity),
          unit: unit || 'count',
          action: action === 'bought' ? 'add' : action === 'used' ? 'subtract' : 'set',
        });
      }
    }

    if (items.length === 0) {
      return { error: 'Could not parse inventory update from text' };
    }

    return { items };
  },
});

/**
 * Tool to fetch current inventory from Firebase
 */
const getInventoryTool = tool({
  name: 'get_inventory',
  description: 'Fetch current inventory items from the database',
  parameters: z.object({
    userId: z.string().describe('User ID to fetch inventory for'),
    lowStockOnly: z.boolean().optional().describe('Only return low stock items'),
  }),
  execute: async ({ userId, lowStockOnly }) => {
    try {
      const snapshot = await db
        .collection(`users/${userId}/inventory`)
        .get();
      
      let items = snapshot.docs.map(doc => ({
        id: doc.id,
        ...doc.data(),
      }));

      if (lowStockOnly) {
        items = items.filter((item: any) => 
          item.quantity <= item.lowStockThreshold
        );
      }

      return { items };
    } catch (error) {
      return { 
        error: `Failed to fetch inventory: ${error}`,
        items: [] 
      };
    }
  },
});

/**
 * Tool to update inventory in Firebase
 */
const updateInventoryTool = tool({
  name: 'update_inventory',
  description: 'Update inventory quantities in the database',
  parameters: z.object({
    userId: z.string(),
    updates: z.array(z.object({
      name: z.string(),
      quantity: z.number(),
      action: z.enum(['add', 'subtract', 'set']),
      unit: z.string().optional(),
    })),
  }),
  execute: async ({ userId, updates }) => {
    const results = [];
    
    for (const update of updates) {
      try {
        // Find existing item
        const query = await db
          .collection(`users/${userId}/inventory`)
          .where('name', '==', update.name)
          .limit(1)
          .get();

        if (query.empty) {
          // Create new item
          const newItem = {
            name: update.name,
            quantity: update.quantity,
            unit: update.unit || 'count',
            category: 'Other',
            lowStockThreshold: 1,
            createdAt: admin.firestore.FieldValue.serverTimestamp(),
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          };
          
          const docRef = await db
            .collection(`users/${userId}/inventory`)
            .add(newItem);
          
          results.push({
            success: true,
            itemId: docRef.id,
            action: 'created',
            name: update.name,
          });
        } else {
          // Update existing item
          const doc = query.docs[0];
          const currentData = doc.data();
          let newQuantity = currentData.quantity;

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

          await doc.ref.update({
            quantity: newQuantity,
            updatedAt: admin.firestore.FieldValue.serverTimestamp(),
          });

          results.push({
            success: true,
            itemId: doc.id,
            action: 'updated',
            name: update.name,
            newQuantity,
          });
        }
      } catch (error) {
        results.push({
          success: false,
          name: update.name,
          error: error instanceof Error ? error.message : 'Unknown error',
        });
      }
    }

    return { results };
  },
});

/**
 * Tool to generate recipe suggestions
 */
const suggestRecipesTool = tool({
  name: 'suggest_recipes',
  description: 'Generate recipe suggestions based on available inventory',
  parameters: z.object({
    ingredients: z.array(z.object({
      name: z.string(),
      quantity: z.number(),
      unit: z.string(),
    })),
    preferences: z.string().optional(),
  }),
  execute: async ({ ingredients, preferences }) => {
    // Simple recipe matching logic
    const recipes = [];
    
    // Check for common recipe patterns
    const hasChicken = ingredients.some(i => i.name.toLowerCase().includes('chicken'));
    const hasPasta = ingredients.some(i => i.name.toLowerCase().includes('pasta'));
    const hasRice = ingredients.some(i => i.name.toLowerCase().includes('rice'));
    
    if (hasChicken && hasRice) {
      recipes.push({
        name: 'Chicken Fried Rice',
        ingredients: ['chicken', 'rice', 'eggs', 'soy sauce'],
        time: '25 minutes',
        difficulty: 'easy',
      });
    }
    
    if (hasPasta) {
      recipes.push({
        name: 'Simple Pasta',
        ingredients: ['pasta', 'tomato sauce', 'cheese'],
        time: '20 minutes',
        difficulty: 'easy',
      });
    }

    if (recipes.length === 0) {
      recipes.push({
        name: 'Mixed Stir Fry',
        ingredients: ingredients.slice(0, 5).map(i => i.name),
        time: '30 minutes',
        difficulty: 'medium',
      });
    }

    return { 
      recipes,
      message: `Found ${recipes.length} recipes based on your ingredients`,
    };
  },
});

/**
 * Tool to create shopping lists
 */
const createShoppingListTool = tool({
  name: 'create_shopping_list',
  description: 'Create a shopping list from low stock items',
  parameters: z.object({
    userId: z.string(),
    includeCategories: z.array(z.string()).optional(),
  }),
  execute: async ({ userId, includeCategories }) => {
    try {
      // Get low stock items
      const snapshot = await db
        .collection(`users/${userId}/inventory`)
        .get();
      
      const lowStockItems = snapshot.docs
        .map(doc => ({
          id: doc.id,
          ...doc.data(),
        }))
        .filter((item: any) => item.quantity <= item.lowStockThreshold)
        .filter((item: any) => 
          !includeCategories || includeCategories.includes(item.category)
        );

      // Group by category
      const grouped = lowStockItems.reduce((acc: any, item: any) => {
        if (!acc[item.category]) acc[item.category] = [];
        acc[item.category].push({
          name: item.name,
          quantity: item.lowStockThreshold * 2 - item.quantity,
          unit: item.unit,
        });
        return acc;
      }, {});

      return {
        list: grouped,
        totalItems: lowStockItems.length,
      };
    } catch (error) {
      return {
        error: `Failed to create shopping list: ${error}`,
        list: {},
      };
    }
  },
});

// ============= Agent Definitions =============

/**
 * Inventory Manager Agent
 * Handles all inventory-related operations
 */
export const inventoryAgent = new Agent({
  name: 'Inventory Manager',
  instructions: `You are an inventory management specialist. You help users:
    1. Parse and update inventory from natural language
    2. Check current stock levels
    3. Identify low stock items
    4. Maintain accurate inventory records
    
    Always confirm updates before making changes.
    Be precise with quantities and units.`,
  tools: [
    parseInventoryTool,
    getInventoryTool,
    updateInventoryTool,
  ],
  model: 'gpt-3.5-turbo',
});

/**
 * Recipe Assistant Agent
 * Provides recipe suggestions and meal planning
 */
export const recipeAgent = new Agent({
  name: 'Recipe Assistant',
  instructions: `You are a culinary expert who suggests recipes based on available ingredients.
    Consider:
    - Using ingredients that are expiring soon
    - Dietary preferences and restrictions
    - Cooking skill level
    - Available cooking time
    
    Provide practical, easy-to-follow recipes.`,
  tools: [
    getInventoryTool,
    suggestRecipesTool,
  ],
  model: 'gpt-3.5-turbo',
});

/**
 * Shopping Assistant Agent
 * Creates and manages shopping lists
 */
export const shoppingAgent = new Agent({
  name: 'Shopping Assistant',
  instructions: `You create smart shopping lists by:
    1. Identifying low stock items
    2. Organizing by store sections
    3. Suggesting quantities based on usage patterns
    4. Considering budget if mentioned
    
    Make shopping efficient and complete.`,
  tools: [
    getInventoryTool,
    createShoppingListTool,
  ],
  model: 'gpt-3.5-turbo',
});

/**
 * Main Coordinator Agent
 * Routes requests to appropriate specialist agents
 */
export const mainAgent = new Agent({
  name: 'Grocery Assistant',
  instructions: `You are the main grocery management assistant. 
    You coordinate between different specialized agents:
    - Inventory Manager: For stock updates and checking
    - Recipe Assistant: For meal suggestions
    - Shopping Assistant: For shopping lists
    
    Understand what the user needs and delegate to the appropriate specialist.
    Always be helpful, friendly, and efficient.`,
  handoffs: [inventoryAgent, recipeAgent, shoppingAgent],
  model: 'gpt-4-turbo-preview',
});

// ============= Helper Functions =============

/**
 * Process a grocery request through the agent system
 */
export async function processGroceryRequest(
  userId: string,
  message: string,
  context?: any
) {
  try {
    // Add userId to context for tools to access
    const enrichedContext = {
      ...context,
      userId,
      timestamp: new Date().toISOString(),
    };

    // Run the main agent with the user's message
    const result = await run(mainAgent, message, {
      context: enrichedContext,
      maxTurns: 10,
    });

    return {
      success: true,
      response: result.finalOutput,
    };
  } catch (error) {
    console.error('Error in agent processing:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Direct inventory update with confirmation
 */
export async function updateInventoryWithConfirmation(
  userId: string,
  updateText: string
) {
  try {
    // First, parse the update
    const parseResult = await run(
      inventoryAgent,
      `Parse this inventory update but don't apply it yet: "${updateText}"`,
      { context: { userId } }
    );

    // Return parsed items for user confirmation
    return {
      success: true,
      parsed: parseResult.finalOutput,
      needsConfirmation: true,
    };
  } catch (error) {
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

export default {
  mainAgent,
  inventoryAgent,
  recipeAgent,
  shoppingAgent,
  processGroceryRequest,
  updateInventoryWithConfirmation,
};