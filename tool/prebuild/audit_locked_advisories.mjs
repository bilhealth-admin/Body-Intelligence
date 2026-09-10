// Only public dependency coordinates are sent to OSV, never private sources.
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";
import { queryAdvisories } from "./audit_pub_advisories.mjs";

export function coordinates(text, ecosystem) {
  const result = new Map();
  const add = (name, version) => {
    if (!name || !version || /[\s\[\]{}()+]/.test(version)) {
      throw new Error("An exact resolved dependency version is required");
    }
    result.set(`${name}@${version}`, { name, version, ecosystem });
  };
  if (ecosystem === "npm") {
    const lock = JSON.parse(text);
    for (const key of Object.keys(lock.npm ?? {})) {
      const match = /^((?:@[^/]+\/)?[^@]+)@([^_]+)(?:_.*)?$/.exec(key);
      if (!match) throw new Error("Invalid locked npm coordinate");
      add(match[1], match[2]);
    }
    for (const url of Object.keys(lock.remote ?? {})) {
      const match = /^https:\/\/esm\.sh\/((?:@[^/]+\/)?[^/@?]+)@(\d[^/?]*)/
        .exec(url);
      if (match) add(match[1], match[2]);
    }
  } else if (ecosystem === "Maven") {
    if (/\bFAILED\b/.test(text) || !text.includes("BUILD SUCCESSFUL")) {
      throw new Error("Gradle dependency resolution is incomplete");
    }
    for (
      const match of text.matchAll(
        /(?:\+---|\\---) ([\w.-]+):([\w.-]+):(\{[^}]*\}|[^\s]+)(?: -> ([^\s]+))?/g,
      )
    ) {
      const resolved = match[4] ?? match[3];
      const components = resolved.split(":");
      add(
        components.length === 3
          ? components.slice(0, 2).join(":")
          : `${match[1]}:${match[2]}`,
        components.at(-1),
      );
    }
  } else {
    throw new Error("Unsupported dependency ecosystem");
  }
  if (!result.size) throw new Error("No resolved packages found");
  return [...result.values()];
}

if (
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const [ecosystem, input] = process.argv.slice(2);
  const packages = coordinates(await readFile(input, "utf8"), ecosystem);
  const findings = await queryAdvisories(packages);
  console.log(
    JSON.stringify(
      {
        source: "https://api.osv.dev/v1/querybatch",
        checked_at: new Date().toISOString(),
        ecosystem,
        packages_checked: packages.length,
        not_covered: ecosystem === "npm"
          ? ["Deno standard-library URLs and JSR packages"]
          : [],
        findings,
      },
      null,
      2,
    ),
  );
  process.exitCode = findings.length ? 1 : 0;
}
