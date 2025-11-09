#!/usr/bin/env node

/**
 * Backfill inventory metadata to align legacy documents with new validation rules.
 *
 * - Ensures every inventory document has `updatedAt` (prefers existing timestamps,
 *   falls back to `lastUpdated`, `createdAt`, or server time).
 * - Regenerates `searchKeywords` using the canonical generator.
 * - Normalises `lowStockThreshold`, `unit`, and `category` defaults where missing.
 *
 * Usage:
 *   node scripts/backfill-inventory-metadata.js
 *
 * Optional:
 *   FIREBASE_CREDENTIALS_PATH=/path/to/service.json node scripts/backfill-inventory-metadata.js
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

const serviceAccountPath = process.env.FIREBASE_CREDENTIALS_PATH ||
  path.join(__dirname, '..', 'service-account-key.json');

if (fs.existsSync(serviceAccountPath)) {
  console.log('✅ Using service account key');
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount),
  });
} else {
  console.log('ℹ️  Service account key not found, using application default credentials');
  console.log('   Run `gcloud auth application-default login` if needed.');
  admin.initializeApp({
    projectId: 'helical-button-461921-v6',
  });
}

const db = admin.firestore();

function generateSearchKeywords(name) {
  if (!name || typeof name !== 'string') return [];
  const tokens = name
    .toLowerCase()
    .replace(/[^a-z0-9\s]/g, ' ')
    .split(/\s+/)
    .filter(Boolean);

  const keywords = new Set(tokens);
  keywords.add(name.toLowerCase().trim());
  return Array.from(keywords).filter(Boolean);
}

function normaliseTimestamp(value) {
  if (!value) return null;

  if (value instanceof admin.firestore.Timestamp) {
    return value;
  }

  if (typeof value.toDate === 'function') {
    try {
      return admin.firestore.Timestamp.fromDate(value.toDate());
    } catch (_) {
      return null;
    }
  }

  if (typeof value === 'number') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ?
      null :
      admin.firestore.Timestamp.fromDate(date);
  }

  if (typeof value === 'string') {
    const date = new Date(value);
    return Number.isNaN(date.getTime()) ?
      null :
      admin.firestore.Timestamp.fromDate(date);
  }

  if (value && typeof value._seconds === 'number') {
    return new admin.firestore.Timestamp(value._seconds, value._nanoseconds || 0);
  }

  return null;
}

(async () => {
  console.log('🔄 Backfilling inventory metadata (updatedAt, searchKeywords)...');

  const usersSnapshot = await db.collection('users').get();
  let totalDocsUpdated = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const inventorySnapshot = await db.collection(`users/${userId}/inventory`).get();
    if (inventorySnapshot.empty) continue;

    let batch = db.batch();
    let writesInBatch = 0;
    let userUpdatedCount = 0;

    const commitBatch = async () => {
      if (writesInBatch === 0) return;
      await batch.commit();
      batch = db.batch();
      writesInBatch = 0;
    };

    for (const itemDoc of inventorySnapshot.docs) {
      const data = itemDoc.data() || {};
      const updates = {};

      // searchKeywords
      const nextKeywords = generateSearchKeywords(data.name || itemDoc.id || '');
      const currentKeywords = Array.isArray(data.searchKeywords) ? data.searchKeywords : [];
      const keywordsChanged = nextKeywords.length > 0 &&
        nextKeywords.sort().join(',') !== currentKeywords.sort().join(',');

      if (keywordsChanged) {
        updates.searchKeywords = nextKeywords;
      }

      // updatedAt
      const updatedAt =
        normaliseTimestamp(data.updatedAt) ||
        normaliseTimestamp(data.lastUpdated) ||
        normaliseTimestamp(data.createdAt);

      if (updatedAt) {
        if (!data.updatedAt ||
            (normaliseTimestamp(data.updatedAt)?.toMillis?.() !== updatedAt.toMillis())) {
          updates.updatedAt = updatedAt;
        }
      } else {
        updates.updatedAt = admin.firestore.FieldValue.serverTimestamp();
      }

      // Ensure lowStockThreshold numeric
      if (data.lowStockThreshold === undefined ||
          data.lowStockThreshold === null ||
          Number.isNaN(Number(data.lowStockThreshold))) {
        updates.lowStockThreshold = 1;
      }

      // Default unit/category if missing
      if (!data.unit || typeof data.unit !== 'string') {
        updates.unit = 'unit';
      }
      if (!data.category || typeof data.category !== 'string') {
        updates.category = 'uncategorized';
      }

      if (Object.keys(updates).length === 0) {
        continue;
      }

      batch.update(itemDoc.ref, updates);
      writesInBatch += 1;
      userUpdatedCount += 1;

      if (writesInBatch === 400) {
        await commitBatch();
      }
    }

    await commitBatch();

    if (userUpdatedCount > 0) {
      totalDocsUpdated += userUpdatedCount;
      console.log(`✅ User ${userId}: updated ${userUpdatedCount} inventory docs`);
    }
  }

  console.log(`🎉 Backfill complete. Total documents updated: ${totalDocsUpdated}`);
  process.exit(0);
})().catch((err) => {
  console.error('❌ Backfill failed:', err);
  process.exit(1);
});
