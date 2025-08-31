# Grocery Inventory App 🛒

A neurodivergent-friendly grocery inventory management app that uses natural language processing to simplify tracking what's in your kitchen. Built with Flutter, Firebase, and integrated with Claude via Model Context Protocol (MCP).

## 🌟 Features

- **Natural Language Input**: Update inventory using everyday language like "bought 2 gallons milk" or "used 3 eggs"
- **AI-Powered Parsing**: OpenAI GPT-4 integration for intelligent text understanding
- **Claude Desktop Integration**: MCP server allows Claude to interact with your inventory
- **Visual Stock Indicators**: Clear visual feedback for stock levels (good/low/out)
- **Category Organization**: Automatic categorization of grocery items
- **Firebase Backend**: Real-time sync across devices with secure user data isolation
- **Neurodivergent-Friendly Design**: Minimal friction, forgiving input, no timers or pressure

## 🏗️ Architecture

The app consists of three main components:

```
├── Flutter Mobile App (lib/)         # Cross-platform mobile UI
├── Firebase Functions (functions/)   # REST API backend
└── MCP Server (mcp-server/)         # Claude Desktop integration
```

## 🚀 Getting Started

### Prerequisites

- Flutter SDK (3.8.1 or higher)
- Node.js (18 or higher)
- Firebase CLI
- Xcode (for iOS development)
- Android Studio (for Android development)

### Installation

1. **Clone the repository**
```bash
git clone https://github.com/yourusername/grocery-inventory-app.git
cd grocery-inventory-app
```

2. **Install Flutter dependencies**
```bash
flutter pub get
```

3. **Install Firebase Functions dependencies**
```bash
cd functions
npm install
cd ..
```

4. **Install MCP Server dependencies**
```bash
cd mcp-server
npm install
cd ..
```

### Configuration

1. **Firebase Setup**
   - Create a new Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Enable Authentication, Firestore, and Functions
   - Download `google-services.json` (Android) and `GoogleService-Info.plist` (iOS)
   - Run `flutterfire configure` to generate `firebase_options.dart`

2. **Environment Variables**
   - Copy `.env.example` to `.env` in both `functions/` and `mcp-server/`
   - Add your Firebase service account key and OpenAI API key

3. **Claude Desktop Integration**
   - Add the MCP server to your `claude_desktop_config.json`
   - See `mcp-server/README.md` for detailed instructions

## 🛠️ Development

### Running the Flutter App

```bash
# iOS Simulator
flutter run -d iphone

# Android Emulator
flutter run -d android

# Physical device
flutter run
```

### Running Firebase Functions Locally

```bash
cd functions
npm run serve
```

### Running MCP Server

```bash
cd mcp-server
npm run dev
```

### Testing

```bash
# Flutter tests
flutter test

# Functions tests
cd functions && npm test

# MCP Server tests
cd mcp-server && npm test
```

## 📱 App Structure

### Core Features

- **Text Input Screen**: Natural language grocery input
- **Review Screen**: AI-parsed items with confidence scores
- **Inventory Screen**: Current stock with search and filters
- **Settings Screen**: API keys and preferences

### State Management

The app uses Provider pattern with:
- `AuthProvider`: Authentication state
- `InventoryProvider`: Inventory data and operations
- `GroceryListProvider`: Grocery list and parsing logic

### Data Flow

1. User enters text → AI Parser → Structured data
2. Review & confirm → Update inventory
3. Sync with Firebase → Available everywhere

## 🔒 Security

- User data isolation via Firebase Security Rules
- Secure API key storage using `flutter_secure_storage`
- Authentication required for all API endpoints
- No sensitive data in repository

## 🤝 Contributing

Contributions are welcome! Please read [CONTRIBUTING.md](CONTRIBUTING.md) for details on our code of conduct and the process for submitting pull requests.

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## 🙏 Acknowledgments

- Built for the neurodivergent community
- Inspired by the challenges of grocery management with ADHD
- Claude Desktop MCP integration for AI assistance

## 📞 Support

For issues, questions, or suggestions:
- Open an issue on GitHub
- Contact: your-email@example.com

---

**Note**: This is a beta version. Some features are still in development.
