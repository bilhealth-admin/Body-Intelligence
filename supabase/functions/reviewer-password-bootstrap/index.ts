
Deno.serve(() =>
  Response.json(
    { ok: false, error: "bootstrap_disabled" },
    { status: 410, headers: { "cache-control": "no-store" } },
  )
);
