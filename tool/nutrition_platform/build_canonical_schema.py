from __future__ import annotations
import argparse
from pathlib import Path
from tool.nutrition_platform.canonical_model import create_canonical_database, schema_sha256

def main() -> int:
    p=argparse.ArgumentParser()
    p.add_argument('--database', required=True)
    args=p.parse_args()
    path=Path(args.database)
    create_canonical_database(path)
    print(f"Canonical schema created: {path}")
    print(f"Schema SHA-256: {schema_sha256()}")
    return 0

if __name__ == '__main__':
    raise SystemExit(main())
