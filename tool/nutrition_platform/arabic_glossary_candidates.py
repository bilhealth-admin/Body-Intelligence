from __future__ import annotations

import argparse
import csv
import sqlite3
from contextlib import closing
from pathlib import Path

try:
    from .arabic_catalog_enricher import normalize, read_glossary
except ImportError:  # Direct execution from the repository root.
    from arabic_catalog_enricher import normalize, read_glossary


COMPOSITE_PENALTIES = {
    "babyfood",
    "chips",
    "flour",
    "juice",
    "lunchmeat",
    "melon",
    "pepper",
    "pie",
    "powder",
    "pudding",
    "snacks",
    "soup",
    "spread",
    "yogurt",
}


def _token_matches(query: str, candidate: str) -> bool:
    return query == candidate or (
        len(query) >= 4
        and len(candidate) >= 4
        and (candidate.startswith(query) or query.startswith(candidate))
    )


def _relevance_score(query: str, candidate: str) -> int:
    query_tokens = normalize(query).split()
    candidate_tokens = normalize(candidate).split()
    if not query_tokens or not all(
        any(_token_matches(token, value) for value in candidate_tokens)
        for token in query_tokens
    ):
        return -10_000
    score = 100
    if normalize(query) == normalize(candidate):
        score += 100
    score -= 30 * len(COMPOSITE_PENALTIES.intersection(candidate_tokens))
    score -= max(0, len(candidate_tokens) - len(query_tokens))
    if "raw" in candidate_tokens:
        score += 8
    return score


def export_candidates(master: Path, glossary: Path, output: Path, limit: int) -> int:
    entries = read_glossary(glossary)
    output.parent.mkdir(parents=True, exist_ok=True)
    written = 0
    with closing(sqlite3.connect(master)) as connection, output.open(
        "w", encoding="utf-8-sig", newline=""
    ) as handle:
        writer = csv.writer(handle)
        writer.writerow(
            [
                "requested_english_name",
                "requested_arabic_name",
                "candidate_bil_food_id",
                "candidate_english_name",
                "candidate_kind",
                "relevance_score",
                "ranking_score",
                "source_systems",
                "nutrient_count",
            ]
        )
        foods = connection.execute(
            "SELECT bil_food_id,canonical_name_en,food_kind FROM canonical_food "
            "WHERE status='active' AND canonical_name_en IS NOT NULL"
        ).fetchall()
        source_systems_by_food: dict[str, str] = {}
        for food_id, source_systems in connection.execute(
            "SELECT bil_food_id, GROUP_CONCAT(DISTINCT source_system) "
            "FROM source_record WHERE record_status='active' "
            "AND bil_food_id IS NOT NULL GROUP BY bil_food_id"
        ):
            source_systems_by_food[str(food_id)] = str(source_systems or "")
        nutrient_count_by_food = {
            str(food_id): int(nutrient_count)
            for food_id, nutrient_count in connection.execute(
                "SELECT bil_food_id, COUNT(DISTINCT bil_nutrient_id) "
                "FROM nutrient_evidence GROUP BY bil_food_id"
            )
        }
        for entry in entries:
            if entry.bil_food_id:
                continue
            candidates = []
            for food_id, english_name, kind in foods:
                score = _relevance_score(entry.english_name, str(english_name))
                if score > -10_000:
                    source_systems = source_systems_by_food.get(str(food_id), "")
                    nutrient_count = nutrient_count_by_food.get(str(food_id), 0)
                    if nutrient_count:
                        ranking_score = score + min(int(nutrient_count), 30)
                        candidates.append(
                            (
                                food_id,
                                english_name,
                                kind,
                                score,
                                ranking_score,
                                source_systems,
                                nutrient_count,
                            )
                        )
            candidates.sort(
                key=lambda row: (-row[4], -row[3], len(str(row[1])), str(row[1]))
            )
            for (
                food_id,
                english_name,
                kind,
                score,
                ranking_score,
                source_systems,
                nutrient_count,
            ) in candidates[:limit]:
                writer.writerow(
                    [
                        entry.english_name,
                        entry.arabic_name,
                        food_id,
                        english_name,
                        kind,
                        score,
                        ranking_score,
                        source_systems,
                        nutrient_count,
                    ]
                )
                written += 1
    return written


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--master", type=Path, required=True)
    parser.add_argument("--glossary", type=Path, required=True)
    parser.add_argument("--output", type=Path, required=True)
    parser.add_argument("--limit", type=int, default=12)
    args = parser.parse_args()
    if args.limit <= 0:
        raise ValueError("limit must be positive")
    print(
        {
            "candidates_written": export_candidates(
                args.master, args.glossary, args.output, args.limit
            )
        }
    )


if __name__ == "__main__":
    main()
