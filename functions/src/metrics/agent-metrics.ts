import * as admin from "firebase-admin";
import * as logger from "firebase-functions/logger";

if (admin.apps.length === 0) {
  admin.initializeApp();
}

const db = admin.firestore();

export interface AgentInteractionLog {
  userId: string;
  input: string;
  agent: string;
  success: boolean;
  usedFallback?: boolean;
  latencyMs?: number | null;
  confidence?: number | null;
  metadata?: Record<string, any>;
  error?: string | null;
}

export async function recordAgentInteraction(log: AgentInteractionLog) {
  const latency = Number.isFinite(log.latencyMs ?? NaN) ?
    Math.max(0, Number(log.latencyMs)) :
    null;

  let confidence: number | null = null;
  if (Number.isFinite(log.confidence ?? NaN)) {
    confidence = Math.min(1, Math.max(0, Number(log.confidence)));
  }

  const safeMetadata =
    log.metadata && typeof log.metadata === "object" && !Array.isArray(log.metadata) ?
      log.metadata :
      undefined;

  try {
    await db.collection("agent_interactions").add({
      userId: log.userId,
      input: log.input?.slice(0, 2000) ?? "",
      agent: log.agent,
      success: Boolean(log.success),
      usedFallback: Boolean(log.usedFallback),
      latencyMs: latency,
      confidence,
      metadata: safeMetadata ?? null,
      error: log.error ?? null,
      createdAt: admin.firestore.FieldValue.serverTimestamp(),
    });
  } catch (error: any) {
    logger.error("Failed to record agent interaction", {
      userId: log.userId,
      agent: log.agent,
      error: error?.message ?? error,
    });
  }
}
