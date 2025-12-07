// One-time Firestore category seeder.
// Usage:
//   export GOOGLE_APPLICATION_CREDENTIALS=/path/to/serviceAccount.json
//   node scripts/seed_categories.js

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

  const batch = db.batch();
  categories.forEach((c, idx) => {
    const ref = db.collection('categories').doc(c.id);
    batch.set(ref, { ...c, sortOrder: idx + 1 }, { merge: false });
  });

  await batch.commit();
  console.log('Categories seeded:', categories.length);
}

main().catch((err) => {
  console.error('Failed to seed categories:', err);
  process.exit(1);
});
