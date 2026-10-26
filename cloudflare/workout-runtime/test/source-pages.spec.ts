import { createExecutionContext, waitOnExecutionContext } from "cloudflare:test";
import { env } from "cloudflare:workers";
import { describe, expect, it } from "vitest";
import worker from "../src/index";
import approvedObjects from "../../../artifacts/workout_media/cloudflare_runtime_v2/protected_object_keys_v2.json";
import freePreviews from "../../../artifacts/workout_media/cloudflare_runtime_v2/free_preview_keys_v1.json";
import { escapeSourceHtml } from "../src/source-pages";

const paidKey = approvedObjects.keys.find((key) => key.endsWith(".mp4") &&
  !freePreviews.videoObjectKeys.includes(key))!;

async function source(path: string, init?: RequestInit) {
  const context = createExecutionContext();
  const response = await worker.fetch(new Request(`https://workouts.bilhealth.com${path}`, init), env, context);
  await waitOnExecutionContext(context);
  return response;
}

describe("BIL39 public source information is separate from premium video", () => {
  for (const group of ["home", "gym-six-month"]) {
    const key = approvedObjects.keys.find((key) => key.startsWith(`workouts/v1/${group}/`) && key.endsWith(".mp4"))!;
    for (const authorization of [null, "Bearer free-fixture", "Bearer paid-fixture", "Bearer expired-fixture"]) {
      it(`${group} metadata is readable without consulting ${authorization ?? "an anonymous account"}`, async () => {
        const context = createExecutionContext();
        const noBackend = new Proxy(env, {
          get(_target, property) { throw new Error(`Source page accessed forbidden binding ${String(property)}`); },
        });
        const headers = authorization ? { authorization } : undefined;
        const response = await worker.fetch(new Request(`https://workouts.bilhealth.com/v2/source/${key}?token=private-sentinel`,
          { ...(headers ? { headers } : {}) }), noBackend, context);
        await waitOnExecutionContext(context);
        expect(response.status).toBe(200);
        expect(response.headers.get("location")).toBeNull();
        expect(response.headers.get("x-content-type-options")).toBe("nosniff");
        expect(response.headers.get("content-security-policy")).toContain("default-src 'none'");
        const body = await response.text();
        expect(body).toContain("Publisher: BIL Health");
        expect(body).toContain("synthetic performer");
        expect(body).not.toContain("private-sentinel");
        expect(body).not.toContain(".mp4");
        expect(body).not.toContain("<iframe");
        expect(body).not.toContain("/v2/objects/");
      });
    }
  }

  it("HEAD has no body and a Range request never becomes premium video bytes", async () => {
    const head = await source(`/v2/source/${paidKey}`, { method: "HEAD" });
    expect(head.status).toBe(200);
    expect(await head.text()).toBe("");
    expect(head.headers.get("content-type")).toBe("text/html; charset=utf-8");
    const range = await source(`/v2/source/${paidKey}`, { headers: { Range: "bytes=0-20" } });
    expect(range.status).toBe(200);
    expect(range.headers.get("content-range")).toBeNull();
    expect(await range.text()).toContain("<!doctype html>");
    expect((await source(`/v2/objects/${paidKey}`, { method: "HEAD", headers: { Range: "bytes=0-20" } })).status).toBe(401);
  });

  for (const path of [
    "/v2/source/workouts/v1/home/movements/not-in-approved-catalog.mp4",
    "/v2/source/workouts%2Fv1%2Fhome%2Fmovements%2Ftest.mp4",
    "/v2/source/workouts/v1/home/movements/%2e%2e/secret.mp4",
    "/v2/source/workouts/v1/home/movements/test.mp4.html",
    "/v2/source/workouts/v2/catalog/catalog.json",
    "/v2/source/workouts/v2/home/posters/test.webp",
    "/v2/source/workouts/v1/home/movements/<script>.mp4",
  ]) {
    it(`rejects an unapproved source path ${path}`, async () => {
      const response = await source(path);
      expect(response.status).toBe(404);
      expect(response.headers.get("location")).toBeNull();
      expect(await response.text()).not.toContain("<script>");
    });
  }

  it("escapes catalog labels and rejects non-read methods", async () => {
    expect(escapeSourceHtml('A<&\"\'>')).toBe("A&lt;&amp;&quot;&#39;&gt;");
    expect((await source(`/v2/source/${paidKey}`, { method: "POST" })).status).toBe(405);
  });

  it("serves readable HTML while the corresponding video still requires authentication", async () => {
    const response = await source(`/v2/source/${paidKey}`);
    expect(response.status).toBe(200);
    expect(response.headers.get("content-type")).toBe("text/html; charset=utf-8");
    const body = await response.text();
    expect(body).toContain("BIL exercise source");
    expect(body).not.toContain("/v2/objects/");
    expect(body).not.toContain("<video");
    expect(body).not.toContain("<script");
    expect(body).not.toContain("Bearer");
    expect((await source(`/v2/objects/${paidKey}`)).status).toBe(401);
  });
});
