import { handler } from "./server.ts";

Deno.serve((request) => handler(request));
