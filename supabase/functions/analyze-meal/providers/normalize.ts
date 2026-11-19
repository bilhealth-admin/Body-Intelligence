import {
  BilVisionCandidate,
  NormalizedProviderResult,
  ProviderConfig,
  VisionProviderError,
} from "./types.ts";
import { validateVisionResponseLocale } from "./locale.ts";

const finiteMetric = (value: unknown): number | null =>
  typeof value === "number" && Number.isFinite(value) && value >= 0
    ? value
    : null;


export type SafeVisionProviderErrorCategory =
  | "schema_too_complex" | "unsupported_schema_field" | "invalid_argument"
  | "credentials_rejected" | "other";

const safeProviderStatuses = [
  "INVALID_ARGUMENT", "UNAUTHENTICATED", "PERMISSION_DENIED", "RESOURCE_EXHAUSTED",
  "NOT_FOUND", "UNAVAILABLE", "INTERNAL", "DEADLINE_EXCEEDED", "FAILED_PRECONDITION",
  "OUT_OF_RANGE", "ABORTED", "ALREADY_EXISTS", "CANCELLED", "DATA_LOSS", "UNKNOWN", "OK",
] as const;

/** Bounded diagnostics only: never return message/body/details/paths/account values. */
export function classifyProviderHttpFailure(httpStatus: number, payload: unknown): {
  code: string | number | null;
  category: SafeVisionProviderErrorCategory;
  keywords: Record<string, boolean>;
} {
  const root = payload && typeof payload === "object" && !Array.isArray(payload)
    ? payload as Record<string, unknown> : {};
  // Google error.message is the only text inspected. Never scan the root,
  // details, headers, image payload or an unstructured upstream body.
  const error = root.error && typeof root.error === "object" && !Array.isArray(root.error)
    ? root.error as Record<string, unknown> : {};
  const message = typeof error.message === "string" ? error.message.slice(0, 8192) : "";
  const status = typeof error.status === "string" && error.status.length <= 64
    ? safeProviderStatuses.find((known) => known === error.status) ?? null : null;
  const rawCode = error.code;
  const numericCode = typeof rawCode === "number" && Number.isInteger(rawCode) &&
      ((rawCode >= 0 && rawCode <= 16) || (rawCode >= 100 && rawCode <= 599))
    ? rawCode : null;
  const code = status ?? numericCode;
  const keywords = {
    schema: /\b(?:response[_\s-]?schema|schema)\b/i.test(message),
    propertyOrdering: /\bproperty_?ordering\b/i.test(message),
    nullable: /\bnullable\b/i.test(message),
    minimum: /\bminimum\b/i.test(message),
    maximum: /\bmaximum\b/i.test(message),
    required: /\brequired\b/i.test(message),
    enum: /\benum\b/i.test(message),
    additionalProperties: /\badditional_?properties\b/i.test(message),
    anyOf: /\bany_?of\b/i.test(message),
    responseMimeType: /\bresponse_?mime_?type\b/i.test(message),
  };
  let category: SafeVisionProviderErrorCategory = "other";
  if (httpStatus === 401 || httpStatus === 403 ||
      status === "UNAUTHENTICATED" || status === "PERMISSION_DENIED" ||
      /\b(?:api key not valid|invalid api key|api_key_invalid)\b/i.test(message)) {
    category = "credentials_rejected";
  } else if (keywords.schema && /\b(?:too complex|too many states|schema complexity|schema is too large)\b/i.test(message)) {
    category = "schema_too_complex";
  } else if (Object.values(keywords).some(Boolean) &&
      /\b(?:unsupported|not supported|unknown name|unknown field|unrecognized field|cannot find field)\b/i.test(message)) {
    category = "unsupported_schema_field";
  } else if (httpStatus === 400 || status === "INVALID_ARGUMENT" || numericCode === 3 || numericCode === 400) {
    category = "invalid_argument";
  }
  return { code, category, keywords };
}

export function jsonObject(
  text: string,
  config: ProviderConfig,
): Record<string, unknown> {
  const trimmed = text.trim();
  const jsonText = trimmed.startsWith("```") && trimmed.endsWith("```")
    ? trimmed.replace(/^```(?:json)?\s*/i, "").replace(/\s*```$/, "")
    : trimmed;
  try {
    const value = JSON.parse(jsonText);
    if (value && typeof value === "object" && !Array.isArray(value)) {
      return value;
    }
  } catch { /* handled below */ }
  throw new VisionProviderError(
    "malformed_response",
    "Model content is not a JSON object",
    config.provider,
  );
}

export function textAndUsage(envelope: unknown, config: ProviderConfig): {
  text: string;
  input: number | null;
  output: number | null;
  cost: number | null;
} {
  if (!envelope || typeof envelope !== "object") {
    throw new VisionProviderError(
      "malformed_response",
      "Provider envelope is not an object",
      config.provider,
    );
  }
  const root = envelope as Record<string, unknown>;
  if (root.error) {
    throw new VisionProviderError(
      "provider_error",
      "Provider returned an error envelope",
      config.provider,
    );
  }
  if (config.provider === "openai") {
    if (typeof root.status === "string" && root.status !== "completed") {
      throw new VisionProviderError(
        "provider_error",
        "OpenAI response is not complete",
        config.provider,
      );
    }
    const output = Array.isArray(root.output) ? root.output : [];
    const content = output.flatMap((row) =>
      row && typeof row === "object" &&
        Array.isArray((row as Record<string, unknown>).content)
        ? (row as { content: unknown[] }).content
        : []
    );
    const block = content.find((row) =>
      row && typeof row === "object" &&
      (row as Record<string, unknown>).type === "output_text"
    ) as Record<string, unknown> | undefined;
    const usage = root.usage && typeof root.usage === "object"
      ? root.usage as Record<string, unknown>
      : {};
    if (typeof block?.text !== "string") {
      throw new VisionProviderError(
        "malformed_response",
        "OpenAI output_text missing",
        config.provider,
      );
    }
    return {
      text: block.text,
      input: finiteMetric(usage.input_tokens),
      output: finiteMetric(usage.output_tokens),
      cost: finiteMetric(usage.cost_usd),
    };
  }
  if (config.provider === "gemini") {
    const promptFeedback = root.promptFeedback &&
        typeof root.promptFeedback === "object"
      ? root.promptFeedback as Record<string, unknown>
      : {};
    if (typeof promptFeedback.blockReason === "string") {
      throw new VisionProviderError(
        "provider_error",
        "Gemini response was blocked",
        config.provider,
      );
    }
    const candidates = Array.isArray(root.candidates) ? root.candidates : [];
    const first = candidates[0] as Record<string, unknown> | undefined;
    if (
      typeof first?.finishReason === "string" &&
      first.finishReason !== "STOP"
    ) {
      throw new VisionProviderError(
        "provider_error",
        "Gemini response is not complete",
        config.provider,
      );
    }
    const content = first?.content as Record<string, unknown> | undefined;
    const parts = Array.isArray(content?.parts) ? content.parts : [];
    // Gemini 3 may return thought parts before the visible structured JSON.
    // Never parse or expose those parts as the user-facing meal result.
    const visibleText = parts
      .filter((row) =>
        row && typeof row === "object" &&
        (row as Record<string, unknown>).thought !== true &&
        typeof (row as Record<string, unknown>).text === "string"
      )
      .map((row) => String((row as Record<string, unknown>).text))
      .join("")
      .trim();
    const usage = root.usageMetadata && typeof root.usageMetadata === "object"
      ? root.usageMetadata as Record<string, unknown>
      : {};
    const visibleOutputTokens = finiteMetric(usage.candidatesTokenCount);
    const thoughtTokens = finiteMetric(usage.thoughtsTokenCount);
    const output = visibleOutputTokens === null && thoughtTokens === null
      ? null
      : (visibleOutputTokens ?? 0) + (thoughtTokens ?? 0);
    if (!visibleText) {
      throw new VisionProviderError(
        "malformed_response",
        "Gemini text part missing",
        config.provider,
      );
    }
    return {
      text: visibleText,
      input: finiteMetric(usage.promptTokenCount),
      output,
      cost: finiteMetric(usage.costUsd),
    };
  }
  const choices = Array.isArray(root.choices) ? root.choices : [];
  const first = choices[0] as Record<string, unknown> | undefined;
  if (
    typeof first?.finish_reason === "string" && first.finish_reason !== "stop"
  ) {
    throw new VisionProviderError(
      "provider_error",
      "Mistral response is not complete",
      config.provider,
    );
  }
  const message = first?.message as Record<string, unknown> | undefined;
  const usage = root.usage && typeof root.usage === "object"
    ? root.usage as Record<string, unknown>
    : {};
  if (typeof message?.content !== "string") {
    throw new VisionProviderError(
      "malformed_response",
      "Mistral message content missing",
      config.provider,
    );
  }
  return {
    text: message.content,
    input: finiteMetric(usage.prompt_tokens),
    output: finiteMetric(usage.completion_tokens),
    cost: finiteMetric(usage.cost_usd),
  };
}

export function candidate(value: unknown, config: ProviderConfig): BilVisionCandidate {
  if (!value || typeof value !== "object") {
    throw new VisionProviderError(
      "malformed_response",
      "Candidate is not an object",
      config.provider,
    );
  }
  const row = value as Record<string, unknown>;
  const name = typeof row.name === "string" ? row.name.trim() : "";
  const confidence = typeof row.confidence === "number" ? row.confidence : NaN;
  const evidence = typeof row.evidence === "string" ? row.evidence.trim() : "";
  const amount = row.amount === null || row.amount === undefined
    ? null
    : typeof row.amount === "number" && Number.isFinite(row.amount) &&
        row.amount <= 0
    ? null
    : typeof row.amount === "number" && Number.isFinite(row.amount) &&
        row.amount <= 100000
    ? row.amount
    : NaN;
  const unit = row.unit === null || row.unit === undefined
    ? null
    : typeof row.unit === "string" && row.unit.trim()
    ? row.unit.trim()
    : null;
  const uncertainty = row.uncertainty === null || row.uncertainty === undefined
    ? null
    : typeof row.uncertainty === "string" && row.uncertainty.trim()
    ? row.uncertainty.trim()
    : null;
  const rawAlternatives = row.alternatives == null ? [] : row.alternatives;
  const rawWarnings = row.warnings == null ? [] : row.warnings;
  const rawIdentity = row.dish_identity === undefined
    ? null
    : row.dish_identity;
  const rawVisible = row.visible_components == null
    ? []
    : row.visible_components;
  if (
    !name || name.length > 160 || evidence.length > 500 ||
    !Number.isFinite(confidence) || confidence < 0 || confidence > 1
  ) {
    throw new VisionProviderError(
      "malformed_response",
      "Candidate fields are invalid",
      config.provider,
    );
  }
  if (
    Number.isNaN(amount) || (unit !== null && (!unit || unit.length > 24)) ||
    (uncertainty !== null && (!uncertainty || uncertainty.length > 300)) ||
    !Array.isArray(rawAlternatives) ||
    !Array.isArray(rawWarnings) ||
    !Array.isArray(rawVisible)
  ) {
    throw new VisionProviderError(
      "malformed_response",
      "Candidate detail fields are invalid",
      config.provider,
    );
  }
  const alternatives = rawAlternatives.slice(0, 3).map((alternative) => {
    if (!alternative || typeof alternative !== "object") {
      throw new VisionProviderError(
        "malformed_response",
        "Alternative is invalid",
        config.provider,
      );
    }
    const item = alternative as Record<string, unknown>;
    const alternativeName = typeof item.name === "string"
      ? item.name.trim()
      : "";
    const alternativeConfidence = typeof item.confidence === "number"
      ? item.confidence
      : NaN;
    if (
      !alternativeName || alternativeName.length > 160 ||
      !Number.isFinite(alternativeConfidence) || alternativeConfidence < 0 ||
      alternativeConfidence > 1
    ) {
      throw new VisionProviderError(
        "malformed_response",
        "Alternative fields are invalid",
        config.provider,
      );
    }
    return { name: alternativeName, confidence: alternativeConfidence };
  });
  const warnings = rawWarnings.slice(0, 5).map((warning) => {
    if (
      typeof warning !== "string" || !warning.trim() ||
      warning.trim().length > 240
    ) {
      throw new VisionProviderError(
        "malformed_response",
        "Warning is invalid",
        config.provider,
      );
    }
    return warning.trim();
  });
  const parseNamedConfidence = (value: unknown, label: string) => {
    if (!value || typeof value !== "object") {
      throw new VisionProviderError(
        "malformed_response",
        `${label} is invalid`,
        config.provider,
      );
    }
    const item = value as Record<string, unknown>;
    const itemName = typeof item.name === "string" ? item.name.trim() : "";
    const itemConfidence = typeof item.confidence === "number"
      ? item.confidence
      : NaN;
    if (
      !itemName || itemName.length > 160 || !Number.isFinite(itemConfidence) ||
      itemConfidence < 0 || itemConfidence > 1
    ) {
      throw new VisionProviderError(
        "malformed_response",
        `${label} fields are invalid`,
        config.provider,
      );
    }
    return { name: itemName, confidence: itemConfidence };
  };
  let dish_identity: BilVisionCandidate["dish_identity"] = null;
  if (rawIdentity !== null) {
    const identityRow = rawIdentity as Record<string, unknown>;
    const rawIdentityName = typeof identityRow?.name === "string"
      ? identityRow.name.trim()
      : "";
    const rawIdentityConfidence = typeof identityRow?.confidence === "number"
      ? identityRow.confidence
      : NaN;
    // Some providers express an abstention as an empty/low-confidence object
    // despite being asked for null. Normalize that representation to null;
    // never fail the useful visible observations because identity abstained.
    if (
      !rawIdentityName ||
      (Number.isFinite(rawIdentityConfidence) && rawIdentityConfidence < 0.90)
    ) {
      dish_identity = null;
    } else {
      const identity = parseNamedConfidence(rawIdentity, "Dish identity");
      const identityAlternatives = identityRow.alternatives == null
        ? []
        : identityRow.alternatives;
      if (!Array.isArray(identityAlternatives)) {
        throw new VisionProviderError(
          "malformed_response",
          "Dish identity alternatives are invalid",
          config.provider,
        );
      }
      dish_identity = identity.confidence < 0.90 ? null : {
        ...identity,
        alternatives: identityAlternatives.slice(0, 3).map((item) =>
          parseNamedConfidence(item, "Dish identity alternative")
        ),
      };
    }
  }
  const nonFoodComponentLabel =
    /\b(?:grill marks?|seasonings?|spices?|coating|char marks?|browning|roasted surface|cooked surface|charred surface|glossy glaze)\b/i;
  // A color/texture-only liquid label cannot be resolved to a verified food
  // record. Keep ingredient-named sauces (for example, blueberry sauce), but
  // abstain from generic red/yellow sauce or broth instead of inventing its
  // composition.
  const unresolvedLiquidLabel =
    /^(?:(?:red|yellow|brown|green|white|tomato[- ]based)\s+)?(?:broth|sauce)(?:\s*\/\s*(?:broth|sauce))?$/i;
  const visible_components = rawVisible.slice(0, 12).map((value) => {
    const parsed = parseNamedConfidence(value, "Visible component");
    const component = value as Record<string, unknown>;
    const componentEvidence = typeof component.evidence === "string"
      ? component.evidence.trim()
      : "";
    if (!componentEvidence || componentEvidence.length > 500) {
      throw new VisionProviderError(
        "malformed_response",
        "Visible component evidence is invalid",
        config.provider,
      );
    }
    return { ...parsed, evidence: componentEvidence };
  }).filter((item) =>
    item.confidence >= 0.92 &&
    !nonFoodComponentLabel.test(item.name) &&
    !unresolvedLiquidLabel.test(item.name)
  )
    .filter((item, index, items) => {
      const key = item.name.trim().toLocaleLowerCase();
      return items.findIndex((candidate) =>
        candidate.name.trim().toLocaleLowerCase() === key
      ) === index;
    });
  return {
    name,
    confidence,
    evidence,
    amount,
    unit,
    alternatives,
    uncertainty,
    warnings,
    dish_identity,
    visible_components,
    provenance: {
      identification_provider: config.provider,
      model_revision: config.model,
      nutrition_resolution: "requires_verified_food_match",
    },
  };
}

export function normalizeProviderResponse(
  envelope: unknown,
  config: ProviderConfig,
  requestedLocale?: string,
): NormalizedProviderResult {
  const extracted = textAndUsage(envelope, config);
  if (new TextEncoder().encode(extracted.text).byteLength > 256 * 1024) {
    throw new VisionProviderError(
      "malformed_response",
      "Model content exceeds response limit",
      config.provider,
    );
  }
  const decoded = jsonObject(extracted.text, config);
  if (!Array.isArray(decoded.candidates) || decoded.candidates.length > 8) {
    throw new VisionProviderError(
      "malformed_response",
      "candidates must be an array of at most 8 items",
      config.provider,
    );
  }
  const candidates = decoded.candidates.map((row) => candidate(row, config));
  const responseLocale = requestedLocale === undefined
    ? typeof decoded.response_locale === "string"
      ? decoded.response_locale
      : null
    : validateVisionResponseLocale(
      decoded.response_locale,
      requestedLocale,
      candidates,
    );
  return {
    schema_version: 1,
    response_locale: responseLocale,
    candidates,
    usage: {
      input_tokens: extracted.input,
      output_tokens: extracted.output,
      cost_usd: extracted.cost,
    },
  };
}
