import {describe, it, expect, vi} from "vitest";
import type {Request, Response, NextFunction} from "express";

vi.mock("firebase-functions/logger", () => ({
  info: vi.fn(),
  warn: vi.fn(),
  error: vi.fn(),
}));

import {
  createAuthenticateMiddleware,
  extractBearerToken,
  DEFAULT_ERROR,
} from "../src/middleware/authenticate";

const makeResponse = () => {
  const res: Partial<Response> = {};
  res.status = vi.fn().mockReturnValue(res);
  res.json = vi.fn().mockReturnValue(res);
  return res as Response;
};

describe("extractBearerToken", () => {
  it("returns token when header is valid", () => {
    expect(extractBearerToken("Bearer token123")).toBe("token123");
  });

  it("returns null for invalid header", () => {
    expect(extractBearerToken("Basic abc")).toBeNull();
    expect(extractBearerToken(undefined)).toBeNull();
  });
});

describe("createAuthenticateMiddleware", () => {
  it("rejects missing headers", async () => {
    const authMock = {verifyIdToken: vi.fn()} as any;
    const authenticate = createAuthenticateMiddleware(authMock);

    const req = {headers: {}} as Request;
    const res = makeResponse();
    const next = vi.fn() as unknown as NextFunction;

    await authenticate(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(DEFAULT_ERROR);
    expect(next).not.toHaveBeenCalled();
  });

  it("attaches decoded token and calls next on success", async () => {
    const authMock = {
      verifyIdToken: vi.fn().mockResolvedValue({uid: "user-1"}),
    } as any;
    const authenticate = createAuthenticateMiddleware(authMock);

    const req = {
      headers: {authorization: "Bearer good-token"},
    } as unknown as Request & {user?: any};
    const res = makeResponse();
    const next = vi.fn() as unknown as NextFunction;

    await authenticate(req, res, next);

    expect(authMock.verifyIdToken).toHaveBeenCalledWith("good-token");
    expect(next).toHaveBeenCalled();
    expect(req.user).toEqual({uid: "user-1"});
  });

  it("responds with 401 when verification fails", async () => {
    const authMock = {
      verifyIdToken: vi.fn().mockRejectedValue(new Error("bad token")),
    } as any;
    const authenticate = createAuthenticateMiddleware(authMock);

    const req = {
      headers: {authorization: "Bearer bad-token"},
    } as Request;
    const res = makeResponse();
    const next = vi.fn() as unknown as NextFunction;

    await authenticate(req, res, next);

    expect(res.status).toHaveBeenCalledWith(401);
    expect(res.json).toHaveBeenCalledWith(
      expect.objectContaining({
        error: "Unauthorized",
        message: "Invalid token",
      })
    );
    expect(next).not.toHaveBeenCalled();
  });
});
