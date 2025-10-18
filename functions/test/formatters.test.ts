import {describe, it, expect} from "vitest";
import * as admin from "firebase-admin";

import {
  formatTimestamp,
  formatInventoryItem,
  formatGroceryList,
  formatGroceryListItem,
} from "../src/utils/formatters";

const makeDoc = (
  id: string,
  data: Record<string, any>
) =>
  ({
    id,
    data: () => data,
  } as unknown as FirebaseFirestore.DocumentSnapshot);

describe("formatTimestamp", () => {
  it("converts Firestore Timestamp to ISO string", () => {
    const timestamp = admin.firestore.Timestamp.fromDate(new Date("2024-01-01T00:00:00Z"));
    expect(formatTimestamp(timestamp)).toBe("2024-01-01T00:00:00.000Z");
  });

  it("returns null for invalid string", () => {
    expect(formatTimestamp("not-a-date")).toBeNull();
  });
});

describe("formatInventoryItem", () => {
  it("normalizes numerical fields and timestamps", () => {
    const doc = makeDoc("abc123", {
      name: "Milk",
      quantity: "2",
      unit: "gallon",
      category: "dairy",
      lowStockThreshold: "1",
      createdAt: "2024-03-10T12:00:00Z",
      updatedAt: admin.firestore.Timestamp.fromDate(new Date("2024-03-11T12:00:00Z")),
    });

    const result = formatInventoryItem(doc);

    expect(result).toEqual(
      expect.objectContaining({
        id: "abc123",
        name: "Milk",
        quantity: 2,
        unit: "gallon",
        category: "dairy",
        lowStockThreshold: 1,
        createdAt: "2024-03-10T12:00:00.000Z",
        updatedAt: "2024-03-11T12:00:00.000Z",
      })
    );
  });

  it("falls back to defaults for missing fields", () => {
    const doc = makeDoc("xyz", {});
    const result = formatInventoryItem(doc);

    expect(result).toEqual(
      expect.objectContaining({
        id: "xyz",
        name: "",
        quantity: 0,
        unit: "unit",
        category: "uncategorized",
        lowStockThreshold: 1,
      })
    );
  });
});

describe("formatGroceryList helpers", () => {
  it("formats list items with generated ids", () => {
    const item = formatGroceryListItem("list-1", {name: "Eggs", quantity: "1"}, 0);
    expect(item).toEqual(
      expect.objectContaining({
        id: "list-1-item-0",
        name: "Eggs",
        quantity: 1,
        unit: "unit",
        isChecked: false,
      })
    );
  });

  it("formats grocery list documents", () => {
    const doc = makeDoc("list-1", {
      name: "Shopping List",
      status: "active",
      createdAt: "2024-03-15T10:00:00Z",
      items: [
        {name: "Eggs", quantity: 1, unit: "dozen", isChecked: true},
        {name: "Milk", quantity: 1, unit: "gallon"},
      ],
    });

    const result = formatGroceryList(doc);

    expect(result.id).toBe("list-1");
    expect(result.items).toHaveLength(2);
    expect(result.items[0]).toEqual(
      expect.objectContaining({
        name: "Eggs",
        isChecked: true,
      })
    );
  });
});
