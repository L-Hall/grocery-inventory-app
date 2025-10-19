import * as admin from "firebase-admin";

const isoNow = () => new Date().toISOString();

export function formatTimestamp(value: any): string | null {
  if (!value) return null;

  if (value instanceof admin.firestore.Timestamp) {
    return value.toDate().toISOString();
  }

  if (value.toDate && typeof value.toDate === "function") {
    return value.toDate().toISOString();
  }

  if (value._seconds && value._nanoseconds) {
    return new Date(value._seconds * 1000 + value._nanoseconds / 1e6).toISOString();
  }

  if (value instanceof Date) {
    return value.toISOString();
  }

  if (typeof value === "string") {
    const parsed = new Date(value);
    if (!Number.isNaN(parsed.getTime())) {
      return parsed.toISOString();
    }
    return null;
  }

  return null;
}

export function formatInventoryItem(
  doc: FirebaseFirestore.DocumentSnapshot
): Record<string, any> {
  const data = doc.data() ?? {};

  const quantity =
    typeof data.quantity === "number" ? data.quantity : Number(data.quantity ?? 0);
  const lowStockThreshold = typeof data.lowStockThreshold === "number" ?
    data.lowStockThreshold :
    Number(data.lowStockThreshold ?? 1);

  const createdAt = formatTimestamp(data.createdAt) ?? isoNow();
  const updatedAt = formatTimestamp(
    data.updatedAt ?? data.lastUpdated ?? data.createdAt,
  ) ?? createdAt;

  return {
    id: doc.id,
    name: data.name ?? "",
    quantity: Number.isFinite(quantity) ? quantity : 0,
    unit: data.unit ?? "unit",
    category: data.category ?? "uncategorized",
    location: data.location ?? null,
    size: data.size ?? null,
    lowStockThreshold: Number.isFinite(lowStockThreshold) ? lowStockThreshold : 1,
    expirationDate: formatTimestamp(data.expirationDate),
    notes: data.notes ?? null,
    brand: data.brand ?? null,
    createdAt,
    updatedAt,
  };
}

export function formatGroceryListItem(
  listId: string,
  item: Record<string, any>,
  index: number
): Record<string, any> {
  const quantity =
    typeof item.quantity === "number" ? item.quantity : Number(item.quantity ?? 0);

  return {
    id: item.id ?? `${listId}-item-${index}`,
    name: item.name ?? "",
    quantity: Number.isFinite(quantity) ? quantity : 0,
    unit: item.unit ?? "unit",
    category: item.category ?? "uncategorized",
    isChecked: item.isChecked ?? item.checked ?? false,
    notes: item.notes ?? null,
    addedAt: formatTimestamp(item.addedAt),
  };
}

export function formatGroceryList(
  doc: FirebaseFirestore.DocumentSnapshot
): Record<string, any> {
  const data = doc.data() ?? {};
  const createdAt = formatTimestamp(data.createdAt) ?? isoNow();
  const updatedAt = formatTimestamp(data.updatedAt ?? data.createdAt) ?? createdAt;

  const itemsArray: any[] = Array.isArray(data.items) ? data.items : [];
  const formattedItems = itemsArray.map((item, index) =>
    formatGroceryListItem(doc.id, item, index)
  );

  return {
    id: doc.id,
    name: data.name ?? "Shopping List",
    status: data.status ?? "active",
    notes: data.notes ?? null,
    items: formattedItems,
    createdAt,
    updatedAt,
  };
}
