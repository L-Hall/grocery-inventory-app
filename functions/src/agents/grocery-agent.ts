/**
 * OpenAI Agents configuration for Grocery Inventory App
 *
 * Provides agent wrappers plus resilient fallbacks so the backend can keep
 * functioning when the Agents API is unavailable.
 */

import {Agent, run} from "@openai/agents";
import {z} from "zod";
import * as logger from "firebase-functions/logger";

import {GroceryParser} from "../ai-parser";

const FALLBACK_NOTICE =
  "OpenAI agents are not available right now. Using heuristic suggestions instead.";

const unitMap: Record<string, string> = {
  gallon: "gallon",
  gallons: "gallon",
  gal: "gallon",
  liter: "liter",
  liters: "liter",
  lb: "pound",
  lbs: "pound",
  pound: "pound",
  pounds: "pound",
  ounce: "ounce",
  ounces: "ounce",
  oz: "ounce",
  count: "count",
  piece: "count",
  pieces: "count",
  item: "count",
  items: "count",
  dozen: "dozen",
  bag: "bag",
  bags: "bag",
  box: "box",
  boxes: "box",
};

function normalizeUnit(value: string | undefined): string {
  if (!value) return "count";
  const cleaned = value.trim().toLowerCase();
  return unitMap[cleaned] || cleaned || "count";
}

function normalizeQuantity(raw: number | string | undefined): number {
  if (typeof raw === "number") return Number.isFinite(raw) ? raw : 1;
  if (typeof raw === "string") {
    const parsed = parseFloat(raw);
    return Number.isFinite(parsed) ? parsed : 1;
  }
  return 1;
}

function normalizeAction(value: string | undefined): "add" | "subtract" | "set" {
  const cleaned = (value ?? "").toLowerCase();
  if (["subtract", "used", "use", "consumed", "consume", "ate", "finished"].includes(cleaned)) {
    return "subtract";
  }
  if (["set", "have", "left", "remaining"].includes(cleaned)) {
    return "set";
  }
  return "add";
}

const RawAgentItemSchema = z.object({
  name: z.string().min(1),
  quantity: z.union([z.number(), z.string()]).optional(),
  unit: z.string().optional(),
  action: z.string().optional(),
  category: z.string().optional(),
});

const AgentItemSchema = RawAgentItemSchema.transform((item) => ({
  name: item.name.trim(),
  quantity: normalizeQuantity(item.quantity),
  unit: normalizeUnit(item.unit),
  action: normalizeAction(item.action),
  category: item.category?.trim() || null,
}));

const AgentItemsSchema = z.union([
  z.object({items: z.array(AgentItemSchema)}).transform((data) => data.items),
  z.array(AgentItemSchema),
  AgentItemSchema.transform((item) => [item]),
]);

function isOpenAIConfigured(): boolean {
  return Boolean(process.env.OPENAI_API_KEY && process.env.OPENAI_API_KEY.trim());
}

function extractJsonBlock(output: string): string {
  const fenced = output.match(/```(?:json)?\s*([\s\S]*?)```/i);
  if (fenced) {
    return fenced[1].trim();
  }
  return output.trim();
}

async function fallbackParseInventory(userInput: string) {
  const parser = new GroceryParser("");
  const result = await parser.parseGroceryText(userInput);

  if (result.items?.length) {
    return {
      success: true as const,
      data: result.items.map((item) => ({
        name: item.name,
        quantity: item.quantity,
        unit: item.unit,
        action: item.action,
        category: item.category ?? null,
      })),
      usedFallback: true,
      notice: FALLBACK_NOTICE,
    };
  }

  return {
    success: false as const,
    error: "Unable to interpret inventory update.",
  };
}

function inventoryFallbackSummary(lowStockItems: any[]): string {
  if (!lowStockItems?.length) {
    return `Inventory looks healthy. ${FALLBACK_NOTICE}`;
  }

  const headline = lowStockItems
    .slice(0, 5)
    .map((item: any) => item.name)
    .join(", ");

  return `You're running low on: ${headline}. ${FALLBACK_NOTICE}`;
}

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
 */
export const recipeSuggester = new Agent({
  name: "RecipeSuggester",
  instructions: `You suggest recipes based on available ingredients in the user's inventory.
    
    Consider:
    - Items with high quantities
    - Items expiring soon (prioritize these)
    - User's dietary preferences if known
    - Simple recipes with common ingredients`,
  model: "gpt-3.5-turbo",
});

/**
 * Shopping List Agent
 */
export const shoppingListAgent = new Agent({
  name: "ShoppingListAgent",
  instructions: `You create smart shopping lists based on:
    1. Items that are out of stock or low
    2. Items needed for suggested recipes
    3. User's shopping patterns and preferences`,
  model: "gpt-3.5-turbo",
});

/**
 * Parse inventory updates using the agent with graceful fallback.
 */
export async function parseInventoryUpdate(userInput: string) {
  const failWithFallback = async (message: string) => {
    logger.warn("Agent parse fallback", {message});
    return await fallbackParseInventory(userInput);
  };

  if (!isOpenAIConfigured()) {
    return await fallbackParseInventory(userInput);
  }

  try {
    const result = await run(
      inventoryParser,
      `Parse this inventory update into JSON: "${userInput}"`
    );

    const payload = extractJsonBlock(result.finalOutput);
    let parsed: unknown;
    try {
      parsed = JSON.parse(payload);
    } catch {
      return await failWithFallback("Agent did not return valid JSON.");
    }

    let items: Array<z.infer<typeof AgentItemSchema>>;
    try {
      const parsedItems = AgentItemsSchema.parse(parsed) as Array<z.infer<typeof AgentItemSchema>>;
      items = parsedItems;
    } catch (schemaError) {
      logger.warn("Agent schema validation failed", {
        error: schemaError instanceof Error ? schemaError.message : schemaError,
      });
      return await failWithFallback("Agent returned unexpected structure.");
    }

    if (!items.length) {
      return await failWithFallback("Agent returned an empty item list.");
    }

    return {
      success: true as const,
      data: items.map((item) => ({
        ...item,
        quantity: item.quantity < 0 ? Math.abs(item.quantity) : item.quantity,
      })),
    };
  } catch (error) {
    logger.error("Error parsing with agent", {
      error: error instanceof Error ? error.message : error,
    });
    return await failWithFallback(
      error instanceof Error ? error.message : "Unknown error"
    );
  }
}

/**
 * Generate recipe suggestions.
 */
export async function getRecipeSuggestions(inventory: any[]) {
  const fallback = () => {
    const available = inventory.filter((item) => item.quantity > 0);
    if (!available.length) {
      return {
        success: false as const,
        error: "No inventory items available for suggestions.",
      };
    }

    const staples = available
      .slice(0, 5)
      .map((item) => item.name)
      .join(", ");

    return {
      success: true as const,
      suggestions: `Try simple meals featuring: ${staples}. ${FALLBACK_NOTICE}`,
      usedFallback: true,
    };
  };

  if (!isOpenAIConfigured()) {
    return fallback();
  }

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
      success: true as const,
      suggestions: result.finalOutput,
    };
  } catch (error) {
    logger.error("Error getting recipe suggestions", {
      error: error instanceof Error ? error.message : error,
    });
    return fallback();
  }
}

/**
 * Create a shopping list suggestion.
 */
export async function createShoppingList(
  lowStockItems: any[],
  preferences?: string
) {
  const fallback = () => {
    if (!lowStockItems.length) {
      return {
        success: false as const,
        error: "No low-stock items available to build a list.",
      };
    }

    const grouped = lowStockItems.reduce(
      (
        acc: Record<
          string,
          Array<{name: string; quantity: number; unit: string}>
        >,
        item
      ) => {
        const category = item.category || "Other";
        acc[category] = acc[category] || [];
        acc[category].push({
          name: item.name,
          quantity: Math.max(item.lowStockThreshold - item.quantity + 1, 1),
          unit: item.unit || "count",
        });
        return acc;
      },
      {}
    );

    const sections = Object.keys(grouped)
      .map((category) => {
        const header = `${category}:`;
        const lines = grouped[category]
          .map(
            (item) => `- ${item.name} - ${item.quantity} ${item.unit}`
          )
          .join("\n");
        return `${header}\n${lines}`;
      })
      .join("\n");

    return {
      success: true as const,
      list: sections,
      usedFallback: true,
      notice: FALLBACK_NOTICE,
    };
  };

  if (!isOpenAIConfigured()) {
    return fallback();
  }

  try {
    const itemsList = lowStockItems
      .map((item) => `${item.name} (current: ${item.quantity} ${item.unit}, need: ${item.lowStockThreshold} ${item.unit})`)
      .join(", ");

    const prompt = preferences ?
      `Create a shopping list for these low stock items: ${itemsList}. User preferences: ${preferences}` :
      `Create a shopping list for these low stock items: ${itemsList}`;

    const result = await run(shoppingListAgent, prompt);

    return {
      success: true as const,
      list: result.finalOutput,
    };
  } catch (error) {
    logger.error("Error creating shopping list", {
      error: error instanceof Error ? error.message : error,
    });
    return fallback();
  }
}

/**
 * Multi-agent workflow for complete grocery management.
 */
export async function handleGroceryRequest(userInput: string, context: any) {
  const fallback = () => ({
    success: true as const,
    response: inventoryFallbackSummary(context?.lowStockItems ?? []),
    usedFallback: true,
  });

  if (!isOpenAIConfigured()) {
    return fallback();
  }

  try {
    const intent = await detectIntent(userInput);

    switch (intent) {
    case "update_inventory":
      return await parseInventoryUpdate(userInput);

    case "get_recipes":
      return await getRecipeSuggestions(context.inventory);

    case "create_list":
      return await createShoppingList(context.lowStockItems, context.preferences);

    default: {
      const result = await run(groceryAssistant, userInput);
      return {
        success: true as const,
        response: result.finalOutput,
      };
    }
    }
  } catch (error) {
    logger.error("Error handling grocery request", {
      error: error instanceof Error ? error.message : error,
    });
    return fallback();
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
