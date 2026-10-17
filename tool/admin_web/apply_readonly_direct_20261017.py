#!/usr/bin/env python3
"""BIL: read-only admin transport, direct Supabase Edge. No financial mutations."""
from pathlib import Path
import shutil

main, checks = Path('web/main.js'), Path('web/headers.test.mjs')
if not main.is_file() or not checks.is_file():
    raise SystemExit('STOP: not in BIL Secure Admin project root')
a, b = main.read_text(), checks.read_text()
old = "new URL('/api/admin-readonly',window.location.href).toString()"
new = "API_HOST + '/functions/v1/bil-admin-web-v1'"
start = "test('V7 frontend directs admin API over same-origin read-only proxy',async()=>{"
new_test = '''test('V7 frontend reads from authenticated Supabase Edge directly',async()=>{
  const file=await (await import('node:fs/promises')).readFile(new URL('./main.js', import.meta.url),'utf8');
  assert.ok(file.includes("API_HOST + '/functions/v1/bil-admin-web-v1'"));
  assert.ok(!file.includes("new URL('/api/admin-readonly',window.location.href).toString()"));
});'''
if new in a and new_test in b:
    print('Already installed; no files changed.')
    raise SystemExit(0)
if a.count(old) != 1 or b.count(start) != 1:
    raise SystemExit('STOP: unexpected BIL version; nothing changed')
pos = b.index(start)
end = b.find('\n});', pos)
if end == -1:
    raise SystemExit('STOP: test block not found; nothing changed')
updated = b[:pos] + new_test + b[end+4:]
for f in (main, checks):
    bak = f.with_name(f.name+'.before-direct-20261017')
    if not bak.exists():
        shutil.copy2(f, bak)
try:
    main.write_text(a.replace(old, new))
    checks.write_text(updated)
except BaseException:
    main.write_text(a)
    checks.write_text(b)
    raise
print('Read-only direct Supabase connection installed; grant/revoke remain locked.')
