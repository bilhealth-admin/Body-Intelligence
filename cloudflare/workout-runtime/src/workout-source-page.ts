/**
 * Public source-attribution landing page for browser document navigation only.
 *
 * Workout media is still served only through the existing authenticated
 * Supabase JWT + verified Premium entitlement boundary. In particular:
 * - never return a byte of the protected R2 video here;
 * - never handle player/HEAD/range/conditional requests as document navigation;
 * - never serve a document for a request with an authorization header.
 *
 * This compensates for native external browsers not receiving Flutter's
 * Authorization header when opening "Open original source".
 */
export function isWorkoutSourceDocumentRequest(request: Request): boolean {
  if (request.method !== "GET") return false;
  if (
    [
      "authorization",
      "origin",
      "range",
      "if-match",
      "if-none-match",
      "if-modified-since",
      "if-unmodified-since",
      "if-range",
    ].some((header) => request.headers.has(header))
  ) {
    return false;
  }

  const fetchMode = request.headers.get("sec-fetch-mode")?.toLowerCase();
  const fetchDestination = request.headers.get("sec-fetch-dest")?.toLowerCase();
  if (fetchMode !== undefined && fetchMode !== "navigate") return false;
  if (
    fetchDestination !== undefined &&
    fetchDestination !== "document" &&
    fetchDestination !== "empty"
  ) {
    return false;
  }

  const acceptsHtml = /(^|[,;\s])text\/html(?=$|[,;\s])/i.test(
    request.headers.get("accept") ?? "",
  );
  return acceptsHtml ||
    (fetchMode === "navigate" && fetchDestination === "document");
}

/**
 * Renders only BIL attribution and safe playback guidance. The allowlisted
 * object key, not a caller-supplied title or query parameter, is the input.
 */
export function workoutSourceDocumentResponse(objectKey: string): Response {
  const filename = objectKey.split("/").at(-1) ?? "workout.mp4";
  const slug = filename
    .replace(/\.mp4$/, "")
    .replace(
      /^(?:resistance-(?:upper-body|lower-body|full-body)|mobility-flexibility|cardio-(?:conditioning|low-impact)|recovery-beginner|home-bodyweight)-/,
      "",
    )
    .replace(/-(?:technique|original)$/, "");
  const name = slug.split("-")
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1))
    .join(" ") || "Workout Demonstration";
  const title = escapeHtml(name);

  const body = [
    "<!doctype html>",
    '<html lang="en"><head><meta charset="utf-8">',
    '<meta name="viewport" content="width=device-width, initial-scale=1">',
    '<meta name="robots" content="noindex,nofollow,noarchive">',
    "<title>", title, " — BIL Health source</title>",
    "<style>",
    "*{box-sizing:border-box}body{margin:0;min-height:100vh;background:#f1f5fa;",
    "color:#182e40;font:16px/1.65 -apple-system,BlinkMacSystemFont,'Segoe UI',sans-serif;",
    "display:flex;align-items:center;justify-content:center;padding:28px}",
    ".panel{width:100%;max-width:620px;border-radius:22px;background:#fff;",
    "border:1px solid #d9e5f0;box-shadow:0 10px 38px #142b4410;padding:34px}",
    ".brand{font-size:14px;font-weight:800;letter-spacing:.12em;color:#1279ce}",
    "h1{font-size:clamp(25px,5vw,34px);line-height:1.2;margin:18px 0}",
    "p{margin:14px 0}.notice{background:#eaf3fb;border-radius:14px;padding:18px}",
    ".muted{color:#506679;font-size:14px}.ar{direction:rtl;text-align:right}",
    "</style></head><body><main class=\"panel\">",
    '<div class="brand">BIL HEALTH</div>',
    "<h1>", title, "</h1>",
    "<p>Source: BIL Health — reviewed exercise demonstration.</p>",
    '<div class="notice"><strong>View this workout inside Body Intelligence Log.</strong>',
    "<p>This video requires an eligible account. Browser links do not carry the ",
    "app's secure sign-in session. Return to the workout in the app to play it.</p>",
    "</div>",
    '<p class="ar" lang="ar">هذا الفيديو محمي ويُعرض داخل تطبيق Body Intelligence Log ',
    "للحسابات المصرّح لها. ارجع إلى التطبيق لتشغيل التمرين.</p>",
    '<p class="muted">Safety: stop exercising for pain, dizziness, or unusual ',
    "shortness of breath.</p>",
    "</main></body></html>",
  ].join("");

  return new Response(body, {
    status: 200,
    headers: {
      "content-type": "text/html; charset=utf-8",
      "cache-control": "no-store",
      "content-security-policy":
        "default-src 'none'; style-src 'unsafe-inline'; base-uri 'none'; " +
        "frame-ancestors 'none'; form-action 'none'",
      "referrer-policy": "no-referrer",
      "x-content-type-options": "nosniff",
      "x-robots-tag": "noindex, nofollow, noarchive",
      "vary": "Accept, Authorization, Range, Origin, Sec-Fetch-Mode, Sec-Fetch-Dest",
    },
  });
}

function escapeHtml(value: string): string {
  return value.replace(/[&<>"']/g, (character) => {
    switch (character) {
      case "&": return "&amp;";
      case "<": return "&lt;";
      case ">": return "&gt;";
      case '"': return "&quot;";
      default: return "&#39;";
    }
  });
}
