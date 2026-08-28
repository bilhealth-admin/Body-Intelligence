import { env } from "cloudflare:workers";
import {
  exportJWK,
  generateKeyPair,
  SignJWT,
  type JWK,
} from "jose";
import { describe, expect, it } from "vitest";

import {
  AuthenticationError,
  bearerToken,
  verifySupabaseJwt,
} from "../src/auth";
import { verifyPremiumEntitlement } from "../src/entitlement";

const userId = "d9428888-122b-4f5d-b69f-818f58ab0f12";

async function signedToken(overrides: {
  audience?: string;
  role?: string;
} = {}): Promise<{ jwk: JWK; token: string }> {
  const { privateKey, publicKey } = await generateKeyPair("RS256", {
    extractable: true,
  });
  const jwk = await exportJWK(publicKey);
  Object.assign(jwk, { alg: "RS256", kid: "test-key", use: "sig" });
  const token = await new SignJWT({
    role: overrides.role ?? "authenticated",
  })
    .setProtectedHeader({ alg: "RS256", kid: "test-key" })
    .setSubject(userId)
    .setAudience(overrides.audience ?? "authenticated")
    .setIssuer(`${env.SUPABASE_URL}/auth/v1`)
    .setIssuedAt()
    .setExpirationTime("5m")
    .sign(privateKey);
  return { jwk, token };
}

describe("Supabase authentication", () => {
  it("requires a strict Bearer header", () => {
    expect(
      bearerToken(
        new Request("https://workouts.bilhealth.com/v2/objects/example", {
          headers: { authorization: "Bearer header.payload.signature" },
        }),
      ),
    ).toBe("header.payload.signature");
    expect(() =>
      bearerToken(new Request("https://workouts.bilhealth.com")),
    ).toThrow(AuthenticationError);
    expect(() =>
      bearerToken(
        new Request("https://workouts.bilhealth.com", {
          headers: { authorization: "Basic credentials" },
        }),
      ),
    ).toThrow(AuthenticationError);
  });

  it("verifies a signed asymmetric JWT against the pinned Supabase issuer", async () => {
    const { jwk, token } = await signedToken();
    const user = await verifySupabaseJwt(token, env, async (input, init) => {
      expect(new URL(input.toString()).pathname).toBe(
        "/auth/v1/.well-known/jwks.json",
      );
      expect(init?.redirect).toBe("manual");
      return Response.json({ keys: [jwk] });
    });

    expect(user).toEqual({ id: userId, token });
  });

  it("rejects a valid signature with the wrong audience or role", async () => {
    for (const overrides of [
      { audience: "anon" },
      { role: "service_role" },
    ]) {
      const { jwk, token } = await signedToken(overrides);
      await expect(
        verifySupabaseJwt(
          token,
          env,
          async () => Response.json({ keys: [jwk] }),
        ),
      ).rejects.toMatchObject({ kind: "unauthorized" });
    }
  });
});

describe("premium entitlement", () => {
  it("uses owner-scoped RLS requests with the same Bearer and public key", async () => {
    const token = "header.payload.signature";
    const seen: URL[] = [];
    const runtimeFetch = async (
      input: RequestInfo | URL,
      init?: RequestInit,
    ): Promise<Response> => {
      const url = new URL(input.toString());
      seen.push(url);
      const headers = new Headers(init?.headers);
      expect(headers.get("authorization")).toBe(`Bearer ${token}`);
      expect(headers.get("apikey")).toBe(env.SUPABASE_PUBLISHABLE_KEY);
      expect(init?.redirect).toBe("manual");
      expect(url.searchParams.get("owner_id")).toBe(`eq.${userId}`);
      if (url.pathname.endsWith("/bil_ai_closed_test_grants")) {
        return Response.json([]);
      }
      return Response.json([
        {
          expires_at: "2026-09-24T00:00:00Z",
          grace_period_ends_at: null,
          lifecycle: "active",
          owner_id: userId,
          plan_id: "premium",
          provider: "google",
          started_at: "2026-08-01T00:00:00Z",
          verified_at: "2026-08-24T00:00:00Z",
        },
      ]);
    };

    await expect(
      verifyPremiumEntitlement(
        { id: userId, token },
        env,
        runtimeFetch,
        new Date("2026-08-24T12:00:00Z"),
      ),
    ).resolves.toBe(true);
    expect(seen).toHaveLength(2);
  });

  it("accepts only a current owner-scoped closed-test grant", async () => {
    const runtimeFetch = async (input: RequestInfo | URL): Promise<Response> => {
      const url = new URL(input.toString());
      if (url.pathname.endsWith("/bil_subscriptions")) {
        return Response.json([]);
      }
      return Response.json([
        {
          active: true,
          expires_at: "2026-08-25T00:00:00Z",
          owner_id: userId,
        },
      ]);
    };
    await expect(
      verifyPremiumEntitlement(
        { id: userId, token: "header.payload.signature" },
        env,
        runtimeFetch,
        new Date("2026-08-24T12:00:00Z"),
      ),
    ).resolves.toBe(true);
  });

  it("fails closed for stale verification or an untrusted provider", async () => {
    for (const mutation of [
      { provider: "google", verified_at: "2026-08-20T00:00:00Z" },
      { provider: "untrusted", verified_at: "2026-08-24T00:00:00Z" },
      {
        plan_id: "legacy_plus",
        provider: "google",
        verified_at: "2026-08-24T00:00:00Z",
      },
    ]) {
      const runtimeFetch = async (input: RequestInfo | URL): Promise<Response> => {
        const url = new URL(input.toString());
        if (url.pathname.endsWith("/bil_ai_closed_test_grants")) {
          return Response.json([]);
        }
        return Response.json([
          {
            expires_at: "2026-09-24T00:00:00Z",
            grace_period_ends_at: null,
            lifecycle: "active",
            owner_id: userId,
            plan_id: "premium",
            started_at: "2026-08-01T00:00:00Z",
            ...mutation,
          },
        ]);
      };
      await expect(
        verifyPremiumEntitlement(
          { id: userId, token: "header.payload.signature" },
          env,
          runtimeFetch,
          new Date("2026-08-24T12:00:00Z"),
        ),
      ).resolves.toBe(false);
    }
  });
});
