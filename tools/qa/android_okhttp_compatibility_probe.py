#!/usr/bin/env python3
"""Offline JVM/security and ML Kit binary-linkage probe for isolated OkHttp 4.9.2.

No Gradle, application network, accounts, TLS server, private keys or production.
Only official, pinned Maven Central artifacts are fetched; shared caches stay read-only.
Actual runtimeComponents/runtimeDependencies JSON identifies the cached input JARs.
--candidate-model can later bind the isolated proof to a new resolved application graph.
With --candidate-model and no --model, CI downloads the official pinned 3.0.0 API
baseline and uses the candidate's real Okio/Kotlin dependencies. That is not an old APK graph.
"""
from __future__ import annotations

import argparse
import hashlib
import io
import json
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import time
import urllib.error
import urllib.request
from urllib.parse import urlparse
import xml.etree.ElementTree as ET
import zipfile

ROOT = Path(__file__).resolve().parents[2]
CANDIDATE = "4.9.2"
TARGETS = ("okhttp3/", "okio/")
JAR_SHA256_PINS = {
    "3.0.0": "8f25394193dffd55b11d70eede78086afef736174ccdf74a1e3f6f51b1a2e4aa",
    "4.9.2": "3b2ee1b768c1df28c30d2fe6b38dda4d2c519210e30ca3d27950618c563c92de",
}


def sha(path: Path) -> str:
    return hashlib.sha256(path.read_bytes()).hexdigest()


def execute(command: list[str], timeout: int = 60) -> str:
    result = subprocess.run(command, capture_output=True, text=True, encoding="utf8",
                            errors="replace", timeout=timeout)
    if result.returncode:
        raise RuntimeError(f"exit={result.returncode}: {result.stderr.strip()[:1800]}")
    return result.stdout


def verify_download(version: str, extension: str, data: bytes, checksum: str) -> None:
    if hashlib.sha1(data).hexdigest() != checksum:
        raise ValueError("Official Maven checksum differs")
    if extension == "jar" and hashlib.sha256(data).hexdigest() != JAR_SHA256_PINS.get(version):
        raise ValueError("Official artifact differs from the pinned SHA-256")


def download(version: str, extension: str, folder: Path) -> tuple[Path, dict]:
    if version not in ("3.0.0", "4.9.2", "4.12.0") or extension not in ("jar", "pom"):
        raise ValueError("Only the pinned official baseline/candidates are allowed")
    if extension == "jar" and version not in JAR_SHA256_PINS:
        raise ValueError("A JAR requires an independently recorded SHA-256 pin")
    name = f"okhttp-{version}.{extension}"
    url = f"https://repo.maven.apache.org/maven2/com/squareup/okhttp3/okhttp/{version}/{name}"

    def read(target: str, limit: int) -> bytes:
        with urllib.request.urlopen(target, timeout=30) as response:
            if urlparse(response.url).hostname != "repo.maven.apache.org":
                raise ValueError("Unexpected Maven download host")
            data = response.read(limit + 1)
            if len(data) > limit:
                raise ValueError("Oversized Maven response")
            return data

    checksum = read(url + ".sha1", 1024).decode("ascii").strip().split()[0].lower()
    if not re.fullmatch(r"[0-9a-f]{40}", checksum):
        raise ValueError("Invalid official Maven checksum")
    path = folder / name
    if path.exists() or path.is_symlink():
        raise ValueError("Refusing to overwrite an existing artifact")
    data = read(url, 16 * 1024 * 1024)
    verify_download(version, extension, data, checksum)
    path.write_bytes(data)
    return path, {"url": url, "sha256": sha(path), "maven_sha1_matches": True,
                  "pinned_sha256_matches": extension == "jar", "size": len(data)}


def graph(path: Path) -> tuple[bytes, dict[str, str], dict[str, dict]]:
    data = path.read_bytes()
    document = json.loads(data)
    components = document.get("runtimeComponents", document.get("runtimeDependencies"))
    if not isinstance(components, list):
        raise ValueError("A resolved runtime component list is required")
    versions = {}
    for item in components:
        ga = f"{item['group']}:{item['name']}"
        if ga in versions and versions[ga] != item["version"]:
            raise ValueError(f"Ambiguous actual runtime dependency: {ga}")
        versions[ga] = item["version"]
    artifacts = {item["coordinate"]: item for item in document.get("artifacts", [])
                 if isinstance(item, dict) and "coordinate" in item}
    return data, versions, artifacts


def artifact(cache: Path, versions: dict, supplied: dict, ga: str, suffix: str) -> Path:
    group, name = ga.split(":")
    version = versions.get(ga)
    if not version or not re.fullmatch(r"[A-Za-z0-9_.-]+", version):
        raise ValueError(f"Missing/invalid resolved component: {ga}")
    coordinate = ga + ":" + version
    given = supplied.get(coordinate)
    if given and suffix != ".pom":
        path = Path(given["path"])
        if (path.suffix != suffix or not path.is_absolute() or not path.is_file()
                or sha(path) != given["sha256"]):
            raise ValueError(f"Actual resolved artifact/hash mismatch: {ga}")
        return path
    candidates = list((cache / group / name / version).glob("*/" + name + "-" + version + suffix))
    if len(candidates) != 1:
        raise ValueError(f"Expected one cached coordinate/version artifact: {ga}")
    return candidates[0]


def dependencies(pom: Path) -> list[dict]:
    ns = {"m": "http://maven.apache.org/POM/4.0.0"}
    root = ET.parse(pom).getroot()
    props_node = root.find("m:properties", ns)
    props = {} if props_node is None else {p.tag.rsplit("}", 1)[-1]: p.text for p in props_node}
    result = []
    for entry in root.findall("./m:dependencies/m:dependency", ns):
        version = entry.findtext("m:version", namespaces=ns)
        if version and version.startswith("${"):
            version = props[version[2:-1]]
        result.append({"group": entry.findtext("m:groupId", namespaces=ns),
                       "name": entry.findtext("m:artifactId", namespaces=ns), "version": version})
    return result


def constant_pool(data: bytes) -> tuple[list, int]:
    if data[:4] != b"\xca\xfe\xba\xbe":
        raise ValueError("Invalid Java class")
    offset = 10
    count = struct.unpack_from(">H", data, 8)[0]
    pool = [None] * count
    index = 1
    while index < count:
        tag = data[offset]
        offset += 1
        if tag == 1:
            size = struct.unpack_from(">H", data, offset)[0]
            offset += 2
            pool[index] = (tag, data[offset:offset + size].decode("utf8", "replace"))
            offset += size
        elif tag in (7, 8, 16, 19, 20):
            pool[index] = (tag, struct.unpack_from(">H", data, offset)[0])
            offset += 2
        elif tag in (9, 10, 11, 12, 17, 18):
            pool[index] = (tag, *struct.unpack_from(">HH", data, offset))
            offset += 4
        elif tag in (3, 4):
            offset += 4
        elif tag in (5, 6):
            offset += 8
            index += 1
        elif tag == 15:
            offset += 3
        else:
            raise ValueError(f"Unknown JVM constant-pool tag: {tag}")
        index += 1
    return pool, offset


def mlkit_symbols(aar: Path, folder: Path, javap: Path) -> tuple[list[str], dict]:
    classes, members, containing, reflective = set(), set(), [], []
    target_inheritance = []
    jars = []
    with zipfile.ZipFile(aar) as archive:
        for number, name in enumerate(n for n in archive.namelist() if n.endswith(".jar")):
            content = archive.read(name)
            path = folder / f"mlkit-classes-{number}.jar"
            path.write_bytes(content)
            jars.append(path)
            with zipfile.ZipFile(io.BytesIO(content)) as jar:
                for class_name in jar.namelist():
                    if not class_name.endswith(".class"):
                        continue
                    data = jar.read(class_name)
                    pool, offset = constant_pool(data)
                    hits = False
                    for entry in pool:
                        if not entry:
                            continue
                        if entry[0] == 7:
                            target = pool[entry[1]][1]
                            if target.startswith(TARGETS):
                                classes.add(target)
                                hits = True
                        if entry[0] in (9, 10, 11):
                            owner = pool[pool[entry[1]][1]][1]
                            name_and_type = pool[entry[2]]
                            descriptor = pool[name_and_type[2]][1]
                            classes.update(re.findall(r"L((?:okhttp3|okio)/[^;]+);", descriptor))
                            if owner.startswith(TARGETS):
                                members.add(("F" if entry[0] == 9 else "M", owner,
                                             pool[name_and_type[1]][1], descriptor))
                                hits = True
                        if entry[0] == 8 and pool[entry[1]][1].startswith(TARGETS):
                            reflective.append({"class": class_name, "value": pool[entry[1]][1]})
                    if hits:
                        containing.append(class_name[:-6].replace("/", "."))
                    _, _, parent = struct.unpack_from(">HHH", data, offset)
                    interface_count = struct.unpack_from(">H", data, offset + 6)[0]
                    ancestors = ([parent] if parent else []) + list(struct.unpack_from(
                        ">" + "H" * interface_count, data, offset + 8))
                    for ancestor in ancestors:
                        target = pool[pool[ancestor][1]][1]
                        if target.startswith(TARGETS):
                            target_inheritance.append({"class": class_name, "parent": target})
    if reflective or target_inheritance:
        raise ValueError("Reflective target names/subtyping need separate binary review")
    if not containing or not members:
        raise ValueError("Missing actual ML Kit target references; refusing a zero-coverage pass")
    instruction = re.compile(r'^\s*\d+:\s+(invokevirtual|invokestatic|invokespecial|invokeinterface|getstatic|putstatic|getfield|putfield)\b.*// (?:InterfaceMethod|Method|Field) ((?:okhttp3|okio)/[^. ]+)\.([^: ]+):(\S+)')
    usages = {}
    for name in containing:
        disassembly = execute([str(javap), "-classpath", os.pathsep.join(map(str, jars)), "-c", "-p", name])
        for line in disassembly.splitlines():
            match = instruction.match(line)
            if match:
                operation, owner, member, descriptor = match.groups()
                key = ("F" if operation in ("getstatic", "putstatic", "getfield", "putfield") else "M",
                       owner, member.strip('"'), descriptor)
                usages.setdefault(key, set()).add(operation)
    lines = ["C\t" + name for name in sorted(classes)]
    for member in sorted(members):
        modes = usages.get(member, {"unknown"})
        if modes == {"unknown"}:
            raise ValueError("Cannot establish actual invocation kind for an ML Kit member")
        lines.extend("\t".join((*member, mode)) for mode in sorted(modes))
    return lines, {"classes_with_target_references": containing,
        "target_class_symbols": len(classes), "target_member_symbols": len(members),
        "direct_okio_member_symbols": sum(m[1].startswith("okio/") for m in members),
        "internal_member_symbols": [list(m) for m in members if "/internal/" in m[1]],
        "target_subclasses": target_inheritance, "reflective_target_names": reflective,
        "all_aar_embedded_jars_scanned": len(jars), "symbol_rows": len(lines),
        "symbol_sha256": hashlib.sha256(("\n".join(lines) + "\n").encode()).hexdigest()}


def only_one_okhttp(paths: list[Path], expected: Path) -> None:
    providers = []
    for path in paths:
        with zipfile.ZipFile(path) as jar:
            if "okhttp3/OkHttpClient.class" in jar.namelist():
                providers.append(path)
    if providers != [expected] or len(paths) != len(set(paths)):
        raise ValueError("Mixed/duplicate OkHttp JVM classpath")


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--java-home", type=Path, required=True)
    parser.add_argument("--model", type=Path)
    parser.add_argument("--candidate-model", type=Path)
    parser.add_argument("--gradle-cache", type=Path, default=Path(os.environ.get("GRADLE_USER_HOME", str(Path.home() / ".gradle"))) / "caches/modules-2/files-2.1")
    parser.add_argument("--output-root", type=Path, default=ROOT / "build/qa/policy-gate-20261015")
    args = parser.parse_args()
    output = args.output_root.resolve()
    if not output.is_relative_to((ROOT / "build").resolve()):
        raise ValueError("Output must remain inside build")
    output.mkdir(parents=True, exist_ok=True)
    folder = output / ("okhttp-compatibility-" + time.strftime("%Y%m%dT%H%M%S"))
    folder.mkdir()
    result = {"schema": "bil.qa.okhttp.compatibility.v1", "status": "RUNNING", "phases": [],
        "candidate": CANDIDATE, "actual_candidate_graph_verified": False,
        "network_app_requests": 0, "private_keys_created": False,
        "limits": ["JVM reflection checks actual ML Kit symbolic linkage, not execution of Translation or its network",
                   "Synthetic X509 SAN/public keys only; no real certificate/TLS trust chain",
                   "CVE-2021-0341 direct-verifier regression, not proof of exploitable BIL input",
                   "CertificatePinner functionality only; CVE-2016-2402 exact chain attack not reproduced",
                   "No Android ART/R8/native/device/signed-artifact claim"], "failures": []}
    try:
        source = ROOT / "tools/qa/jvm/OkHttpCompatibilityProbe.java"
        result["sources"] = {str(Path(__file__).resolve()): sha(Path(__file__)), str(source): sha(source)}
        java = args.java_home / "bin" / ("java.exe" if os.name == "nt" else "java")
        javac = args.java_home / "bin" / ("javac.exe" if os.name == "nt" else "javac")
        javap = args.java_home / "bin" / ("javap.exe" if os.name == "nt" else "javap")
        version = subprocess.run([str(java), "-version"], capture_output=True, text=True, timeout=20, check=True)
        if not re.search(r'version "21[.\"]', version.stderr):
            raise ValueError("Java 21 required")
        ci_baseline = args.model is None and args.candidate_model is not None
        result["downloads"] = []
        result["baseline_is_old_apk_graph"] = False
        if ci_baseline:
            new_data, new_versions, new_supplied = graph(args.candidate_model)
            old_versions = dict(new_versions)
            old_versions["com.squareup.okhttp3:okhttp"] = "3.0.0"
            old_supplied = new_supplied
            baseline, receipt = download("3.0.0", "jar", folder)
            result["downloads"].append(receipt)
            result["baseline_evidence_kind"] = "official pinned 3.0.0 API baseline with candidate graph dependencies; not an old APK graph"
        else:
            model = args.model or ROOT / "build/qa/policy-gate-20261015/android-runtime-dependencies.json"
            data, old_versions, old_supplied = graph(model)
            (folder / "original-resolved-graph.json").write_bytes(data)
            result["original_graph_sha256"] = hashlib.sha256(data).hexdigest()
            if old_versions.get("com.squareup.okhttp3:okhttp") != "3.0.0":
                raise ValueError("Baseline graph must resolve exact OkHttp 3.0.0")
            baseline = artifact(args.gradle_cache, old_versions, old_supplied, "com.squareup.okhttp3:okhttp", ".jar")
            if sha(baseline) != JAR_SHA256_PINS["3.0.0"]:
                raise ValueError("Actual baseline JAR differs from its pinned SHA-256")
            new_versions, new_supplied = old_versions, old_supplied
            result["baseline_evidence_kind"] = "saved actual 3.0.0 runtime graph; no APK execution claim"
            if args.candidate_model:
                new_data, new_versions, new_supplied = graph(args.candidate_model)
        if args.candidate_model:
            (folder / "candidate-resolved-graph.json").write_bytes(new_data)
            result["candidate_graph_sha256"] = hashlib.sha256(new_data).hexdigest()
            result["candidate_graph_is_synthetic"] = json.loads(new_data).get("synthetic", False) is True
            if new_versions.get("com.squareup.okhttp3:okhttp") != CANDIDATE:
                raise ValueError("Actual candidate differs from the pinned, tested version")
        aar = artifact(args.gradle_cache, old_versions, old_supplied, "com.google.mlkit:translate", ".aar")
        mlkit_pom = artifact(args.gradle_cache, old_versions, old_supplied, "com.google.mlkit:translate", ".pom")
        result["mlkit_pom_dependencies"] = dependencies(mlkit_pom)
        poms = {}
        for version in (CANDIDATE, "4.12.0"):
            pom, receipt = download(version, "pom", folder)
            poms[version] = dependencies(pom)
            result["downloads"].append(receipt)
        result["candidate_pom_comparison"] = poms
        candidate, receipt = download(CANDIDATE, "jar", folder)
        result["downloads"].append(receipt)
        if args.candidate_model:
            resolved = artifact(args.gradle_cache, new_versions, new_supplied, "com.squareup.okhttp3:okhttp", ".jar")
            if sha(resolved) != sha(candidate):
                raise ValueError("Actual candidate JAR differs from official Maven")
            result["candidate_graph_jars_verified"] = True
            result["actual_candidate_graph_verified"] = not result["candidate_graph_is_synthetic"]
        shared = {}
        for label, versions, supplied in [("baseline", old_versions, old_supplied), ("candidate", new_versions, new_supplied)]:
            shared[label] = [artifact(args.gradle_cache, versions, supplied, ga, ".jar") for ga in
                             ("com.squareup.okio:okio-jvm", "org.jetbrains.kotlin:kotlin-stdlib")]
        paths = {"baseline": [baseline, *shared["baseline"]], "candidate": [candidate, *shared["candidate"]]}
        result["classpaths"] = {label: [{"path": str(p), "sha256": sha(p)} for p in jars] for label, jars in paths.items()}
        only_one_okhttp(paths["baseline"], baseline)
        only_one_okhttp(paths["candidate"], candidate)
        result["mlkit_artifacts"] = {str(aar): sha(aar), str(mlkit_pom): sha(mlkit_pom)}
        symbols, evidence = mlkit_symbols(aar, folder, javap)
        result["binary_symbols"] = evidence
        symbols_file = folder / "mlkit-okhttp-okio-symbols.tsv"
        symbols_file.write_text("\n".join(symbols) + "\n", encoding="utf8")
        classes = folder / "classes"
        classes.mkdir()
        execute([str(javac), "--release", "11", "-encoding", "UTF-8", "-cp", os.pathsep.join(map(str, paths["baseline"])),
                 "-d", str(classes), str(source)])
        for label, version in [("baseline", "3.0.0"), ("candidate", CANDIDATE)]:
            for mode in ("linkage", "functional"):
                public = execute([str(java), "-cp", os.pathsep.join(map(str, [classes, *paths[label]])),
                                  "OkHttpCompatibilityProbe", mode, version, str(symbols_file)])
                (folder / f"{label}-{mode}.log").write_text(public, encoding="utf8")
                phase = json.loads(public.strip().splitlines()[-1])
                if mode == "linkage" and (phase["failed"] or phase["symbols_checked"] != len(symbols)):
                    raise ValueError("Incomplete binary linkage evidence")
                if mode == "functional" and phase["failed"] != (2 if label == "baseline" else 0):
                    raise ValueError("Unexpected hostname regression results")
                result["phases"].append({"label": label, **phase})
                print(f"{label} {version} {mode}: {phase['passed']} PASS / {phase['failed']} FAIL", flush=True)
        result["status"] = "PASS_ISOLATED_CANDIDATE_WITH_BASELINE_REGRESSION_REPRODUCED"
    except Exception as error:
        result["status"] = "FAIL"
        result["failures"].append({"type": type(error).__name__, "message": str(error)[:1800]})
        print(f"OKHTTP_QA_FAILED {type(error).__name__}: {error}", file=sys.stderr)
    finally:
        receipt = folder / "result.json"
        receipt.write_text(json.dumps(result, ensure_ascii=False, indent=2) + "\n", encoding="utf8")
        print(f"OKHTTP_QA_RECEIPT={receipt}", flush=True)
    return 0 if result["status"].startswith("PASS_") else 1


if __name__ == "__main__":
    sys.exit(main())
