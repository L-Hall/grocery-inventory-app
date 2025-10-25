/**
 * Secret Manager Integration for Firebase Functions
 *
 * This module provides utilities for accessing secrets from Google Cloud Secret Manager
 * and handles fallback for local development
 */

import {SecretManagerServiceClient} from "@google-cloud/secret-manager";
import * as logger from "firebase-functions/logger";
import * as functions from "firebase-functions";
import * as fs from "fs";
import * as path from "path";

// Initialize Secret Manager client
const secretsClient = new SecretManagerServiceClient();

/**
 * Get secret value from Secret Manager or local file
 * @param secretName - Name of the secret to retrieve
 * @return The secret value as a string
 */
export async function getSecret(secretName: string): Promise<string | undefined> {
  try {
    // In production, secrets are available as environment variables
    // when using runWith({ secrets: [...] })
    if (process.env[secretName]) {
      return process.env[secretName];
    }

    // For local development, check .secret.local file
    if (process.env.FUNCTIONS_EMULATOR === "true") {
      const secretsPath = path.join(__dirname, "..", ".secret.local");
      if (fs.existsSync(secretsPath)) {
        const secrets = fs.readFileSync(secretsPath, "utf8")
          .split("\n")
          .reduce((acc, line) => {
            const [key, value] = line.split("=");
            if (key && value) {
              acc[key.trim()] = value.trim();
            }
            return acc;
          }, {} as Record<string, string>);

        return secrets[secretName];
      }
    }

    // Fallback to Firebase config (for backward compatibility)
    const config = functions.config();
    const configPath = secretName.toLowerCase().replace(/_/g, ".");
    const parts = configPath.split(".");

    let value = config;
    for (const part of parts) {
      value = value?.[part];
    }

    if (typeof value === "string") {
      return value;
    }

    logger.warn(`Secret ${secretName} not found in any source`);
    return undefined;
  } catch (error) {
    logger.error(`Error accessing secret ${secretName}`, {
      error,
    });
    return undefined;
  }
}

/**
 * Get secret value directly from Secret Manager
 * Used when you need to access secrets outside of function context
 * @param projectId - GCP project ID
 * @param secretName - Name of the secret
 * @param version - Version of the secret (default: 'latest')
 */
export async function getSecretFromManager(
  projectId: string,
  secretName: string,
  version: string = "latest"
): Promise<string | undefined> {
  try {
    const name = `projects/${projectId}/secrets/${secretName}/versions/${version}`;
    const [accessResponse] = await secretsClient.accessSecretVersion({name});

    const responsePayload = accessResponse.payload?.data;
    if (responsePayload) {
      return responsePayload.toString();
    }

    return undefined;
  } catch (error) {
    logger.error(`Error accessing secret ${secretName} from Secret Manager`, {
      error,
    });
    return undefined;
  }
}

/**
 * Configuration for secrets used in the application
 */
export const SECRETS = {
  OPENAI_API_KEY: "OPENAI_API_KEY",
  // Add more secrets as needed
} as const;

/**
 * Get all required secrets for a function
 * @return Array of secret names
 */
export function getRequiredSecrets(): string[] {
  return Object.values(SECRETS);
}

/**
 * Validate that all required secrets are available
 * @param requiredSecrets - Array of secret names to validate
 * @return Boolean indicating if all secrets are available
 */
export async function validateSecrets(requiredSecrets: string[]): Promise<boolean> {
  for (const secretName of requiredSecrets) {
    const value = await getSecret(secretName);
    if (!value) {
      logger.error(`Required secret ${secretName} is not available`);
      return false;
    }
  }
  return true;
}

/**
 * Runtime configuration with secrets
 * Use this to configure functions with required secrets
 */
export const runtimeOpts = {
  timeoutSeconds: 300,
  memory: "1GB" as const,
  // Uncomment after setting the secret with: firebase functions:secrets:set OPENAI_API_KEY
  // secrets: [SECRETS.OPENAI_API_KEY],
};

/**
 * Helper to check if running in emulator
 */
export function isEmulator(): boolean {
  return process.env.FUNCTIONS_EMULATOR === "true";
}

/**
 * Get project ID from environment or metadata server
 */
export function getProjectId(): string {
  return process.env.GCLOUD_PROJECT ||
         process.env.FIREBASE_PROJECT_ID ||
         process.env.GCP_PROJECT ||
         "helical-button-461921-v6";
}
