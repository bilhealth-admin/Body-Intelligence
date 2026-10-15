import { assertEquals } from "jsr:@std/assert@1";
import { fetchDisclosedProvider } from "./ai_provider_recipient.ts";

for (const type of ["text", "image", "transcript"]) {
  Deno.test(`Provider transport preserves ${type} payload and refuses redirect opt-in`, async () => {
    const body = JSON.stringify({ synthetic_only: true, type });
    let calls = 0;
    const fetcher: typeof fetch = (_input, init) => {
      calls++;
      assertEquals(init?.redirect, "error");
      assertEquals(init?.body, body);
      assertEquals(init?.method, "POST");
      return Promise.resolve(
        new Response(null, {
          status: 307,
          headers: { location: "https://undisclosed.example" },
        }),
      );
    };
    const response = await fetchDisclosedProvider(
      fetcher,
      "https://generativelanguage.googleapis.com/v1beta",
      {
        method: "POST",
        body,
        redirect: "follow",
      },
    );
    assertEquals(response.status, 307);
    assertEquals(calls, 1);
  });
}
