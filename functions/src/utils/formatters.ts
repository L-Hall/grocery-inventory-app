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

export function formatLocation(
  doc: FirebaseFirestore.DocumentSnapshot
): Record<string, any> {
  const data = doc.data() ?? {};
  const createdAt = formatTimestamp(data.createdAt);
  const updatedAt = formatTimestamp(data.updatedAt ?? data.createdAt);

  return {
    id: doc.id,
    name: data.name ?? "Location",
    color: data.color ?? "#FFFFFF",
    icon: data.icon ?? "inventory",
    temperature: data.temperature ?? null,
    sortOrder:
      typeof data.sortOrder === "number" ? data.sortOrder : null,
    createdAt,
    updatedAt,
  };
}

export function formatUserPreferences(
  doc: FirebaseFirestore.DocumentSnapshot
): Record<string, any> {
  const data = doc.data() ?? {};
  return {
    id: doc.id,
    defaultView: data.defaultView ?? null,
    searchHistory: Array.isArray(data.searchHistory) ?
      data.searchHistory.slice(-25) :
      [],
    exportPreferences:
      data.exportPreferences && typeof data.exportPreferences === "object" ?
        data.exportPreferences :
        {},
    bulkOperationHistory: Array.isArray(data.bulkOperationHistory) ?
      data.bulkOperationHistory.slice(-100) :
      [],
    createdAt: formatTimestamp(data.createdAt),
    updatedAt: formatTimestamp(data.updatedAt ?? data.createdAt),
  };
}

export function formatSavedSearch(
  doc: FirebaseFirestore.DocumentSnapshot
): Record<string, any> {
  const data = doc.data() ?? {};
  return {
    id: doc.id,
    name: data.name ?? "",
    config: data.config ?? {},
    useCount:
      typeof data.useCount === "number" ? data.useCount : 0,
    createdAt: formatTimestamp(data.createdAt),
    updatedAt: formatTimestamp(data.updatedAt ?? data.createdAt),
  };
}

export function formatCustomView(
  doc: FirebaseFirestore.DocumentSnapshot
): Record<string, any> {
  const data = doc.data() ?? {};
  return {
    id: doc.id,
    name: data.name ?? "",
    type: data.type ?? "custom",
    filters: Array.isArray(data.filters) ? data.filters : [],
    sortConfig:
      data.sortConfig && typeof data.sortConfig === "object" ?
        data.sortConfig :
        null,
    groupBy: data.groupBy ?? null,
    isDefault: Boolean(data.isDefault),
    createdAt: formatTimestamp(data.createdAt),
    updatedAt: formatTimestamp(data.updatedAt ?? data.createdAt),
  };
}
