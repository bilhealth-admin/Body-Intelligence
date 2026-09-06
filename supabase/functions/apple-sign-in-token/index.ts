import { createClient } from "npm:@supabase/supabase-js@2.112.3";

import {
  type AppleTokenRpcClient,
  exchangeAppleAuthorizationCode,
  loadAppleTokenServerConfiguration,
  normalizeAppleAuthorizationPayload,
  revokeAppleRefreshToken,
  storeAppleRefreshToken,
  verifyAppleIdentityToken,
  verifyAppleNonce,
} from "../_shared/apple_sign_in_token_lifecycle.ts";

function json(body: Record<string, unknown>, status = 200) {
  return Response.json(body, {
    status,
    headers: { "cache-control": "no-store" },
  });
}

function bearerToken(request: Request) {
  const authorization = request.headers.get("authorization")?.trim() ?? "";
  return /^Bearer\s+(.+)$/i.exec(authorization)?.[1]?.trim() ?? "";
}

function record(value: unknown) {
  return value && typeof value === "object" && !Array.isArray(value)
    ? value as Record<string, unknown>
    : null;
}

function userOwnsAppleSubject(user: unknown, subject: string) {
  const userRecord = record(user);
  const identities = Array.isArray(userRecord?.identities)
    ? userRecord.identities
    : [];
  return identities.some((value) => {
    const identity = record(value);
    if (identity?.provider !== "apple") return false;
    const identityData = record(identity.identity_data) ??
      record(identity.identityData);
    return identityData?.sub === subject;
  });
}

function responseForError(error: unknown) {
  const code = error instanceof Error ? error.message : "";
  const name = error instanceof Error ? error.name : "";
  if (code === "invalid_apple_authorization_payload") {
    return json({ error: "invalid_request" }, 400);
  }
  if (
    code.startsWith("apple_identity_") ||
    code === "apple_identity_subject_missing" ||
    code === "apple_identity_owner_mismatch" ||
    name.startsWith("JWS") || name.startsWith("JWT") ||
    code.toLowerCase().includes("jws") ||
    code.toLowerCase().includes("jwt") ||
    code.includes("signature") || code.includes("claim")
  ) {
    return json({ error: "invalid_apple_credential" }, 401);
  }
  if (code.startsWith("apple_configuration_")) {
    return json({ error: "apple_sign_in_not_configured" }, 503);
  }
  if (code.startsWith("apple_authorization_code_exchange")) {
    return json({ error: "apple_authorization_code_rejected" }, 502);
  }
  return json({ error: "apple_credential_registration_failed" }, 503);
}

export async function handleAppleSignInToken(request: Request) {
  if (request.method !== "POST") {
    return json({ error: "method_not_allowed" }, 405);
  }
  const url = Deno.env.get("SUPABASE_URL");
  const key = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY");
  const token = bearerToken(request);
  if (!url || !key) return json({ error: "cloud_not_configured" }, 503);
  if (!token) return json({ error: "unauthorized" }, 401);

  const admin = createClient(url, key, {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data: userData, error: userError } = await admin.auth.getUser(token);
  if (userError || !userData.user) return json({ error: "unauthorized" }, 401);

  try {
    const authorization = normalizeAppleAuthorizationPayload(
      await request.json(),
    );
    const configuration = loadAppleTokenServerConfiguration();
    const originalClaims = await verifyAppleIdentityToken(
      authorization.identityToken,
      configuration.clientId,
    );
    await verifyAppleNonce(originalClaims, authorization.rawNonce);
    if (
      originalClaims.subject !== authorization.appleUserIdentifier ||
      !userOwnsAppleSubject(userData.user, originalClaims.subject)
    ) {
      throw new Error("apple_identity_owner_mismatch");
    }

    const exchanged = await exchangeAppleAuthorizationCode(
      authorization.authorizationCode,
      configuration,
    );
    const exchangedClaims = await verifyAppleIdentityToken(
      exchanged.identityToken,
      configuration.clientId,
    );
    if (exchangedClaims.subject !== originalClaims.subject) {
      throw new Error("apple_identity_owner_mismatch");
    }

    try {
      await storeAppleRefreshToken(
        admin as unknown as AppleTokenRpcClient,
        {
          userId: userData.user.id,
          appleSubject: originalClaims.subject,
          refreshToken: exchanged.refreshToken,
          configuration,
        },
      );
    } catch (storageError) {
      // The one-use authorization code has already been consumed. Revoke the
      // in-memory token rather than leaving an untracked Apple grant behind.
      try {
        await revokeAppleRefreshToken(exchanged.refreshToken, configuration);
      } catch (_revocationError) {
        // Never replace the original durable-custody failure with a provider
        // detail or log either token.
      }
      throw storageError;
    }

    return json({ registered: true });
  } catch (error) {
    return responseForError(error);
  }
}

if (import.meta.main) Deno.serve(handleAppleSignInToken);
