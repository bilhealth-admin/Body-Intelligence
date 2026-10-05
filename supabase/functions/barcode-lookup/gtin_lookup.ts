import { isValidGtin } from "../_shared/gtin.ts";

/** Only formatting is removed. Never turn an arbitrary URL/text into a GTIN. */
export function normalizeLookupGtin(value: unknown): string | null {
  if (typeof value !== "string" || value.length > 80) return null;
  const source = "٠١٢٣٤٥٦٧٨٩۰۱۲۳۴۵۶۷۸۹";
  const digits = value.trim().replace(/[٠-٩۰-۹]/g, (x) => String(source.indexOf(x) % 10))
    .replace(/[\s-]/g, "");
  return isValidGtin(digits) && !/^0+$/.test(digits) ? digits : null;
}

export function canonicalGtin(value: unknown): string | null {
  const gtin = normalizeLookupGtin(value);
  return gtin === null ? null : gtin.padStart(14, "0");
}

export function sameGtin(left: unknown, right: unknown): boolean {
  const key = canonicalGtin(left);
  return key !== null && key === canonicalGtin(right);
}

/** Zero padding is equivalent; changing a nonzero package indicator is not. */
export function lookupGtinCandidates(value: unknown): string[] {
  const gtin = normalizeLookupGtin(value);
  if (gtin === null) return [];
  const canonical = gtin.padStart(14, "0");
  const result = new Set([gtin]);
  for (const length of [8, 12, 13, 14]) {
    const prefix = canonical.slice(0, 14 - length);
    const candidate = canonical.slice(14 - length);
    if (/^0*$/.test(prefix) && isValidGtin(candidate)) result.add(candidate);
  }
  return [...result];
}

export const barcodeLocales = [
  "ar", "en", "fr", "es", "tr", "de", "it", "pt-BR", "pt-PT", "ur",
  "fa", "hi", "id", "ms", "ja", "ko", "zh-Hans", "zh-Hant", "ru",
  "bn", "vi", "th", "pl", "nl", "uk",
] as const;

export function canonicalBarcodeLocale(value: unknown): string {
  const tag = typeof value === "string" ? value.trim().replaceAll("_", "-").toLowerCase() : "";
  if (["zh-tw", "zh-hk", "zh-hant"].includes(tag)) return "zh-Hant";
  if (["zh", "zh-cn", "zh-hans"].includes(tag)) return "zh-Hans";
  if (tag === "pt") return "pt-BR";
  const exact = barcodeLocales.find((x) => x.toLowerCase() === tag);
  if (exact) return exact;
  const base = tag.split("-")[0];
  return barcodeLocales.find((x) => x === base) ?? "en";
}

export function offLanguage(locale: string): string {
  if (locale === "zh-Hant") return "zh-tw";
  if (locale === "zh-Hans") return "zh";
  return locale.split("-")[0];
}

export type Product = Record<string, unknown>;
export function record(value: unknown): Product | null {
  return value !== null && typeof value === "object" && !Array.isArray(value)
    ? value as Product : null;
}
export function text(value: unknown): string { return typeof value === "string" ? value.trim() : ""; }
export function finiteAmount(value: unknown): number | null {
  if (typeof value !== "number" && typeof value !== "string") return null;
  if (typeof value === "string" && !value.trim()) return null;
  const number = Number(value);
  return Number.isFinite(number) && number >= 0 ? number : null;
}

export function hasCompleteCore(product: Product): boolean {
  const rows = Array.isArray(product.nutrients) ? product.nutrients : [];
  return ["Energy", "Protein", "Carbohydrate, by difference", "Total lipid (fat)"].every(
    (key) => rows.some((raw) => {
      const row = record(raw);
      return row?.name === key && finiteAmount(row?.amount) !== null;
    }),
  );
}

/** Localize the response, not the shared cache; retain the old mobile contract. */
export function responseProduct(product: Product, locale: string): Product {
  const names = record(product.names) ?? {};
  const candidates = [locale, locale.toLowerCase(), offLanguage(locale), locale.split("-")[0]];
  const localized = candidates.map((key) => text(names[key])).find(Boolean);
  if (!localized) return product;
  return { ...product, name: localized, names: { ...names, [locale.split("-")[0]]: localized } };
}
