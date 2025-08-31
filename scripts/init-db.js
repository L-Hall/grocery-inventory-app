/**
 * Database initialization script for Grocery Inventory App
 * Run this after setting up Firebase to create initial data structure
 */

const admin = require('firebase-admin');

// Initialize Firebase Admin SDK
const serviceAccount = require('./service-account-key.json');
admin.initializeApp({
  credential: admin.credential.cert(serviceAccount)
});

const db = admin.firestore();

async function initializeDatabase() {
  console.log('🚀 Initializing database...');
  
  // Create a demo user for testing
  const testUserId = 'demo-user-123';
  
  try {
    // Create user document
    await db.doc(`users/${testUserId}`).set({
      email: 'demo@example.com',
      name: 'Demo User',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      settings: {
        lowStockThreshold: 2,
        notifications: true,
        preferredUnits: {
          milk: 'gallon',
          bread: 'loaf',
          eggs: 'dozen'
        }
      }
    });
    console.log('✅ Created demo user');

    // Create default categories
    const categories = [
      { id: 'dairy', name: 'Dairy', color: '#FFE4B5', icon: '🥛' },
      { id: 'produce', name: 'Produce', color: '#90EE90', icon: '🥬' },
      { id: 'meat', name: 'Meat & Poultry', color: '#FFB6C1', icon: '🥩' },
      { id: 'pantry', name: 'Pantry', color: '#DEB887', icon: '🥫' },
      { id: 'frozen', name: 'Frozen', color: '#B0E0E6', icon: '❄️' },
      { id: 'beverages', name: 'Beverages', color: '#FFFFE0', icon: '🧃' },
      { id: 'snacks', name: 'Snacks', color: '#F0E68C', icon: '🍿' },
      { id: 'bakery', name: 'Bakery', color: '#FFDAB9', icon: '🍞' }
    ];

    for (const category of categories) {
      await db.doc(`users/${testUserId}/categories/${category.id}`).set({
        ...category,
        sortOrder: categories.indexOf(category),
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    console.log('✅ Created default categories');

    // Create sample inventory items
    const sampleItems = [
      {
        name: 'Milk',
        quantity: 1,
        unit: 'gallon',
        category: 'dairy',
        location: 'fridge',
        lowStockThreshold: 1,
        brand: '2% Organic'
      },
      {
        name: 'Bread',
        quantity: 2,
        unit: 'loaf',
        category: 'bakery',
        location: 'pantry',
        lowStockThreshold: 1,
        brand: 'Whole Wheat'
      },
      {
        name: 'Eggs',
        quantity: 1,
        unit: 'dozen',
        category: 'dairy',
        location: 'fridge',
        lowStockThreshold: 1,
        brand: 'Free Range Large'
      },
      {
        name: 'Bananas',
        quantity: 6,
        unit: 'count',
        category: 'produce',
        location: 'counter',
        lowStockThreshold: 3,
        notes: 'Organic'
      },
      {
        name: 'Ground Coffee',
        quantity: 0,
        unit: 'bag',
        category: 'beverages',
        location: 'pantry',
        lowStockThreshold: 1,
        brand: 'Colombian Medium Roast'
      }
    ];

    for (const item of sampleItems) {
      await db.collection(`users/${testUserId}/inventory`).add({
        ...item,
        lastUpdated: admin.firestore.FieldValue.serverTimestamp(),
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
    }
    console.log('✅ Created sample inventory items');

    // Create sample grocery list
    await db.collection(`users/${testUserId}/grocery_lists`).add({
      name: 'Weekly Shopping',
      status: 'active',
      items: [
        {
          name: 'Ground Coffee',
          quantity: 1,
          unit: 'bag',
          category: 'beverages',
          checked: false,
          notes: 'Out of stock'
        },
        {
          name: 'Bananas',
          quantity: 6,
          unit: 'count',
          category: 'produce',
          checked: false,
          notes: 'Running low'
        }
      ],
      createdAt: admin.firestore.FieldValue.serverTimestamp()
    });
    console.log('✅ Created sample grocery list');

    console.log('🎉 Database initialization complete!');
    console.log(`Demo user ID: ${testUserId}`);
    
  } catch (error) {
    console.error('❌ Error initializing database:', error);
  }
}

// Run the initialization
initializeDatabase().then(() => {
  console.log('✨ Script completed');
  process.exit(0);
}).catch((error) => {
  console.error('💥 Script failed:', error);
  process.exit(1);
});