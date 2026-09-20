type JsonObject = Record<string, unknown>;

export class MobileIntegrityFailure extends Error {
  constructor(
    readonly code: string,
    readonly status = 403,
  ) {
    super(code);
  }
}

const utf8Length = (value: string) => new TextEncoder().encode(value).length;
const lengthPrefixed = (tag: string, value: string) =>
  `${tag}${utf8Length(value)}:${value};`;

/** Must remain byte-for-byte aligned with bil_integrity_payload.dart. */
export function canonicalIntegrityValue(value: unknown): string {
  if (value === null) return "N;";
  if (typeof value === "boolean") return value ? "B1;" : "B0;";
  if (typeof value === "string") return lengthPrefixed("S", value);
  if (typeof value === "number") {
    if (!Number.isFinite(value)) {
      throw new MobileIntegrityFailure(
        "integrity_payload_non_finite_number",
        400,
      );
    }
    const bytes = new Uint8Array(8);
    new DataView(bytes.buffer).setFloat64(0, value, false);
    const bits = Array.from(bytes)
      .map((byte) => byte.toString(16).padStart(2, "0"))
      .join("");
    return `D${bits};`;
  }
  if (Array.isArray(value)) {
    return `L${value.length}:[${value.map(canonicalIntegrityValue).join("")}];`;
  }
  if (typeof value === "object") {
    const entries = Object.entries(value as JsonObject)
      .sort(([left], [right]) => left < right ? -1 : left > right ? 1 : 0);
    const encoded = entries.map(([key, item]) =>
      `${lengthPrefixed("K", key)}${canonicalIntegrityValue(item)}`
    ).join("");
    return `M${entries.length}:{${encoded}};`;
  }
  throw new MobileIntegrityFailure("integrity_payload_unsupported_type", 400);
}

export async function integrityPayloadDigest(
  payload: JsonObject,
): Promise<string> {
  const bytes = new TextEncoder().encode(canonicalIntegrityValue(payload));
  const digest = new Uint8Array(await crypto.subtle.digest("SHA-256", bytes));
  return Array.from(digest)
    .map((byte) => byte.toString(16).padStart(2, "0"))
    .join("");
}

export type IntegrityGrantAdmin = {
  rpc: (
    name: string,
    params: Record<string, unknown>,
  ) => Promise<{ data: unknown; error: null | { message?: string } }>;
};

function mobileIntegrityEnforcement(override?: string): "off" | "enforce" {
  const value =
    (override ?? Deno.env.get("BIL_MOBILE_INTEGRITY_ENFORCEMENT") ?? "off")
      .trim().toLowerCase();
  if (value === "" || value === "off") return "off";
  if (value === "enforce") return "enforce";
  // A typo must never silently downgrade an intended enforcement deployment.
  throw new MobileIntegrityFailure(
    "mobile_integrity_server_misconfigured",
    503,
  );
}

/**
 * Removes the private envelope in every rollout phase. In explicit `enforce`
 * mode it atomically consumes the one-use grant; the database compares owner,
 * action, server-computed payload digest and expiry in the same UPDATE, so a
 * copied grant cannot authorize another request. The default `off` phase is
 * backward-compatible and must not be represented as an integrity guarantee.
 */
export async function requireMobileIntegrityGrant({
  admin,
  ownerId,
  action,
  body,
  enforcement,
}: {
  admin: IntegrityGrantAdmin;
  ownerId: string;
  action: string;
  body: JsonObject;
  /** Test/rollout override; production callers use the Edge Function secret. */
  enforcement?: "off" | "enforce";
}): Promise<JsonObject> {
  const protectedBody: JsonObject = { ...body };
  delete protectedBody._integrity;
  // This compatibility phase deliberately provides no attestation claim. It
  // prevents a protected-function deployment from breaking existing clients
  // before the migration/functions/configuration and new app are all live.
  if (mobileIntegrityEnforcement(enforcement) === "off") {
    return protectedBody;
  }

  const envelope = body._integrity;
  const grantId =
    envelope && typeof envelope === "object" && !Array.isArray(envelope)
      ? String((envelope as JsonObject).grant_id ?? "").trim()
      : "";
  if (
    !/^[0-9a-f]{8}-[0-9a-f]{4}-[1-5][0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$/i
      .test(grantId)
  ) {
    throw new MobileIntegrityFailure("mobile_integrity_grant_required");
  }

  const payloadDigest = await integrityPayloadDigest(protectedBody);
  const { data, error } = await admin.rpc(
    "bil_consume_mobile_integrity_grant",
    {
      p_grant_id: grantId,
      p_owner_id: ownerId,
      p_action: action,
      p_payload_digest: payloadDigest,
    },
  );
  if (error) {
    throw new MobileIntegrityFailure(
      "mobile_integrity_verification_unavailable",
      503,
    );
  }
  if (data !== true) {
    throw new MobileIntegrityFailure("mobile_integrity_grant_invalid");
  }
  return protectedBody;
}
