/** Provider-internal encoding only; the mobile wire contract remains an object.
 * An empty structured-output object schema otherwise constrains Gemini to {}.
 * The JSON string supports the existing nested native tool arguments without
 * a permissive or enormous provider schema. Native allow-lists still apply.
 */
export function decodeCoachToolArguments(
  item: Record<string, unknown>,
): Record<string, unknown> {
  let value = item.arguments;
  if (Object.hasOwn(item, "arguments_json")) {
    const raw = item.arguments_json;
    if (typeof raw !== "string" || raw.length > 2000) {
      throw new Error("malformed_action_arguments");
    }
    try {
      value = JSON.parse(raw);
    } catch {
      throw new Error("malformed_action_arguments");
    }
    if (
      item.arguments && typeof item.arguments === "object" &&
      Object.keys(item.arguments).length > 0 &&
      JSON.stringify(item.arguments) !== JSON.stringify(value)
    ) throw new Error("malformed_action_arguments");
  } else if (value == null) {
    value = {};
  }
  if (
    value == null || typeof value !== "object" || Array.isArray(value) ||
    JSON.stringify(value).length > 2000
  ) throw new Error("malformed_action_arguments");
  function safe(node: unknown, depth = 0): boolean {
    if (depth > 12) return false;
    if (node && typeof node === "object") {
      return Object.entries(node).every(([key, child]) =>
        !["__proto__", "prototype", "constructor"].includes(key) &&
        safe(child, depth + 1)
      );
    }
    return typeof node !== "number" || Number.isFinite(node);
  }
  if (!safe(value)) throw new Error("malformed_action_arguments");
  return value as Record<string, unknown>;
}
