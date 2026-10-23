"""Check final app icon resources; does not claim Apple's purchase UI displays them."""
import argparse
import hashlib
import json
from pathlib import Path, PurePosixPath
import plistlib
import struct
import zipfile


def inspect(ipa):
    with zipfile.ZipFile(ipa) as archive:
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise ValueError('Duplicate IPA paths')
        infos = [n for n in names if len(PurePosixPath(n).parts) == 3
                 and n.startswith('Payload/') and n.endswith('.app/Info.plist')]
        if len(infos) != 1:
            raise ValueError('One top-level app is required')
        info = plistlib.loads(archive.read(infos[0]))
        root = infos[0].removesuffix('Info.plist')
        resources = {}
        for family in ('CFBundleIcons', 'CFBundleIcons~ipad'):
            primary = info.get(family, {}).get('CFBundlePrimaryIcon', {})
            if primary.get('CFBundleIconName') != 'AppIcon':
                raise ValueError('Primary AppIcon metadata missing: ' + family)
            files = primary.get('CFBundleIconFiles')
            if not isinstance(files, list) or not files:
                raise ValueError('Primary icon file references missing: ' + family)
            for icon in files:
                if not isinstance(icon, str) or PurePosixPath(icon).name != icon or '\\' in icon:
                    raise ValueError('Unsafe icon file reference')
                stem = icon.removesuffix('.png')
                matching = [n for n in names if n.startswith(root + stem)
                            and PurePosixPath(n).parent == PurePosixPath(root)
                            and n.endswith('.png')]
                if not matching:
                    raise ValueError('Referenced icon PNG missing: ' + icon)
                for name in matching:
                    raw = archive.read(name)
                    if len(raw) < 33 or raw[:8] != b'\x89PNG\r\n\x1a\n':
                        raise ValueError('Invalid icon PNG header')
                    offset = 8
                    # Xcode may add Apple's CgBI chunk before the standard IHDR.
                    if raw[12:16] == b'CgBI':
                        size = struct.unpack('>I', raw[8:12])[0]
                        if size > 16:
                            raise ValueError('Invalid optimized icon header')
                        offset += size + 12
                    if raw[offset + 4:offset + 8] != b'IHDR' or len(raw) < offset + 25:
                        raise ValueError('Icon IHDR is missing')
                    width, height = struct.unpack('>II', raw[offset + 8:offset + 16])
                    if width != height or width < 20:
                        raise ValueError('Invalid icon dimensions')
                    resources[name.removeprefix(root)] = {'width': width, 'height': height,
                        'sha256': hashlib.sha256(raw).hexdigest()}
        catalog = archive.read(root + 'Assets.car')
        if not catalog:
            raise ValueError('Compiled asset catalog empty')
    return {'status': 'FINAL_IPA_ICON_RESOURCES_PRESENT', 'icons': resources,
            'asset_catalog_sha256': hashlib.sha256(catalog).hexdigest(),
            'apple_purchase_sheet_display_verified': False}


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--ipa', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    result = inspect(args.ipa)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(result, indent=2) + '\n', encoding='utf8')
    print(result['status'])


if __name__ == '__main__':
    main()
