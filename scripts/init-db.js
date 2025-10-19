/**
 * Database Initialization Script for Grocery Inventory App
 * 
 * This script sets up the initial Firestore database structure
 * including categories, sample inventory items, and user settings
 * 
 * Usage: node scripts/init-db.js [--test-user-id=<userId>]
 */

const admin = require('firebase-admin');
const path = require('path');
const fs = require('fs');

// Parse command line arguments
const args = process.argv.slice(2);
const testUserId = args.find(arg => arg.startsWith('--test-user-id='))?.split('=')[1] || 'test-user-' + Date.now();

// Initialize Firebase Admin SDK
const serviceAccountPath = process.env.FIREBASE_CREDENTIALS_PATH || 
                          path.join(__dirname, '..', 'service-account-key.json');

if (fs.existsSync(serviceAccountPath)) {
  console.log('✅ Using service account key');
  const serviceAccount = require(serviceAccountPath);
  admin.initializeApp({
    credential: admin.credential.cert(serviceAccount)
  });
} else {
  console.log('ℹ️  Service account key not found, using application default credentials');
  console.log('   Make sure you are logged in with: gcloud auth application-default login');
  admin.initializeApp({
    projectId: 'helical-button-461921-v6'
  });
}

const db = admin.firestore();

// Default categories with neurodivergent-friendly colors and icons
const DEFAULT_CATEGORIES = [
  { id: 'dairy', name: 'Dairy', color: '#FFE4B5', icon: '🥛', sortOrder: 0 },
  { id: 'produce', name: 'Produce', color: '#90EE90', icon: '🥬', sortOrder: 1 },
  { id: 'meat', name: 'Meat & Poultry', color: '#FFB6C1', icon: '🥩', sortOrder: 2 },
  { id: 'seafood', name: 'Seafood', color: '#E0FFFF', icon: '🐟', sortOrder: 3 },
  { id: 'pantry', name: 'Pantry', color: '#DEB887', icon: '🥫', sortOrder: 4 },
  { id: 'frozen', name: 'Frozen', color: '#B0E0E6', icon: '❄️', sortOrder: 5 },
  { id: 'beverages', name: 'Beverages', color: '#FFFFE0', icon: '🧃', sortOrder: 6 },
  { id: 'snacks', name: 'Snacks', color: '#F0E68C', icon: '🍿', sortOrder: 7 },
  { id: 'bakery', name: 'Bakery', color: '#FFDAB9', icon: '🍞', sortOrder: 8 },
  { id: 'household', name: 'Household', color: '#DDA0DD', icon: '🧹', sortOrder: 9 },
  { id: 'personal', name: 'Personal Care', color: '#FFB6C1', icon: '🧴', sortOrder: 10 },
  { id: 'other', name: 'Other', color: '#D3D3D3', icon: '📦', sortOrder: 11 }
];

// Sample inventory items for testing
const SAMPLE_INVENTORY = [
  // Dairy
  { name: 'Milk', quantity: 1, unit: 'gallon', category: 'dairy', location: 'fridge', lowStockThreshold: 1 },
  { name: 'Eggs', quantity: 6, unit: 'count', category: 'dairy', location: 'fridge', lowStockThreshold: 6 },
  { name: 'Butter', quantity: 2, unit: 'stick', category: 'dairy', location: 'fridge', lowStockThreshold: 1 },
  { name: 'Cheese', quantity: 1, unit: 'block', category: 'dairy', location: 'fridge', lowStockThreshold: 1 },
  { name: 'Yogurt', quantity: 4, unit: 'cup', category: 'dairy', location: 'fridge', lowStockThreshold: 2 },
  
  // Produce
  { name: 'Apples', quantity: 5, unit: 'count', category: 'produce', location: 'pantry', lowStockThreshold: 3 },
  { name: 'Bananas', quantity: 3, unit: 'count', category: 'produce', location: 'pantry', lowStockThreshold: 2 },
  { name: 'Lettuce', quantity: 1, unit: 'head', category: 'produce', location: 'fridge', lowStockThreshold: 1 },
  { name: 'Tomatoes', quantity: 4, unit: 'count', category: 'produce', location: 'pantry', lowStockThreshold: 2 },
  { name: 'Carrots', quantity: 1, unit: 'bag', category: 'produce', location: 'fridge', lowStockThreshold: 1 },
  
  // Pantry
  { name: 'Bread', quantity: 1, unit: 'loaf', category: 'bakery', location: 'pantry', lowStockThreshold: 1 },
  { name: 'Rice', quantity: 2, unit: 'lb', category: 'pantry', location: 'pantry', lowStockThreshold: 1 },
  { name: 'Pasta', quantity: 3, unit: 'box', category: 'pantry', location: 'pantry', lowStockThreshold: 2 },
  { name: 'Cereal', quantity: 2, unit: 'box', category: 'pantry', location: 'pantry', lowStockThreshold: 1 },
  { name: 'Peanut Butter', quantity: 1, unit: 'jar', category: 'pantry', location: 'pantry', lowStockThreshold: 1 },
  
  // Meat
  { name: 'Chicken Breast', quantity: 2, unit: 'lb', category: 'meat', location: 'fridge', lowStockThreshold: 1 },
  { name: 'Ground Beef', quantity: 1, unit: 'lb', category: 'meat', location: 'fridge', lowStockThreshold: 1 },
  
  // Beverages
  { name: 'Orange Juice', quantity: 1, unit: 'carton', category: 'beverages', location: 'fridge', lowStockThreshold: 1 },
  { name: 'Coffee', quantity: 1, unit: 'bag', category: 'beverages', location: 'pantry', lowStockThreshold: 1 },
  { name: 'Tea Bags', quantity: 20, unit: 'count', category: 'beverages', location: 'pantry', lowStockThreshold: 10 },
  
  // Household
  { name: 'Paper Towels', quantity: 4, unit: 'roll', category: 'household', location: 'pantry', lowStockThreshold: 2 },
  { name: 'Toilet Paper', quantity: 8, unit: 'roll', category: 'household', location: 'pantry', lowStockThreshold: 4 },
  { name: 'Dish Soap', quantity: 1, unit: 'bottle', category: 'household', location: 'pantry', lowStockThreshold: 1 }
];

async function initializeDatabase() {
  console.log('🚀 Starting database initialization...\n');
  
  try {
    // Step 1: Create or update user document
    console.log('📝 Creating user document for:', testUserId);
    const userRef = db.doc(`users/${testUserId}`);
    
    await userRef.set({
      email: `${testUserId}@example.com`,
      name: 'Test User',
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
      settings: {
        lowStockThreshold: 2,
        notifications: true,
        preferredUnits: {
          milk: 'gallon',
          bread: 'loaf',
          eggs: 'dozen',
          meat: 'lb',
          produce: 'lb'
        }
      }
    }, { merge: true });
    
    console.log('✅ User document created\n');
    
    // Step 2: Create categories
    console.log('🏷️  Creating categories...');
    const batch = db.batch();
    
    for (const category of DEFAULT_CATEGORIES) {
      const categoryRef = db.doc(`users/${testUserId}/categories/${category.id}`);
      batch.set(categoryRef, {
        ...category,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }
    
    await batch.commit();
    console.log(`✅ Created ${DEFAULT_CATEGORIES.length} categories\n`);
    
    // Step 3: Create sample inventory items
    console.log('📦 Creating sample inventory items...');
    const inventoryBatch = db.batch();
    
    for (const item of SAMPLE_INVENTORY) {
      // Use item name as ID for consistency
      const itemId = item.name.toLowerCase().replace(/\s+/g, '-');
      const itemRef = db.doc(`users/${testUserId}/inventory/${itemId}`);
      
      inventoryBatch.set(itemRef, {
        ...item,
        createdAt: admin.firestore.FieldValue.serverTimestamp(),
        lastUpdated: admin.firestore.FieldValue.serverTimestamp()
      }, { merge: true });
    }
    
    await inventoryBatch.commit();
    console.log(`✅ Created ${SAMPLE_INVENTORY.length} inventory items\n`);
    
    // Step 4: Create a sample grocery list from low stock items
    console.log('📋 Creating sample grocery list...');
    
    const lowStockItems = SAMPLE_INVENTORY.filter(item => 
      item.quantity <= item.lowStockThreshold
    );
    
    if (lowStockItems.length > 0) {
      const listItems = lowStockItems.map(item => ({
        name: item.name,
        quantity: (item.lowStockThreshold + 1) - item.quantity,
        unit: item.unit,
        category: item.category,
        checked: false,
        notes: item.quantity === 0 ? 'Out of stock' : 'Running low'
      }));
      
      const listRef = await db.collection(`users/${testUserId}/grocery_lists`).add({
        name: 'Weekly Shopping List',
        status: 'active',
        items: listItems,
        createdAt: admin.firestore.FieldValue.serverTimestamp()
      });
      
      console.log(`✅ Created grocery list with ${listItems.length} items\n`);
    }
    
    // Step 5: Display summary
    console.log('🎉 Database initialization complete!\n');
    console.log('📊 Summary:');
    console.log(`   • User ID: ${testUserId}`);
    console.log(`   • Categories: ${DEFAULT_CATEGORIES.length}`);
    console.log(`   • Inventory Items: ${SAMPLE_INVENTORY.length}`);
    console.log(`   • Low Stock Items: ${lowStockItems.length}`);
    
    console.log('\n📱 To use this database:');
    console.log(`   1. Update your Flutter app to use User ID: ${testUserId}`);
    console.log('   2. Or create a new user through the app authentication flow');
    console.log('   3. Start the Firebase emulator: firebase emulators:start');
    console.log('   4. Run your Flutter app: flutter run');
    
    // Export test data for reference
    const configData = {
      testUserId,
      initialized: new Date().toISOString(),
      categories: DEFAULT_CATEGORIES.length,
      inventory: SAMPLE_INVENTORY.length
    };
    
    fs.writeFileSync(
      path.join(__dirname, 'test-config.json'),
      JSON.stringify(configData, null, 2)
    );
    
    console.log('\n💾 Test configuration saved to scripts/test-config.json');
    
  } catch (error) {
    console.error('❌ Error initializing database:', error);
    process.exit(1);
  }
  
  process.exit(0);
}

// Run the initialization
initializeDatabase();