#!/usr/bin/env node

/**
 * Deployment verification script for Firebase Functions.
 *
 * Usage:
 *   node scripts/verify-deployment.js
 *
 * Optionally override the base URL:
 *   FUNCTIONS_BASE_URL="https://<region>-<project>.cloudfunctions.net/api" node scripts/verify-deployment.js
 */

const DEFAULT_BASE_URL = "https://us-central1-helical-button-461921-v6.cloudfunctions.net/api";

async function main() {
  const baseUrl = process.env.FUNCTIONS_BASE_URL || DEFAULT_BASE_URL;
  const normalizedBase = baseUrl.endsWith("/") ? baseUrl : `${baseUrl}/`;
  const healthUrl = new URL("health", normalizedBase).toString();

  try {
    const response = await fetch(healthUrl, {
      headers: {"Accept": "application/json"},
      method: "GET",
    });

    if (!response.ok) {
      throw new Error(`Health check returned HTTP ${response.status}`);
    }

    const payload = await response.json();
    if (payload.status !== "healthy") {
      throw new Error(`Unexpected health status: ${JSON.stringify(payload)}`);
    }

    console.log("✅ Deployment verification passed:", {
      url: healthUrl,
      status: payload.status,
      timestamp: payload.timestamp,
    });
  } catch (error) {
    console.error("❌ Deployment verification failed:", error.message);
    process.exitCode = 1;
  }
}

main();
