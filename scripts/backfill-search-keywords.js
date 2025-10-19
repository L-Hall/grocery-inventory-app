#!/usr/bin/env node

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

function generateSearchKeywords(name) {
  return Array.from(
    new Set(
      name
        .toLowerCase()
        .replace(/[^a-z0-9\s]/g, ' ')
        .split(/\s+/)
        .filter(Boolean)
        .concat(name.toLowerCase().trim())
    )
  ).filter(Boolean);
}

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
  admin.initializeApp({
    projectId: 'helical-button-461921-v6',
  });
}

const db = admin.firestore();

(async () => {
  console.log('🔍 Backfilling searchKeywords for inventory documents...');

  const usersSnapshot = await db.collection('users').get();
  let updatedCount = 0;

  for (const userDoc of usersSnapshot.docs) {
    const userId = userDoc.id;
    const inventorySnapshot = await db.collection(`users/${userId}/inventory`).get();

    const batch = db.batch();
    let userUpdates = 0;

    inventorySnapshot.docs.forEach((itemDoc) => {
      const data = itemDoc.data();
      const keywords = generateSearchKeywords(data.name || '');
      if (!keywords.length) return;

      if (!Array.isArray(data.searchKeywords) || data.searchKeywords.sort().join(',') !== keywords.sort().join(',')) {
        batch.update(itemDoc.ref, {searchKeywords: keywords});
        userUpdates += 1;
      }
    });

    if (userUpdates === 0) {
      continue;
    }

    await batch.commit();
    updatedCount += userUpdates;
    console.log(`✅ Updated ${userUpdates} docs for user ${userId}`);
  }

  console.log(`🎉 Backfill complete. Documents updated: ${updatedCount}`);
  process.exit(0);
})().catch((err) => {
  console.error('❌ Backfill failed:', err);
  process.exit(1);
});
