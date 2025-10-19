import {describe, it, expect, beforeAll, afterAll, beforeEach} from "vitest";
import {initializeTestEnvironment, RulesTestContext} from "@firebase/rules-unit-testing";
import {readFileSync} from "fs";
import {resolve} from "path";

const firestoreHost = process.env.FIRESTORE_EMULATOR_HOST;

const describeOrSkip = firestoreHost ? describe : describe.skip;

describeOrSkip("Firestore security rules", () => {
  let testEnv: Awaited<ReturnType<typeof initializeTestEnvironment>>;
  let authedContext: RulesTestContext;
  let otherUserContext: RulesTestContext;

  beforeAll(async () => {
    if (!firestoreHost) return;

    const [host, portString] = firestoreHost.split(":");
    const port = Number(portString);

    const rulesPath = resolve(__dirname, "..", "..", "firestore.rules");
    const rules = readFileSync(rulesPath, "utf8");

    testEnv = await initializeTestEnvironment({
      projectId: "demo-test-project",
      firestore: {
        host,
        port,
        rules,
      },
    });

    authedContext = testEnv.authenticatedContext("user-123");
    otherUserContext = testEnv.authenticatedContext("user-456");
  });

  afterAll(async () => {
    if (testEnv) {
      await testEnv.cleanup();
    }
  });

  beforeEach(async () => {
    if (testEnv) {
      await testEnv.clearFirestore();
    }
  });

  it("allows a user to read their own inventory documents", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("users/user-123/inventory")
        .doc("milk")
        .set({name: "Milk", quantity: 1});
    });

    const authedDb = authedContext.firestore();
    const snapshot = await authedDb.collection("users/user-123/inventory").get();
    expect(snapshot.empty).toBe(false);
  });

  it("denies access to other users' inventory", async () => {
    await testEnv.withSecurityRulesDisabled(async (context) => {
      await context
        .firestore()
        .collection("users/user-123/inventory")
        .doc("eggs")
        .set({name: "Eggs", quantity: 12});
    });

    const otherDb = otherUserContext.firestore();
    await expect(
      otherDb.collection("users/user-123/inventory").get()
    ).rejects.toThrow(/PERMISSION_DENIED/);
  });
});
