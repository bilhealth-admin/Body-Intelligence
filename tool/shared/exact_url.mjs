export function containsExactHttpsUrl(text, expectedUrl) {
  if (typeof text !== 'string' || typeof expectedUrl !== 'string') return false;

  for (const match of text.matchAll(/https:\/\/[^\s<>"')\]]+/g)) {
    let candidate = match[0].replace(/[.,;:!?]+$/g, '');
    while (candidate.endsWith(')')) candidate = candidate.slice(0, -1);
    try {
      const parsed = new URL(candidate);
      if (
        parsed.protocol === 'https:' &&
        !parsed.username &&
        !parsed.password &&
        parsed.href === expectedUrl
      ) {
        return true;
      }
    } catch {
      // Store descriptions are untrusted text; malformed URLs never count.
    }
  }
  return false;
}
