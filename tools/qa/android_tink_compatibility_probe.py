#!/usr/bin/env python3
"""Isolated Tink 1.21/1.22 JVM compatibility probe; never Android/Production evidence.

Run with Java 21. Each JVM loads exactly one pinned Tink JAR. Synthetic keysets
remain in an ACL-private, Git-ignored build subdirectory, never in the receipt.
Only pinned 1.21.0/1.22.0 artifacts/POM/checksums are fetched, from Maven Central.
--new-model accepts AGP XML, or JSON with runtimeClasspath/artifacts entries:
{"coordinate": "group:artifact:version", "path": "/absolute/file.jar", "sha256": "..."}.
Also accepts runtimeDependencies: [{group, name, version, artifact, sha256?}],
resolving each needed JAR from --gradle-cache by exact coordinate/name/hash.
With no --old-model, the old baseline is official 1.21.0 plus the candidate graph's
resolved runtime dependencies; the receipt explicitly distinguishes this CI mode.
"""

from __future__ import annotations

import argparse
import csv
import hashlib
import io
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import time
import urllib.request
from urllib.parse import urlparse
import xml.etree.ElementTree as ET
import zipfile


ROOT = Path(__file__).resolve().parents[2]
DEFAULT_MODEL = ROOT / (
    "build/app/intermediates/lint_report_lint_model/release/"
    "generateReleaseLintReportModel/release-artifact-libraries.xml"
)
MAVEN = "https://repo.maven.apache.org/maven2/com/google/crypto/tink/tink-android/"
VERSIONS = ("1.21.0", "1.22.0")
MARKER = "BIL_QA_SYNTHETIC_TINK_ONLY_V1"
MAX_DOWNLOAD = 16 * 1024 * 1024
RUNTIME_GAS = {"com.google.crypto.tink:tink-android", "com.google.code.gson:gson",
               "androidx.annotation:annotation-jvm", "com.google.code.findbugs:jsr305",
               "com.google.errorprone:error_prone_annotations", "org.jspecify:jspecify"}
EXPECTED_PHASE_COUNTS = {"create": 146, "peer": 176, "return": 146}
GRAPH_SIDECARS: dict[str, tuple[Path, bytes]] = {}


def digest(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def run(command: list[str], timeout: int = 45) -> str:
    result = subprocess.run(command, capture_output=True, text=True,
                            encoding="utf-8", errors="replace", timeout=timeout)
    if result.returncode:
        # Probe output has controlled labels only, never key material/exception messages.
        raise RuntimeError(f"exit={result.returncode}: {result.stderr.strip()[:2000]}")
    return result.stdout


def fetch(name: str, destination: Path) -> dict:
    match = re.fullmatch(r"tink-android-(1\.2[12]\.0)\.(jar|pom)", name)
    if not match:
        raise ValueError("Only pinned Tink 1.21.0/1.22.0 may be downloaded")
    url = MAVEN + match[1] + "/" + name

    def get(target: str, limit: int) -> bytes:
        with urllib.request.urlopen(target, timeout=30) as response:
            if urlparse(response.url).hostname != "repo.maven.apache.org":
                raise ValueError("Maven response redirected outside its approved host")
            body = response.read(limit + 1)
            if len(body) > limit:
                raise ValueError("Maven response exceeded its byte limit")
            return body

    checksum = get(url + ".sha512", 1024).decode("ascii").strip().split()[0].lower()
    if not re.fullmatch(r"[0-9a-f]{128}", checksum):
        raise ValueError("Malformed official Maven SHA-512")
    if destination.is_symlink():
        raise ValueError("Downloaded artifact destination is linked")
    data = destination.read_bytes() if destination.exists() else get(url, MAX_DOWNLOAD)
    if hashlib.sha512(data).hexdigest() != checksum:
        raise ValueError("Pinned Maven artifact checksum mismatch")
    if not destination.exists():
        destination.write_bytes(data)
    return {"url": url, "sha256": digest(destination),
            "sha512_matches_maven": True, "size": len(data)}


def model(path: Path, gradle_cache: Path) -> tuple[bytes, dict[str, dict]]:
    data = path.read_bytes()
    found = {}
    if data.lstrip().startswith(b"<"):
        if not path.name.endswith("-libraries.xml"):
            raise ValueError("AGP libraries XML needs its original filename and companion dependencies XML")
        dependencies = path.with_name(path.name.replace("-libraries.xml", "-dependencies.xml"))
        dependency_data = dependencies.read_bytes()
        package = ET.fromstring(dependency_data).find("package")
        if package is None:
            raise ValueError("AGP dependencies XML has no package runtime scope")
        selected = {entry.attrib.get("name") for entry in package.iter("dependency")}
        GRAPH_SIDECARS[str(path.resolve())] = (dependencies, dependency_data)
        entries = [{"coordinate": e.attrib.get("resolved", ""),
                    "path": e.attrib.get("jars")} for e in ET.fromstring(data).iter("library")
                   if e.attrib.get("name") in selected]
    else:
        document = json.loads(data)
        entries = document.get("runtimeClasspath", document.get("artifacts"))
        if entries is None and isinstance(document.get("runtimeDependencies"), list):
            entries = []
            for item in document["runtimeDependencies"]:
                ga = f"{item.get('group')}:{item.get('name')}"
                if ga not in RUNTIME_GAS:
                    continue
                name = item.get("artifact")
                if not isinstance(name, str) or Path(name).name != name or not name.endswith(".jar"):
                    raise ValueError(f"Invalid resolved JAR name: {ga}")
                version = item.get("version", "")
                if not re.fullmatch(r"[A-Za-z0-9_.-]+", version):
                    raise ValueError(f"Invalid resolved version: {ga}")
                location = gradle_cache / item["group"] / item["name"] / version
                candidates = list(location.glob("*/" + name))
                expected = item.get("sha256")
                if expected:
                    if not re.fullmatch(r"[0-9a-fA-F]{64}", expected):
                        raise ValueError(f"Invalid resolved checksum: {ga}")
                    candidates = [p for p in candidates if digest(p) == expected.lower()]
                if len(candidates) != 1:
                    raise ValueError(f"Cannot uniquely match resolved JAR coordinate/name/hash: {ga}")
                entries.append({"coordinate": ga + ":" + version,
                                "path": str(candidates[0].resolve()), "sha256": expected})
        if not isinstance(entries, list):
            raise ValueError("Resolved JSON graph needs runtimeClasspath/artifacts/runtimeDependencies")
    for entry in entries:
        coordinate = entry.get("coordinate", "")
        parts = coordinate.split(":")
        if len(parts) == 3 and entry.get("path"):
            ga = ":".join(parts[:2])
            if ga not in RUNTIME_GAS:
                continue
            if ga in found:
                raise ValueError(f"Duplicate resolved dependency: {ga}")
            artifact = Path(entry["path"])
            if not artifact.is_absolute() or not artifact.is_file():
                raise ValueError(f"Resolved artifact is not an existing absolute file: {ga}")
            if entry.get("sha256") and digest(artifact) != entry["sha256"].lower():
                raise ValueError(f"Resolved artifact hash differs: {ga}")
            found[ga] = {"version": parts[2], "path": artifact, "coordinate": coordinate}
    return data, found


def snapshot_graph(path: Path, data: bytes, destination: Path) -> dict:
    destination.mkdir()
    saved = destination / path.name
    saved.write_bytes(data)
    evidence = {path.name: hashlib.sha256(data).hexdigest()}
    companion = GRAPH_SIDECARS.get(str(path.resolve()))
    if companion:
        sidecar, content = companion
        (destination / sidecar.name).write_bytes(content)
        evidence[sidecar.name] = hashlib.sha256(content).hexdigest()
    return evidence


def pom_dependencies(path: Path) -> list[dict]:
    ns = {"m": "http://maven.apache.org/POM/4.0.0"}
    tree = ET.parse(path).getroot()
    props_node = tree.find("m:properties", ns)
    props = {entry.tag.rsplit("}", 1)[-1]: entry.text for entry in props_node}
    deps = []
    for entry in tree.findall("./m:dependencies/m:dependency", ns):
        group = entry.findtext("m:groupId", namespaces=ns)
        artifact = entry.findtext("m:artifactId", namespaces=ns)
        version = entry.findtext("m:version", namespaces=ns)
        if version and version.startswith("${"):
            version = props[version[2:-1]]
        deps.append({"ga": f"{group}:{artifact}", "declared_version": version})
    return deps


def classpath(jar: Path, pom: Path, graph: dict[str, dict]) -> tuple[list[Path], list[dict]]:
    paths = [jar]
    dependencies = []
    for dep in pom_dependencies(pom):
        resolved = graph.get(dep["ga"])
        if not resolved or not resolved["path"].is_file():
            raise ValueError(f"AGP graph lacks a runtime dependency: {dep['ga']}")
        path = resolved["path"]
        paths.append(path)
        dependencies.append({**dep, "resolved": resolved["coordinate"],
                             "path": str(path), "sha256": digest(path)})
    # Gson's annotations are also represented by the actual AGP graph.
    if "org.jspecify:jspecify" in graph:
        item = graph["org.jspecify:jspecify"]
        paths.append(item["path"])
        dependencies.append({"ga": "org.jspecify:jspecify", "transitive": True,
                             "resolved": item["coordinate"], "path": str(item["path"]),
                             "sha256": digest(item["path"])})
    providers = []
    for path in paths:
        with zipfile.ZipFile(path) as archive:
            if "com/google/crypto/tink/Aead.class" in archive.namelist():
                providers.append(path)
    if providers != [jar] or len(paths) != len(set(paths)):
        raise ValueError("Mixed or duplicate Tink/runtime classpath")
    return paths, dependencies


def private_directory(path: Path) -> str:
    path.mkdir(mode=0o700)
    if os.name == "nt":
        identity = run(["whoami", "/user", "/fo", "csv", "/nh"])
        sid = next(csv.reader(io.StringIO(identity)))[1]
        if not re.fullmatch(r"S-[0-9-]+", sid):
            raise ValueError("Cannot establish a private QA directory owner")
        run(["icacls", str(path), "/inheritance:r", "/grant:r",
             f"*{sid}:(OI)(CI)F", "*S-1-5-18:(OI)(CI)F"])
        return "Windows ACL: inherited access removed; current user and SYSTEM only"
    path.chmod(0o700)
    return "POSIX mode 0700"


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java-home", type=Path, required=True)
    parser.add_argument("--old-model", type=Path)
    parser.add_argument("--new-model", type=Path)
    parser.add_argument("--gradle-cache", type=Path, default=Path(
        os.environ.get("GRADLE_USER_HOME", str(Path.home() / ".gradle")))
        / "caches/modules-2/files-2.1")
    parser.add_argument("--output-root", type=Path, default=ROOT / "build/qa/policy-gate-20261015")
    args = parser.parse_args()
    output = args.output_root.resolve()
    if not output.is_relative_to((ROOT / "build").resolve()):
        raise ValueError("QA output must remain inside the ignored build directory")
    output.mkdir(parents=True, exist_ok=True)
    run_root = output / ("tink-jvm-compatibility-" + time.strftime("%Y%m%dT%H%M%S"))
    run_root.mkdir()
    receipt = {"schema": "bil.qa.tink.jvm.compatibility.v1", "status": "RUNNING",
        "versions": list(VERSIONS), "phases": [], "constant_time_measured": False,
        "native_keystore_or_esp_migration_tested": False,
        "legacy_121_is_intentionally_the_affected_baseline": True,
        "public_evidence_allowlist": ["result.json", "patched-verifyMac-javap.txt"],
        "never_upload": ["**/private-synthetic-keysets/**"],
        "coverage": {"templates": ["AES256_GCM", "AES256_SIV", "HMAC_SHA256_128BITTAG", "AES_CMAC"],
                     "value_categories": ["English", "Arabic", "empty", "mixed Unicode", "binary"],
                     "associated_data": ["empty", "nonempty", "wrong must reject"],
                     "keysets": ["raw binary", "software-AEAD protected", "tampered must reject"]},
        "limits": ["Synthetic JVM keysets and software AEAD only",
                   "Not Android Keystore, device ESP migration, signed APK/AAB or store proof",
                   "MAC tests check correctness/rejection, not constant-time execution"],
        "source": {}, "failures": []}
    started = time.monotonic()
    try:
        for source in [Path(__file__).resolve(), ROOT / "tools/qa/jvm/TinkCompatibilityProbe.java"]:
            receipt["source"][str(source)] = digest(source)
        java = args.java_home / "bin" / ("java.exe" if os.name == "nt" else "java")
        javac = args.java_home / "bin" / ("javac.exe" if os.name == "nt" else "javac")
        javap = args.java_home / "bin" / ("javap.exe" if os.name == "nt" else "javap")
        version = subprocess.run([str(java), "-version"], capture_output=True, text=True,
                                 timeout=15, check=True).stderr.splitlines()[0]
        if not re.search(r'version "21[.\"]', version):
            raise ValueError("The bounded harness requires Java 21")
        receipt["java"] = version
        private = run_root / "private-synthetic-keysets"
        ignored = subprocess.run(["git", "check-ignore", "-q", "--", str(private)],
                                 cwd=ROOT, timeout=10)
        if ignored.returncode != 0:
            raise ValueError("Private synthetic key material is not ignored by Git")
        receipt["private_storage"] = private_directory(private)
        (private / ".synthetic-only").write_text(MARKER, encoding="utf8")
        if args.old_model is None and args.new_model is None:
            _, discovered = model(DEFAULT_MODEL, args.gradle_cache)
            discovered_version = discovered.get("com.google.crypto.tink:tink-android", {}).get("version")
            if discovered_version == VERSIONS[0]:
                args.old_model = DEFAULT_MODEL
            else:
                args.new_model = DEFAULT_MODEL
        new_data, new_graph = model(args.new_model or args.old_model, args.gradle_cache)
        receipt["new_graph_evidence"] = snapshot_graph(
            args.new_model or args.old_model, new_data, run_root / "new-graph")
        receipt["new_model_sha256"] = hashlib.sha256(new_data).hexdigest()
        receipt["new_runtime_graph_is_final_122"] = (
            new_graph.get("com.google.crypto.tink:tink-android", {}).get("version") == "1.22.0")
        if args.new_model and not receipt["new_runtime_graph_is_final_122"]:
            raise ValueError("Candidate graph must resolve the tested 1.22.0; another version needs fresh proof, not a force")
        receipt["downloads"] = []
        if args.old_model:
            old_data, old_graph = model(args.old_model, args.gradle_cache)
            receipt["old_graph_evidence"] = snapshot_graph(args.old_model, old_data, run_root / "old-graph")
            receipt["old_model_sha256"] = hashlib.sha256(old_data).hexdigest()
            old = old_graph.get("com.google.crypto.tink:tink-android")
            if not old or old["version"] != VERSIONS[0]:
                raise ValueError("Old graph must resolve exact Tink Android 1.21.0")
            old_jar = old["path"]
            poms = list(old_jar.parents[1].glob("*/*.pom"))
            if len(poms) != 1:
                raise ValueError("Expected one cached official 1.21.0 POM")
            old_pom = poms[0]
            receipt["old_baseline"] = "Original AGP graph and cached 1.21.0 artifact/POM"
        else:
            old_graph = new_graph
            old_jar = run_root / "tink-android-1.21.0.jar"
            old_pom = run_root / "tink-android-1.21.0.pom"
            receipt["downloads"].extend([fetch(old_jar.name, old_jar), fetch(old_pom.name, old_pom)])
            receipt["old_baseline"] = "Official pinned 1.21.0 plus candidate graph dependencies; not an old APK classpath claim"
        new_jar = run_root / "tink-android-1.22.0.jar"
        new_pom = run_root / "tink-android-1.22.0.pom"
        receipt["downloads"].extend([fetch(new_jar.name, new_jar), fetch(new_pom.name, new_pom)])
        if receipt["new_runtime_graph_is_final_122"]:
            actual_jar = new_graph["com.google.crypto.tink:tink-android"]["path"]
            if digest(actual_jar) != digest(new_jar):
                raise ValueError("Actual candidate JAR differs from checksum-verified Maven 1.22.0")
            receipt["actual_candidate_jar_sha256_matches_maven"] = True
        jars = {VERSIONS[0]: old_jar, VERSIONS[1]: new_jar}
        cp_old, deps_old = classpath(old_jar, old_pom, old_graph)
        cp_new, deps_new = classpath(new_jar, new_pom, new_graph)
        receipt["runtime_dependencies"] = {VERSIONS[0]: deps_old, VERSIONS[1]: deps_new}
        receipt["artifact_sha256"] = {v: digest(p) for v, p in jars.items()}
        receipt["pom_sha256"] = {VERSIONS[0]: digest(old_pom), VERSIONS[1]: digest(new_pom)}
        disassembly = run([str(javap), "-classpath", str(new_jar), "-c", "-p",
                          "com.google.crypto.tink.mac.internal.ChunkedMacVerificationFromComputation"])
        method = disassembly.split("public void verifyMac()", 1)[1].split("\n  static ", 1)[0]
        if "java/security/MessageDigest.isEqual" not in method or "Bytes.equals" in method:
            raise ValueError("Pinned 1.22.0 JAR does not contain the required comparison fix")
        (run_root / "patched-verifyMac-javap.txt").write_text(disassembly, encoding="utf8")
        receipt["patched_comparison_bytecode"] = "MessageDigest.isEqual present; Bytes.equals absent"
        classes = run_root / "classes"
        classes.mkdir()
        compile_cp = os.pathsep.join(str(p) for p in cp_old)
        run([str(javac), "--release", "11", "-encoding", "UTF-8", "-cp", compile_cp,
             "-d", str(classes), str(ROOT / "tools/qa/jvm/TinkCompatibilityProbe.java")])
        runtime = {VERSIONS[0]: cp_old, VERSIONS[1]: cp_new}
        for origin, peer in [VERSIONS, tuple(reversed(VERSIONS))]:
            direction = private / f"{origin}-to-{peer}"
            direction.mkdir()
            for phase, selected in [("create", origin), ("peer", peer), ("return", origin)]:
                cp = os.pathsep.join(str(p) for p in [classes, *runtime[selected]])
                public = run([str(java), f"-Dbil.qa.private.root={private}", "-cp", cp,
                              "TinkCompatibilityProbe", phase, str(direction), selected])
                event = json.loads(public.strip())
                if (event["failed"] != 0 or event["passed"] != EXPECTED_PHASE_COUNTS[phase]
                        or event["phase"] != phase or event["tink_version"] != selected):
                    raise ValueError("A phase did not provide a fail-closed result")
                receipt["phases"].append({"origin": origin, "peer": peer, **event})
                print(f"{origin}->{peer} {phase} Tink={selected}: {event['passed']} PASS", flush=True)
        receipt["passed"] = sum(event["passed"] for event in receipt["phases"])
        receipt["failed"] = 0
        receipt["status"] = "PASS_JVM_ONLY"
    except Exception as error:
        receipt["status"] = "FAIL"
        receipt["failures"].append({"type": type(error).__name__, "message": str(error)[:2000]})
        print(f"TINK_JVM_PROBE_FAILED {type(error).__name__}: {error}", file=sys.stderr)
    finally:
        receipt["elapsed_seconds"] = round(time.monotonic() - started, 3)
        result = run_root / "result.json"
        result.write_text(json.dumps(receipt, indent=2, ensure_ascii=False) + "\n", encoding="utf8")
        print(f"TINK_JVM_RECEIPT={result}", flush=True)
    return 0 if receipt["status"] == "PASS_JVM_ONLY" else 1


if __name__ == "__main__":
    sys.exit(main())
