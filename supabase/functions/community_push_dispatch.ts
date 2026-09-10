// Compatibility entry point; all dispatch/security logic has one owner.
import { handler } from "./community-push-dispatch/server.ts";

Deno.serve((request) => handler(request));
