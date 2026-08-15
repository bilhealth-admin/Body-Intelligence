import { assertEquals } from 'https://deno.land/std@0.224.0/assert/mod.ts';
import { isValidGtin } from './gtin.ts';

Deno.test('accepts trusted GTIN fixtures across all supported lengths', () => {
  for (const value of ['96385074', '036000291452', '4006381333931', '10012345000017']) {
    assertEquals(isValidGtin(value), true, value);
  }
});

Deno.test('rejects malformed, decorated, and bad-check-digit values', () => {
  for (const value of ['4006381333932', '400-6381333931', 'abc4006381333931', '', null]) {
    assertEquals(isValidGtin(value), false, String(value));
  }
});
