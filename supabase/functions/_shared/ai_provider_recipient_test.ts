import { assertEquals, assertThrows } from "jsr:@std/assert@1";
import {
  disclosedGeminiEndpoint,
  fetchDisclosedProvider,
} from "./ai_provider_recipient.ts";

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

Deno.test("Only disclosed Google Gemini and Google Vertex publisher paths are allowed", () => {
  for (
    const endpoint of [
      "https://generativelanguage.googleapis.com/v1beta",
      "https://aiplatform.googleapis.com/v1/publishers/google",
      "https://aiplatform.googleapis.com/v1beta1/publishers/google/",
    ]
  ) {
    assertEquals(
      disclosedGeminiEndpoint(endpoint),
      endpoint.replace(/\/$/, ""),
    );
  }
  for (
    const endpoint of [
      "https://aiplatform.googleapis.com.evil.example/v1/publishers/google",
      "https://aiplatform.googleapis.com/v1/publishers/third-party",
      "https://aiplatform.googleapis.com/v1/publishers/google?key=private",
      "http://aiplatform.googleapis.com/v1/publishers/google",
      "https://aiplatform.googleapis.com/v1/publishers/google#override",
    ]
  ) {
    assertThrows(
      () => disclosedGeminiEndpoint(endpoint),
      Error,
      "provider_endpoint_not_allowed",
    );
  }
});
