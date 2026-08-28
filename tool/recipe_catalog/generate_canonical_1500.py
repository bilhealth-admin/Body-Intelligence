"""Build the deterministic BIL 1,500-recipe catalog without network or images.

The reviewed 100-record catalog is preserved verbatim as the first records.
New records use distinct component combinations, localized primary copy, and
nutrition calculated exclusively from the pinned USDA FoodData Central records
declared below. No synthetic nutrition fallback is permitted.
"""
from __future__ import annotations

import hashlib
import json
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SOURCE = ROOT / "artifacts/meal_catalog/recipe_canonical_100_verified.json"
CLEAN_LOCALIZATION_SOURCE = ROOT / "artifacts/meal_catalog/recipe_canonical_100.json"
TARGET = ROOT / "artifacts/meal_catalog/recipe_canonical_1500.json"
GENERATED_TERMS_SOURCE = ROOT / "artifacts/meal_catalog/recipe_generated_locale_terms_25.json"
LOCALES = ("ar", "en", "fr", "es", "tr")
ALL_LOCALES = (
    "ar", "en", "fr", "es", "tr", "de", "it", "pt-BR", "pt-PT", "ur",
    "fa", "hi", "id", "ms", "ja", "ko", "zh-Hans", "zh-Hant", "ru",
    "bn", "vi", "th", "pl", "nl", "uk",
)

# name, FDC id, kcal, protein, carbohydrate, fat, fibre, sugar, sodium, potassium / 100 g
FOODS = {
    "chicken": (171477, 165, 31.0, 0.0, 3.6, 0.0, 0.0, 74, 256),
    "turkey": (171496, 135, 29.0, 0.0, 1.8, 0.0, 0.0, 54, 239),
    "salmon": (175168, 206, 22.0, 0.0, 12.0, 0.0, 0.0, 59, 363),
    "cod": (171956, 89, 19.9, 0.0, 0.7, 0.0, 0.0, 66, 413),
    "beef": (174032, 250, 26.0, 0.0, 15.0, 0.0, 0.0, 72, 318),
    "egg": (173424, 143, 12.6, 0.7, 9.5, 0.0, 0.4, 142, 138),
    "lentils": (172420, 352, 24.6, 63.4, 1.1, 10.7, 2.0, 6, 677),
    "chickpeas": (173757, 164, 8.9, 27.4, 2.6, 7.6, 4.8, 7, 291),
    "black-beans": (173735, 132, 8.9, 23.7, 0.5, 8.7, 0.3, 1, 355),
    "tofu": (172475, 83, 10.0, 1.2, 5.3, 1.0, 0.7, 4, 121),
    "rice": (169756, 365, 7.1, 80.0, 0.7, 1.3, 0.1, 5, 115),
    "bulgur": (170287, 342, 12.3, 75.9, 1.3, 18.3, 0.4, 17, 410),
    "quinoa": (168874, 368, 14.1, 64.2, 6.1, 7.0, 0.0, 5, 563),
    "barley": (170283, 352, 9.9, 77.7, 1.2, 15.6, 0.8, 9, 280),
    "oats": (173904, 379, 13.2, 67.7, 6.5, 10.1, 1.0, 6, 362),
    "potato": (170026, 77, 2.1, 17.5, 0.1, 2.1, 0.8, 6, 425),
    "sweet-potato": (168482, 86, 1.6, 20.1, 0.1, 3.0, 4.2, 55, 337),
    "whole-wheat-pasta": (168934, 348, 14.6, 75.0, 1.4, 11.0, 3.1, 8, 434),
    "couscous": (169699, 376, 12.8, 77.4, 0.6, 5.0, 0.0, 10, 166),
    "corn": (169998, 86, 3.3, 18.7, 1.4, 2.0, 6.3, 15, 270),
    "tomato": (170457, 18, 0.9, 3.9, 0.2, 1.2, 2.6, 5, 237),
    "spinach": (168462, 23, 2.9, 3.6, 0.4, 2.2, 0.4, 79, 558),
    "broccoli": (170379, 34, 2.8, 6.6, 0.4, 2.6, 1.7, 33, 316),
    "zucchini": (169291, 17, 1.2, 3.1, 0.3, 1.0, 2.5, 8, 261),
    "eggplant": (169228, 25, 1.0, 5.9, 0.2, 3.0, 3.5, 2, 229),
    "carrot": (168568, 41, 0.9, 9.6, 0.2, 2.8, 4.7, 69, 320),
    "pepper": (170108, 31, 1.0, 6.0, 0.3, 2.1, 4.2, 4, 211),
    "cabbage": (169975, 25, 1.3, 5.8, 0.1, 2.5, 3.2, 18, 170),
    "peas": (170419, 81, 5.4, 14.5, 0.4, 5.1, 5.7, 5, 244),
    "mushroom": (169251, 22, 3.1, 3.3, 0.3, 1.0, 2.0, 5, 318),
    "onion": (790646, 40, 1.1, 9.3, 0.1, 1.7, 4.2, 4, 146),
    "olive-oil": (171413, 884, 0.0, 0.0, 100.0, 0.0, 0.0, 2, 1),
    "yogurt": (171284, 61, 3.5, 4.7, 3.3, 0.0, 4.7, 46, 141),
    "tahini": (170189, 595, 17.0, 21.2, 53.8, 9.3, 0.5, 115, 414),
    "lemon": (167747, 22, 0.4, 6.9, 0.2, 0.3, 2.5, 1, 103),
}

PROTEINS = tuple(FOODS)[:10]
BASES = tuple(FOODS)[10:20]
VEGETABLES = tuple(FOODS)[20:30]
FINISHES = ("onion", "olive-oil", "yogurt", "tahini", "lemon")
REGIONS = {
    "ar": ("egypt", "levant", "gulf", "iraq", "maghreb"),
    "en": ("united-states", "canada", "united-kingdom", "ireland", "australia", "new-zealand"),
    "fr": ("france", "quebec", "maghreb", "west-africa"),
    "es": ("spain", "mexico", "central-america", "south-america", "caribbean"),
    "tr": ("marmara", "aegean", "mediterranean", "central-anatolia", "black-sea", "eastern-anatolia", "southeastern-anatolia"),
}

# Country claims are added only when the reviewed dish identity itself is
# explicit. Broad regional dishes remain regional rather than being guessed.
CUISINE_OVERRIDES = {
    "palestinian-musakhan": "palestine",
    "moroccan-harira": "morocco",
    "tunisian-couscous-vegetables": "tunisia",
    "algerian-chakhchoukha-chicken": "algeria",
    "moroccan-tagine-fish": "morocco",
    "sopa-negra-costarricense": "costa-rica",
    "casamiento-hondureno": "honduras",
}
TECHNIQUES = {
    "ar": (("وعاء", "يُطهى على نار هادئة"), ("صينية", "يُخبز حتى ينضج"), ("طبق حبوب", "تُجمع المكونات بعناية")),
    "en": (("bowl", "simmer gently until cooked"), ("tray bake", "bake until safely cooked"), ("grain plate", "assemble just before serving")),
    "fr": (("bol", "mijoter doucement jusqu'à cuisson"), ("plat rôti", "cuire au four jusqu'à cuisson complète"), ("assiette de céréales", "assembler juste avant de servir")),
    "es": (("bol", "cocer a fuego lento hasta completar la cocción"), ("bandeja al horno", "hornear hasta que esté bien cocido"), ("plato de cereal", "montar justo antes de servir")),
    "tr": (("kase", "kısık ateşte tamamen pişirin"), ("fırın tepsisi", "güvenli biçimde pişene kadar fırınlayın"), ("tahıl tabağı", "servisten hemen önce birleştirin")),
}
DISPLAY = {
    "ar": {"with": "مع", "and": "و"}, "en": {"with": "with", "and": "and"},
    "fr": {"with": "avec", "and": "et"}, "es": {"with": "con", "and": "y"},
    "tr": {"with": "ile", "and": "ve"},
}
FOOD_NAMES = {
    "ar": dict(zip(FOODS, ("دجاج", "ديك رومي", "سلمون", "سمك القد", "لحم بقري", "بيض", "عدس", "حمص", "فاصوليا سوداء", "توفو", "أرز", "برغل", "كينوا", "شعير", "شوفان", "بطاطس", "بطاطا حلوة", "مكرونة قمح كامل", "كسكسي", "ذرة", "طماطم", "سبانخ", "بروكلي", "كوسة", "باذنجان", "جزر", "فلفل", "ملفوف", "بازلاء", "فطر", "بصل", "زيت زيتون", "زبادي", "طحينة", "ليمون"))),
    "en": {key: label for key, label in zip(FOODS, ("chicken", "turkey", "salmon", "cod", "beef", "egg", "lentils", "chickpeas", "black beans", "tofu", "rice", "bulgur", "quinoa", "barley", "oats", "potato", "sweet potato", "whole-wheat pasta", "couscous", "corn", "tomato", "spinach", "broccoli", "zucchini", "eggplant", "carrot", "pepper", "cabbage", "peas", "mushroom", "onion", "olive oil", "yogurt", "tahini", "lemon"))},
    "fr": dict(zip(FOODS, ("poulet", "dinde", "saumon", "cabillaud", "bœuf", "œuf", "lentilles", "pois chiches", "haricots noirs", "tofu", "riz", "boulgour", "quinoa", "orge", "avoine", "pomme de terre", "patate douce", "pâtes complètes", "couscous", "maïs", "tomate", "épinards", "brocoli", "courgette", "aubergine", "carotte", "poivron", "chou", "petits pois", "champignon", "oignon", "huile d'olive", "yaourt", "tahini", "citron"))),
    "es": dict(zip(FOODS, ("pollo", "pavo", "salmón", "bacalao", "ternera", "huevo", "lentejas", "garbanzos", "frijoles negros", "tofu", "arroz", "bulgur", "quinoa", "cebada", "avena", "patata", "batata", "pasta integral", "cuscús", "maíz", "tomate", "espinaca", "brócoli", "calabacín", "berenjena", "zanahoria", "pimiento", "repollo", "guisantes", "champiñón", "cebolla", "aceite de oliva", "yogur", "tahini", "limón"))),
    "tr": dict(zip(FOODS, ("tavuk", "hindi", "somon", "morina", "dana eti", "yumurta", "mercimek", "nohut", "siyah fasulye", "tofu", "pirinç", "bulgur", "kinoa", "arpa", "yulaf", "patates", "tatlı patates", "tam buğday makarna", "kuskus", "mısır", "domates", "ıspanak", "brokoli", "kabak", "patlıcan", "havuç", "biber", "lahana", "bezelye", "mantar", "soğan", "zeytinyağı", "yoğurt", "tahin", "limon"))),
}


def label(item: str) -> str:
    return item.replace("-", " ")


def quantities(index: int) -> tuple[float, float, float, float, float]:
    return (320 + index % 7 * 25, 220 + index % 9 * 20, 180 + index % 11 * 15,
            120 + index % 5 * 20, 18 + index % 4 * 6)


def nutrition(items: list[tuple[str, float]], servings: int) -> tuple[dict, list[str]]:
    totals = [0.0] * 8
    refs = []
    for item, grams in items:
        fdc, *values = FOODS[item]
        refs.append(f"usda:{fdc}")
        for i, value in enumerate(values):
            totals[i] += value * grams / 100
    keys = ("kcal", "proteinG", "carbohydrateG", "fatG", "fiberG", "sugarG", "sodiumMg", "potassiumMg")
    return ({key: round(value / servings, 2) for key, value in zip(keys, totals)}, sorted(set(refs)))


def initial_cap(value: str) -> str:
    return value[:1].upper() + value[1:] if value else value


def make_record(
    locale: str,
    index: int,
    generated_terms: dict,
    cuisine_prefixes: dict,
) -> dict:
    # The generated set is made of explicitly labelled BIL originals inspired
    # by a declared culinary profile. It is not presented as 1,400 invented
    # traditional dishes, and the original stable IDs remain image-compatible.
    protein = PROTEINS[index % len(PROTEINS)]
    base = BASES[(index // len(PROTEINS)) % len(BASES)]
    vegetable = VEGETABLES[
        (index // (len(PROTEINS) * len(BASES))) % len(VEGETABLES)
    ]
    second_vegetable = VEGETABLES[(index * 3 + 4) % len(VEGETABLES)]
    if second_vegetable == vegetable:
        second_vegetable = VEGETABLES[
            (VEGETABLES.index(vegetable) + 1) % len(VEGETABLES)
        ]
    finish = FINISHES[(index * 7 + 2) % len(FINISHES)]
    region = REGIONS[locale][index % len(REGIONS[locale])]
    # Arabic- and French-authored Maghrebi sets overlap on 14 Cartesian
    # points. Give the Francophone originals a distinct preparation family
    # and ID so they are genuinely separate recipes and require their own
    # matching images rather than silently reusing the old duplicate asset.
    francophone_maghreb = locale == "fr" and region == "maghreb"
    style_index = (index + (1 if francophone_maghreb else 0)) % 3
    id_region = "maghreb-francophone" if francophone_maghreb else region
    q = quantities(index)
    items = list(zip((protein, base, vegetable, second_vegetable, finish), q))
    servings = 2 + index % 5
    prep = 10 + index % 5 * 5
    cook = (0 if index % 3 == 2 else 20 + index % 7 * 5)
    cid = f"bil-{locale}-{id_region}-{protein}-{base}-{vegetable}-{index + 1:03d}"
    ingredients = []
    for item, grams in items:
        fdc = FOODS[item][0]
        ingredients.append({"itemId": item, "quantity": grams, "unit": "g", "grams": grams,
                            "recordId": f"usda:{fdc}", "sourceRefs": [f"usda:{fdc}"]})
    per_serving, refs = nutrition(items, servings)
    localizations = {}
    for target_locale in LOCALES:
        names = FOOD_NAMES[target_locale]
        style, cook_phrase = TECHNIQUES[target_locale][style_index]
        words = DISPLAY[target_locale]
        localized_title = (
            f"{cuisine_prefixes[target_locale][region]} — "
            f"{names[protein].title()} {style} {words['with']} {names[base]}, "
            f"{names[vegetable]} {words['and']} {names[second_vegetable]}"
        )
        if target_locale == "ar":
            steps = ["زِن المكونات وجهزها قبل الطهي.", cook_phrase + ".", "قسّم الوصفة إلى الحصص المحددة وقدّمها."]
        elif target_locale == "fr":
            steps = ["Peser et préparer tous les ingrédients.", cook_phrase + ".", "Répartir selon le nombre de portions indiqué et servir."]
        elif target_locale == "es":
            steps = ["Pesar y preparar todos los ingredientes.", cook_phrase + ".", "Dividir en las porciones indicadas y servir."]
        elif target_locale == "tr":
            steps = ["Tüm malzemeleri tartın ve hazırlayın.", cook_phrase + ".", "Belirtilen porsiyonlara ayırıp servis edin."]
        else:
            steps = ["Weigh and prepare every ingredient.", cook_phrase.capitalize() + ".", "Divide into the stated servings and serve."]
        localizations[target_locale] = {
            "title": localized_title,
            "ingredients": [f"{grams:g} g {names[item]}" for item, grams in items],
            "steps": steps,
            "translationStatus": "native-reviewed" if target_locale == locale else "deterministic-localized",
        }
    for target_locale, copy in generated_terms.items():
        names = copy["foods"]
        recipe_title = copy["titleTemplate"].format(
            protein=initial_cap(names[protein]),
            style=copy["styles"][style_index],
            base=names[base],
            vegetable=names[vegetable],
            secondVegetable=names[second_vegetable],
        )
        localized_title = (
            f"{cuisine_prefixes[target_locale][region]} — {recipe_title}"
        )
        localizations[target_locale] = {
            "title": localized_title,
            "ingredients": [
                copy["ingredientTemplate"].format(
                    grams=f"{grams:g}", food=names[item]
                )
                for item, grams in items
            ],
            "steps": [
                copy["stepPrepare"],
                copy["cookPhrases"][style_index],
                copy["stepServe"],
            ],
            "translationStatus": "machine-translated",
        }
    title = localizations[locale]["title"]
    fingerprint_payload = {"locale": locale, "title": title, "items": items, "steps": localizations[locale]["steps"], "servings": servings}
    fingerprint = hashlib.sha256(json.dumps(fingerprint_payload, ensure_ascii=False, sort_keys=True,
                                            separators=(",", ":")).encode("utf-8")).hexdigest()
    allergens = (["milk"] if finish == "yogurt" else []) + (["sesame"] if finish == "tahini" else []) + (["egg"] if protein == "egg" else [])
    vegetarian = protein in {"lentils", "chickpeas", "black-beans", "tofu", "egg"}
    return {
        "canonicalId": cid, "contentFingerprint": fingerprint, "origin": "bil-original",
        "primaryLocale": locale, "region": region, "countryTags": [region],
        "mealTypes": ["lunch", "dinner"], "allergens": allergens,
        "dietTags": ["balanced", "vegetarian" if vegetarian else "omnivore"],
        "budgetTier": ("low" if vegetarian else "medium"),
        "serving": {"count": servings, "size": 1, "unit": "serving"},
        "timing": {"prepMinutes": prep, "cookMinutes": cook, "totalMinutes": prep + cook},
        "ingredients": ingredients,
        "method": [{"order": n + 1, "instructionKey": f"{cid}.step{n + 1}"} for n in range(3)],
        "localizations": localizations,
        "nutrition": {"status": "calculated", "servings": servings, "sourceRefs": refs,
            "reviewedAt": None, "perServing": per_serving},
        "image": {"status": "planned", "assetPath": None, "sha256": None, "width": None,
            "height": None, "provenance": "No image generated; catalog contract only.",
            "promptId": f"recipe-{cid}-v1"},
    }


def validate(records: list[dict]) -> None:
    if len(records) != 1500:
        raise RuntimeError(f"expected 1500 records, found {len(records)}")
    for locale in LOCALES:
        count = sum(r["primaryLocale"] == locale for r in records)
        if count != 300:
            raise RuntimeError(f"expected 300 {locale} records, found {count}")
    for field in ("canonicalId", "contentFingerprint"):
        values = [r[field] for r in records]
        if len(values) != len(set(values)):
            raise RuntimeError(f"duplicate {field}")
    generated = [record for record in records if record["canonicalId"].startswith("bil-")]
    for locale in LOCALES:
        locale_records = [r for r in generated if r["primaryLocale"] == locale]
        ingredient_identities = [
            tuple(ingredient["itemId"] for ingredient in record["ingredients"])
            for record in locale_records
        ]
        if len(ingredient_identities) != len(set(ingredient_identities)):
            raise RuntimeError(f"duplicate generated ingredient identity in {locale}")
        if any(
            record["region"] not in REGIONS[locale]
            or record["countryTags"] != [record["region"]]
            for record in locale_records
        ):
            raise RuntimeError(f"generated BIL recipe has invalid cuisine profile: {locale}")
    for locale in ALL_LOCALES:
        titles = [record["localizations"][locale]["title"].casefold() for record in generated]
        if len(titles) != len(set(titles)):
            raise RuntimeError(f"duplicate generated title in {locale}")
    for record in records:
        if set(record["localizations"]) != set(ALL_LOCALES):
            raise RuntimeError(f"incomplete 25-language recipe: {record['canonicalId']}")
        if record["timing"]["totalMinutes"] != record["timing"]["prepMinutes"] + record["timing"]["cookMinutes"]:
            raise RuntimeError(f"invalid timing: {record['canonicalId']}")
        if [s["order"] for s in record["method"]] != list(range(1, len(record["method"]) + 1)):
            raise RuntimeError(f"invalid method: {record['canonicalId']}")
        if record["canonicalId"].startswith("bil-") and any(
            not (i.get("recordId") or "").startswith("usda:")
            for i in record["ingredients"]
        ):
            raise RuntimeError(f"ingredient without USDA evidence: {record['canonicalId']}")


def main() -> None:
    source = json.loads(SOURCE.read_text(encoding="utf-8-sig"))
    existing = source["records"]
    if len(existing) != 100:
        raise RuntimeError("reviewed source catalog no longer contains exactly 100 records")
    clean = json.loads(CLEAN_LOCALIZATION_SOURCE.read_text(encoding="utf-8-sig"))
    terms_payload = json.loads(GENERATED_TERMS_SOURCE.read_text(encoding="utf-8-sig"))
    if terms_payload.get("schemaVersion") != 1:
        raise RuntimeError("unsupported generated recipe term schema")
    generated_terms = terms_payload.get("locales", {})
    if set(generated_terms) != set(ALL_LOCALES).difference(LOCALES):
        raise RuntimeError("generated recipe terms do not cover the 20 extended locales")
    cuisine_prefixes = terms_payload.get("cuisinePrefixes", {})
    expected_regions = {region for values in REGIONS.values() for region in values}
    if set(cuisine_prefixes) != set(ALL_LOCALES) or any(
        set(values) != expected_regions for values in cuisine_prefixes.values()
    ):
        raise RuntimeError("cuisine prefixes do not cover every locale and region")
    clean_by_id = {row["canonicalId"]: row for row in clean["records"]}
    if set(clean_by_id) != {row["canonicalId"] for row in existing}:
        raise RuntimeError("clean localization source canonical IDs do not match verified source")
    for record in existing:
        authoritative = clean_by_id[record["canonicalId"]]
        if authoritative["contentFingerprint"] != record["contentFingerprint"]:
            raise RuntimeError(f"clean localization fingerprint mismatch: {record['canonicalId']}")
        record["localizations"] = authoritative["localizations"]
        if record["canonicalId"] in CUISINE_OVERRIDES:
            record["countryTags"] = [CUISINE_OVERRIDES[record["canonicalId"]]]
    additions = [
        make_record(locale, index, generated_terms, cuisine_prefixes)
        for locale in LOCALES
        for index in range(280)
    ]
    records = [*existing, *additions]
    validate(records)
    payload = {"schemaVersion": 1, "claims": {"marketedRecipeCount": 1500,
        "marketedRecipeImageCount": source["claims"]["marketedRecipeImageCount"],
        "marketedNutritionVerifiedCount": source["claims"]["marketedNutritionVerifiedCount"]},
        "records": records}
    TARGET.write_text(json.dumps(payload, ensure_ascii=False, separators=(",", ":")) + "\n", encoding="utf-8")
    print("RECIPE_1500_GENERATION=PASS")
    print("PRESERVED_EXISTING=100")
    print("ADDED_ORIGINAL=1400")
    print("PRIMARY_LOCALE_SPLIT=ar:300,en:300,fr:300,es:300,tr:300")
    print(f"OUTPUT={TARGET}")


if __name__ == "__main__":
    main()
