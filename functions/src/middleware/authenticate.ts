import type {Auth} from "firebase-admin/auth";
import type {Request, Response, NextFunction} from "express";
import * as logger from "firebase-functions/logger";

export interface AuthenticateOptions {
  required?: boolean;
}

export const DEFAULT_ERROR = {
  error: "Unauthorized",
  message: "Missing or invalid authorization header",
};

export function extractBearerToken(header?: string): string | null {
  if (!header || !header.startsWith("Bearer ")) {
    return null;
  }
  return header.substring("Bearer ".length);
}

export function createAuthenticateMiddleware(
  auth: Auth,
  options: AuthenticateOptions = {}
) {
  return async (req: Request & {user?: any}, res: Response, next: NextFunction) => {
    try {
      const token = extractBearerToken(req.headers.authorization);

      if (!token) {
        if (options.required === false) {
          return next();
        }
        return res.status(401).json(DEFAULT_ERROR);
      }

      const decodedToken = await auth.verifyIdToken(token);
      req.user = decodedToken;
      return next();
    } catch (error: any) {
      logger.error("Authentication error", {
        error: error?.message || error,
      });
      const message = error?.message || "Invalid token";
      return res.status(401).json({
        error: "Unauthorized",
        message: "Invalid token",
        details: message,
      });
    }
  };
}
