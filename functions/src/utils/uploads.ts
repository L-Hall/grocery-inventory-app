import * as admin from "firebase-admin";
import {randomUUID} from "crypto";

export const UploadStatus = {
  awaitingUpload: "awaiting_upload",
  queued: "queued",
  processing: "processing",
  completed: "completed",
  failed: "failed",
} as const;

export type UploadStatus = typeof UploadStatus[keyof typeof UploadStatus];

export const UploadJobStatus = {
  queued: "queued",
  received: "received",
  awaitingParser: "awaiting_parser",
  completed: "completed",
  failed: "failed",
} as const;

export type UploadJobStatus = typeof UploadJobStatus[keyof typeof UploadJobStatus];

export type UploadSourceType = "text" | "pdf" | "image_receipt" | "image_list" | "unknown";

export interface UploadMetadata {
  id: string;
  filename: string;
  originalFilename: string;
  contentType: string;
  sizeBytes: number | null;
  sourceType: UploadSourceType;
  bucket: string;
  storagePath: string;
  status: UploadStatus;
  createdAt: FirebaseFirestore.FieldValue;
  updatedAt: FirebaseFirestore.FieldValue;
  lastError?: string | null;
  processingJobId?: string | null;
}

export interface UploadJobPayload {
  uploadId: string;
  userId: string;
  storagePath: string;
  bucket: string;
  contentType: string;
  sourceType: UploadSourceType;
  status: UploadJobStatus;
  attempts: number;
  createdAt: FirebaseFirestore.FieldValue;
  updatedAt: FirebaseFirestore.FieldValue;
}

export function sanitizeUploadFilename(filename: string): string {
  if (!filename) {
    return `upload-${randomUUID()}`;
  }

  const trimmed = filename.trim().replace(/[/\\]/g, "");
  if (!trimmed) {
    return `upload-${randomUUID()}`;
  }

  return trimmed.replace(/[^\w.-]/g, "_").slice(0, 120);
}

export function buildUploadStoragePath(
  uid: string,
  uploadId: string,
  filename: string,
): string {
  return `uploads/${uid}/${uploadId}/${filename}`;
}

export function getUploadsBucketName(): string {
  const envBucket = process.env.UPLOADS_BUCKET?.trim();
  if (envBucket) {
    return envBucket;
  }
  return admin.storage().bucket().name;
}

export async function generateSignedUploadUrl(
  storagePath: string,
  contentType: string,
  expiresInSeconds = 15 * 60,
  bucketName = getUploadsBucketName(),
): Promise<{
    uploadUrl: string;
    expiresAt: string;
    bucket: string;
  }> {
  const bucket = admin.storage().bucket(bucketName);
  const file = bucket.file(storagePath);
  const expiresAt = new Date(Date.now() + expiresInSeconds * 1000);

  const [url] = await file.getSignedUrl({
    version: "v4",
    action: "write",
    expires: expiresAt,
    contentType,
  });

  return {
    uploadUrl: url,
    expiresAt: expiresAt.toISOString(),
    bucket: bucketName,
  };
}

export function getUploadDocRef(uid: string, uploadId: string) {
  return admin.firestore().doc(`users/${uid}/uploads/${uploadId}`);
}
