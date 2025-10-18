import {describe, it, expect, beforeAll, beforeEach, vi} from "vitest";
import request from "supertest";

vi.mock("firebase-functions/logger", () => ({
  info: vi.fn(),
  warn: vi.fn(),
  error: vi.fn(),
}));

const verifyIdToken = vi.fn();

const inventoryDocs = [
  {
    id: "milk",
    data: () => ({
      name: "Milk",
      quantity: 2,
      unit: "gallon",
      category: "dairy",
      lowStockThreshold: 1,
      createdAt: "2024-01-01T00:00:00.000Z",
      updatedAt: "2024-01-02T00:00:00.000Z",
    }),
  },
  {
    id: "eggs",
    data: () => ({
      name: "Eggs",
      quantity: 0,
      unit: "dozen",
      category: "dairy",
      lowStockThreshold: 1,
      createdAt: "2024-01-01T00:00:00.000Z",
      updatedAt: "2024-01-02T00:00:00.000Z",
    }),
  },
];

const makeQuery = (docs: Array<{id: string; data: () => any}>) => {
  const chain: any = {
    where: vi.fn().mockImplementation(() => chain),
    orderBy: vi.fn().mockImplementation(() => chain),
    limit: vi.fn().mockImplementation(() => chain),
    get: vi.fn().mockResolvedValue({
      forEach: (cb: (doc: any) => void) => docs.forEach(cb),
    }),
  };
  return chain;
};

const inventoryQuery = makeQuery(inventoryDocs);

const firestoreMock = {
  collection: vi.fn().mockImplementation((path: string) => {
    if (path.endsWith("/inventory")) {
      return inventoryQuery;
    }
    // Fallback query with empty results
    return makeQuery([]);
  }),
};

vi.mock("firebase-admin", () => {
  const firestoreFn: any = () => firestoreMock;
  firestoreFn.FieldValue = {
    serverTimestamp: vi.fn(() => "timestamp"),
  };
  firestoreFn.Timestamp = class MockTimestamp {
    toDate() {
      return new Date("2024-01-01T00:00:00.000Z");
    }
  };

  return {
    initializeApp: vi.fn(),
    apps: [],
    firestore: firestoreFn,
    auth: () => ({verifyIdToken}),
  };
});

let app: import("express").Express;

beforeAll(async () => {
  ({app} = await import("../src/index"));
});

beforeEach(() => {
  verifyIdToken.mockReset();
  verifyIdToken.mockResolvedValue({uid: "test-user"});
  inventoryQuery.where.mockClear();
  inventoryQuery.orderBy.mockClear();
  inventoryQuery.limit.mockClear();
});

describe("GET /inventory", () => {
  it("rejects requests without authorization", async () => {
    const res = await request(app).get("/inventory");
    expect(res.status).toBe(401);
    expect(verifyIdToken).not.toHaveBeenCalled();
  });

  it("returns normalized inventory items for authorized user", async () => {
    const res = await request(app)
      .get("/inventory")
      .set("Authorization", "Bearer valid-token");

    expect(res.status).toBe(200);
    expect(verifyIdToken).toHaveBeenCalledWith("valid-token");
    expect(res.body.success).toBe(true);
    expect(res.body.items).toHaveLength(2);
    expect(res.body.items[0]).toEqual(
      expect.objectContaining({
        id: "milk",
        name: "Milk",
        quantity: 2,
        unit: "gallon",
        category: "dairy",
      })
    );
  });
});
