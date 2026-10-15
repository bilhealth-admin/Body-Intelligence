// Consent names the provider. Neither environment overrides nor a redirect may
// silently send the prompt, health context, image, audio, or key elsewhere.
export function disclosedGeminiEndpoint(configured: string): string {
  let url: URL;
  try {
    url = new URL(configured);
  } catch {
    throw new Error("provider_endpoint_not_allowed");
  }
  if (
    url.protocol !== "https:" ||
    url.hostname.toLowerCase() !== "generativelanguage.googleapis.com" ||
    url.username || url.password || url.port || url.search || url.hash
  ) {
    throw new Error("provider_endpoint_not_allowed");
  }
  return url.toString().replace(/\/$/, "");
}

export function fetchDisclosedProvider(
  fetcher: typeof fetch,
  input: string | URL | Request,
  init: RequestInit,
): Promise<Response> {
  return fetcher(input, { ...init, redirect: "error" });
}
