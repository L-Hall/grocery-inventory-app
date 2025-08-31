#!/bin/bash

# Secret Manager Setup Script for Firebase Functions
# This script helps you configure secrets in Google Cloud Secret Manager

set -e

echo "🔐 Firebase Secret Manager Setup"
echo "================================"
echo ""

# Check if Firebase CLI is installed
if ! command -v firebase &> /dev/null; then
    echo "❌ Firebase CLI is not installed."
    echo "Please install it with: npm install -g firebase-tools"
    exit 1
fi

# Check if logged in to Firebase
if ! firebase projects:list &> /dev/null; then
    echo "❌ You are not logged in to Firebase."
    echo "Please run: firebase login"
    exit 1
fi

echo "📝 This script will help you set up secrets for your Firebase Functions."
echo ""

# Function to set a secret
set_secret() {
    local secret_name=$1
    local secret_description=$2
    
    echo ""
    echo "Setting up: $secret_name"
    echo "Description: $secret_description"
    echo ""
    
    read -p "Would you like to set $secret_name? (y/n): " -n 1 -r
    echo ""
    
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        echo "Enter the value for $secret_name (input will be hidden):"
        read -s secret_value
        echo ""
        
        if [ -z "$secret_value" ]; then
            echo "⚠️  Skipping $secret_name (no value provided)"
        else
            echo "Setting $secret_name in Secret Manager..."
            echo "$secret_value" | firebase functions:secrets:set $secret_name
            
            if [ $? -eq 0 ]; then
                echo "✅ $secret_name has been set successfully"
            else
                echo "❌ Failed to set $secret_name"
            fi
        fi
    else
        echo "⏭️  Skipping $secret_name"
    fi
}

# Main script
echo "🔍 Checking current project..."
firebase projects:list | head -5
echo ""

read -p "Is the correct project selected? (y/n): " -n 1 -r
echo ""

if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    echo "Please select the correct project:"
    echo "Run: firebase use <project-id>"
    exit 1
fi

echo "📦 Setting up required secrets..."
echo "================================"

# Set up OpenAI API Key
set_secret "OPENAI_API_KEY" "OpenAI API key for natural language processing (get from https://platform.openai.com/api-keys)"

# Add more secrets as needed
# set_secret "STRIPE_SECRET_KEY" "Stripe secret key for payment processing"
# set_secret "SENDGRID_API_KEY" "SendGrid API key for email notifications"

echo ""
echo "📋 Managing Secrets"
echo "==================="
echo ""
echo "To view current secrets:"
echo "  firebase functions:secrets:access SECRET_NAME"
echo ""
echo "To list all secrets:"
echo "  firebase functions:secrets:list"
echo ""
echo "To delete a secret:"
echo "  firebase functions:secrets:destroy SECRET_NAME"
echo ""
echo "To update a secret:"
echo "  firebase functions:secrets:set SECRET_NAME"
echo ""

echo "📝 Local Development"
echo "===================="
echo ""
echo "For local development with emulators:"
echo "1. Copy functions/.secret.local.example to functions/.secret.local"
echo "2. Add your API keys to functions/.secret.local"
echo "3. The emulator will automatically use these values"
echo ""

echo "🚀 Deployment"
echo "============="
echo ""
echo "After setting secrets, deploy your functions:"
echo "  firebase deploy --only functions"
echo ""
echo "Note: Functions must be redeployed to use updated secret values"
echo ""

echo "✅ Secret setup complete!"