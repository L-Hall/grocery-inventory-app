/**
 * Grocery ingestion agent runner.
 *
 * Provides tool abstractions for reading user context, parsing grocery text,
 * and applying inventory updates using the shared validation helpers.
 */

import {Agent, tool, run} from "@openai/agents";
import {z} from "zod";
import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

import {GroceryParser} from "../ai-parser";
import {
  applyInventoryUpdatesForUser,
  InventoryActionType,
} from "../services/inventory";
import {recordAgentInteraction} from "../metrics/agent-metrics";
import {
  formatGroceryList,
  formatInventoryItem,
} from "../utils/formatters";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

const DEFAULT_AGENT_MODEL = process.env.GROCERY_AGENT_MODEL || "gpt-4o-mini";

const fetchUserContextTool = tool({
  name: "fetch_user_context",
  description: "Fetch formatted inventory context for the user",
  parameters: z.object({
    userId: z.string().describe("Firebase Auth user ID"),
    includeLists: z.boolean().optional()
      .describe("Include active grocery lists for additional context"),
  }),
  execute: async ({userId, includeLists}) => {
    try {
      const [inventorySnapshot, listsSnapshot] = await Promise.all([
        db.collection(`users/${userId}/inventory`)
          .orderBy("updatedAt", "desc")
          .limit(200)
          .get(),
        includeLists ?
          db.collection(`users/${userId}/grocery_lists`)
            .where("status", "==", "active")
            .orderBy("createdAt", "desc")
            .limit(20)
            .get() :
          Promise.resolve(null),
      ]);

      const inventory = inventorySnapshot.docs.map((doc) => formatInventoryItem(doc));
      const lowStock = inventory.filter((item) => item.quantity <= item.lowStockThreshold);
      const activeLists = listsSnapshot ?
        listsSnapshot.docs.map((doc) => formatGroceryList(doc)) :
        [];

      return {
        inventory,
        lowStock,
        activeLists,
      };
    } catch (error: any) {
      logger.error("fetch_user_context tool failed", {
        userId,
        error: error?.message ?? error,
      });
      return {
        error: error?.message ?? "Failed to fetch user context",
      };
    }
  },
});

const parseGroceryTextTool = tool({
  name: "parse_grocery_text",
  description: "Parse grocery-related natural language into structured updates",
  parameters: z.object({
    text: z.string().min(1).describe("Natural language grocery description"),
  }),
  execute: async ({text}) => {
    try {
      const parser = new GroceryParser(process.env.OPENAI_API_KEY ?? "");
      const parseResult = await parser.parseGroceryText(text);
      const items = parser.validateItems(parseResult.items ?? []);

      return {
        items,
        confidence: parseResult.confidence ?? 0,
        needsReview: parseResult.needsReview,
        originalText: parseResult.originalText,
        warnings: parseResult.error ?? null,
      };
    } catch (error: any) {
      logger.error("parse_grocery_text tool failed", {
        error: error?.message ?? error,
      });
      return {
        error: error?.message ?? "Failed to parse grocery text",
      };
    }
  },
});

const applyInventoryUpdatesTool = tool({
  name: "apply_inventory_updates",
  description: "Apply structured inventory updates using existing validation logic",
  parameters: z.object({
    userId: z.string(),
    updates: z.array(z.object({
      name: z.string(),
      quantity: z.number(),
      unit: z.string().optional(),
      action: z.enum(["add", "subtract", "set"]),
      category: z.string().optional(),
      location: z.string().nullable().optional(),
      notes: z.string().nullable().optional(),
      expirationDate: z.string().nullable().optional(),
      brand: z.string().nullable().optional(),
      lowStockThreshold: z.number().optional(),
    })).min(1),
    actionType: z.enum(["inventory_update", "inventory_apply", "inventory_agent"])
      .optional()
      .describe("Audit log action type"),
  }),
  execute: async ({userId, updates, actionType}) => {
    try {
      const result = await applyInventoryUpdatesForUser(
        userId,
        updates,
        actionType as InventoryActionType ?? "inventory_agent",
      );

      return result;
    } catch (error: any) {
      logger.error("apply_inventory_updates tool failed", {
        userId,
        error: error?.message ?? error,
      });
      return {
        error: error?.message ?? "Failed to apply inventory updates",
      };
    }
  },
});

export const groceryIngestAgent = new Agent({
  name: "GroceryIngestAgent",
  instructions: `You help users ingest grocery receipts, PDFs, or free-form text.
When a user provides new information:
1. Fetch their current inventory context if needed.
2. Parse the provided text into structured updates.
3. Confirm that updates look reasonable for the existing inventory.
4. Call apply_inventory_updates only after summarizing the changes.`,
  tools: [
    fetchUserContextTool,
    parseGroceryTextTool,
    applyInventoryUpdatesTool,
  ],
  model: DEFAULT_AGENT_MODEL,
});

export interface IngestAgentInput {
  userId: string;
  text: string;
  metadata?: Record<string, any>;
}

export interface IngestAgentResult {
  success: boolean;
  response?: string;
  error?: string;
}

export async function runIngestionAgent(input: IngestAgentInput): Promise<IngestAgentResult> {
  if (!input.text || !input.text.trim()) {
    return {
      success: false,
      error: "Text payload is required for ingestion.",
    };
  }

  const startedAt = Date.now();
  try {
    const context = {
      userId: input.userId,
      metadata: input.metadata ?? {},
      timestamp: new Date().toISOString(),
    };

    const message = `User provided new grocery information:\n"""${input.text.trim()}"""\n
Use tools to parse the text, inspect context, and apply updates if confident.`;

    const result = await run(groceryIngestAgent, message, {
      context,
      maxTurns: 12,
    });

    await recordAgentInteraction({
      userId: input.userId,
      input: input.text,
      agent: "grocery_ingest",
      success: true,
      usedFallback: false,
      latencyMs: Date.now() - startedAt,
      confidence: null,
      metadata: {
        metadata: input.metadata ?? {},
      },
    });

    return {
      success: true,
      response: result.finalOutput,
    };
  } catch (error: any) {
    await recordAgentInteraction({
      userId: input.userId,
      input: input.text,
      agent: "grocery_ingest",
      success: false,
      usedFallback: true,
      latencyMs: Date.now() - startedAt,
      metadata: {
        metadata: input.metadata ?? {},
      },
      error: error?.message ?? "Unknown error",
    });
    logger.error("runIngestionAgent failed", {
      userId: input.userId,
      error: error?.message ?? error,
    });
    return {
      success: false,
      error: error instanceof Error ? error.message : "Unknown error",
    };
  }
}

export default {
  groceryIngestAgent,
  runIngestionAgent,
};
