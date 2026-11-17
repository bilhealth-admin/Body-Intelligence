"""External candidate. Reviewed application/CI integration is required.

Copy the exact locked StoreKit plugin to the existing .dart_tool overlay area.
Never modify PUB_CACHE, change dependencies, or read credentials. The only
runtime delta makes an existing unverified-restore error codec-safe.
"""
from __future__ import annotations

import argparse
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import stat
from urllib.parse import urljoin, urlsplit
from urllib.request import url2pathname

PLUGIN = 'in_app_purchase_storekit'
VERSION = '0.4.13+1'
RECIPE = 'bil-storekit-unverified-restore-codec-count-v1'
RELATIVE_SWIFT = Path('darwin/in_app_purchase_storekit/Sources/in_app_purchase_storekit/StoreKit2/InAppPurchasePlugin+StoreKit2.swift')
BEFORE_SHA = 'ee03daa8c3006114b2dc38d6c50b5730bfd89b6c849e419e26d90f2d1fc56304'
AFTER_SHA = 'be93cbd553c31c89d2aef0bfc021180da4bc70c43809fbf7c0e76e156b142bf2'
LOCK_ARCHIVE_SHA = '8e4c0523b5bbac99e87a2d4cd9ece58958166e3ef5fa5b2ed96b2de936d89c71'
OLD_BLOCK = '          completion(\n            .failure(\n              PigeonError(\n                code: "storekit2_restore_failed",\n                message:\n                  "This purchase could not be restored.",\n                details: unverifiedPurchases)))'
NEW_BLOCK = '          completion(\n            .failure(Self.bilUnverifiedRestoreFailure(\n              unverifiedCount: unverifiedPurchases.count)))'
FACTORY = '  // A Pigeon error must contain only standard-codec values. Do not expose\n  // receipt/JWS data, transaction identifiers, or native Error objects here.\n  static func bilUnverifiedRestoreFailure(unverifiedCount: Int) -> PigeonError {\n    PigeonError(\n      code: "storekit2_restore_failed",\n      message: "This purchase could not be restored.",\n      details: ["unverifiedPurchaseCount": unverifiedCount])\n  }\n\n'
ANCHOR = '  func restorePurchases(completion: @escaping (Result<Void, Error>) -> Void) {'


def sha(value: bytes) -> str:
    return hashlib.sha256(value).hexdigest()


def no_link(path: Path) -> None:
    for item in (path, *path.parents):
        if not item.exists():
            continue
        info = item.lstat()
        if stat.S_ISLNK(info.st_mode) or getattr(info, 'st_file_attributes', 0) & 0x400:
            raise ValueError('symlink_or_reparse_point')


def files(root: Path) -> dict[str, str]:
    no_link(root)
    result = {}
    for item in sorted(root.rglob('*')):
        no_link(item)
        if item.is_file():
            result[item.relative_to(root).as_posix()] = sha(item.read_bytes())
        elif not item.is_dir():
            raise ValueError('non_regular_package_entry')
    return result


def one_entry(config: dict) -> dict:
    rows = [x for x in config.get('packages', []) if x.get('name') == PLUGIN]
    if len(rows) != 1:
        raise ValueError('exact_package_entry_required')
    return rows[0]


def local_uri_root(config_path: Path, root_uri: str) -> Path:
    parsed = urlsplit(urljoin(config_path.as_uri(), root_uri))
    if parsed.scheme != 'file' or parsed.netloc or parsed.query or parsed.fragment:
        raise ValueError('local_file_package_uri_required')
    raw_path = Path(url2pathname(parsed.path))
    no_link(raw_path)
    return raw_path.resolve(strict=True)


def atomic_json(path: Path, payload: dict) -> None:
    temp = path.with_name(path.name + '.bil-storekit-codec-new')
    if temp.exists():
        raise ValueError('stale_atomic_temp')
    created = False
    try:
        with temp.open('x', encoding='utf-8', newline='\n') as stream:
            created = True
            stream.write(json.dumps(payload, separators=(',', ':')) + '\n')
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temp, path)
    finally:
        if created and temp.exists():
            temp.unlink()


def plugin_rows(graph: dict) -> list[dict]:
    plugins = graph.get('plugins')
    if not isinstance(plugins, dict):
        raise ValueError('plugin_graph_required')
    selected = []
    for platform in ('ios', 'macos'):
        rows = plugins.get(platform, [])
        if not isinstance(rows, list) or not all(isinstance(row, dict) for row in rows):
            raise ValueError('invalid_plugin_graph_rows')
        matching = [row for row in rows if row.get('name') == PLUGIN]
        if platform == 'ios' and len(matching) != 1:
            raise ValueError('exact_ios_plugin_graph_entry_required')
        if platform == 'macos' and len(matching) > 1:
            raise ValueError('duplicate_macos_plugin_graph_entry')
        selected.extend(matching)
    return selected


def graph_root(row: dict) -> Path:
    value = row.get('path')
    if not isinstance(value, str) or not value:
        raise ValueError('local_plugin_graph_path_required')
    raw = Path(value)
    if not raw.is_absolute():
        raise ValueError('absolute_plugin_graph_path_required')
    no_link(raw)
    return raw.resolve(strict=True)


def cache_patch(source: Path, project: Path, destination: Path) -> tuple[bytes, dict[str, str]]:
    no_link(source)
    if source == project or project in source.parents or source in destination.resolve().parents:
        raise ValueError('source_destination_overlap')
    original_files = files(source)
    if '.bil-storekit-restore-codec.json' in original_files:
        raise ValueError('cache_must_not_be_an_overlay')
    before = (source / RELATIVE_SWIFT).read_bytes()
    if sha(before) != BEFORE_SHA:
        raise ValueError('unexpected_storekit_swift_preimage')
    text = before.decode('utf-8')
    if text.count(OLD_BLOCK) != 1 or text.count(ANCHOR) != 1:
        raise ValueError('non_unique_restore_patch_anchors')
    after = text.replace(OLD_BLOCK, NEW_BLOCK).replace(ANCHOR, FACTORY + ANCHOR).encode('utf-8')
    if sha(after) != AFTER_SHA:
        raise ValueError('unexpected_storekit_swift_postimage')
    expected_files = dict(original_files)
    expected_files[RELATIVE_SWIFT.as_posix()] = AFTER_SHA
    return after, expected_files


def prepare(project_root: Path) -> dict:
    no_link(project_root)
    project = project_root.resolve(strict=True)
    dart = project / '.dart_tool'
    no_link(dart)
    if not dart.is_dir():
        raise ValueError('pub_get_required')
    config_path = dart / 'package_config.json'
    graph_path = project / '.flutter-plugins-dependencies'
    for path in (config_path, graph_path, project / 'pubspec.lock'):
        no_link(path)
        if not path.is_file():
            raise ValueError('required_build_metadata_missing')
    # Reject either ambiguous atomic-temp name before copying an overlay or
    # rebinding either metadata file. Never delete an unknown existing temp.
    for path in (config_path, graph_path):
        temp = path.with_name(path.name + '.bil-storekit-codec-new')
        no_link(temp)
        if temp.exists() or temp.is_symlink():
            raise ValueError('stale_atomic_temp')
    lock = (project / 'pubspec.lock').read_text(encoding='utf-8')
    matches = list(re.finditer(r'(?m)^  in_app_purchase_storekit:\n(?P<body>(?:    .*\n)+)', lock))
    if len(matches) != 1:
        raise ValueError('exact_locked_package_required')
    block = matches[0]['body']
    versions = re.findall(r'(?m)^    version: "([^"\n]+)"[ \t]*(?:#.*)?$', block)
    checksums = re.findall(r'(?m)^      sha256: "([a-f0-9]{64})"[ \t]*(?:#.*)?$', block)
    if versions != [VERSION] or checksums != [LOCK_ARCHIVE_SHA]:
        raise ValueError('exact_locked_package_required')
    config_bytes, graph_bytes = config_path.read_bytes(), graph_path.read_bytes()
    config, graph = json.loads(config_bytes), json.loads(graph_bytes)
    entry = one_entry(config)
    discovered_root = local_uri_root(config_path, entry['rootUri'])
    selected_rows = plugin_rows(graph)  # Required for every path, including reuse.
    row_roots = [graph_root(row) for row in selected_rows]
    parent = dart / 'bil_release_plugin_overrides'
    no_link(parent)
    destination = parent / PLUGIN
    no_link(destination)
    canonical_destination = destination.resolve()
    if project not in canonical_destination.parents:
        raise ValueError('overlay_must_stay_within_project')
    marker_path = destination / '.bil-storekit-restore-codec.json'
    exists = destination.exists()
    if exists and not destination.is_dir():
        raise ValueError('existing_overlay_not_directory')
    if discovered_root == canonical_destination:
        if not exists or not marker_path.is_file():
            raise ValueError('existing_overlay_origin_missing')
        no_link(marker_path)
        marker = json.loads(marker_path.read_text(encoding='utf-8'))
        origin_uri = marker.get('source_root_uri')
        if not isinstance(origin_uri, str):
            raise ValueError('existing_overlay_origin_missing')
        source = local_uri_root(config_path, origin_uri)
    else:
        source = discovered_root
    after, expected_files = cache_patch(source, project, destination)
    expected_marker = {
        'recipe': RECIPE, 'version': VERSION,
        'source_root_uri': source.as_uri(),
        'source_swift_sha256': BEFORE_SHA, 'swift_sha256': AFTER_SHA,
        'files': expected_files,
    }
    # Both exact roots are known and verified. This also recovers a partial
    # metadata rebind without accepting a foreign plugin path or cache alias.
    if any(root not in (source, canonical_destination) for root in row_roots):
        raise ValueError('package_config_plugin_graph_mismatch')
    if exists:
        if not marker_path.is_file():
            raise ValueError('refuse_existing_overlay_destination')
        no_link(marker_path)
        actual_marker = json.loads(marker_path.read_text(encoding='utf-8'))
        actual_files = files(destination)
        actual_files.pop(marker_path.name, None)
        if actual_marker != expected_marker or actual_files != expected_files:
            raise ValueError('existing_overlay_drift')
        if discovered_root == canonical_destination and all(root == canonical_destination for root in row_roots):
            return {'status': 'already-prepared', 'recipe': RECIPE, 'swift_sha256': AFTER_SHA}
        status = 'rebound'
    else:
        # All source/graph/lock checks complete before the first write. The
        # operation never removes or replaces an existing package directory.
        parent.mkdir(exist_ok=True)
        shutil.copytree(source, destination)
        (destination / RELATIVE_SWIFT).write_bytes(after)
        if files(destination) != expected_files:
            raise ValueError('non_codec_package_delta')
        marker_path.write_text(json.dumps(expected_marker, sort_keys=True) + '\n', encoding='utf-8')
        status = 'prepared'
    entry['rootUri'] = 'bil_release_plugin_overrides/in_app_purchase_storekit/'
    for row in selected_rows:
        row['path'] = str(destination) + os.sep
    if config_path.read_bytes() != config_bytes or graph_path.read_bytes() != graph_bytes:
        raise ValueError('build_metadata_changed_during_prepare')
    atomic_json(config_path, config)
    atomic_json(graph_path, graph)
    return {
        'status': status, 'recipe': RECIPE,
        'source_swift_sha256': BEFORE_SHA, 'swift_sha256': AFTER_SHA,
        'other_package_files_unchanged': True,
    }


if __name__ == '__main__':
    parser = argparse.ArgumentParser()
    parser.add_argument('--project-root', type=Path, required=True)
    args = parser.parse_args()
    print(json.dumps(prepare(args.project_root), sort_keys=True))
