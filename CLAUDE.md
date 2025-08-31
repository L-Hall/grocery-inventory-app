# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

A neurodivergent-friendly grocery inventory management app with natural language processing. Users can update inventory using everyday language like "bought 2 gallons milk" or "used 3 eggs". The app consists of a Flutter mobile frontend, Firebase Functions backend, and MCP server for Claude Desktop integration.

## Architecture

### Flutter App (`lib/`)
- **State Management**: Provider pattern with GetIt dependency injection
- **Feature Structure**: Each feature in `lib/features/` contains:
  - `providers/` - State management classes extending ChangeNotifier
  - `screens/` - UI screens
  - `services/` - Business logic and API calls
  - `models/` - Data models
  - `repositories/` - Data access layer
- **Core Services** (`lib/core/`):
  - `api_service.dart` - HTTP client for Firebase Functions
  - `storage_service.dart` - Local storage and secure credentials
  - `di/service_locator.dart` - Dependency injection setup

### Firebase Functions (`functions/`)
- **Express.js REST API** with Firebase Auth middleware
- **Key Files**:
  - `src/index.ts` - Main API routes
  - `src/ai-parser.ts` - OpenAI GPT-4 integration for natural language parsing
  - `src/middleware/auth.ts` - Firebase Auth verification
- **Endpoints**:
  - `POST /inventory/parse` - Parse natural language text
  - `GET /inventory` - List inventory items
  - `POST /inventory/update` - Update inventory quantities
  - `GET /inventory/low-stock` - Get low stock items

### MCP Server (`mcp-server/`)
- **Model Context Protocol** server for Claude Desktop
- **Tools**: `list_inventory`, `update_inventory`, `get_low_stock`, `search_inventory`, `create_grocery_list`
- Shares same Firebase backend as mobile app

## Development Commands

### Flutter Development
```bash
# Install dependencies
flutter pub get

# Run on iOS simulator
flutter run -d iphone

# Run on Android emulator  
flutter run -d android

# Run tests
flutter test

# Analyze code
flutter analyze

# Format code
dart format lib/

# Build for release
flutter build apk --release  # Android
flutter build ios --release  # iOS
```

### Firebase Functions
```bash
cd functions

# Install dependencies
npm install

# Lint TypeScript code
npm run lint

# Build TypeScript
npm run build

# Run with emulators
npm run serve

# Deploy to production
npm run deploy

# View logs
npm run logs
```

### MCP Server
```bash
cd mcp-server

# Install dependencies
npm install

# Build TypeScript
npm run build

# Development mode (with hot reload)
npm run dev

# Production mode
npm run start
```

### Firebase Emulators
```bash
# From project root
firebase emulators:start                    # All emulators
firebase emulators:start --only functions   # Functions only
firebase emulators:start --only firestore   # Firestore only
```

## Initial Setup

### 1. Firebase Configuration
```bash
# Install Firebase CLI
npm install -g firebase-tools

# Login and select project
firebase login
firebase use --add

# Generate Flutter config
flutterfire configure
```

### 2. Environment Files
Create `.env` files from examples:
```bash
# MCP Server
cp mcp-server/.env.example mcp-server/.env
# Add: FIREBASE_CREDENTIALS_PATH, USER_ID, OPENAI_API_KEY

# Functions  
cp functions/.env.example functions/.env
# Add: OPENAI_API_KEY
```

### 3. Database Initialization
```bash
node scripts/init-db.js
```

### 4. Claude Desktop Integration
Add to `claude_desktop_config.json`:
```json
{
  "mcpServers": {
    "grocery-inventory": {
      "command": "node",
      "args": ["path/to/mcp-server/dist/index.js"]
    }
  }
}
```

## Key Business Logic

### Natural Language Parsing
The app uses OpenAI GPT-4 to parse natural language into structured updates:
- **Actions**: `add` (bought, got), `subtract` (used, ate), `set` (have X left)
- **Parser Location**: `functions/src/ai-parser.ts`
- **Fallback**: Keyword-based parsing when OpenAI unavailable

### Inventory Update Flow
1. User enters text in `TextInputScreen`
2. Text sent to `/inventory/parse` endpoint
3. OpenAI returns structured `ParsedItem[]`
4. User reviews in `ReviewScreen`
5. Confirmed updates sent to `/inventory/update`
6. Firestore updated, UI refreshes via Provider

### Stock Status Calculation
```typescript
// In lib/features/inventory/models/inventory_item.dart
StockStatus get stockStatus {
  if (quantity == 0) return StockStatus.out;
  if (quantity <= lowStockThreshold) return StockStatus.low;
  return StockStatus.good;
}
```

## Testing Approach

### Flutter Tests
```bash
# Run all tests
flutter test

# Run specific test file
flutter test test/features/auth/auth_provider_test.dart

# Run with coverage
flutter test --coverage
```

### Functions Tests
```bash
cd functions
npm test  # When test files are added
```

## Common Issues and Solutions

### Import Conflicts
- `AuthProvider` conflicts with firebase_auth: Use import alias
  ```dart
  import '../../features/auth/providers/auth_provider.dart' as auth;
  ```
- `Category` conflicts with Flutter foundation: Use import alias
  ```dart
  import '../models/category.dart' as cat;
  ```

### Flutter Build Issues
```bash
# Clean build artifacts
flutter clean
flutter pub get

# Reset iOS pods
cd ios && pod deintegrate && pod install
```

### Firebase Emulator Issues
```bash
# Kill existing emulators
lsof -i :5001  # Find process using port
kill -9 [PID]  # Kill process

# Clear emulator data
firebase emulators:start --clear
```

## API Authentication

All API endpoints require Firebase Auth token in header:
```javascript
headers: {
  'Authorization': `Bearer ${idToken}`,
  'Content-Type': 'application/json'
}
```

## Database Structure

Firestore collections:
```
users/{userId}/
  ├── inventory/{itemId}    # Inventory items
  ├── categories/{catId}    # Item categories  
  └── grocery_lists/{listId} # Shopping lists
```

## Security Rules

Users can only access their own data:
```javascript
match /users/{userId}/{document=**} {
  allow read, write: if request.auth != null && request.auth.uid == userId;
}
```