import { assertEquals, assertRejects } from "jsr:@std/assert@1";
import { geminiCall } from "./server.ts";

async function withEndpoint(endpoint: string, run: () => Promise<void>) {
  const names = [
    "BIL_GEMINI_API_KEY",
    "BIL_GEMINI_VISION_ENDPOINT",
    "BIL_GEMINI_TEXT_ENDPOINT",
  ];
  const saved = names.map((name) => Deno.env.get(name));
  Deno.env.set(names[0], "synthetic-non-secret-test-key");
  Deno.env.delete(names[1]);
  Deno.env.set(names[2], endpoint);
  try {
    await run();
  } finally {
    names.forEach((name, i) => {
      if (saved[i] === undefined) Deno.env.delete(name);
      else Deno.env.set(name, saved[i]!);
    });
  }
}

for (
  const endpoint of [
    "http://generativelanguage.googleapis.com/v1beta",
    "https://outside.example/v1beta",
    "https://generativelanguage.googleapis.com.outside.example/v1beta",
    "https://user:password@generativelanguage.googleapis.com/v1beta",
    "https://generativelanguage.googleapis.com:8443/v1beta",
    "https://generativelanguage.googleapis.com/v1beta?override=recipient",
    "https://generativelanguage.googleapis.com/v1beta#recipient",
    "not a URL",
  ]
) {
  Deno.test(`Coach rejects an undisclosed recipient before fetch: ${endpoint}`, async () => {
    await withEndpoint(endpoint, async () => {
      let calls = 0;
      const fetcher: typeof fetch = () => {
        calls++;
        return Promise.resolve(
          new Response('{"candidates":[]}', { status: 200 }),
        );
      };
      await assertRejects(
        () =>
          geminiCall(
            "gemini-test",
            [],
            "synthetic context",
            32,
            false,
            "LOW",
            fetcher,
          ),
        Error,
        "provider_endpoint_not_allowed",
      );
      assertEquals(calls, 0);
    });
  });
}

Deno.test("Coach uses the disclosed Gemini origin and prohibits redirects", async () => {
  await withEndpoint(
    "https://generativelanguage.googleapis.com/v1beta/",
    async () => {
      let calls = 0;
      const fetcher: typeof fetch = (input, init) => {
        calls++;
        assertEquals(
          new URL(String(input)).origin,
          "https://generativelanguage.googleapis.com",
        );
        assertEquals(
          new URL(String(input)).pathname,
          "/v1beta/models/gemini-test:generateContent",
        );
        assertEquals(init?.redirect, "error");
        return Promise.resolve(
          new Response('{"candidates":[]}', { status: 200 }),
        );
      };
      await geminiCall(
        "gemini-test",
        [],
        "synthetic context",
        32,
        false,
        "LOW",
        fetcher,
      );
      assertEquals(calls, 1);
    },
  );
});

Deno.test("Coach does not accept a redirect response as a provider answer", async () => {
  await withEndpoint(
    "https://generativelanguage.googleapis.com/v1beta",
    async () => {
      let calls = 0;
      const fetcher: typeof fetch = (_input, init) => {
        calls++;
        assertEquals(init?.redirect, "error");
        return Promise.resolve(
          new Response(null, {
            status: 302,
            headers: { location: "https://outside.example" },
          }),
        );
      };
      await assertRejects(
        () =>
          geminiCall(
            "gemini-test",
            [],
            "synthetic context",
            32,
            false,
            "LOW",
            fetcher,
          ),
        Error,
        "provider_http_302",
      );
      assertEquals(calls, 1);
    },
  );
});
