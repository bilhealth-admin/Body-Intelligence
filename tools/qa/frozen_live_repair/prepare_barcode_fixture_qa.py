"""QA-only adapter for frozen barcode fixture. Never changes a tracked file."""
from __future__ import annotations
import argparse
import hashlib
import json
import pathlib
import subprocess

FROZEN = '31554b3e078667a38bd3c53aa105f5f1d2a4dc96'
SOURCE = 'tool/nutrition/run_live_barcode_resolved_fixture_e2e.ps1'
BLOB = 'b98bfb00f889ab5f8c1a11ddd594286a7b62b037'
DB = r'''function Db([string]$sql) {
  . "$PSScriptRoot/../release/supabase_query_result.ps1"
  $old=$ErrorActionPreference
  $ErrorActionPreference='Continue'
  try {
    $raw=($sql | & npx --yes supabase@2.121.0 db query --linked --project-ref $ProjectRef --output json 2>$null)-join [Environment]::NewLine
    $exit=$LASTEXITCODE
  } finally {
    $ErrorActionPreference=$old
  }
  if($exit -ne 0) { throw "db query failed (exit $exit; explicit project ref)" }
  $parsed=ConvertFrom-BilSupabaseQueryJson -Json $raw
  foreach($row in $parsed.rows) { $row }
}

'''
CACHE = r'''function Get-CacheRows([string]$key) {
  if($key -cnotmatch '^[0-9]{13}$') { throw 'Invalid controlled GTIN' }
  # Fixture setup/cleanup uses the already-authorized management transport.
  # The product still calls the original RPC and HTTP barcode-lookup endpoint.
  return (Db "select gtin,payload from public.bil_barcode_shared_cache where gtin='$key'")
}

function RemoveOwnedCacheEntry([string]$key) {
  $rows=@(Get-CacheRows $key)
  if($rows.Count -eq 0) { return $true }
  if($rows.Count -ne 1) { return $false }
  $row=$rows[0]
  if($row.gtin -ne $key) { return $false }
  if($row.payload.brand -ne $fixtureBrand -or $row.payload.name -ne $fixtureName) {
    return $true
  }
  $brandSql=$fixtureBrand.Replace("'", "''")
  $nameSql=$fixtureName.Replace("'", "''")
  # Recheck exact synthetic identity atomically; never delete a real product.
  $deletedRows=@(Db "delete from public.bil_barcode_shared_cache where gtin='$key' and payload->>'brand'='$brandSql' and payload->>'name'='$nameSql' returning gtin,payload")
  if($deletedRows.Count -ne 1) { return $false }
  if($deletedRows[0].gtin -ne $key -or
     $deletedRows[0].payload.brand -ne $fixtureBrand -or
     $deletedRows[0].payload.name -ne $fixtureName) { return $false }
  $remaining=@(Get-CacheRows $key)
  return ($remaining.Count -eq 0)
}

'''

def replace_functions(text: str) -> str:
    markers = ('function Db(', 'function New-TestGtin13',
               'function Get-CacheRows(', 'function New-FixtureHeaders')
    if any(text.count(marker) != 1 for marker in markers):
        raise ValueError('Original function boundaries changed; no patch applied')
    text = text[:text.index(markers[0])] + DB + text[text.index(markers[1]):]
    text = text[:text.index(markers[2])] + CACHE + text[text.index(markers[3]):]
    text = text.replace('supabase@latest', 'supabase@2.121.0')
    if '/rest/v1/bil_barcode_shared_cache' in text:
        raise ValueError('Forbidden direct table REST access remains')
    for retained in ('/rest/v1/rpc/bil_put_cached_barcode', '/functions/v1/barcode-lookup',
                     '$fixtureAttempted=$true', 'cleanup_fixture', 'cleanup_user',
                     'Synthetic GTIN collision; refusing to overwrite an existing barcode'):
        if retained not in text:
            raise ValueError('Original live probe or safety guard missing: ' + retained)
    return text

def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--source-root', type=pathlib.Path, required=True)
    parser.add_argument('--evidence', type=pathlib.Path, required=True)
    args = parser.parse_args()
    root = args.source_root.resolve()
    def git(*a: str) -> str:
        return subprocess.check_output(['git', '-C', str(root), *a], text=True).strip()
    if git('rev-parse','HEAD') != FROZEN or git('hash-object', SOURCE) != BLOB:
        raise SystemExit('Original frozen source identity mismatch')
    if git('status','--porcelain=v1','--untracked-files=no'):
        raise SystemExit('Tracked source is not pristine')
    source = (root / SOURCE).read_text(encoding='utf-8-sig')
    patched = replace_functions(source)
    target = root / 'tool/nutrition/.ci-barcode-fixture-qa-20261022.ps1'
    if target.exists():
        raise SystemExit('Refuse to overwrite an existing QA adapter')
    target.write_text(patched, encoding='utf-8')
    args.evidence.mkdir(parents=True, exist_ok=True)
    (args.evidence / 'fixture-functions.ps1').write_text(CACHE, encoding='utf-8')
    (args.evidence / 'adapter.json').write_text(json.dumps({
        'source_sha': FROZEN, 'original_path': SOURCE, 'original_blob': BLOB,
        'adapter_sha256': hashlib.sha256(patched.encode()).hexdigest(),
        'scope': 'QA fixture management transport and strict CLI JSON parsing only',
        'production_code_modified': False, 'permissions_modified': False,
        'release_certification': False,
    }, indent=2) + '\n', encoding='utf-8')
    if git('hash-object', SOURCE) != BLOB or git('diff','--name-only','HEAD'):
        raise SystemExit('Original tracked files changed')
    print(str(target))

if __name__ == '__main__':
    main()
