import argparse
import json
import math
import statistics
import re
from pathlib import Path


def norm(value):
    return " ".join(str(value).strip().casefold().replace("-", " ").split())


_MATCH_STOPWORDS = {
    "a", "an", "and", "with", "of", "the",
    "baked", "braised", "cooked", "fried", "grilled", "pan", "roasted",
    "seasoned", "steamed", "stewed", "toasted",
}

_IDENTITY_CRITICAL = {
    "beef", "chicken", "cod", "egg", "fish", "lamb", "pork", "salmon",
    "shrimp", "tofu", "tuna", "turkey", "quinoa",
}

_GENERIC_SINGLETONS = {
    "bowl", "casserole", "curry", "dish", "food", "meal", "plate",
    "salad", "soup", "stew",
}


def food_tokens(value):
    """Return conservative, order-insensitive food identity tokens.

    Preparation words are deliberately ignored, while ingredients remain. This
    lets provider-neutral labels such as ``vegetable lentil stew`` and
    ``lentil and vegetable stew`` match without accepting a generic ``stew``.
    """
    words = re.findall(r"[\w]+", norm(value), flags=re.UNICODE)
    tokens = []
    for word in words:
        if word in _MATCH_STOPWORDS:
            continue
        if len(word) > 4 and word.endswith("ies"):
            word = word[:-3] + "y"
        elif len(word) > 4 and word.endswith("s") and not word.endswith("ss"):
            word = word[:-1]
        tokens.append(word)
    return set(tokens)


def identity_match(left, right):
    if norm(left) == norm(right):
        return True
    a, b = food_tokens(left), food_tokens(right)
    if not a or not b:
        return False
    # Never erase a named protein or identity-defining grain merely because the
    # rest of a generic bowl/stew label overlaps.
    if (a & _IDENTITY_CRITICAL) != (b & _IDENTITY_CRITICAL):
        return False
    overlap = len(a & b)
    if min(len(a), len(b)) == 1:
        singleton = next(iter(a if len(a) == 1 else b))
        return singleton not in _GENERIC_SINGLETONS and singleton in (a & b)
    # Require two meaningful shared tokens and strong containment. This handles
    # harmless label detail ("shrimp bowl" vs "shrimp rice bowl") but rejects
    # ingredient-changing matches ("tabbouleh" vs "quinoa tabbouleh").
    return overlap >= 2 and overlap / min(len(a), len(b)) >= 0.8 and overlap / max(len(a), len(b)) >= 0.6


def percentile(values, p):
    if not values:
        return None
    ordered = sorted(values)
    index = (len(ordered) - 1) * p
    low, high = math.floor(index), math.ceil(index)
    if low == high:
        return ordered[low]
    return ordered[low] + (ordered[high] - ordered[low]) * (index - low)


def score_case(case, run):
    truth = case["truth"]
    predictions = run.get("components", [])
    remaining = set(range(len(predictions)))
    matches = []
    for item in truth:
        aliases = [item["id"], *item.get("aliases", [])]
        matched = next((i for i in remaining if any(
            identity_match(name, alias)
            for name in [predictions[i].get("name", ""), *predictions[i].get("aliases", [])]
            for alias in aliases
        )), None)
        if matched is not None:
            remaining.remove(matched)
            matches.append((item, predictions[matched]))
    tp, fn, fp = len(matches), len(truth) - len(matches), len(remaining)
    recall = 1.0 if not truth else tp / len(truth)
    precision = 1.0 if not predictions else tp / len(predictions)
    f1 = 0.0 if precision + recall == 0 else 2 * precision * recall / (precision + recall)
    amount_errors = []
    for expected, predicted in matches:
        actual = predicted.get("amount_g")
        target = expected.get("amount_g")
        if isinstance(actual, (int, float)) and target:
            amount_errors.append(abs(actual - target) / target)
    row = {
        "case_id": case["id"], "category": case["category"],
        "exact_case_accuracy": 1.0 if fn == 0 and fp == 0 else 0.0,
        "component_precision": precision, "component_recall": recall,
        "component_f1": f1, "hallucination_count": fp,
        "hallucination_rate": 0.0 if not predictions else fp / len(predictions),
        "amount_mape": statistics.mean(amount_errors) if amount_errors else None,
        "latency_ms": run.get("latency_ms"), "cost_usd": run.get("cost_usd", 0.0),
        "input_tokens": run.get("input_tokens"),
        "output_tokens": run.get("output_tokens"),
    }
    for prefix, truth_key, run_key in (
        ("identity", "dish_identity_truth", "dish_identities"),
        ("visible", "visible_component_truth", "visible_components"),
    ):
        if truth_key in case:
            nested = score_case(
                {"id": case["id"], "category": case["category"], "truth": case[truth_key]},
                {"components": run.get(run_key, [])},
            )
            for metric in ("component_precision", "component_recall", "component_f1", "hallucination_rate"):
                row[f"{prefix}_{metric}"] = nested[metric]
    return row


def main():
    parser = argparse.ArgumentParser(description="Offline provider-neutral meal vision benchmark")
    parser.add_argument("--manifest", required=True)
    parser.add_argument("--predictions", required=True)
    parser.add_argument("--output")
    args = parser.parse_args()
    manifest = json.loads(Path(args.manifest).read_text(encoding="utf-8"))
    predictions = json.loads(Path(args.predictions).read_text(encoding="utf-8"))
    if manifest.get("schema_version") != 1 or predictions.get("schema_version") != 1:
        raise SystemExit("Unsupported schema_version")
    runs = {run["case_id"]: run for run in predictions["runs"]}
    missing = [case["id"] for case in manifest["cases"] if case["id"] not in runs]
    unknown = sorted(set(runs) - {case["id"] for case in manifest["cases"]})
    if missing or unknown:
        raise SystemExit(f"Case mismatch: missing={missing}, unknown={unknown}")
    cases = [score_case(case, runs[case["id"]]) for case in manifest["cases"]]
    def avg(key):
        values = [row[key] for row in cases if row[key] is not None]
        return statistics.mean(values) if values else None
    latencies = [row["latency_ms"] for row in cases if isinstance(row["latency_ms"], (int, float))]
    input_tokens = [row["input_tokens"] for row in cases if isinstance(row["input_tokens"], int)]
    output_tokens = [row["output_tokens"] for row in cases if isinstance(row["output_tokens"], int)]
    report = {
        "schema_version": 1, "suite_id": manifest["suite_id"],
        "provider": predictions.get("provider"), "model_revision": predictions.get("model_revision"),
        "summary": {
            "case_count": len(cases), "exact_case_accuracy": avg("exact_case_accuracy"),
            "component_precision": avg("component_precision"), "component_recall": avg("component_recall"),
            "component_f1": avg("component_f1"), "amount_mape": avg("amount_mape"),
            "hallucination_rate": avg("hallucination_rate"),
            "latency_p50_ms": percentile(latencies, .5), "latency_p95_ms": percentile(latencies, .95),
            "cost_total_usd": sum(row["cost_usd"] for row in cases),
            "cost_mean_usd": avg("cost_usd"),
            "input_tokens_total": sum(input_tokens),
            "input_tokens_mean": statistics.mean(input_tokens) if input_tokens else None,
            "output_tokens_total": sum(output_tokens),
            "output_tokens_mean": statistics.mean(output_tokens) if output_tokens else None,
        },
        "cases": cases,
    }
    for prefix in ("identity", "visible"):
        key = f"{prefix}_component_f1"
        if any(key in row for row in cases):
            for metric in ("component_precision", "component_recall", "component_f1", "hallucination_rate"):
                report["summary"][f"{prefix}_{metric}"] = avg(f"{prefix}_{metric}")
    non_food = [row for row in cases if row["category"] == "non_food"]
    if non_food:
        report["summary"]["non_food_rejection_rate"] = statistics.mean(
            row["exact_case_accuracy"] for row in non_food)
    visible_f1 = report["summary"].get("visible_component_f1")
    visible_hallucination = report["summary"].get("visible_hallucination_rate")
    non_food_rejection = report["summary"].get("non_food_rejection_rate")
    if visible_f1 is not None and visible_hallucination is not None and non_food_rejection is not None:
        report["release_gate"] = {
            "visible_component_f1_min": 0.90,
            "visible_hallucination_rate_max": 0.05,
            "non_food_rejection_rate_required": 1.0,
            "passed": visible_f1 >= 0.90 and visible_hallucination <= 0.05 and non_food_rejection == 1.0,
        }
    encoded = json.dumps(report, ensure_ascii=False, indent=2) + "\n"
    if args.output:
        Path(args.output).write_text(encoded, encoding="utf-8")
    else:
        print(encoded, end="")


if __name__ == "__main__":
    main()
