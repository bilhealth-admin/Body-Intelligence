import metadata from "../../../artifacts/workout_media/cloudflare_runtime_v2/workout_source_pages_v1.json";

const prefix = "/v2/source/";
const movement = /^workouts\/v1\/(?:home|gym-six-month)\/movements\/[a-z0-9]+(?:-[a-z0-9]+)*\.mp4$/;
type Source = { title: string; publisher: string; syntheticPerformer: boolean; termsUrl: string };
const sources: Readonly<Record<string, Source>> = metadata.entries;
if (metadata.schema !== "bil.workout-source-information.v1") throw new Error("source_metadata_invalid");

export function escapeSourceHtml(value: string): string {
  return value.replace(/[&<>"']/gu, (character) => ({
    "&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;", "'": "&#39;",
  })[character]!);
}

/** A public provenance document. Never reads R2, Auth or subscription data. */
export function workoutSourceInformation(pathname: string, method: string): Response | null {
  if (!pathname.startsWith(prefix) || (method !== "GET" && method !== "HEAD")) return null;
  const key = pathname.slice(prefix.length);
  if (!movement.test(key) || !Object.hasOwn(sources, key)) return null;
  const source = sources[key]!;
  const html = `<!doctype html><html lang="en"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${escapeSourceHtml(source.title)} · BIL exercise source</title>
<style>html{color-scheme:light dark}body{margin:0;padding:32px 20px;font:17px/1.6 system-ui,sans-serif;background:#edf3f9;color:#14243a}main{max-width:640px;margin:8vh auto;padding:28px;border:1px solid #bacadd;border-radius:24px;background:#fff;box-shadow:0 16px 48px #14243a14}h1{font-size:1.1rem;color:#07518f}h2{font-size:1.8rem;line-height:1.2}a{color:#07518f;text-underline-offset:.2em}a:focus-visible{outline:3px solid #07518f;outline-offset:4px}@media(prefers-color-scheme:dark){body{background:#101c2a;color:#edf3fa}main{background:#1c2c3e;border-color:#52667e}h1,a{color:#a9d7ff}}</style></head>
<body><main><h1>BIL exercise source</h1><h2>${escapeSourceHtml(source.title)}</h2>
<p>Publisher: ${escapeSourceHtml(source.publisher)}</p>
<p>This page identifies the demonstration in the BIL exercise library. It does not play or download the video.</p>
${source.syntheticPerformer ? "<p>This demonstration uses a synthetic performer.</p>" : ""}
<p>Return to BIL to view the demonstration. Video availability follows your current account access in the app.</p>
<p><a href="https://www.bilhealth.com/terms" rel="noopener noreferrer">Terms of use</a></p></main></body></html>`;
  return new Response(method === "HEAD" ? null : html, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "public, max-age=3600",
      "content-security-policy": "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; form-action 'none'; frame-ancestors 'none'",
      "x-content-type-options": "nosniff",
      "referrer-policy": "no-referrer",
      "permissions-policy": "camera=(), microphone=(), geolocation=()",
      "x-robots-tag": "noindex, nofollow",
    },
  });
}
