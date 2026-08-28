const utf8Decoder = new TextDecoder("utf-8", {
  fatal: true,
  ignoreBOM: false,
});

export async function readBoundedJson(
  response: Response,
  maximumBytes: number,
): Promise<unknown> {
  const declaredLength = Number(response.headers.get("content-length"));
  if (Number.isFinite(declaredLength) && declaredLength > maximumBytes) {
    throw new Error("response_too_large");
  }
  if (response.body === null) {
    throw new Error("response_body_missing");
  }
  const reader = response.body.getReader();
  const chunks: Uint8Array[] = [];
  let received = 0;
  for (;;) {
    const result = await reader.read();
    if (result.done) break;
    received += result.value.byteLength;
    if (received > maximumBytes) {
      await reader.cancel("response_too_large");
      throw new Error("response_too_large");
    }
    chunks.push(result.value);
  }
  const bytes = new Uint8Array(received);
  let offset = 0;
  for (const chunk of chunks) {
    bytes.set(chunk, offset);
    offset += chunk.byteLength;
  }
  return JSON.parse(utf8Decoder.decode(bytes));
}
