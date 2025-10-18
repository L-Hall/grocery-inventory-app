/**
 * OpenAI Agents configuration for Grocery Inventory App
 *
 * This agent helps users manage their grocery inventory using natural language.
 * It can parse inventory updates, suggest recipes, and manage shopping lists.
 */

import {Agent, run} from "@openai/agents";

// Initialize OpenAI client
// Note: This is for future use when we need direct OpenAI API calls
// Currently using the agents SDK which handles this internally

/**
 * Main Grocery Assistant Agent
 * Handles natural language interactions for inventory management
 */
export const groceryAssistant = new Agent({
  name: "GroceryAssistant",
  instructions: `You are a helpful grocery inventory assistant. You help users:
    1. Update their inventory using natural language (e.g., "I bought 2 gallons of milk")
    2. Check what items are running low
    3. Create shopping lists
    4. Suggest recipes based on available ingredients
    5. Track expiration dates and remind about items expiring soon
    
    When parsing inventory updates:
    - Identify the action (add/bought, used/consumed, set)
    - Extract quantities and units
    - Determine the item name and category
    - Be flexible with natural language variations
    
    Always be friendly, concise, and helpful.`,
  model: "gpt-4-turbo-preview",
});

/**
 * Inventory Parser Agent
 * Specialized in parsing natural language inventory updates
 */
export const inventoryParser = new Agent({
  name: "InventoryParser",
  instructions: `You are specialized in parsing natural language inventory updates.
    Convert user input into structured data:
    
    Actions:
    - "bought", "got", "purchased", "added" → action: "add"
    - "used", "consumed", "ate", "finished" → action: "subtract"
    - "have X left", "down to X" → action: "set"
    
    Extract:
    - Item name
    - Quantity (as a number)
    - Unit (standardize to: count, lb, oz, gal, qt, etc.)
    - Category (if mentioned or inferred)
    
    Return structured JSON with these fields.`,
  model: "gpt-3.5-turbo",
});

/**
 * Recipe Suggestion Agent
 * Suggests recipes based on available inventory
 */
export const recipeSuggester = new Agent({
  name: "RecipeSuggester",
  instructions: `You suggest recipes based on available ingredients in the user's inventory.
    
    Consider:
    - Items with high quantities
    - Items expiring soon (prioritize these)
    - User's dietary preferences if known
    - Simple recipes with common ingredients
    
    For each recipe, provide:
    - Recipe name
    - Required ingredients from inventory
    - Additional ingredients needed (if any)
    - Brief cooking instructions
    - Prep time and cook time`,
  model: "gpt-3.5-turbo",
});

/**
 * Shopping List Agent
 * Creates and manages shopping lists based on low stock items
 */
export const shoppingListAgent = new Agent({
  name: "ShoppingListAgent",
  instructions: `You create smart shopping lists based on:
    1. Items that are out of stock or low
    2. Items needed for suggested recipes
    3. User's shopping patterns and preferences
    
    Organize lists by:
    - Store sections (produce, dairy, meat, etc.)
    - Priority (urgent vs. nice-to-have)
    
    Include quantity suggestions based on:
    - Typical consumption patterns
    - Storage capacity
    - Item shelf life`,
  model: "gpt-3.5-turbo",
});

/**
 * Example function to parse inventory update using the agent
 */
export async function parseInventoryUpdate(userInput: string) {
  try {
    const result = await run(
      inventoryParser,
      `Parse this inventory update: "${userInput}"`
    );

    // Parse the agent's response as JSON
    const parsed = JSON.parse(result.finalOutput);
    return {
      success: true,
      data: parsed,
    };
  } catch (error) {
    console.error("Error parsing with agent:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

/**
 * Example function to get recipe suggestions
 */
export async function getRecipeSuggestions(inventory: any[]) {
  try {
    const inventoryList = inventory
      .filter((item) => item.quantity > 0)
      .map((item) => `${item.name}: ${item.quantity} ${item.unit}`)
      .join(", ");

    const result = await run(
      recipeSuggester,
      `Suggest 3 recipes I can make with these ingredients: ${inventoryList}`
    );

    return {
      success: true,
      suggestions: result.finalOutput,
    };
  } catch (error) {
    console.error("Error getting recipe suggestions:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

/**
 * Example function to create a shopping list
 */
export async function createShoppingList(lowStockItems: any[], preferences?: string) {
  try {
    const itemsList = lowStockItems
      .map((item) => `${item.name} (current: ${item.quantity} ${item.unit}, need: ${item.lowStockThreshold} ${item.unit})`)
      .join(", ");

    const prompt = preferences ?
      `Create a shopping list for these low stock items: ${itemsList}. User preferences: ${preferences}` :
      `Create a shopping list for these low stock items: ${itemsList}`;

    const result = await run(
      shoppingListAgent,
      prompt
    );

    return {
      success: true,
      list: result.finalOutput,
    };
  } catch (error) {
    console.error("Error creating shopping list:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

/**
 * Multi-agent workflow for complete grocery management
 */
export async function handleGroceryRequest(userInput: string, context: any) {
  try {
    // Determine which agent to use based on the request
    const intent = await detectIntent(userInput);

    switch (intent) {
    case "update_inventory": {
      return await parseInventoryUpdate(userInput);
    }

    case "get_recipes": {
      return await getRecipeSuggestions(context.inventory);
    }

    case "create_list": {
      return await createShoppingList(context.lowStockItems, context.preferences);
    }

    default: {
      // Use the main assistant for general queries
      const result = await run(groceryAssistant, userInput);
      return {
        success: true,
        response: result.finalOutput,
      };
    }
    }
  } catch (error) {
    console.error("Error handling grocery request:", error);
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

/**
 * Simple intent detection (can be enhanced with classification)
 */
async function detectIntent(userInput: string): Promise<string> {
  const input = userInput.toLowerCase();

  if (input.includes("bought") || input.includes("used") || input.includes("have") || input.includes("added")) {
    return "update_inventory";
  }

  if (input.includes("recipe") || input.includes("cook") || input.includes("make")) {
    return "get_recipes";
  }

  if (input.includes("shopping") || input.includes("list") || input.includes("buy")) {
    return "create_list";
  }

  return "general";
}

export default {
  groceryAssistant,
  inventoryParser,
  recipeSuggester,
  shoppingListAgent,
  parseInventoryUpdate,
  getRecipeSuggestions,
  createShoppingList,
  handleGroceryRequest,
};
