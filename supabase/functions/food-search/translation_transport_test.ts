import { translateManyWithGoogle, translateWithGoogle } from "./index.ts";

Deno.test("food phrase and name translation never place the key in URLs or follow redirects", async () => {
  const previous = Deno.env.get("BIL_TRANSLATION_API_KEY");
  Deno.env.set("BIL_TRANSLATION_API_KEY", "synthetic-transport-key");
  try {
    const bodies: unknown[] = [];
    const fetcher = ((input: string | URL | Request, init?: RequestInit) => {
      if (
        String(input) !==
          "https://translation.googleapis.com/language/translate/v2"
      ) throw Error("unexpected endpoint");
      const headers = new Headers(init?.headers);
      if (
        headers.get("x-goog-api-key") !== "synthetic-transport-key" ||
        init?.redirect !== "error"
      ) throw Error("unsafe key transport");
      bodies.push(JSON.parse(String(init?.body)));
      return Promise.resolve(
        new Response(
          JSON.stringify({
            data: { translations: [{ translatedText: "chicken" }] },
          }),
          { status: 200 },
        ),
      );
    }) as typeof fetch;
    if (await translateWithGoogle("دجاج", "ar", "en", fetcher) !== "chicken") {
      throw Error("phrase result lost");
    }
    if (
      (await translateManyWithGoogle(["Chicken"], "ar", fetcher)).get(
        "Chicken",
      ) !== "chicken"
    ) throw Error("name result lost");
    if (bodies.length !== 2) throw Error("both real transport paths required");
    const rejectRedirect = (() =>
      Promise.reject(new TypeError("redirect rejected"))) as typeof fetch;
    if (
      await translateWithGoogle("دجاج", "ar", "en", rejectRedirect) !== null
    ) {
      throw Error("phrase must degrade safely");
    }
    if (
      (await translateManyWithGoogle(["Chicken"], "ar", rejectRedirect))
        .size !== 0
    ) {
      throw Error("names must degrade safely");
    }
  } finally {
    if (previous === undefined) Deno.env.delete("BIL_TRANSLATION_API_KEY");
    else Deno.env.set("BIL_TRANSLATION_API_KEY", previous);
  }
});
