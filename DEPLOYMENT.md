# Firebase Backend Deployment Guide

This guide provides step-by-step instructions for deploying the Firebase backend for the Grocery Inventory App.

## Prerequisites

- Node.js 16+ installed
- Firebase CLI installed (`npm install -g firebase-tools`)
- Google Cloud account with billing enabled
- Flutter SDK installed (for mobile app)

## Initial Setup

### 1. Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Your project is already created: `helical-button-461921-v6`
3. If needed, access it at: https://console.firebase.google.com/project/helical-button-461921-v6

### 2. Enable Required Services

In Firebase Console, enable:
- **Authentication** → Email/Password and Google Sign-In
- **Firestore Database** → Start in production mode
- **Cloud Functions** → Requires billing account
- **Cloud Storage** (optional for future features)

### 3. Download Service Account Key

1. Go to Project Settings → Service Accounts
2. Click "Generate New Private Key"
3. Save as `service-account-key.json` in project root
4. Add to `.gitignore` (should already be there)

## Local Development Setup

### 1. Install Dependencies

```bash
# Install Firebase Functions dependencies
cd functions
npm install

# Install MCP Server dependencies (optional)
cd ../mcp-server
npm install

# Return to root
cd ..
```

### 2. Configure Secrets with Google Cloud Secret Manager

Firebase Functions now use Google Cloud Secret Manager for secure API key storage.

#### Set up secrets for production:

```bash
# Run the automated setup script
./scripts/setup-secrets.sh

# Or manually set secrets using Firebase CLI
firebase functions:secrets:set OPENAI_API_KEY
```

#### For local development:

```bash
# Copy the local secrets template
cp functions/.secret.local.example functions/.secret.local

# Edit functions/.secret.local and add your API keys
# NEVER commit .secret.local to version control
OPENAI_API_KEY=your_openai_api_key_here
```

#### Configure non-secret environment variables:

```bash
# Copy example files (for non-secret configuration only)
cp functions/.env.example functions/.env
cp mcp-server/.env.example mcp-server/.env

# Edit mcp-server/.env (service account path only)
FIREBASE_CREDENTIALS_PATH=../service-account-key.json
USER_ID=test-user-123
```

### 3. Initialize Database

```bash
# Run initialization script
node scripts/init-db.js

# Or with custom user ID
node scripts/init-db.js --test-user-id=my-test-user
```

### 4. Start Firebase Emulators

```bash
# Start all emulators
firebase emulators:start

# Or specific emulators
firebase emulators:start --only functions,firestore

# Access Emulator UI at http://localhost:4000
```

## Production Deployment

### 1. Set Production Secrets

```bash
# Use Secret Manager for sensitive data (recommended)
firebase functions:secrets:set OPENAI_API_KEY

# Or use the setup script
./scripts/setup-secrets.sh

# List all secrets
firebase functions:secrets:list

# View a secret value (be careful - this displays the secret)
firebase functions:secrets:access OPENAI_API_KEY
```

### 2. Deploy Security Rules

```bash
# Deploy Firestore security rules
firebase deploy --only firestore:rules

# Deploy Storage rules (if using)
firebase deploy --only storage:rules
```

### 3. Deploy Firestore Indexes

```bash
# Deploy database indexes
firebase deploy --only firestore:indexes
```

### 4. Deploy Cloud Functions

```bash
# Build and deploy functions
cd functions
npm run build
firebase deploy --only functions

# Or deploy everything
firebase deploy
```

### 5. Initialize Production Database

1. Update `scripts/init-db.js` with production user ID
2. Run initialization:
```bash
node scripts/init-db.js --test-user-id=production-demo-user
```

## Testing Deployment

### 1. Test API Endpoints

```bash
# Get health status
curl https://us-central1-helical-button-461921-v6.cloudfunctions.net/api/health

# Test with authentication (get token from Firebase Auth)
curl -H "Authorization: Bearer [TOKEN]" \
  https://us-central1-helical-button-461921-v6.cloudfunctions.net/api/inventory
```

### 2. Test Flutter App Connection

Update Flutter app configuration:
```dart
// lib/core/config/firebase_config.dart
const String apiBaseUrl = 'https://us-central1-helical-button-461921-v6.cloudfunctions.net/api';
```

### 3. Monitor Functions

```bash
# View logs
firebase functions:log

# View specific function logs
firebase functions:log --only api
```

## CI/CD Setup (GitHub Actions)

Create `.github/workflows/deploy.yml`:

```yaml
name: Deploy to Firebase

on:
  push:
    branches: [main]

jobs:
  deploy:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v2
      
      - name: Setup Node.js
        uses: actions/setup-node@v2
        with:
          node-version: '16'
          
      - name: Install dependencies
        run: |
          npm install -g firebase-tools
          cd functions && npm ci
          
      - name: Build Functions
        run: cd functions && npm run build
        
      - name: Deploy to Firebase
        run: firebase deploy --only functions,firestore
        env:
          FIREBASE_TOKEN: ${{ secrets.FIREBASE_TOKEN }}
```

Generate Firebase CI token:
```bash
firebase login:ci
# Add token to GitHub Secrets as FIREBASE_TOKEN
```

## Environment-Specific Configuration

### Development
- Uses Firebase Emulators
- Test data in local Firestore
- Console logging enabled
- CORS allows all origins

### Staging (Optional)
- Separate Firebase project
- Limited test users
- Production-like rules
- Performance monitoring

### Production
- Production Firebase project
- Strict security rules
- Error reporting to Cloud Logging
- Performance monitoring enabled

## Secret Management

### Google Cloud Secret Manager

The application uses Google Cloud Secret Manager for storing sensitive data like API keys. This provides:
- Secure encrypted storage
- Version control for secrets
- Audit logging
- Fine-grained access control

### Managing Secrets

```bash
# Set a new secret
firebase functions:secrets:set SECRET_NAME

# Update an existing secret (creates new version)
firebase functions:secrets:set SECRET_NAME

# List all secrets
firebase functions:secrets:list

# View secret value (use with caution)
firebase functions:secrets:access SECRET_NAME

# Delete a secret
firebase functions:secrets:destroy SECRET_NAME

# Prune old versions (keep only latest)
firebase functions:secrets:prune
```

### Secret Rotation

To rotate a secret:
1. Set new value: `firebase functions:secrets:set OPENAI_API_KEY`
2. Redeploy functions: `firebase deploy --only functions`
3. Verify deployment
4. Optional: Prune old versions

### Cost Considerations

- First 6 active secret versions are free
- Additional versions: $0.06 per version per month
- Access operations: First 10,000 free per month
- Use `firebase functions:secrets:prune` to manage costs

## Monitoring & Maintenance

### 1. Monitor Usage

- Firebase Console → Usage tab
- Monitor Firestore reads/writes
- Check Functions invocations
- Review error logs

### 2. Backup Strategy

```bash
# Export Firestore data
gcloud firestore export gs://helical-button-461921-v6.appspot.com/backups/

# Schedule automatic backups
gcloud firestore operations schedule-recurring-backup \
  --database=default \
  --recurrence=daily \
  --retention=7d
```

### 3. Update Dependencies

```bash
# Check for updates
cd functions
npm outdated

# Update dependencies
npm update

# Test after updates
npm test
firebase emulators:start
```

## Troubleshooting

### Common Issues

1. **CORS Errors**
   - Check Functions CORS configuration
   - Verify Flutter app API URL
   - Add domain to allowed origins

2. **Authentication Failures**
   - Verify Firebase Auth configuration
   - Check token expiration
   - Ensure user initialization

3. **Firestore Permission Denied**
   - Review security rules
   - Check user authentication
   - Verify document paths

4. **Functions Timeout**
   - Increase timeout in function config
   - Optimize database queries
   - Consider pagination

### Debug Commands

```bash
# Check Firebase project
firebase projects:list

# Verify configuration
firebase functions:config:get

# Test locally with shell
firebase functions:shell

# View detailed logs
firebase functions:log --tail 100
```

## Security Checklist

- [ ] Service account key not in version control (.gitignore configured)
- [ ] API keys stored in Google Cloud Secret Manager (not in .env files)
- [ ] .secret.local file not in version control (for local dev only)
- [ ] Secrets properly configured via Firebase CLI
- [ ] Security rules tested and deployed
- [ ] API endpoints require authentication
- [ ] Input validation on all endpoints
- [ ] Rate limiting configured
- [ ] CORS properly configured
- [ ] Sensitive data encrypted
- [ ] Secret Manager IAM permissions configured correctly

## Support Resources

- [Firebase Documentation](https://firebase.google.com/docs)
- [Flutter Firebase Setup](https://firebase.flutter.dev/)
- [Firebase Functions Best Practices](https://firebase.google.com/docs/functions/tips)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/get-started)

## Contact

For deployment issues or questions:
- Create issue in GitHub repository
- Check Firebase Status: https://status.firebase.google.com/