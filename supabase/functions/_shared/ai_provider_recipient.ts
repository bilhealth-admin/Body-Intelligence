// Consent names the provider. Neither environment overrides nor a redirect may
// silently send the prompt, health context, image, audio, or key elsewhere.
export function disclosedGeminiEndpoint(configured: string): string {
  let url: URL;
  try {
    url = new URL(configured);
  } catch {
    throw new Error("provider_endpoint_not_allowed");
  }
  const host = url.hostname.toLowerCase();
  const path = url.pathname.replace(/\/$/, "");
  const googleGemini = host === "generativelanguage.googleapis.com" &&
    /^\/v1(?:beta)?$/.test(path);
  const googleVertexGemini = host === "aiplatform.googleapis.com" &&
    /^\/v1(?:beta1)?\/publishers\/google$/.test(path);
  if (
    (!googleGemini && !googleVertexGemini) ||
    url.protocol !== "https:" ||
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
