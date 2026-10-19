"""Read-only audit of explicitly listed Storage images; never saves photo bytes or metadata values."""
import argparse
from concurrent.futures import ThreadPoolExecutor
import io
import json
from pathlib import Path
import re
import shutil
import subprocess
import urllib.error
import urllib.parse
import urllib.request
import warnings


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--run-live', action='store_true', required=True)
    parser.add_argument('--manifest', type=Path, required=True)
    parser.add_argument('--output', type=Path, required=True)
    args = parser.parse_args()
    from PIL import Image
    project = 'tgmanzhqulksykhslrzb'
    listed = json.loads(args.manifest.read_text(encoding='utf-8'))
    assert isinstance(listed, list) and listed
    for row in listed:
        assert row['bucket_id'] in {'profile-avatars', 'community-post-images', 'community-circle-media'}
        assert all(part not in ('', '.', '..') for part in row['name'].split('/'))
        assert 0 < int(row['size']) <= 32 * 1024 * 1024
    result = subprocess.run([shutil.which('npx.cmd') or shutil.which('npx'), '--yes',
        '--cache', 'G:/BIL_Toolchains/npm-cache-bil-release', '--package', 'supabase@2.121.0',
        'supabase', 'projects', 'api-keys', '--project-ref', project, '--reveal', '--output', 'json'],
        capture_output=True, text=True, timeout=120)
    if result.returncode:
        raise RuntimeError('Authenticated read-only management credentials unavailable')
    keys = json.loads(result.stdout)
    service = next(k['api_key'] for k in keys if k.get('name') == 'service_role')
    del keys, result

    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, req, fp, code, msg, headers, newurl):
            return None

    def inspect(row):
        record = {'object_id': row['id'], 'bucket': row['bucket_id']}
        path = urllib.parse.quote(row['name'], safe='/')
        request = urllib.request.Request(f'https://{project}.supabase.co/storage/v1/object/{row["bucket_id"]}/{path}',
            headers={'apikey': service, 'Authorization': f'Bearer {service}', 'User-Agent': 'BIL-image-metadata-audit/1'})
        try:
            with urllib.request.build_opener(NoRedirect).open(request, timeout=45) as response:
                body = response.read(32 * 1024 * 1024 + 1)
            if len(body) != int(row['size']):
                return {**record, 'error': 'object_size_changed_or_incomplete'}
            with warnings.catch_warnings(record=True):
                with Image.open(io.BytesIO(body)) as image:
                    exif = image.getexif()
                    gps = exif.get_ifd(0x8825) if 0x8825 in exif else {}
                    xmp = image.info.get('xmp', image.info.get('XML:com.adobe.xmp', b''))
                    if isinstance(xmp, str):
                        xmp = xmp.encode()
                    return {**record, 'decoded': True, 'bytes': len(body),
                        'gps_metadata_present': bool(gps),
                        'gps_coordinate_tags_present': 2 in gps or 4 in gps,
                        'xmp_gps_tags_present': bool(re.search(rb'GPS(?:Latitude|Longitude|Altitude)', xmp, re.I)),
                        'other_exif_present': bool(exif),
                        'text_metadata_present': bool(getattr(image, 'text', {}))}
        except urllib.error.HTTPError as error:
            return {**record, 'error': f'http_{error.code}'}
        except Exception as error:
            return {**record, 'error': type(error).__name__}

    with ThreadPoolExecutor(max_workers=4) as pool:
        records = list(pool.map(inspect, listed))
    errors = sum('error' in r for r in records)
    gps = sum(bool(r.get('gps_metadata_present') or r.get('xmp_gps_tags_present')) for r in records)
    proof = {'read_only': True, 'photo_bytes_saved': False, 'metadata_values_saved': False,
        'objects': len(records), 'errors': errors, 'gps_metadata_objects': gps,
        'status': 'PASS_NO_GPS_METADATA_OBSERVED' if not errors and not gps else 'NEEDS_REVIEW',
        'scope': 'Listed stored images and recognized EXIF/XMP GPS metadata; not all policy certification',
        'records': records}
    args.output.write_text(json.dumps(proof, indent=2), encoding='utf-8')
    print(json.dumps({k: v for k, v in proof.items() if k != 'records'}))
    return 2 if errors or gps else 0


if __name__ == '__main__':
    raise SystemExit(main())
