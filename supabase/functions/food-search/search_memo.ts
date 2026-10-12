/** Memory-only, bounded, owner-scoped memo. No query, credential or URL logs. */
export class FoodSearchMemo {
  private readonly rows = new Map<
    string,
    { expires: number; body: string; status: number }
  >();
  private readonly pending = new Map<string, Promise<Response>>();
  constructor(private readonly now: () => number = Date.now) {}

  async run(key: string, load: () => Promise<Response>): Promise<Response> {
    const row = this.rows.get(key);
    if (row && row.expires > this.now()) {
      this.rows.delete(key);
      this.rows.set(key, row);
      return this.response(row.body, row.status);
    }
    this.rows.delete(key);
    const existing = this.pending.get(key);
    if (existing) return (await existing).clone();
    const operation = (async () => {
      const response = await load();
      if (response.status === 200 || response.status === 404) {
        const body = await response.clone().text();
        if (new TextEncoder().encode(body).length <= 128 * 1024) {
          this.rows.set(key, {
            body,
            status: response.status,
            expires: this.now() + (response.status === 200 ? 300000 : 30000),
          });
          let bytes = 0;
          for (const entry of this.rows.values()) {
            bytes += entry.body.length * 2;
          }
          while (this.rows.size > 128 || bytes > 2 * 1024 * 1024) {
            const oldest = this.rows.keys().next().value;
            if (!oldest) break;
            bytes -= (this.rows.get(oldest)?.body.length ?? 0) * 2;
            this.rows.delete(oldest);
          }
        }
      }
      return response;
    })();
    this.pending.set(key, operation);
    try {
      return (await operation).clone();
    } finally {
      this.pending.delete(key);
    }
  }

  private response(body: string, status: number): Response {
    return new Response(body, {
      status,
      headers: { "content-type": "application/json" },
    });
  }
}

export async function searchMemoKey(
  owner: string,
  query: string,
  locale: string,
  country: string,
  limit: number,
  hint: string,
): Promise<string> {
  const input = new TextEncoder().encode(
    JSON.stringify([
      "usda-search-v2",
      owner,
      query,
      locale,
      country,
      limit,
      hint,
    ]),
  );
  const digest = await crypto.subtle.digest("SHA-256", input);
  return Array.from(
    new Uint8Array(digest),
    (byte) => byte.toString(16).padStart(2, "0"),
  ).join("");
}
