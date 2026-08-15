from __future__ import annotations

import argparse
import csv
import re
import shutil
import sqlite3
import unicodedata
from contextlib import closing
from dataclasses import dataclass
from pathlib import Path


ARABIC_DIACRITICS = re.compile(r"[\u0610-\u061a\u064b-\u065f\u0670\u06d6-\u06ed]")


def normalize(value: str) -> str:
    value = unicodedata.normalize("NFKC", value).strip().lower()
    value = ARABIC_DIACRITICS.sub("", value)
    value = value.replace("\u0640", "")
    return " ".join(re.sub(r"[^\w\u0600-\u06ff]+", " ", value).split())


@dataclass(frozen=True)
class ArabicFoodName:
    bil_food_id: str
    english_name: str
    arabic_name: str
    aliases: tuple[str, ...]
    confidence: float


def read_glossary(path: Path) -> list[ArabicFoodName]:
    entries: list[ArabicFoodName] = []
    with path.open("r", encoding="utf-8-sig", newline="") as handle:
        for line_number, row in enumerate(csv.DictReader(handle), start=2):
            arabic_name = (row.get("arabic_name") or "").strip()
            if not arabic_name:
                raise ValueError(f"line {line_number}: arabic_name is required")
            confidence = float(row.get("confidence") or 1)
            if not 0 <= confidence <= 1:
                raise ValueError(f"line {line_number}: confidence must be 0..1")
            entries.append(
                ArabicFoodName(
                    bil_food_id=(row.get("bil_food_id") or "").strip(),
                    english_name=(row.get("english_name") or "").strip(),
                    arabic_name=arabic_name,
                    aliases=tuple(
                        alias.strip()
                        for alias in (row.get("aliases") or "").split("|")
                        if alias.strip()
                    ),
                    confidence=confidence,
                )
            )
    return entries


def _resolve_food_id(connection: sqlite3.Connection, entry: ArabicFoodName) -> str:
    if entry.bil_food_id:
        row = connection.execute(
            "SELECT bil_food_id FROM canonical_food WHERE bil_food_id=?",
            (entry.bil_food_id,),
        ).fetchone()
        if row is None:
            raise ValueError(f"unknown bil_food_id: {entry.bil_food_id}")
        return str(row[0])
    if not entry.english_name:
        raise ValueError("each glossary row needs bil_food_id or english_name")
    target = normalize(entry.english_name)
    matches = [
        str(row[0])
        for row in connection.execute(
            "SELECT bil_food_id, canonical_name_en FROM canonical_food "
            "WHERE canonical_name_en IS NOT NULL"
        )
        if normalize(str(row[1])) == target
    ]
    if len(matches) != 1:
        raise ValueError(
            f"english_name must resolve uniquely: {entry.english_name!r} "
            f"matched {len(matches)} rows"
        )
    return matches[0]


def enrich(source: Path, output: Path, glossary: Path) -> dict[str, int]:
    if source.resolve() == output.resolve():
        raise ValueError("output must be a copy, never the source master")
    output.parent.mkdir(parents=True, exist_ok=True)
    shutil.copy2(source, output)
    entries = read_glossary(glossary)
    names_written = 0
    aliases_written = 0
    with closing(sqlite3.connect(output)) as connection:
        connection.execute("PRAGMA foreign_keys=ON")
        with connection:
            for entry in entries:
                food_id = _resolve_food_id(connection, entry)
                connection.execute(
                    "UPDATE canonical_food SET canonical_name_ar=? WHERE bil_food_id=?",
                    (entry.arabic_name, food_id),
                )
                names = ((entry.arabic_name, "canonical"),) + tuple(
                    (alias, "alias") for alias in entry.aliases
                )
                for name, name_type in names:
                    normalized = normalize(name)
                    exists = connection.execute(
                        "SELECT 1 FROM food_name WHERE bil_food_id=? AND language='ar' "
                        "AND normalized_name=? AND name_type=? LIMIT 1",
                        (food_id, normalized, name_type),
                    ).fetchone()
                    if exists is None:
                        connection.execute(
                            "INSERT INTO food_name(bil_food_id,language,name,normalized_name,"
                            "name_type,source_record_id,confidence) "
                            "VALUES(?,?,?,?,?,NULL,?)",
                            (food_id, "ar", name, normalized, name_type, entry.confidence),
                        )
                        aliases_written += 1
                names_written += 1
    return {"foods_localized": names_written, "arabic_names_written": aliases_written}


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--glossary", type=Path, required=True)
    args = parser.parse_args()
    print(enrich(args.source, args.output, args.glossary))


if __name__ == "__main__":
    main()
