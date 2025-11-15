import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";
import {generateSearchKeywords} from "../utils/search";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

export type InventoryActionType =
  | "inventory_update"
  | "inventory_apply"
  | "inventory_agent";

export const normalizeExpirationDateValue = (
  value: any,
): string | null | undefined => {
  if (value === undefined) {
    return undefined;
  }
  if (value === null || value === "") {
    return null;
  }

  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
    throw new Error(
      `Invalid expiration date: "${value}" (expected ISO 8601 format)`,
    );
  }

  if (typeof value === "number") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
    throw new Error(
      "Invalid expiration date: numeric value could not be parsed",
    );
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (value?.seconds) {
    const milliseconds = value.seconds * 1000 + (value.nanoseconds ?? 0) / 1e6;
    const parsed = new Date(milliseconds);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }

  if (value?._seconds) {
    const milliseconds =
      value._seconds * 1000 + (value._nanoseconds ?? 0) / 1e6;
    const parsed = new Date(milliseconds);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
  }

  throw new Error(
    "Invalid expiration date format: provide ISO string or timestamp",
  );
};

async function recordInventoryAuditLog(
  uid: string,
  data: {
    action: InventoryActionType;
    updates: any[];
    results: Record<string, any>[];
    summary: {total: number; successful: number; failed: number};
    validationErrors: string[];
  },
) {
  try {
    const successfulItemIds = data.results
      .filter((result) => result.success && result.id)
      .map((result) => result.id);

    const truncatedResults = data.results.slice(0, 50);
    const truncatedRequestedUpdates = Array.isArray(data.updates) ?
      data.updates.slice(0, 50).map((update) => ({
        name: typeof update?.name === "string" ? update.name : null,
        action: typeof update?.action === "string" ? update.action : null,
        quantity:
          typeof update?.quantity === "number" ?
            update.quantity :
            Number.isFinite(Number(update?.quantity)) ?
              Number(update?.quantity) :
              null,
        unit: typeof update?.unit === "string" ? update.unit : null,
        category: typeof update?.category === "string" ? update.category : null,
      })) :
      [];

    const description = `Processed ${data.summary.successful}/${data.summary.total} inventory updates (${data.action})`;

    await db.collection(`users/${uid}/audit_logs`).add({
      action: data.action,
      timestamp: admin.firestore.FieldValue.serverTimestamp(),
      userId: uid,
      itemIds: successfulItemIds,
      description: description.slice(0, 500),
      metadata: {
        summary: data.summary,
        validationErrors: data.validationErrors,
        results: truncatedResults,
        requestedUpdates: truncatedRequestedUpdates,
      },
    });
  } catch (error: any) {
    logger.error("Failed to record audit log entry", {
      uid,
      error: error?.message ?? String(error),
    });
  }
}

async function processInventoryUpdate(
  uid: string,
  update: Record<string, any>,
): Promise<Record<string, any>> {
  if (!update || typeof update !== "object") {
    return {
      name: update?.name ?? "unknown",
      success: false,
      error: "Invalid update payload",
    };
  }

  const name = String(update.name ?? "").trim();
  const providedQuantity = update.quantity;
  const action = String(update.action ?? "").toLowerCase();

  if (!name || providedQuantity === undefined || !action) {
    return {
      name: name || update.name || "unknown",
      success: false,
      error: "Missing required fields: name, quantity, action",
    };
  }

  if (!["add", "subtract", "set"].includes(action)) {
    return {
      name,
      success: false,
      error: `Invalid action "${action}". Use add, subtract, or set.`,
    };
  }

  const quantity = Number(providedQuantity);
  if (!Number.isFinite(quantity) || quantity < 0) {
    return {
      name,
      success: false,
      error: "Quantity must be a non-negative number",
    };
  }

  let normalizedExpiration: string | null | undefined;
  try {
    normalizedExpiration = normalizeExpirationDateValue(
      update.expirationDate ?? update.expiryDate,
    );
  } catch (error: any) {
    return {
      name,
      success: false,
      error: error.message ?? "Invalid expiration date",
    };
  }

  const inventoryCollection = db.collection(`users/${uid}/inventory`);
  const snapshot = await inventoryCollection.get();

  let existingDoc: FirebaseFirestore.QueryDocumentSnapshot | null = null;
  for (const doc of snapshot.docs) {
    const docName = String(doc.data().name ?? "").toLowerCase();
    if (docName === name.toLowerCase()) {
      existingDoc = doc;
      break;
    }
  }

  const timestamp = admin.firestore.FieldValue.serverTimestamp();

  if (!existingDoc) {
    const newItem: Record<string, any> = {
      name,
      quantity,
      unit: update.unit ?? "unit",
      category: update.category ?? "uncategorized",
      location: update.location ?? null,
      lowStockThreshold:
        Number.isFinite(Number(update.lowStockThreshold)) ?
          Number(update.lowStockThreshold) :
          1,
      notes: update.notes ?? null,
      brand: update.brand ?? null,
      size: update.size ?? null,
      expirationDate: normalizedExpiration ?? null,
      searchKeywords: generateSearchKeywords(name),
      createdAt: timestamp,
      updatedAt: timestamp,
      lastUpdated: timestamp,
    };

    const docRef = await inventoryCollection.add(newItem);

    return {
      id: docRef.id,
      name,
      success: true,
      action: "created",
      quantity,
      expirationDate: newItem.expirationDate,
      message: `Added ${name}: ${quantity} ${newItem.unit}`,
    };
  }

  const currentData = existingDoc.data();
  let newQuantity = Number(currentData.quantity ?? 0);

  switch (action) {
  case "add":
    newQuantity += quantity;
    break;
  case "subtract":
    newQuantity = Math.max(0, newQuantity - quantity);
    break;
  case "set":
    newQuantity = quantity;
    break;
  default:
    newQuantity = quantity;
  }

  const updateData: Record<string, any> = {
    quantity: newQuantity,
    updatedAt: timestamp,
    lastUpdated: timestamp,
    searchKeywords: generateSearchKeywords(name),
  };

  if (update.unit !== undefined) updateData.unit = update.unit;
  if (update.category !== undefined) updateData.category = update.category;
  if (update.location !== undefined) updateData.location = update.location;
  if (update.brand !== undefined) updateData.brand = update.brand;
  if (update.notes !== undefined) updateData.notes = update.notes;
  if (update.size !== undefined) updateData.size = update.size;
  if (update.lowStockThreshold !== undefined) {
    updateData.lowStockThreshold = Number(update.lowStockThreshold);
  }
  if (normalizedExpiration !== undefined) {
    updateData.expirationDate = normalizedExpiration;
  }

  await existingDoc.ref.update(updateData);

  const actionText =
    action === "add" ?
      "Added" :
      action === "subtract" ?
        "Used" :
        "Set";

  return {
    id: existingDoc.id,
    name,
    success: true,
    action: "updated",
    quantity: newQuantity,
    expirationDate:
      updateData.expirationDate ??
      normalizeExpirationDateValue(currentData.expirationDate) ??
      null,
    message: `${actionText} ${name}: now ${newQuantity} ${update.unit ?? currentData.unit ?? "unit"}`,
  };
}

export async function applyInventoryUpdatesForUser(
  uid: string,
  updates: any[],
  actionType: InventoryActionType = "inventory_update",
): Promise<{
    results: Record<string, any>[];
    summary: {total: number; successful: number; failed: number};
    validationErrors: string[];
  }> {
  const results: Record<string, any>[] = [];

  for (const update of updates) {
    try {
      const result = await processInventoryUpdate(uid, update);
      results.push(result);
    } catch (error: any) {
      results.push({
        name: update?.name ?? "unknown",
        success: false,
        error: error.message ?? "Failed to process update",
      });
    }
  }

  const successful = results.filter((r) => r.success).length;
  const failed = results.length - successful;
  const validationErrors = results
    .filter((r) => !r.success && r.error)
    .map((r) => `${r.name}: ${r.error}`);

  await recordInventoryAuditLog(uid, {
    action: actionType,
    updates,
    results,
    summary: {
      total: results.length,
      successful,
      failed,
    },
    validationErrors,
  });

  return {
    results,
    summary: {
      total: results.length,
      successful,
      failed,
    },
    validationErrors,
  };
}
