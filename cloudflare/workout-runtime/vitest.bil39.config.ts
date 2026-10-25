import { cloudflareTest } from "@cloudflare/vitest-plugin";
import { defineConfig } from "vitest/config";

export default defineConfig({
  plugins: [cloudflareTest({
    remoteBindings: false,
    wrangler: { configPath: "./wrangler.bil39-qa.jsonc", environment: "staging" },
  })],
  test: {
    include: ["test/**/*.spec.ts"],
    setupFiles: ["./test/setup.ts"],
  },
});
