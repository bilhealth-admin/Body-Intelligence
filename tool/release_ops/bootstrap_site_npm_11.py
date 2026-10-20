"""Bootstrap one isolated, source-verified npm CLI without its peer resolver."""
from __future__ import annotations

import base64
import hashlib
import json
import os
from pathlib import Path, PurePosixPath
import subprocess
import sys
import tarfile

VERSION = "11.21.1"
ARBORIST = "9.9.3"
ARBORIST_SOURCE_GIT_BLOB = "02fcb86aaa0d10f0c0e3d6e4c1bb0815c06f77c0"
NODE_ENGINE = "^20.17.0 || >=22.9.0"
SOURCE_URL = "https://github.com/npm/cli/blob/v11.21.1/workspaces/arborist/lib/arborist/build-ideal-tree.js"


def require(okay, code):
    if not okay:
        raise ValueError(code)


def save(path, value):
    path.parent.mkdir(parents=True, exist_ok=True)
    path.write_text(json.dumps(value, indent=2) + "\n")


def integrity_check(raw, expected):
    require(isinstance(expected, str) and expected.startswith("sha512-"), "NPM_TARBALL_INTEGRITY_NOT_SHA512")
    digest = hashlib.sha512(raw).digest()
    require(base64.b64decode(expected[7:], validate=True) == digest, "NPM_TARBALL_INTEGRITY_MISMATCH")
    return "sha512-" + base64.b64encode(digest).decode()


def safe_extract(path, target):
    with tarfile.open(path, "r:gz") as archive:
        for member in archive.getmembers():
            name = PurePosixPath(member.name)
            require(not name.is_absolute() and ".." not in name.parts and "\\" not in member.name and
                    name.parts and name.parts[0] == "package", "NPM_TARBALL_UNSAFE_MEMBER")
        archive.extractall(target, filter="data")


def verify_cli(package, evidence=None):
    meta = json.loads((package / "package.json").read_text())
    arborist = package / "node_modules/@npmcli/arborist"
    arb_meta = json.loads((arborist / "package.json").read_text())
    code = (arborist / "lib/arborist/build-ideal-tree.js").read_bytes()
    git_blob = hashlib.sha1(b"blob " + str(len(code)).encode() + b"\0" + code).hexdigest()
    if evidence is not None:
        save(evidence / "actual-package-source-inspection.json", {"status": "INSPECTED_NOT_YET_APPROVED",
            "npm_version": meta.get("version"), "node_engine": meta.get("engines", {}).get("node"),
            "arborist_version": arb_meta.get("version"), "resolver_git_blob_sha": git_blob,
            "resolver_sha256": hashlib.sha256(code).hexdigest()})
    require(meta.get("name") == "npm" and meta.get("version") == VERSION and meta.get("engines", {}).get("node") == NODE_ENGINE,
            "BOOTSTRAPPED_NPM_VERSION_OR_ENGINE_MISMATCH")
    require(arb_meta.get("version") == ARBORIST and git_blob == ARBORIST_SOURCE_GIT_BLOB,
            "BOOTSTRAPPED_PEER_RESOLVER_SOURCE_MISMATCH")
    return {"npm_version": VERSION, "node_engine": NODE_ENGINE, "arborist_version": ARBORIST,
            "arborist_source_git_blob_sha": git_blob, "arborist_source_sha256": hashlib.sha256(code).hexdigest(),
            "source_url": SOURCE_URL}


def bootstrap(target, evidence):
    target.mkdir(parents=True, exist_ok=True)
    evidence.mkdir(parents=True, exist_ok=True)
    save(target / "package.json", {"name": "bil-isolated-npm-bootstrap", "version": "0.0.0", "private": True})
    user_config, global_config = target / "npm-user-config", target / "npm-global-config"
    user_config.write_text("")
    global_config.write_text("")
    env = {**os.environ, "NPM_CONFIG_USERCONFIG": str(user_config), "NPM_CONFIG_GLOBALCONFIG": str(global_config)}
    common = ["--registry=https://registry.npmjs.org/", "--cache", str(target / "cache"), "--workspaces=false", "--ignore-scripts"]

    def npm(*args):
        result = subprocess.run(["npm", *args, *common], cwd=target, env=env, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
        if result.returncode != 0:
            import re
            stderr = result.stderr.decode("utf-8", "replace")
            save(evidence / "public-registry-operation-failure.json", {"operation": args[0], "exit_code": result.returncode,
                "npm_error_codes": sorted(set(re.findall(r"npm (?:ERR!|error) code ([A-Z0-9_-]+)", stderr))),
                "null_edges_out_seen": "Cannot read properties of null (reading 'edgesOut')" in stderr})
        require(result.returncode == 0, "NPM_METADATA_OR_PACK_FAILED")
        return json.loads(result.stdout)

    # npm view/pack use registry/pacote fetches, without Arborist buildIdealTree.
    registry = npm("view", "npm@" + VERSION, "dist.integrity", "gitHead", "--json")
    expected = registry.get("dist.integrity") if isinstance(registry, dict) else None
    if expected is None and isinstance(registry, dict) and isinstance(registry.get("dist"), dict):
        expected = registry["dist"].get("integrity")
    for spec, name in (("wrangler@4.125.0", "wrangler"), ("@cloudflare/deploy-helpers@0.8.0", "deploy-helpers")):
        info = npm("view", spec, "version", "dependencies", "peerDependencies", "peerDependenciesMeta", "--json")
        save(evidence / (name + "-published-dependency-metadata.json"), info)
    packed = npm("pack", "npm@" + VERSION, "--pack-destination", str(target), "--json")
    require(isinstance(packed, list) and len(packed) == 1 and packed[0].get("filename") == "npm-" + VERSION + ".tgz" and
            packed[0].get("integrity") == expected, "NPM_PACK_METADATA_MISMATCH")
    tarball = target / packed[0]["filename"]
    raw = tarball.read_bytes()
    require(0 < len(raw) < 32 * 1024 * 1024, "NPM_TARBALL_SIZE_INVALID")
    integrity = integrity_check(raw, expected)
    (evidence / tarball.name).write_bytes(raw)
    safe_extract(tarball, target)
    result = verify_cli(target / "package", evidence)
    node_version = subprocess.check_output(["node", "--version"], text=True).strip()
    major, minor = [int(part) for part in node_version.lstrip("v").split(".")[:2]]
    require(major == 22 and minor >= 9, "RUNNER_NODE_NOT_REVIEWED_COMPATIBLE_22")
    cli = target / "package/bin/npm-cli.js"
    actual = subprocess.check_output(["node", str(cli), "--version"], text=True).strip()
    require(actual == VERSION, "ACTIVE_ISOLATED_NPM_CLI_MISMATCH")
    result.update(status="PASS", node_version=node_version, registry_git_head=registry.get("gitHead"),
                  tarball_integrity=integrity, tarball_sha256=hashlib.sha256(raw).hexdigest(),
                  global_npm_modified=False, peer_validation_bypassed=False, lifecycle_scripts_enabled=False)
    save(evidence / "npm11-bootstrap.json", result)
    print(json.dumps({"status": "NPM11_SOURCE_VERIFIED", "npm_version": VERSION, "arborist_version": ARBORIST}))


if __name__ == "__main__":
    target, evidence = [Path(value).resolve() for value in sys.argv[1:3]]
    try:
        bootstrap(target, evidence)
    except Exception as failure:
        save(evidence / "npm11-bootstrap-failure.json", {"status": "FAIL", "error_type": type(failure).__name__,
            "guard": str(failure) if isinstance(failure, ValueError) and str(failure).isupper() else "UNEXPECTED_BOOTSTRAP_FAILURE"})
        raise SystemExit(1)
