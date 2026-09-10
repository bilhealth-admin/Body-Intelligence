// Query public package coordinates only; never upload source, paths, or secrets.
import { readFile } from "node:fs/promises";
import { pathToFileURL } from "node:url";

export async function queryAdvisories(packagesToCheck) {
  const findings = [];
  for (let start = 0; start < packagesToCheck.length; start += 100) {
    const packages = packagesToCheck.slice(start, start + 100);
    let queries = packages.map((p) => ({
      package: { name: p.name, ecosystem: p.ecosystem ?? "Pub" },
      version: p.version,
    }));
    while (queries.length) {
      const response = await fetch("https://api.osv.dev/v1/querybatch", {
        method: "POST",
        headers: { "content-type": "application/json" },
        body: JSON.stringify({ queries }),
        signal: AbortSignal.timeout(30_000),
      });
      if (!response.ok) throw new Error(`OSV query failed: ${response.status}`);
      const body = await response.json();
      if (
        !Array.isArray(body.results) || body.results.length !== queries.length
      ) {
        throw new Error("Incomplete OSV coverage");
      }
      const next = [];
      for (const [index, result] of body.results.entries()) {
        for (const vulnerability of result.vulns ?? []) {
          findings.push({
            package: queries[index].package.name,
            ecosystem: queries[index].package.ecosystem,
            version: queries[index].version,
            ...vulnerability,
          });
        }
        if (result.next_page_token) {
          next.push({ ...queries[index], page_token: result.next_page_token });
        }
      }
      queries = next;
    }
  }
  return findings;
}

if (
  process.argv[1] && import.meta.url === pathToFileURL(process.argv[1]).href
) {
  const input = process.argv[2];
  if (!input) throw new Error("Supply the JSON output of dart pub deps --json");
  const deps = JSON.parse(await readFile(input, "utf8"));
  const hosted = deps.packages.filter((p) => p.source === "hosted");
  const findings = await queryAdvisories(hosted);
  console.log(JSON.stringify(
    {
      source: "https://api.osv.dev/v1/querybatch",
      checked_at: new Date().toISOString(),
      packages_checked: hosted.length,
      not_covered: deps.packages.filter((p) => p.source !== "hosted")
        .map(({ name, version, source }) => ({ name, version, source })),
      findings,
    },
    null,
    2,
  ));
  process.exitCode = findings.length ? 1 : 0;
}
