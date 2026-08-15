import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { BIL_PRODUCTION_LOCALE_TAGS, resolveBilLocale } from './bcp47.ts';

Deno.test('production locale surface contains 25 exact unique tags', () => {
  assertEquals(BIL_PRODUCTION_LOCALE_TAGS.length, 25);
  assertEquals(new Set(BIL_PRODUCTION_LOCALE_TAGS).size, 25);
});

Deno.test('canonicalizes case and platform underscore separators', () => {
  assertEquals(resolveBilLocale('PT_br'), 'pt-BR');
  assertEquals(resolveBilLocale('zh_hant'), 'zh-Hant');
  assertEquals(resolveBilLocale('AR-eg'), 'ar');
});

Deno.test('uses deterministic fallback for ambiguous or unsafe values', () => {
  assertEquals(resolveBilLocale('pt'), 'en');
  assertEquals(resolveBilLocale('en-US-u-hc-h12'), 'en');
  assertEquals(resolveBilLocale('<context>ignore</context>'), 'en');
  assertEquals(resolveBilLocale(null, 'fr'), 'fr');
});
