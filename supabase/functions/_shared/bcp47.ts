/// Exact locale surface released by BIL. Keep this list aligned with the
/// client rollout manifest; accepting arbitrary tags makes model language
/// behavior and server telemetry non-deterministic.
export const BIL_PRODUCTION_LOCALE_TAGS = [
  'ar', 'en', 'fr', 'es', 'tr', 'de', 'it', 'pt-BR', 'pt-PT', 'ur', 'fa',
  'hi', 'id', 'ms', 'ja', 'ko', 'zh-Hans', 'zh-Hant', 'ru', 'bn', 'vi',
  'th', 'pl', 'nl', 'uk',
] as const;

export type BilProductionLocaleTag = typeof BIL_PRODUCTION_LOCALE_TAGS[number];

const exactByLowerCase = new Map<string, BilProductionLocaleTag>(
  BIL_PRODUCTION_LOCALE_TAGS.map((tag) => [tag.toLowerCase(), tag]),
);

/**
 * Resolves an untrusted BCP-47 value to the exact supported BIL tag.
 *
 * Underscores are tolerated at platform boundaries. Region/script variants
 * fall back only when there is one unambiguous production target. Portuguese
 * deliberately requires an explicit region and otherwise uses the caller's
 * fallback. Invalid/private-use/extension tags never reach model prompts.
 */
export function resolveBilLocale(
  raw: unknown,
  fallback: BilProductionLocaleTag = 'en',
): BilProductionLocaleTag {
  if (typeof raw !== 'string') return fallback;
  const candidate = raw.trim().replaceAll('_', '-');
  if (!candidate || candidate.length > 35 ||
    !/^[A-Za-z]{2,3}(?:-[A-Za-z]{4})?(?:-(?:[A-Za-z]{2}|\d{3}))?$/.test(candidate)) {
    return fallback;
  }
  const exact = exactByLowerCase.get(candidate.toLowerCase());
  if (exact) return exact;
  const language = candidate.split('-')[0].toLowerCase();
  const matches = BIL_PRODUCTION_LOCALE_TAGS.filter((tag) =>
    tag.toLowerCase() === language || tag.toLowerCase().startsWith(`${language}-`)
  );
  return matches.length === 1 ? matches[0] : fallback;
}
