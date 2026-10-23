"""Install one pinned static recording probe; no global OS package changes."""
import base64
import hashlib
import io
import os
from pathlib import Path
import subprocess
import tarfile
import urllib.request

URL='https://registry.npmjs.org/@ffprobe-installer/linux-x64/-/linux-x64-5.2.0.tgz'
SRI='D3UeqTLYPNs7pBWPLUYGehPdRVqU8eACox4OZy3pZUZatxye2YKlvBwEfaLdL1v2Z4FOAlLUhms0kY8m8kqSRA=='
with urllib.request.urlopen(URL,timeout=90) as response:
    data=response.read(60000000)
assert len(data)<60000000 and hashlib.sha512(data).digest()==base64.b64decode(SRI)
out=Path(os.environ['RUNNER_TEMP'])/'bil-video-probe';out.mkdir()
with tarfile.open(fileobj=io.BytesIO(data),mode='r:gz') as archive:
    item=archive.getmember('package/ffprobe')
    assert item.isfile() and 0<item.size<150000000
    content=archive.extractfile(item).read()
assert content[:4]==b'\x7fELF'
probe=out/'ffprobe';probe.write_bytes(content);probe.chmod(0o700)
subprocess.run([str(probe),'-version'],check=True,timeout=15)
with open(os.environ['GITHUB_PATH'],'a') as stream:stream.write(str(out)+'\n')
print('PINNED_STATIC_FFPROBE_SRI_SHA512=PASS')
