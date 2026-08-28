"""Materialize reviewed recipes and generated-recipe terms in all 25 locales.

This is an explicit, one-time network build step. It never runs in the app.
Existing native copy is preserved, missing copy is translated in bounded
batches, and culturally specific dish-name overrides keep distinct identities.
"""
from __future__ import annotations

import argparse
import json
import time
import urllib.parse
import urllib.request
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "artifacts/meal_catalog/recipe_canonical_100.json"
TERMS_OUTPUT = ROOT / "artifacts/meal_catalog/recipe_generated_locale_terms_25.json"
TARGETS = {
    "ar": "ar", "en": "en", "fr": "fr", "es": "es", "tr": "tr",
    "de": "de", "it": "it", "pt-BR": "pt-BR", "pt-PT": "pt-PT",
    "ur": "ur", "fa": "fa", "hi": "hi", "id": "id", "ms": "ms",
    "ja": "ja", "ko": "ko", "zh-Hans": "zh-CN", "zh-Hant": "zh-TW",
    "ru": "ru", "bn": "bn", "vi": "vi", "th": "th", "pl": "pl",
    "nl": "nl", "uk": "uk",
}
LOCALES = tuple(TARGETS)
BASE_LOCALES = ("ar", "en", "fr", "es", "tr")
DELIMITER = "ZXQPSEGMENT9X7ZXQP"
PLACEHOLDER_TOKENS = {
    "{protein}": "ZXQPPROTEIN9X7ZXQP",
    "{style}": "ZXQPSTYLE9X7ZXQP",
    "{base}": "ZXQPBASE9X7ZXQP",
    "{vegetable}": "ZXQPVEGETABLE9X7ZXQP",
    "{secondVegetable}": "ZXQPSECONDVEGETABLE9X7ZXQP",
    "{grams}": "ZXQPGRAMS9X7ZXQP",
    "{food}": "ZXQPFOOD9X7ZXQP",
}

FOOD_TERM_SOURCES = {
    "chicken": "chicken", "turkey": "turkey meat", "salmon": "salmon",
    "cod": "cod fish", "beef": "beef", "egg": "egg", "lentils": "lentils",
    "chickpeas": "chickpeas", "black-beans": "black beans", "tofu": "tofu",
    "rice": "rice", "bulgur": "bulgur", "quinoa": "quinoa", "barley": "barley",
    "oats": "oats", "potato": "potato", "sweet-potato": "sweet potato",
    "whole-wheat-pasta": "whole-wheat pasta", "couscous": "couscous",
    "corn": "corn", "tomato": "tomato", "spinach": "spinach",
    "broccoli": "broccoli", "zucchini": "zucchini", "eggplant": "eggplant",
    "carrot": "carrot", "pepper": "pepper", "cabbage": "cabbage", "peas": "peas",
    "mushroom": "mushroom", "onion": "onion", "olive-oil": "olive oil",
    "yogurt": "yogurt", "tahini": "tahini", "lemon": "lemon",
}
GENERATED_COPY_SOURCES = {
    "styles": ["bowl", "tray bake", "grain plate"],
    "cookPhrases": [
        "Simmer gently until cooked.",
        "Bake until safely cooked.",
        "Assemble just before serving.",
    ],
    "titleTemplate": "{protein} {style} with {base}, {vegetable} and {secondVegetable}",
    "ingredientTemplate": "{grams} g {food}",
    "stepPrepare": "Weigh and prepare every ingredient.",
    "stepServe": "Divide into the stated servings and serve.",
}

CUISINE_PREFIX_SOURCES = {
    "egypt": "Egyptian-inspired",
    "levant": "Levantine-inspired",
    "gulf": "Gulf-inspired",
    "iraq": "Iraqi-inspired",
    "maghreb": "Maghrebi-inspired",
    "united-states": "American-inspired",
    "canada": "Canadian-inspired",
    "united-kingdom": "British-inspired",
    "ireland": "Irish-inspired",
    "australia": "Australian-inspired",
    "new-zealand": "New Zealand-inspired",
    "france": "French-inspired",
    "quebec": "Quebec-inspired",
    "west-africa": "West African-inspired",
    "spain": "Spanish-inspired",
    "mexico": "Mexican-inspired",
    "central-america": "Central American-inspired",
    "south-america": "South American-inspired",
    "caribbean": "Caribbean-inspired",
    "marmara": "Marmara-inspired",
    "aegean": "Aegean-inspired",
    "mediterranean": "Mediterranean-inspired",
    "central-anatolia": "Central Anatolian-inspired",
    "black-sea": "Black Sea-inspired",
    "eastern-anatolia": "Eastern Anatolian-inspired",
    "southeastern-anatolia": "Southeastern Anatolian-inspired",
}

TITLE_OVERRIDES = {
    "chickpea-salad": {"tr": "Otlu nohut salatası"},
    "overnight-oats-figs": {"es": "Avena reposada con higos", "tr": "Bir gece bekletilmiş incirli yulaf"},
    "tofu-stir-fry": {"tr": "Tofulu sebze sote"},
    "egyptian-koshari": {
        "ar": "كشري مصري", "en": "Egyptian koshary", "fr": "Koshari égyptien",
        "es": "Koshari egipcio", "tr": "Mısır usulü koshari",
    },
    "palestinian-musakhan": {
        "ar": "مسخن فلسطيني", "en": "Palestinian musakhan", "fr": "Musakhan palestinien",
        "es": "Musakhan palestino", "tr": "Filistin usulü musakhan",
    },
    "harees-chicken": {
        "ar": "هريس بالدجاج", "en": "Chicken harees", "fr": "Harees au poulet",
        "es": "Harees con pollo", "tr": "Tavuklu harees",
    },
    "machboos-fish": {
        "ar": "مجبوس السمك", "en": "Fish machboos", "fr": "Machboos au poisson",
        "es": "Machboos de pescado", "tr": "Balık machboos",
    },
    "turkey-three-bean-chili": {
        "ar": "تشيلي الديك الرومي بثلاثة أنواع من الفاصوليا",
        "en": "Three-bean chili with turkey meat", "fr": "Chili de dinde aux trois haricots",
        "es": "Chili de pavo con tres frijoles", "tr": "Üç fasulyeli hindi chili",
    },
    "pate-chinois-dinde": {
        "ar": "باتيه شينوا بالديك الرومي", "en": "Turkey pâté chinois (Québec shepherd’s pie)",
        "fr": "Pâté chinois à la dinde", "es": "Pâté chinois de pavo", "tr": "Hindili pâté chinois",
    },
    "ragout-boulettes-dinde": {
        "ar": "يخنة كرات لحم الديك الرومي", "en": "Turkey meatball stew",
        "fr": "Ragoût de boulettes de dinde", "es": "Estofado de albóndigas de pavo",
        "tr": "Hindi köfteli yahni",
    },
    "cassoulet-haricots-dinde": {
        "ar": "كاسوليه خفيف بالديك الرومي", "en": "Light turkey cassoulet",
        "fr": "Cassoulet léger à la dinde", "es": "Cassoulet ligero de pavo",
        "tr": "Hafif hindili cassoulet",
    },
    "chorba-lentilles": {
        "ar": "شوربا بالعدس", "en": "Lentil chorba", "fr": "Chorba aux lentilles",
        "es": "Chorba de lentejas", "tr": "Mercimekli chorba",
    },
    "tourtiere-lentilles": {
        "ar": "تورتيير بالعدس", "en": "Lentil tourtière", "fr": "Tourtière aux lentilles",
        "es": "Tourtière de lentejas", "tr": "Mercimekli tourtière",
    },
    "fabada-ligera": {
        "ar": "فابادا خفيفة", "en": "Light fabada", "fr": "Fabada légère",
        "es": "Fabada ligera", "tr": "Hafif fabada",
    },
    "gallo-pinto-huevo": {
        "ar": "غالو بينتو بالبيض", "en": "Gallo pinto with egg",
        "fr": "Gallo pinto à l’œuf", "es": "Gallo pinto con huevo", "tr": "Yumurtalı gallo pinto",
    },
    "aji-gallina-ligero": {
        "ar": "آخي دي غايينا خفيف", "en": "Light ají de gallina",
        "fr": "Ají de gallina léger", "es": "Ají de gallina ligero", "tr": "Hafif ají de gallina",
    },
    "locro-calabaza": {
        "ar": "لوكرو اليقطين", "en": "Pumpkin locro", "fr": "Locro au potiron",
        "es": "Locro de calabaza", "tr": "Balkabaklı locro",
    },
    "casamiento-hondureno": {
        "ar": "كاساميينتو هندوراسي", "en": "Honduran casamiento",
        "fr": "Casamiento hondurien", "es": "Casamiento hondureño", "tr": "Honduras casamiento",
    },
    "seco-pollo-quinoa": {
        "ar": "سيكو الدجاج مع الكينوا", "en": "Chicken seco with quinoa",
        "fr": "Seco de poulet au quinoa", "es": "Seco de pollo con quinoa", "tr": "Kinoalı tavuk seco",
    },
    "sancocho-pollo": {
        "ar": "سانكوتشو بالدجاج", "en": "Chicken sancocho", "fr": "Sancocho au poulet",
        "es": "Sancocho de pollo", "tr": "Tavuklu sancocho",
    },
    "antalya-piyaz": {
        "ar": "بياز أنطاليا", "en": "Antalya piyaz", "fr": "Piyaz d’Antalya",
        "es": "Piyaz de Antalya", "tr": "Antalya piyazı",
    },
    "otlu-borek-yogurt": {
        "ar": "بورك بالأعشاب والزبادي", "en": "Herb börek with yogurt",
        "fr": "Börek aux herbes et yaourt", "es": "Börek de hierbas con yogur", "tr": "Otlu börek ve yoğurt",
    },
    "ayran-asi-corbasi": {
        "ar": "شوربة آيران آشي", "en": "Ayran aşı soup", "fr": "Soupe ayran aşı",
        "es": "Sopa ayran aşı", "tr": "Ayran aşı çorbası",
    },
    "iskender-tavuk": {
        "ar": "إسكندر بالدجاج", "en": "Chicken İskender", "fr": "İskender au poulet",
        "es": "İskender de pollo", "tr": "Tavuk İskender",
    },
    "fellah-koftesi": {
        "ar": "كفتة الفلاح التركية", "en": "Fellah köftesi (bulgur dumplings)",
        "fr": "Fellah köftesi (boulettes de boulgour)",
        "es": "Fellah köftesi (bolitas de bulgur)", "tr": "Fellah köftesi",
    },
    "ankara-tava": {
        "ar": "أنقرة تافا", "en": "Ankara tava", "fr": "Ankara tava",
        "es": "Ankara tava", "tr": "Ankara tava",
    },
    "yesil-mercimek-manti": {
        "ar": "مانتي بالعدس الأخضر", "en": "Green lentil mantı",
        "fr": "Mantı aux lentilles vertes", "es": "Mantı de lentejas verdes",
        "tr": "Yeşil mercimekli mantı",
    },
    "tavuklu-bostana": {
        "ar": "سلطة بستانة بالدجاج", "en": "Chicken bostana salad",
        "fr": "Salade bostana au poulet", "es": "Ensalada bostana con pollo", "tr": "Tavuklu bostana",
    },
    "algerian-chakhchoukha-chicken": {
        "ar": "الشخشوخة الجزائرية بالدجاج",
        "en": "Algerian chicken chakhchoukha",
        "fr": "Chakhchoukha algérienne au poulet",
        "es": "Chakhchoukha argelina con pollo",
        "tr": "Cezayir usulü tavuklu chakhchoukha",
    },
    "shakshuka": {
        "ar": "شكشوكة بالأعشاب",
        "en": "Herbed shakshuka",
        "fr": "Chakchouka aux herbes",
        "es": "Shakshuka con hierbas",
        "tr": "Otlu shakshuka",
    },
}

# These are proper dish identities, not ordinary words. Machine translation
# may otherwise turn harees into "hares", casamiento into "marriage", or
# İskender into "Alexander". Extended-language titles keep the identity token
# verbatim while translating the surrounding description.
CULTURAL_TITLE_TERMS = {
    "egyptian-koshari": ("koshary",),
    "palestinian-musakhan": ("musakhan",),
    "harees-chicken": ("harees",),
    "machboos-fish": ("machboos",),
    "pate-chinois-dinde": ("pâté chinois",),
    "cassoulet-haricots-dinde": ("cassoulet",),
    "chorba-lentilles": ("chorba",),
    "tourtiere-lentilles": ("tourtière",),
    "fabada-ligera": ("fabada",),
    "gallo-pinto-huevo": ("Gallo pinto",),
    "aji-gallina-ligero": ("ají de gallina",),
    "locro-calabaza": ("locro",),
    "casamiento-hondureno": ("casamiento",),
    "seco-pollo-quinoa": ("seco",),
    "sancocho-pollo": ("sancocho",),
    "antalya-piyaz": ("piyaz",),
    "otlu-borek-yogurt": ("börek",),
    "ayran-asi-corbasi": ("Ayran aşı",),
    "iskender-tavuk": ("İskender",),
    "fellah-koftesi": ("Fellah köftesi",),
    "ankara-tava": ("Ankara tava",),
    "yesil-mercimek-manti": ("mantı",),
    "tavuklu-bostana": ("bostana",),
    "algerian-chakhchoukha-chicken": ("chakhchoukha",),
    "shakshuka": ("shakshuka",),
    "moroccan-harira": ("harira",),
    # Re-translate this corrected, unambiguous English title too.
    "turkey-three-bean-chili": (),
}

CORRECTED_INGREDIENTS_EN = {
    "overnight-oats-figs": [
        "40 g raw oat bran",
        "150 g plain low-fat yogurt",
        "100 g raw figs",
    ],
    "roasted-quinoa-bowl": [
        "150 g cooked quinoa",
        "100 g cooked zucchini",
        "100 g raw green sweet pepper",
        "15 g raw lemon juice",
        "5 g fresh parsley",
    ],
}


def translate(texts: list[str], source: str, target: str) -> list[str]:
    values: list[str] = []
    for start in range(0, len(texts), 24):
        chunk = texts[start:start + 24]
        protected_chunk = [
            _replace_all(text, PLACEHOLDER_TOKENS) for text in chunk
        ]
        payload = f"\n{DELIMITER}\n".join(protected_chunk)
        last_error: Exception | None = None
        for attempt in range(4):
            try:
                body = urllib.parse.urlencode({
                    "client": "gtx", "sl": source, "tl": target,
                    "dt": "t", "q": payload,
                }).encode()
                request = urllib.request.Request(
                    "https://translate.google.com/translate_a/t?client=gtx",
                    data=body,
                    headers={"Content-Type": "application/x-www-form-urlencoded; charset=utf-8"},
                )
                with urllib.request.urlopen(request, timeout=30) as response:
                    decoded = json.loads(response.read().decode("utf-8"))
                if all(isinstance(value, str) for value in decoded):
                    translated = "".join(decoded)
                else:
                    translated = "".join(row[0] for row in decoded[0])
                parts = [
                    _replace_all(part.strip(), {v: k for k, v in PLACEHOLDER_TOKENS.items()})
                    for part in translated.split(DELIMITER)
                ]
                if len(parts) != len(chunk) or any(not part for part in parts):
                    raise RuntimeError(
                        f"translation segment mismatch {len(parts)}/{len(chunk)}"
                    )
                values.extend(parts)
                print(f"  {source}->{target} {len(values)}/{len(texts)}", flush=True)
                break
            except Exception as error:  # bounded network build retry
                last_error = error
                if attempt == 3:
                    raise RuntimeError(
                        f"translation failed {source}->{target} at {start}: {last_error}"
                    ) from error
                time.sleep(0.4 * (attempt + 1))
    return values


def _replace_all(value: str, replacements: dict[str, str]) -> str:
    for before, after in replacements.items():
        value = value.replace(before, after)
    return value


def generate_terms() -> None:
    sources = [
        *FOOD_TERM_SOURCES.values(),
        *GENERATED_COPY_SOURCES["styles"],
        *GENERATED_COPY_SOURCES["cookPhrases"],
        GENERATED_COPY_SOURCES["titleTemplate"],
        GENERATED_COPY_SOURCES["ingredientTemplate"],
        GENERATED_COPY_SOURCES["stepPrepare"],
        GENERATED_COPY_SOURCES["stepServe"],
    ]
    locales: dict[str, dict] = {}
    for locale, target in TARGETS.items():
        if locale in BASE_LOCALES:
            continue
        values = translate(sources, "en", target)
        offset = 0
        foods = {}
        for key in FOOD_TERM_SOURCES:
            foods[key] = values[offset]
            offset += 1
        styles = values[offset:offset + 3]
        offset += 3
        cook_phrases = values[offset:offset + 3]
        offset += 3
        title_template, ingredient_template, step_prepare, step_serve = values[offset:offset + 4]
        if offset + 4 != len(values):
            raise RuntimeError(f"generated term assignment mismatch: {locale}")
        required_title = {"{protein}", "{style}", "{base}", "{vegetable}", "{secondVegetable}"}
        if not all(token in title_template for token in required_title):
            raise RuntimeError(f"title placeholders changed: {locale}")
        if "{grams}" not in ingredient_template or "{food}" not in ingredient_template:
            raise RuntimeError(f"ingredient placeholders changed: {locale}")
        locales[locale] = {
            "foods": foods,
            "styles": styles,
            "cookPhrases": cook_phrases,
            "titleTemplate": title_template,
            "ingredientTemplate": ingredient_template,
            "stepPrepare": step_prepare,
            "stepServe": step_serve,
        }
    TERMS_OUTPUT.write_text(
        json.dumps({"schemaVersion": 1, "locales": locales}, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"RECIPE_GENERATED_TERMS=PASS locales={len(locales)}")


def repair_cultural_titles(records: list[dict]) -> None:
    by_id = {record["canonicalId"]: record for record in records}
    extended_locales = set(TARGETS).difference(BASE_LOCALES)
    if all(
        all(
            term in by_id[recipe_id]["localizations"][locale]["title"]
            for term in terms
        )
        for recipe_id, terms in CULTURAL_TITLE_TERMS.items()
        for locale in extended_locales
    ):
        print(
            "RECIPE_CULTURAL_TITLES=REUSED "
            f"recipes={len(CULTURAL_TITLE_TERMS)} locales={len(extended_locales)}"
        )
        return
    for locale, target in TARGETS.items():
        if locale in BASE_LOCALES:
            continue
        sources: list[str] = []
        restorations: list[dict[str, str]] = []
        recipe_ids: list[str] = []
        for ordinal, (recipe_id, terms) in enumerate(CULTURAL_TITLE_TERMS.items()):
            source_title = by_id[recipe_id]["localizations"]["en"]["title"]
            restore: dict[str, str] = {}
            for term_index, term in enumerate(terms):
                marker = f"ZXQPDISH{ordinal:03d}{term_index:02d}ZXQP"
                if term not in source_title:
                    raise RuntimeError(
                        f"cultural title term missing: {recipe_id} / {term}"
                    )
                source_title = source_title.replace(term, marker)
                restore[marker] = term
            sources.append(source_title)
            restorations.append(restore)
            recipe_ids.append(recipe_id)
        translated = translate(sources, "en", target)
        for recipe_id, title, restore in zip(
            recipe_ids, translated, restorations, strict=True
        ):
            for marker, term in restore.items():
                if marker not in title:
                    raise RuntimeError(
                        f"cultural title marker changed: {recipe_id} / {locale}"
                    )
                title = title.replace(marker, term)
            by_id[recipe_id]["localizations"][locale]["title"] = title
    print(
        "RECIPE_CULTURAL_TITLES=PASS "
        f"recipes={len(CULTURAL_TITLE_TERMS)} locales={len(TARGETS) - len(BASE_LOCALES)}"
    )


def repair_ingredient_mismatches(records: list[dict]) -> None:
    by_id = {record["canonicalId"]: record for record in records}
    if all(
        by_id[recipe_id]["localizations"]["en"]["ingredients"] == source_values
        and all(
            len(by_id[recipe_id]["localizations"][locale]["ingredients"])
            == len(source_values)
            for locale in TARGETS
        )
        for recipe_id, source_values in CORRECTED_INGREDIENTS_EN.items()
    ):
        print(
            "RECIPE_INGREDIENT_ALIGNMENT=REUSED "
            f"recipes={len(CORRECTED_INGREDIENTS_EN)} locales={len(TARGETS)}"
        )
        return
    for recipe_id, source_values in CORRECTED_INGREDIENTS_EN.items():
        record = by_id[recipe_id]
        if len(source_values) != len(record["ingredients"]):
            raise RuntimeError(f"corrected ingredient count mismatch: {recipe_id}")
        record["localizations"]["en"]["ingredients"] = source_values
        for locale, target in TARGETS.items():
            if locale == "en":
                continue
            record["localizations"][locale]["ingredients"] = translate(
                source_values, "en", target
            )
    print(
        "RECIPE_INGREDIENT_ALIGNMENT=PASS "
        f"recipes={len(CORRECTED_INGREDIENTS_EN)} locales={len(TARGETS)}"
    )


def ensure_cuisine_prefixes() -> None:
    payload = json.loads(TERMS_OUTPUT.read_text(encoding="utf-8"))
    existing = payload.get("cuisinePrefixes", {})
    if set(existing) == set(TARGETS) and all(
        set(values) == set(CUISINE_PREFIX_SOURCES) for values in existing.values()
    ):
        print(f"RECIPE_CUISINE_PREFIXES=REUSED locales={len(existing)}")
        return
    source_values = list(CUISINE_PREFIX_SOURCES.values())
    localized: dict[str, dict[str, str]] = {}
    for locale, target in TARGETS.items():
        values = source_values if locale == "en" else translate(
            source_values, "en", target
        )
        localized[locale] = dict(zip(CUISINE_PREFIX_SOURCES, values, strict=True))
    payload["cuisinePrefixes"] = localized
    TERMS_OUTPUT.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    print(f"RECIPE_CUISINE_PREFIXES=PASS locales={len(localized)}")


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--write", action="store_true")
    args = parser.parse_args()
    if not args.write:
        raise SystemExit("Refusing network translation without --write")

    payload = json.loads(SOURCE.read_text(encoding="utf-8-sig"))
    records = payload["records"]
    pending: dict[tuple[str, str], list[tuple[dict, int, list[str]]]] = {}
    for record in records:
        source_locale = "en"
        source_copy = record["localizations"][source_locale]
        source_values = [
            source_copy["title"],
            *source_copy["ingredients"],
            *source_copy["steps"],
        ]
        ingredient_count = len(source_copy["ingredients"])
        for target in LOCALES:
            if target in record["localizations"]:
                continue
            pending.setdefault((source_locale, target), []).append(
                (record, ingredient_count, source_values)
            )

    for (source_locale, target), tasks in pending.items():
        flattened = [value for _, _, values in tasks for value in values]
        translated = translate(flattened, source_locale, TARGETS[target])
        offset = 0
        for record, ingredient_count, source_values in tasks:
            values = translated[offset:offset + len(source_values)]
            offset += len(source_values)
            title = TITLE_OVERRIDES.get(record["canonicalId"], {}).get(
                target, values[0]
            )
            record["localizations"][target] = {
                "title": title,
                "ingredients": values[1:1 + ingredient_count],
                "steps": values[1 + ingredient_count:],
                "translationStatus": "machine-translated",
            }
        if offset != len(translated):
            raise RuntimeError(f"translation assignment mismatch {source_locale}->{target}")
        SOURCE.write_text(
            json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
            encoding="utf-8",
        )

    for record in records:
        for target, title in TITLE_OVERRIDES.get(record["canonicalId"], {}).items():
            if target in record["localizations"]:
                record["localizations"][target]["title"] = title

    repair_cultural_titles(records)
    repair_ingredient_mismatches(records)

    incomplete = [
        record["canonicalId"]
        for record in records
        if set(record["localizations"]) != set(LOCALES)
    ]
    if incomplete:
        raise RuntimeError(f"incomplete recipe localizations: {incomplete[:3]}")
    SOURCE.write_text(
        json.dumps(payload, ensure_ascii=False, indent=2) + "\n",
        encoding="utf-8",
    )
    if TERMS_OUTPUT.exists():
        terms_payload = json.loads(TERMS_OUTPUT.read_text(encoding="utf-8"))
        expected = set(TARGETS).difference(BASE_LOCALES)
        if set(terms_payload.get("locales", {})) != expected:
            raise RuntimeError("existing generated locale terms are incomplete")
        print(f"RECIPE_GENERATED_TERMS=REUSED locales={len(expected)}")
    else:
        generate_terms()
    ensure_cuisine_prefixes()
    print(f"RECIPE_25_LOCALE_LOCALIZATION=PASS records={len(records)}")


if __name__ == "__main__":
    main()
