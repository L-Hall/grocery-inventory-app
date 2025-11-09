/**
 * AI-powered grocery list parser
 *
 * Uses OpenAI's GPT models to parse natural language grocery text
 * into structured inventory updates
 */

import OpenAI from "openai";
import * as logger from "firebase-functions/logger";

interface ParsedItem {
  name: string;
  quantity: number;
  unit: string;
  action: "add" | "subtract" | "set";
  category?: string;
  brand?: string;
  location?: string;
  notes?: string;
  confidence: number;
  expiryDate?: string | null;
  expirationDate?: string | null;
}

interface ParseResult {
  items: ParsedItem[];
  confidence: number;
  originalText: string;
  needsReview: boolean;
  error?: string;
}

export class GroceryParser {
  private openai: OpenAI | null = null;

  constructor(apiKey: string) {
    if (apiKey) {
      this.openai = new OpenAI({
        apiKey: apiKey,
      });
    }
  }

  /**
   * Parse natural language grocery text into structured updates
   */
  async parseGroceryText(text: string): Promise<ParseResult> {
    if (!this.openai) {
      return this.fallbackParse(text);
    }
    try {
      const completion = await this.openai.chat.completions.create({
        model: "gpt-4",
        messages: [
          {
            role: "system",
            content: this.getSystemPrompt(),
          },
          {
            role: "user",
            content: text,
          },
        ],
        functions: [
          {
            name: "parse_grocery_items",
            description: "Parse grocery text into structured inventory updates",
            parameters: {
              type: "object",
              properties: {
                items: {
                  type: "array",
                  description: "List of parsed grocery items",
                  items: {
                    type: "object",
                    properties: {
                      name: {
                        type: "string",
                        description: "Item name (standardized, e.g. 'Milk', 'Bread')",
                      },
                      quantity: {
                        type: "number",
                        description: "Quantity of the item",
                      },
                      unit: {
                        type: "string",
                        description: "Unit of measurement (gallon, loaf, dozen, count, bag, etc.)",
                      },
                      action: {
                        type: "string",
                        enum: ["add", "subtract", "set"],
                        description: "Action: 'add' for purchases, 'subtract' for consumption, 'set' for exact inventory",
                      },
                      category: {
                        type: "string",
                        description: "Category: dairy, produce, meat, pantry, frozen, beverages, snacks, bakery, or uncategorized",
                      },
                      location: {
                        type: "string",
                        description: "Storage location (e.g. pantry, fridge, freezer) if mentioned",
                      },
                      brand: {
                        type: "string",
                        description: "Brand name or specific variety if mentioned",
                      },
                      notes: {
                        type: "string",
                        description: "Additional notes or specifications",
                      },
                      expirationDate: {
                        type: "string",
                        description: "ISO 8601 date string for expiry or best-before date if provided",
                      },
                      expiryDate: {
                        type: "string",
                        description: "Alias for expirationDate (ISO 8601) for flexibility in agent responses",
                      },
                      confidence: {
                        type: "number",
                        description: "Confidence level from 0-1 for this parsing",
                      },
                    },
                    required: ["name", "quantity", "unit", "action", "confidence"],
                  },
                },
                overallConfidence: {
                  type: "number",
                  description: "Overall confidence in the parsing from 0-1",
                },
                needsReview: {
                  type: "boolean",
                  description: "Whether items need human review before applying",
                },
              },
              required: ["items", "overallConfidence", "needsReview"],
            },
          },
        ],
        function_call: {name: "parse_grocery_items"},
      });

      const functionCall = completion.choices[0].message.function_call;
      if (!functionCall || !functionCall.arguments) {
        throw new Error("No function call returned from OpenAI");
      }

      const parsed = JSON.parse(functionCall.arguments);

      return {
        items: parsed.items || [],
        confidence: parsed.overallConfidence || 0,
        originalText: text,
        needsReview: parsed.needsReview || false,
      };
    } catch (error: any) {
      logger.error("Error parsing grocery text", {
        error: error instanceof Error ? error.message : error,
      });

      // Fallback to simple parsing if OpenAI fails
      const fallbackResult = this.fallbackParse(text);
      return {
        ...fallbackResult,
        error: `AI parsing failed: ${error.message}. Using fallback parser.`,
      };
    }
  }

  /**
   * System prompt for the OpenAI model
   */
  private getSystemPrompt(): string {
    return `You are an expert grocery inventory assistant. Your job is to parse natural language text about 
grocery shopping, cooking, or food consumption into structured inventory updates.

Key guidelines:
1. **Actions**: 
   - "add" for purchases: "bought milk", "picked up bread", "got some eggs"
   - "subtract" for consumption: "used 2 eggs", "ate the last banana", "finished the milk"
   - "set" for exact inventory: "have 3 apples left", "only 1 loaf remaining"

2. **Quantities**: Default to 1 if not specified. Be smart about units:
   - Milk → gallons (or liters for metric)
   - Bread → loaves
   - Eggs → dozens (convert: 12 eggs = 1 dozen)
   - Bananas → count
   - Ground meat → pounds
   - Vegetables → count or pounds as appropriate

3. **Categories**: 
   - dairy: milk, cheese, yogurt, eggs, butter
   - produce: fruits, vegetables, herbs
   - meat: chicken, beef, pork, fish, deli meat
   - pantry: canned goods, pasta, rice, oils, spices
   - frozen: frozen vegetables, ice cream, frozen meals
   - beverages: coffee, tea, juice, soda, water
   - snacks: chips, cookies, crackers, nuts
   - bakery: bread, bagels, muffins, pastries

4. **Brand detection**: Extract brand names when mentioned: "Starbucks coffee", "Organic Valley milk"

5. **Locations**: Capture storage hints when present (fridge, freezer, pantry, cupboard, fruit bowl). Leave blank if not mentioned.

6. **Expiration dates**: When the text mentions "expires", "expiry", "best before", or similar, capture the date as ISO 8601 (YYYY-MM-DD). If you infer a reasonable expiry (e.g. milk lasts 5 days), include it with lower confidence.

7. **Confidence scoring**:
   - 0.9-1.0: Very clear, unambiguous
   - 0.7-0.8: Mostly clear, minor assumptions
   - 0.5-0.6: Some ambiguity, needs review
   - 0.3-0.4: Unclear, definitely needs review
   - 0.0-0.2: Very unclear, probably wrong

8. **Review needed**: Set to true if:
   - Overall confidence < 0.7
   - Any ambiguous quantities or units
   - Unusual or unclear item names
   - Mixed actions (buying and consuming in same text)

Examples:
- "bought 2 gallons of milk and a loaf of bread" → add 2 milk (gallon), add 1 bread (loaf)
- "used 3 eggs for breakfast" → subtract 3 eggs (count) or subtract 0.25 eggs (dozen)
- "we're out of coffee" → set 0 coffee (bag)
- "picked up some bananas at the store" → add 6 bananas (count, estimated)

Be helpful and smart about interpreting context while being conservative about confidence when things are unclear.`;
  }

  /**
   * Simple fallback parser when OpenAI is unavailable
   */
  private fallbackParse(text: string): Omit<ParseResult, "error"> {
    const items: ParsedItem[] = [];
    const lowerText = text.toLowerCase();

    // Simple keyword-based parsing
    const commonItems = [
      {keywords: ["milk"], name: "Milk", unit: "gallon", category: "dairy"},
      {keywords: ["bread", "loaf"], name: "Bread", unit: "loaf", category: "bakery"},
      {keywords: ["eggs"], name: "Eggs", unit: "dozen", category: "dairy"},
      {keywords: ["banana", "bananas"], name: "Bananas", unit: "count", category: "produce"},
      {keywords: ["coffee"], name: "Coffee", unit: "bag", category: "beverages"},
      {keywords: ["chicken"], name: "Chicken", unit: "pound", category: "meat"},
    ];

    // Determine action based on context
    let action: "add" | "subtract" | "set" = "add";
    if (lowerText.includes("bought") || lowerText.includes("got") || lowerText.includes("picked up")) {
      action = "add";
    } else if (lowerText.includes("used") || lowerText.includes("ate") || lowerText.includes("finished")) {
      action = "subtract";
    } else if (lowerText.includes("have") || lowerText.includes("left") || lowerText.includes("remaining")) {
      action = "set";
    }

    for (const item of commonItems) {
      for (const keyword of item.keywords) {
        if (lowerText.includes(keyword)) {
          // Simple quantity extraction
          const quantityMatch = text.match(new RegExp(`(\\d+)\\s*${keyword}`, "i"));
          const quantity = quantityMatch ? parseInt(quantityMatch[1]) : 1;

          items.push({
            name: item.name,
            quantity,
            unit: item.unit,
            action,
            category: item.category,
            location: null,
            confidence: 0.6, // Medium confidence for fallback
            expirationDate: null,
            expiryDate: null,
          });
          break;
        }
      }
    }

    return {
      items,
      confidence: items.length > 0 ? 0.6 : 0.2,
      originalText: text,
      needsReview: true, // Always need review for fallback parsing
    };
  }

  /**
   * Validate and clean parsed items
   */
  /**
   * Parse grocery receipt or list image using GPT-4V
   */
  async parseGroceryImage(imageBase64: string, imageType: string = "receipt"): Promise<ParseResult> {
    if (!this.openai) {
      return {
        items: [],
        confidence: 0,
        originalText: "[Image processing requires OpenAI API]",
        needsReview: true,
        error: "OpenAI API key not configured",
      };
    }

    try {
      const prompt = imageType === "receipt" ?
        this.getReceiptPrompt() :
        this.getGroceryListImagePrompt();

      const completion = await this.openai.chat.completions.create({
        model: "gpt-4-vision-preview",
        messages: [
          {
            role: "user",
            content: [
              {
                type: "text",
                text: prompt,
              },
              {
                type: "image_url",
                image_url: {
                  url: `data:image/jpeg;base64,${imageBase64}`,
                  detail: "high",
                },
              },
            ],
          },
        ],
        max_tokens: 1000,
        temperature: 0.3,
      });

      const response = completion.choices[0]?.message?.content;

      if (!response) {
        throw new Error("No response from OpenAI Vision API");
      }

      // Parse the JSON response
      const parsedData = JSON.parse(response);

      // Calculate overall confidence
      const avgConfidence = parsedData.items?.length > 0 ?
        parsedData.items.reduce((sum: number, item: ParsedItem) => sum + (item.confidence || 0.8), 0) / parsedData.items.length :
        0;

      return {
        items: parsedData.items || [],
        confidence: avgConfidence,
        originalText: `[Parsed from ${imageType} image]`,
        needsReview: avgConfidence < 0.7 || parsedData.items?.some((item: ParsedItem) => item.confidence < 0.6),
        error: undefined,
      };
    } catch (error: any) {
      logger.error("Error parsing image with GPT-4V", {
        error: error instanceof Error ? error.message : error,
      });

      return {
        items: [],
        confidence: 0,
        originalText: `[Failed to process ${imageType} image]`,
        needsReview: true,
        error: error.message || "Failed to parse image",
      };
    }
  }

  private getReceiptPrompt(): string {
    return `You are a grocery receipt analyzer. Extract all grocery items from this receipt image.

For each item found, provide:
- name: The product name (clean and standardized)
- quantity: The quantity purchased (default to 1 if not clear)
- unit: The unit of measurement (item, pound, gallon, etc.)
- action: Always "add" for receipts
- category: The grocery category (produce, dairy, meat, etc.)
- brand: Brand name if visible
- location: Storage location if clearly stated (fridge, freezer, pantry, etc.)
- expirationDate: ISO 8601 expiry/best before date if present on the receipt
- confidence: Your confidence level (0.0 to 1.0)

Return ONLY a valid JSON object in this format:
{
  "items": [
    {
      "name": "Milk",
      "quantity": 1,
      "unit": "gallon",
      "action": "add",
      "category": "dairy",
      "brand": "Store Brand",
      "location": "fridge",
      "expirationDate": "2024-05-12",
      "confidence": 0.9
    }
  ]
}

Be thorough and extract ALL items from the receipt. If you can't read something clearly, still include it with lower confidence.`;
  }

  private getGroceryListImagePrompt(): string {
    return `You are a grocery list analyzer. Extract all items from this handwritten or printed grocery list image.

For each item found, provide:
- name: The item name (clean and standardized)
- quantity: The quantity if specified (default to 1)
- unit: The unit if specified (default to "item")
- action: Always "add" for grocery lists
- category: The grocery category
- location: Suggested storage spot if written (e.g. pantry, fridge)
- notes: Any additional notes or specifications
- expirationDate: ISO 8601 expiry/best-before date if the list mentions one
- confidence: Your confidence level (0.0 to 1.0)

Return ONLY a valid JSON object in this format:
{
  "items": [
    {
      "name": "Bananas",
      "quantity": 6,
      "unit": "item",
      "action": "add",
      "category": "produce",
      "location": "fruit bowl",
      "notes": "ripe",
      "expirationDate": "2024-04-20",
      "confidence": 0.85
    }
  ]
}

Extract ALL visible items, even if handwriting is unclear (use lower confidence for unclear items).`;
  }

  validateItems(items: ParsedItem[]): ParsedItem[] {
    return items.map((item) => {
      const normalizedExpiration = this.normalizeExpirationDate(
        item.expirationDate ?? item.expiryDate,
      );

      const sanitized: ParsedItem = {
        ...item,
        name: this.standardizeName(item.name),
        quantity: Math.max(0, item.quantity), // Ensure non-negative
        unit: this.standardizeUnit(item.unit),
        category: this.standardizeCategory(item.category),
        location: item.location?.trim() ?? item.location,
        confidence: Math.min(1, Math.max(0, item.confidence)), // Clamp to 0-1
      };

      if (normalizedExpiration !== undefined) {
        sanitized.expirationDate = normalizedExpiration;
        sanitized.expiryDate = normalizedExpiration;
      } else if (item.expirationDate === null || item.expiryDate === null) {
        sanitized.expirationDate = null;
        sanitized.expiryDate = null;
      }

      return sanitized;
    });
  }

  private standardizeName(name: string): string {
    return name.trim()
      .split(" ")
      .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
      .join(" ");
  }

  private standardizeUnit(unit: string): string {
    const unitMap: Record<string, string> = {
      "gallon": "gallon",
      "gallons": "gallon",
      "gal": "gallon",
      "loaf": "loaf",
      "loaves": "loaf",
      "dozen": "dozen",
      "doz": "dozen",
      "count": "count",
      "each": "count",
      "piece": "count",
      "pieces": "count",
      "pound": "pound",
      "pounds": "pound",
      "lb": "pound",
      "lbs": "pound",
      "bag": "bag",
      "bags": "bag",
      "bottle": "bottle",
      "bottles": "bottle",
      "can": "can",
      "cans": "can",
      "box": "box",
      "boxes": "box",
    };

    return unitMap[unit.toLowerCase()] || unit.toLowerCase();
  }

  private standardizeCategory(category?: string): string {
    if (!category) return "uncategorized";

    const categoryMap: Record<string, string> = {
      "dairy": "dairy",
      "produce": "produce",
      "meat": "meat",
      "pantry": "pantry",
      "frozen": "frozen",
      "beverages": "beverages",
      "snacks": "snacks",
      "bakery": "bakery",
    };

    return categoryMap[category.toLowerCase()] || "uncategorized";
  }

  private normalizeExpirationDate(value?: string | null): string | null | undefined {
    if (value === undefined) {
      return undefined;
    }

    if (value === null || value === "") {
      return null;
    }

    const parsed = new Date(value);
    if (Number.isNaN(parsed.getTime())) {
      return undefined;
    }

    return parsed.toISOString();
  }
}
