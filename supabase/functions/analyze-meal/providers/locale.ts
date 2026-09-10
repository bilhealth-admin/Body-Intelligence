import { resolveBilLocale } from "../../_shared/bcp47.ts";
import { VisionProviderError } from "./types.ts";

type VisibleCandidate = {
  name: string;
  evidence: string;
  uncertainty?: string | null;
  warnings?: string[];
  alternatives?: Array<{ name: string }>;
  dish_identity?:
    | { name: string; alternatives: Array<{ name: string }> }
    | null;
  visible_components?: Array<{ name: string; evidence: string }>;
};

export function resolveVisionLocale(raw: unknown): string {
  if (typeof raw !== "string") return "en";
  const parts = raw.trim().replaceAll("_", "-").toLowerCase().split("-");
  if (
    parts[0] === "zh" && parts.length <= 3 &&
    parts.every((part) => /^[a-z]{2,4}$/.test(part))
  ) {
    if (
      parts.includes("hant") || parts.includes("tw") || parts.includes("hk")
    ) return "zh-Hant";
    if (
      parts.includes("hans") || parts.includes("cn") || parts.includes("sg")
    ) return "zh-Hans";
  }
  return resolveBilLocale(raw);
}

export function validateVisionResponseLocale(
  declaredLocale: unknown,
  requestedLocale: string,
  candidates: VisibleCandidate[],
): string {
  const expected = resolveVisionLocale(requestedLocale);
  if (candidates.length === 0) return expected;
  if (
    typeof declaredLocale !== "string" ||
    declaredLocale.toLowerCase() !== expected.toLowerCase()
  ) {
    throw new VisionProviderError(
      "language_mismatch",
      "Response locale does not match request",
    );
  }
  // Detect obvious cross-script regressions. This is not a language detector:
  // Latin-script languages also rely on the strict declared-locale contract.
  const script = ({
    ar: /[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]/,
    fa: /[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]/,
    ur: /[\u0600-\u06ff\u0750-\u077f\u08a0-\u08ff]/,
    hi: /[\u0900-\u097f]/,
    bn: /[\u0980-\u09ff]/,
    ja: /[\u3040-\u30ff\u3400-\u9fff]/,
    ko: /[\u1100-\u11ff\u3130-\u318f\uac00-\ud7af]/,
    zh: /[\u3400-\u9fff]/,
    ru: /[\u0400-\u052f]/,
    uk: /[\u0400-\u052f]/,
    th: /[\u0e00-\u0e7f]/,
  } as Record<string, RegExp>)[expected.split("-")[0]] ??
    /[A-Za-z\u00c0-\u024f\u1e00-\u1eff]/;
  for (const candidate of candidates) {
    const strings = [
      candidate.name,
      candidate.evidence,
      candidate.uncertainty,
      ...(candidate.warnings ?? []),
      ...(candidate.alternatives ?? []).map((item) => item.name),
      candidate.dish_identity?.name,
      ...(candidate.dish_identity?.alternatives ?? []).map((item) => item.name),
      ...(candidate.visible_components ?? []).flatMap((
        item,
      ) => [item.name, item.evidence]),
    ];
    if (strings.some((text) => text?.trim() && !script.test(text))) {
      throw new VisionProviderError(
        "language_mismatch",
        "Visible text has an unexpected script",
      );
    }
  }
  return expected;
}

// The same photo in a different app language needs a separately localized
// result; do not reuse an English response from the image-only cache.
export const visionCacheInput = (locale: string, mime: string, image: string) =>
  `${resolveVisionLocale(locale)}:${mime}:${image}`;
