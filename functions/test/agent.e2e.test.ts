import {describe, it, expect, beforeAll, beforeEach, vi} from "vitest";
import request from "supertest";

vi.mock("firebase-functions/logger", () => ({
  info: vi.fn(),
  warn: vi.fn(),
  error: vi.fn(),
}));

const verifyIdToken = vi.fn();

vi.mock("firebase-admin", () => {
  const firestoreFn: any = () => ({
    collection: vi.fn(),
  });
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

const updateInventoryWithConfirmation = vi.fn();
const processGroceryRequest = vi.fn();

vi.mock("../src/agents", () => ({
  updateInventoryWithConfirmation,
  processGroceryRequest,
}));

let app: import("express").Express;

beforeAll(async () => {
  ({app} = await import("../src/index"));
});

beforeEach(() => {
  verifyIdToken.mockReset();
  verifyIdToken.mockResolvedValue({uid: "agent-user"});
  updateInventoryWithConfirmation.mockReset();
  processGroceryRequest.mockReset();
});

describe("POST /agent/parse", () => {
  it("requires text payload", async () => {
    const res = await request(app)
      .post("/agent/parse")
      .set("Authorization", "Bearer token")
      .send({});

    expect(res.status).toBe(400);
    expect(updateInventoryWithConfirmation).not.toHaveBeenCalled();
  });

  it("returns agent response for authorized request", async () => {
    updateInventoryWithConfirmation.mockResolvedValue({
      success: true,
      summary: "Applied updates",
    });

    const res = await request(app)
      .post("/agent/parse")
      .set("Authorization", "Bearer token")
      .send({text: "bought milk"});

    expect(res.status).toBe(200);
    expect(verifyIdToken).toHaveBeenCalledWith("token");
    expect(updateInventoryWithConfirmation).toHaveBeenCalledWith("agent-user", "bought milk");
    expect(res.body).toEqual({success: true, summary: "Applied updates"});
  });
});

describe("POST /agent/process", () => {
  it("requires message payload", async () => {
    const res = await request(app)
      .post("/agent/process")
      .set("Authorization", "Bearer token")
      .send({});

    expect(res.status).toBe(400);
    expect(processGroceryRequest).not.toHaveBeenCalled();
  });

  it("returns agent processing result", async () => {
    processGroceryRequest.mockResolvedValue({
      success: true,
      response: "Here are suggestions",
    });

    const res = await request(app)
      .post("/agent/process")
      .set("Authorization", "Bearer token")
      .send({message: "What should I cook?", context: {}});

    expect(res.status).toBe(200);
    expect(processGroceryRequest).toHaveBeenCalledWith("agent-user", "What should I cook?", {});
    expect(res.body).toEqual({success: true, response: "Here are suggestions"});
  });
});
