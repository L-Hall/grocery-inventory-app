// Overwrite all users' category subcollections with the latest defaults.
// Usage:
//   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
//   node scripts/reset_user_categories.js

import { initializeApp, applicationDefault } from 'firebase-admin/app';
import { getFirestore } from 'firebase-admin/firestore';

const categories = [
  { id: 'dairy', name: 'Chilled', color: '#FFC107', icon: '🥛' },
  { id: 'produce', name: 'Fruit & veg', color: '#4CAF50', icon: '🥬' },
  { id: 'meat', name: 'Meat', color: '#F44336', icon: '🥩' },
  { id: 'pantry', name: 'Food cupboard', color: '#FF9800', icon: '🥫' },
  { id: 'frozen', name: 'Frozen', color: '#00BCD4', icon: '❄️' },
  { id: 'beverages', name: 'Drinks', color: '#2196F3', icon: '🧃' },
  { id: 'snacks', name: 'Snacks', color: '#9C27B0', icon: '🍿' },
  { id: 'bakery', name: 'Bakery', color: '#FFCA85', icon: '🍞' },
];

async function main() {
  initializeApp({ credential: applicationDefault() });
  const db = getFirestore();

  const usersSnap = await db.collection('users').get();
  console.log(`Updating categories for ${usersSnap.size} users`);

  for (const userDoc of usersSnap.docs) {
    const userId = userDoc.id;
    const catCollection = db.collection(`users/${userId}/categories`);
    const existing = await catCollection.get();

    // Delete existing categories
    if (!existing.empty) {
      const deleteBatch = db.batch();
      existing.docs.forEach((doc) => deleteBatch.delete(doc.ref));
      await deleteBatch.commit();
      console.log(`Cleared ${existing.size} categories for user ${userId}`);
    }

    // Write new categories
    const writeBatch = db.batch();
    categories.forEach((c, idx) => {
      const ref = catCollection.doc(c.id);
      writeBatch.set(ref, {
        ...c,
        sortOrder: idx + 1,
        createdAt: new Date(),
      });
    });
    await writeBatch.commit();
    console.log(`Seeded categories for user ${userId}`);
  }

  console.log('Done.');
}

main().catch((err) => {
  console.error('Failed to reset categories:', err);
  process.exit(1);
});
