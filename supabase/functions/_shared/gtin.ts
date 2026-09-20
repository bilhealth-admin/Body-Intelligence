/** Validates exact GTIN-8, UPC-A, EAN-13, or GTIN-14 digits and check digit. */
export function isValidGtin(value: unknown): value is string {
  if (typeof value !== 'string' || !/^(?:\d{8}|\d{12}|\d{13}|\d{14})$/.test(value)) {
    return false;
  }
  const digits = [...value].map(Number);
  const check = digits.pop()!;
  let sum = 0;
  for (let i = digits.length - 1, multiplier = 3; i >= 0; i -= 1) {
    sum += digits[i] * multiplier;
    multiplier = multiplier === 3 ? 1 : 3;
  }
  return (10 - (sum % 10)) % 10 === check;
}
