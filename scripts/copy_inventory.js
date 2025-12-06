// Copy legacy user inventory into a household items subcollection.
// Usage: node scripts/copy_inventory.js <uid> <householdId>

const admin = require('firebase-admin');

const projectId = 'helical-button-461921-v6';

if (!admin.apps.length) {
  admin.initializeApp({ projectId });
}

const db = admin.firestore();

async function copyInventory(uid, householdId) {
  const legacyRef = db.collection('users').doc(uid).collection('inventory');
  const legacySnap = await legacyRef.get();
  console.log(`Found ${legacySnap.size} legacy items for ${uid}`);

  if (legacySnap.empty) {
    console.log('No legacy items to copy.');
    return;
  }

  const itemsColl = db.collection('households').doc(householdId).collection('items');
  const chunkSize = 400;
  let chunk = [];

  for (const doc of legacySnap.docs) {
    chunk.push(doc);
    if (chunk.length >= chunkSize) {
      await writeChunk(chunk, itemsColl);
      chunk = [];
    }
  }
  if (chunk.length) {
    await writeChunk(chunk, itemsColl);
  }
  console.log('Done.');
}

async function writeChunk(docs, itemsColl) {
  const batch = db.batch();
  docs.forEach((doc) => {
    batch.set(itemsColl.doc(doc.id), doc.data(), { merge: true });
  });
  await batch.commit();
  console.log(`Wrote ${docs.length} docs`);
}

const [uid, householdId] = process.argv.slice(2);
if (!uid || !householdId) {
  console.error('Usage: node scripts/copy_inventory.js <uid> <householdId>');
  process.exit(1);
}

copyInventory(uid, householdId).catch((err) => {
  console.error(err);
  process.exit(1);
});
