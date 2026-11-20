"""Project the signed recipe formulation identities for dietary filtering before opening a shard."""
import hashlib
import json
import math
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
CATALOG = ROOT / "assets/catalogs/recipes/v1"


def checked_file(path, digest, size):
    data = path.read_bytes()
    if len(data) != size or hashlib.sha256(data).hexdigest() != digest:
        raise ValueError(f"Release digest mismatch for {path.name}")
    return json.loads(data)


def main():
    manifest = json.loads((CATALOG / "release-manifest.json").read_bytes())
    index = checked_file(ROOT / manifest["index_path"], manifest["index_sha256"], manifest["index_size_bytes"])
    terms = {}
    rows = []
    for shard in manifest["shards"]:
        records = checked_file(ROOT / shard["path"], shard["sha256"], shard["size_bytes"])["records"]
        for record in records:
            entry = index["entries"][len(rows)]
            if (entry["canonical_id"], entry["content_fingerprint"]) != (record["canonicalId"], record["contentFingerprint"]):
                raise ValueError("Recipe order or identity mismatch")
            bindings = []
            for item in record["ingredients"]:
                identity = (item.get("recordId"), item.get("itemId"), item.get("sourceDescription"))
                grams = item.get("grams")
                if (not all(isinstance(value, str) and value for value in identity)
                        or identity[0] not in (item.get("sourceRefs") or [])
                        or not isinstance(grams, (int, float)) or not math.isfinite(grams) or grams <= 0):
                    bindings.append(None)
                    continue
                bindings.append(terms.setdefault(identity, len(terms)))
            rows.append(bindings)
    if len(rows) != len(index["entries"]):
        raise ValueError("Recipe index count mismatch")
    result = {"canonical": manifest["canonical_sha256"], "index": manifest["index_sha256"],
              "terms": list(terms), "rows": rows}
    data = (json.dumps(result, ensure_ascii=False, separators=(",", ":")) + "\n").encode()
    output = CATALOG / "recipe-dietary-index.json"
    if not output.exists() or output.read_bytes() != data:
        output.write_bytes(data)
    print(len(rows), len(terms), len(data), hashlib.sha256(data).hexdigest())


if __name__ == "__main__":
    main()
