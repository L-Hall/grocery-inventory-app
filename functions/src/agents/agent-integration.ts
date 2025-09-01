/**
 * Integration layer between OpenAI Agents and Firebase Functions
 * 
 * This module bridges the gap between the agent responses and 
 * the existing Firebase/Firestore data structures.
 */

import * as admin from 'firebase-admin';
import { 
  parseInventoryUpdate, 
  getRecipeSuggestions, 
  createShoppingList,
  handleGroceryRequest 
} from './grocery-agent';

const db = admin.firestore();

/**
 * Enhanced inventory parsing with agent integration
 * Falls back to existing parser if agent fails
 */
export async function parseWithAgent(text: string, existingParser: any) {
  try {
    // Try using the OpenAI Agent first
    const agentResult = await parseInventoryUpdate(text);
    
    if (agentResult.success && agentResult.data) {
      // Convert agent response to match existing ParsedItem structure
      return convertAgentToParsedItem(agentResult.data);
    }
    
    // Fall back to existing parser if agent fails
    console.log('Agent parsing failed, falling back to existing parser');
    return await existingParser.parse(text);
  } catch (error) {
    console.error('Error in agent parsing:', error);
    // Fall back to existing parser
    return await existingParser.parse(text);
  }
}

/**
 * Convert agent response to match existing ParsedItem structure
 */
function convertAgentToParsedItem(agentData: any) {
  // Handle both single item and array responses
  const items = Array.isArray(agentData) ? agentData : [agentData];
  
  return items.map(item => ({
    name: item.name || item.item || '',
    quantity: parseFloat(item.quantity) || 1,
    unit: normalizeUnit(item.unit || 'count'),
    action: normalizeAction(item.action || 'add'),
    category: item.category || null,
    confidence: 0.95, // High confidence for agent-parsed items
  }));
}

/**
 * Normalize units to match existing system
 */
function normalizeUnit(unit: string): string {
  const unitMap: Record<string, string> = {
    'gallons': 'gal',
    'gallon': 'gal',
    'pounds': 'lb',
    'pound': 'lb',
    'ounces': 'oz',
    'ounce': 'oz',
    'liters': 'l',
    'liter': 'l',
    'pieces': 'count',
    'piece': 'count',
    'items': 'count',
    'item': 'count',
  };
  
  return unitMap[unit.toLowerCase()] || unit.toLowerCase();
}

/**
 * Normalize actions to match existing system
 */
function normalizeAction(action: string): 'add' | 'subtract' | 'set' {
  const actionMap: Record<string, 'add' | 'subtract' | 'set'> = {
    'add': 'add',
    'added': 'add',
    'bought': 'add',
    'purchased': 'add',
    'subtract': 'subtract',
    'used': 'subtract',
    'consumed': 'subtract',
    'ate': 'subtract',
    'set': 'set',
    'have': 'set',
  };
  
  return actionMap[action.toLowerCase()] || 'add';
}

/**
 * Get recipe suggestions based on current inventory
 */
export async function suggestRecipes(userId: string) {
  try {
    // Fetch user's current inventory
    const inventorySnapshot = await db
      .collection(`users/${userId}/inventory`)
      .where('quantity', '>', 0)
      .get();
    
    const inventory = inventorySnapshot.docs.map(doc => ({
      id: doc.id,
      ...doc.data(),
    }));
    
    // Get suggestions from agent
    const suggestions = await getRecipeSuggestions(inventory);
    
    if (suggestions.success) {
      // Store suggestions in Firestore for later retrieval
      await db.collection(`users/${userId}/recipe_suggestions`).add({
        suggestions: suggestions.suggestions,
        inventorySnapshot: inventory.map((i: any) => ({ name: i.name, quantity: i.quantity })),
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: true,
        suggestions: suggestions.suggestions,
      };
    }
    
    return suggestions;
  } catch (error) {
    console.error('Error suggesting recipes:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Create smart shopping list using agent
 */
export async function generateSmartShoppingList(userId: string, preferences?: string) {
  try {
    // Fetch low stock items
    const inventorySnapshot = await db
      .collection(`users/${userId}/inventory`)
      .get();
    
    const lowStockItems = inventorySnapshot.docs
      .map(doc => ({
        id: doc.id,
        ...doc.data(),
      }))
      .filter((item: any) => item.quantity <= item.lowStockThreshold);
    
    // Get user preferences if not provided
    if (!preferences) {
      const userDoc = await db.doc(`users/${userId}`).get();
      preferences = userDoc.data()?.shoppingPreferences;
    }
    
    // Generate list using agent
    const listResult = await createShoppingList(lowStockItems, preferences);
    
    if (listResult.success) {
      // Parse and structure the list
      const structuredList = parseShoppingListResponse(listResult.list);
      
      // Store in Firestore
      const listRef = await db.collection(`users/${userId}/grocery_lists`).add({
        name: `Smart List - ${new Date().toLocaleDateString()}`,
        items: structuredList,
        status: 'active',
        createdBy: 'ai_agent',
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        updatedAt: admin.firestore.FieldValue.serverTimestamp(),
      });
      
      return {
        success: true,
        listId: listRef.id,
        items: structuredList,
        rawSuggestion: listResult.list,
      };
    }
    
    return listResult;
  } catch (error) {
    console.error('Error generating shopping list:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Parse agent's shopping list response into structured format
 */
function parseShoppingListResponse(listText: string): any[] {
  // This is a simple parser - can be enhanced based on agent response format
  const lines = listText.split('\n').filter(line => line.trim());
  const items: any[] = [];
  
  let currentCategory = 'Other';
  
  for (const line of lines) {
    // Check if line is a category header
    if (line.includes(':') && !line.includes('-')) {
      currentCategory = line.replace(':', '').trim();
      continue;
    }
    
    // Parse item line
    const match = line.match(/[-•*]\s*(.+?)(?:\s*-\s*(.+))?$/);
    if (match) {
      const [, itemPart] = match;
      
      // Try to extract quantity from the item description
      const quantityMatch = itemPart.match(/(\d+)\s*([a-zA-Z]+)?/);
      
      items.push({
        name: itemPart.replace(/\d+\s*[a-zA-Z]+/, '').trim(),
        quantity: quantityMatch ? parseFloat(quantityMatch[1]) : 1,
        unit: quantityMatch?.[2] || 'count',
        category: currentCategory,
        checked: false,
      });
    }
  }
  
  return items;
}

/**
 * Handle general grocery management requests
 */
export async function processGroceryRequest(
  userId: string, 
  userInput: string,
  contextData?: any
) {
  try {
    // Prepare context
    const context = contextData || await buildUserContext(userId);
    
    // Process request through agent
    const result = await handleGroceryRequest(userInput, context);
    
    // Log the interaction for analytics
    await logAgentInteraction(userId, userInput, result);
    
    return result;
  } catch (error) {
    console.error('Error processing grocery request:', error);
    return {
      success: false,
      error: error instanceof Error ? error.message : 'Unknown error',
    };
  }
}

/**
 * Build context for agent from user data
 */
async function buildUserContext(userId: string) {
  const [inventorySnapshot, listsSnapshot, userDoc] = await Promise.all([
    db.collection(`users/${userId}/inventory`).get(),
    db.collection(`users/${userId}/grocery_lists`)
      .where('status', '==', 'active')
      .get(),
    db.doc(`users/${userId}`).get(),
  ]);
  
  const inventory = inventorySnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
  }));
  
  const lowStockItems = inventory.filter((item: any) => 
    item.quantity <= item.lowStockThreshold
  );
  
  const activeLists = listsSnapshot.docs.map(doc => ({
    id: doc.id,
    ...doc.data(),
  }));
  
  const userData = userDoc.data() || {};
  
  return {
    inventory,
    lowStockItems,
    activeLists,
    preferences: userData.preferences,
    dietaryRestrictions: userData.dietaryRestrictions,
  };
}

/**
 * Log agent interactions for analytics and improvement
 */
async function logAgentInteraction(
  userId: string, 
  input: string, 
  result: any
) {
  try {
    await db.collection('agent_interactions').add({
      userId,
      input,
      success: result.success,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      // Don't log full response to save space
      resultType: result.success ? 'success' : 'error',
    });
  } catch (error) {
    console.error('Error logging interaction:', error);
    // Don't throw - logging failure shouldn't break the main flow
  }
}

export default {
  parseWithAgent,
  suggestRecipes,
  generateSmartShoppingList,
  processGroceryRequest,
};