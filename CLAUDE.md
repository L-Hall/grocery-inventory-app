# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

This is a neurodivergent-friendly grocery inventory management app that replicates and enhances an existing Airtable + MCP workflow. The app enables natural language inventory updates (e.g., "bought 2 gallons milk") and targets users with ADHD, chronic illness, and executive function challenges.

## Architecture

The codebase consists of three main components:

### 1. Flutter Mobile App (`lib/`)
- **Architecture**: Feature-based with clean architecture patterns
- **State Management**: Provider pattern with dependency injection via GetIt
- **Structure**: `lib/core/` (shared services, themes, DI) + `lib/features/` (auth, inventory, grocery_list)
- **Key Pattern**: Each feature has `providers/`, `screens/`, `services/`, and `models/` subdirectories

### 2. Firebase Functions API (`functions/`)
- **Purpose**: REST API backend that mirrors MCP server functionality
- **Key File**: `src/index.ts` - Express.js API with Firebase Auth middleware
- **AI Integration**: `src/ai-parser.ts` - OpenAI-powered natural language parsing for grocery text
- **Endpoints**: Inventory CRUD, natural language parsing, low-stock alerts, grocery list generation

### 3. MCP Server (`mcp-server/`)
- **Purpose**: Enables Claude Desktop to interact with the grocery inventory via natural language
- **Key File**: `src/index.ts` - Model Context Protocol server
- **Tools Exposed**: `list_inventory`, `update_inventory`, `get_low_stock`, `search_inventory`, `create_grocery_list`
- **Backend**: Firebase Firestore integration

## Common Development Commands

### Flutter App Development
```bash
# Install dependencies
flutter pub get

# Run on simulator/device
flutter run

# Run tests
flutter test

# Build APK (Android)
flutter build apk

# Build iOS
flutter build ios
```

### Firebase Functions
```bash
cd functions
npm install
npm run build
npm run serve    # Local testing with emulators
npm run deploy   # Deploy to Firebase
npm run logs     # View function logs
```

### MCP Server
```bash
cd mcp-server
npm install
npm run build
npm run dev      # Development mode
npm run start    # Production mode
```

### Firebase Emulators
```bash
# Start all emulators (run from project root)
firebase emulators:start

# Functions only
firebase emulators:start --only functions

# Firestore only
firebase emulators:start --only firestore
```

## Key Configuration Files

### Environment Setup Required
1. **Firebase Project**: Create project and add configuration
2. **MCP Server**: Copy `mcp-server/.env.example` to `.env` and configure:
   - `FIREBASE_CREDENTIALS_PATH`: Path to service account key
   - `USER_ID`: User identifier for testing
   - `OPENAI_API_KEY`: For natural language processing

3. **Claude Desktop MCP Config**: Add server to `claude_desktop_config.json`
4. **Flutter Firebase**: Add `firebase_options.dart` via FlutterFire CLI

### Database Initialization
Run `scripts/init-db.js` to populate Firestore with sample data and categories.

## Core Design Principles

### Neurodivergent-First Design
- **Friction Reduction**: One-tap inventory updates, minimal required input
- **Forgiving Input**: Handles typos, shortcuts, any grocery text format
- **Visual Confirmation**: Review AI-parsed items before applying changes
- **No Timers/Pressure**: Update inventory whenever convenient

### Data Flow
1. **Text Input** → AI Parser → **Structured Updates** → **Review Screen** → **Database Update**
2. **MCP Integration**: Claude Desktop ↔ MCP Server ↔ Firebase ↔ Flutter App
3. **State Management**: UI updates via Provider, API calls via Repository pattern

## Key Business Logic

### Natural Language Processing
- **Input**: "bought 2 gallons milk and 3 loaves bread"
- **Processing**: OpenAI GPT-4 with structured function calling
- **Output**: `[{name: "Milk", quantity: 2, unit: "gallon", action: "add"}, ...]`
- **Fallback**: Simple keyword-based parsing when OpenAI unavailable

### Inventory Actions
- `add`: Purchases (bought, picked up, got)
- `subtract`: Consumption (used, ate, finished)
- `set`: Exact counts (have X left, only Y remaining)

### Stock Status Logic
- **Good**: quantity > lowStockThreshold
- **Low**: quantity <= lowStockThreshold
- **Out**: quantity = 0

## Integration Points

### MCP ↔ Firebase ↔ Flutter
All three components share the same data models and business logic. The MCP server and Firebase Functions expose identical functionality - MCP for Claude Desktop interaction, Functions for Flutter app.

### API Endpoints Mirror MCP Tools
- `GET /inventory` ↔ `list_inventory`
- `POST /inventory/update` ↔ `update_inventory`
- `POST /inventory/parse` ↔ Natural language processing
- `GET /inventory/low-stock` ↔ `get_low_stock`

## Development Workflow

1. **Backend First**: Set up Firebase project, deploy functions, test MCP server
2. **MCP Testing**: Use Claude Desktop to verify natural language workflow
3. **Flutter Integration**: Build UI that consumes the same APIs
4. **End-to-End**: Ensure MCP and Flutter app maintain data consistency

## Firebase Security

Firestore rules enforce user data isolation - users can only access documents where `request.auth.uid == userId`. All subcollections (inventory, categories, grocery_lists) inherit this security model.