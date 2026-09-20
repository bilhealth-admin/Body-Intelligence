import { handler } from "./store_backend.ts";

Deno.serve((request) => handler(request));
