from __future__ import annotations

import argparse
import json
from pathlib import Path

from mobile_catalog_builder import CatalogProfile, build_mobile_catalog

parser = argparse.ArgumentParser()
parser.add_argument("--master", type=Path, required=True)
parser.add_argument("--output", type=Path, required=True)
parser.add_argument("--profile-id", required=True)
parser.add_argument("--market")
parser.add_argument("--language")
parser.add_argument("--minimum-quality", type=float, default=75.0)
parser.add_argument("--max-rows", type=int)
args = parser.parse_args()

result = build_mobile_catalog(
    args.master,
    args.output,
    CatalogProfile(
        profile_id=args.profile_id,
        market_code=args.market,
        language_code=args.language,
        minimum_quality_score=args.minimum_quality,
        max_rows=args.max_rows,
    ),
)
print(json.dumps(result, indent=2, sort_keys=True))
