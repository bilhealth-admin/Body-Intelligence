import base64
import hashlib
import io
import json
from pathlib import Path
import tarfile
import tempfile
import unittest
from unittest.mock import patch

import bootstrap_site_npm_11 as bootstrap


class BootstrapTest(unittest.TestCase):
    def test_actual_tarball_bytes_must_match_registry_sha512(self):
        raw = b'public-package-fixture'
        digest = 'sha512-' + base64.b64encode(hashlib.sha512(raw).digest()).decode()
        self.assertEqual(bootstrap.integrity_check(raw, digest), digest)
        with self.assertRaisesRegex(ValueError, 'INTEGRITY_MISMATCH'):
            bootstrap.integrity_check(raw + b'changed', digest)

    def test_path_escape_is_rejected_before_extraction(self):
        with tempfile.TemporaryDirectory() as directory:
            target = Path(directory)
            archive = target / 'fixture.tgz'
            with tarfile.open(archive, 'w:gz') as output:
                item = tarfile.TarInfo('../escape')
                item.size = 1
                output.addfile(item, io.BytesIO(b'x'))
            with self.assertRaisesRegex(ValueError, 'UNSAFE_MEMBER'):
                bootstrap.safe_extract(archive, target / 'out')

    def test_matching_cli_version_cannot_hide_wrong_resolver_source(self):
        with tempfile.TemporaryDirectory() as directory:
            package = Path(directory)
            (package / 'package.json').write_text(json.dumps({'name': 'npm', 'version': bootstrap.VERSION, 'engines': {'node': bootstrap.NODE_ENGINE}}))
            arb = package / 'node_modules/@npmcli/arborist'
            (arb / 'lib/arborist').mkdir(parents=True)
            (arb / 'package.json').write_text(json.dumps({'version': bootstrap.ARBORIST}))
            (arb / 'lib/arborist/build-ideal-tree.js').write_text('unreviewed-resolver')
            with self.assertRaisesRegex(ValueError, 'RESOLVER_SOURCE_MISMATCH'):
                bootstrap.verify_cli(package)


if __name__ == '__main__':
    unittest.main()
