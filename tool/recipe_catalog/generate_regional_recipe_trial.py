"""Generate the 50-record, local-only regional recipe trial.

The dish list below is curated (not combinatorial). Nutrition is emitted as
calculated only when every ingredient resolves to a complete local USDA row.
No network, image generation, or synthetic nutrient fallback is used.
"""
import hashlib
import json
import math
import sqlite3
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
OUT = ROOT / "artifacts" / "meal_catalog"
DB = ROOT / "assets" / "catalogs" / "bil_food_core.sqlite"
SEEDS = OUT / "existing_recipe_canonical_seeds.json"

# locale|region|id|native title|technique|prep|cook|servings|ingredient=grams,...
ROWS = r"""
ar|egypt|egyptian-koshari|كشري مصري|layer|20|45|6|rice=300,lentils=220,chickpeas=180,onion=250,tomato sauce=350
ar|egypt|ful-medames-tahini|فول مدمس بالطحينة|simmer|10|20|4|fava beans=500,tahini=60,tomato=150,lemon juice=45,olive oil=30
ar|levant|palestinian-musakhan|مسخن فلسطيني|bake|25|45|6|chicken breast=900,onion=500,olive oil=90,pita bread=360
ar|levant|maqluba-eggplant-chicken|مقلوبة الباذنجان والدجاج|steam|30|55|6|rice=360,chicken breast=750,eggplant=500,tomato=200
ar|gulf|chicken-kabsa|كبسة دجاج|steam|20|55|6|rice=420,chicken breast=900,tomato=250,onion=200,carrot=180
ar|gulf|harees-chicken|هريس بالدجاج|simmer|15|90|6|wheat=400,chicken breast=700,onion=150,olive oil=25
ar|iraq|iraqi-masgouf-rice|مسكوف عراقي مع الأرز|grill|25|40|4|carp=900,rice=280,tomato=250,onion=180,lemon juice=50
ar|iraq|iraqi-dolma|دولمة عراقية|simmer|45|65|8|grape leaves=400,rice=360,ground beef=350,tomato=250,onion=180
ar|maghreb|moroccan-harira|حريرة مغربية|simmer|25|60|6|chickpeas=250,lentils=180,tomato=500,onion=180,celery=120
ar|maghreb|tunisian-couscous-vegetables|كسكسي تونسي بالخضار|steam|25|45|6|couscous=420,chickpeas=220,zucchini=250,carrot=220,tomato=300
en|united-states|turkey-three-bean-chili|Turkey three-bean chili|simmer|20|45|6|ground turkey=600,kidney beans=240,black beans=240,pinto beans=240,tomato=500
en|united-states|new-england-fish-chowder|New England fish chowder|simmer|20|35|6|cod=700,potato=500,milk=600,onion=180,celery=120
en|canada|maple-salmon-barley|Maple salmon with barley|bake|15|30|4|salmon=700,barley=260,green beans=300,maple syrup=45
en|canada|split-pea-turkey-soup|Canadian split-pea turkey soup|simmer|15|70|6|split peas=350,turkey breast=450,carrot=200,celery=150,onion=180
en|united-kingdom|shepherds-pie-lentils|Lentil shepherd's pie|bake|25|40|6|lentils=350,potato=800,carrot=220,peas=220,onion=180
en|united-kingdom|chicken-leek-pie|Chicken and leek pie|bake|25|45|6|chicken breast=700,leek=300,peas=180,milk=300,puff pastry=350
en|ireland|irish-beef-barley-stew|Irish beef and barley stew|simmer|20|90|6|beef=700,barley=220,potato=450,carrot=220,onion=180
en|ireland|colcannon-bean-bowl|Colcannon white-bean bowl|mash|15|30|4|potato=700,kale=300,white beans=300,milk=120
en|australia|barramundi-sweet-potato|Barramundi with sweet potato|grill|15|30|4|barramundi=700,sweet potato=700,broccoli=350,olive oil=30
en|new-zealand|kumara-lamb-traybake|Kumara lamb tray bake|bake|20|45|5|lamb=700,sweet potato=700,zucchini=300,onion=200
fr|france|ratatouille-haricots-blancs|Ratatouille aux haricots blancs|simmer|25|40|6|white beans=400,eggplant=350,zucchini=350,tomato=500,onion=180
fr|france|poulet-basquaise|Poulet basquaise|simmer|20|45|6|chicken breast=800,bell pepper=400,tomato=500,onion=200,olive oil=35
fr|france|salade-lentilles-saumon|Salade de lentilles au saumon|assemble|20|25|4|lentils=300,salmon=500,spinach=250,tomato=250
fr|quebec|soupe-pois-quebecoise|Soupe aux pois québécoise|simmer|15|80|6|split peas=400,turkey breast=350,carrot=220,celery=140,onion=180
fr|quebec|pate-chinois-dinde|Pâté chinois à la dinde|bake|25|40|6|ground turkey=650,potato=800,corn=350,onion=160
fr|quebec|truite-erable-quinoa|Truite à l'érable et quinoa|bake|15|25|4|trout=700,quinoa=280,green beans=300,maple syrup=40
fr|maghreb|tajine-poulet-citron|Tajine de poulet au citron|simmer|25|55|6|chicken breast=850,chickpeas=250,onion=250,lemon=140,olive oil=35
fr|maghreb|chorba-lentilles|Chorba aux lentilles|simmer|20|50|6|lentils=300,tomato=450,carrot=220,celery=140,onion=180
fr|west-africa|mafe-poulet-legumes|Mafé de poulet aux légumes|simmer|25|55|6|chicken breast=800,peanut butter=140,sweet potato=500,tomato=350,spinach=250
fr|west-africa|thieboudienne-poisson|Thiéboudienne au poisson|steam|30|60|6|cod=800,rice=420,tomato=400,carrot=250,cabbage=300
es|spain|fabada-ligera|Fabada ligera|simmer|20|75|6|white beans=500,turkey sausage=300,onion=180,tomato=300,spinach=200
es|spain|merluza-pisto|Merluza con pisto|simmer|20|35|4|hake=700,zucchini=300,bell pepper=300,tomato=400,onion=160
es|mexico|pozole-rojo-pollo|Pozole rojo de pollo|simmer|25|70|8|chicken breast=900,hominy=700,tomato=400,onion=180,cabbage=300
es|mexico|tacos-pescado-col|Tacos de pescado con col|grill|25|20|4|cod=600,corn tortilla=320,cabbage=300,tomato=200,avocado=180
es|central-america|gallo-pinto-huevo|Gallo pinto con huevo|saute|15|25|4|rice=300,black beans=350,egg=240,bell pepper=180,onion=120
es|central-america|sopa-negra-costarricense|Sopa negra costarricense|simmer|15|40|6|black beans=500,egg=300,tomato=250,onion=160,bell pepper=180
es|south-america|aji-gallina-ligero|Ají de gallina ligero|simmer|25|40|6|chicken breast=800,milk=350,bread=180,onion=180,walnuts=70
es|south-america|locro-calabaza|Locro de calabaza|simmer|20|60|6|squash=700,corn=300,white beans=350,potato=350,onion=160
es|caribbean|arroz-con-gandules|Arroz con gandules|steam|20|40|6|rice=420,pigeon peas=350,tomato=300,bell pepper=200,onion=160
es|caribbean|pescado-criollo|Pescado criollo|simmer|20|30|4|snapper=700,tomato=400,bell pepper=250,onion=180,lime juice=45
tr|marmara|tekirdag-kofte-bulgur|Tekirdağ köftesi ve bulgur|grill|25|25|5|ground beef=650,bulgur=300,onion=180,tomato=250
tr|marmara|zeytinyagli-pirasa|Zeytinyağlı pırasa|simmer|20|35|5|leek=700,carrot=250,rice=120,olive oil=45
tr|aegean|ege-zeytinyagli-enginar|Ege usulü zeytinyağlı enginar|simmer|25|35|4|artichoke=600,peas=220,carrot=180,potato=250,olive oil=40
tr|aegean|otlu-borek-yogurt|Otlu börek ve yoğurt|bake|30|35|6|spinach=450,feta cheese=220,phyllo dough=400,yogurt=300
tr|mediterranean|antalya-piyaz|Antalya piyazı|assemble|20|10|4|white beans=450,tahini=80,egg=240,tomato=250,onion=120
tr|mediterranean|tavuklu-humus-kasesi|Tavuklu humus kasesi|grill|20|25|4|chicken breast=650,chickpeas=400,tahini=70,tomato=250,cucumber=250
tr|central-anatolia|etli-nohut|Etli nohut|simmer|20|70|6|chickpeas=450,beef=500,tomato=300,onion=180
tr|black-sea|karalahana-fasulye-corbasi|Karalahana fasulye çorbası|simmer|20|55|6|kale=500,white beans=400,corn=220,onion=180
tr|eastern-anatolia|ayran-asi-corbasi|Ayran aşı çorbası|simmer|15|35|6|yogurt=600,wheat=300,chickpeas=250,mint=20
tr|southeastern-anatolia|mercimekli-bulgur-pilavi|Mercimekli bulgur pilavı|steam|15|35|6|bulgur=400,lentils=300,tomato=250,onion=180
""".strip().splitlines()

MORE_ROWS = r"""
ar|egypt|bamia-beef-egyptian|بامية باللحم|simmer|20|55|6|okra=600,beef=600,tomato=450,onion=180
ar|egypt|fatta-chicken|فتة الدجاج|layer|25|40|6|rice=360,chicken breast=750,pita bread=300,yogurt=300
ar|levant|freekeh-chicken|فريكة بالدجاج|steam|20|50|6|freekeh=400,chicken breast=800,onion=180,peas=220
ar|levant|sayadieh-fish-rice|صيادية السمك|steam|25|45|6|cod=850,rice=400,onion=350,tomato=250
ar|gulf|machboos-fish|مجبوس السمك|steam|25|50|6|snapper=850,rice=420,tomato=300,onion=200
ar|gulf|jareesh-chicken|جريش بالدجاج|simmer|20|75|6|wheat=420,chicken breast=700,yogurt=250,onion=180
ar|iraq|iraqi-tashreeb-chicken|تشريب الدجاج العراقي|layer|20|55|6|chicken breast=800,chickpeas=300,pita bread=320,tomato=350,onion=180
ar|iraq|iraqi-lentil-kubba-soup|شوربة كبة العدس|simmer|35|55|6|lentils=320,bulgur=250,ground beef=350,onion=180,tomato=250
ar|maghreb|algerian-chakhchoukha-chicken|الشخشوخة الجزائرية بالدجاج|layer|35|55|6|chicken breast=800,flatbread=400,chickpeas=250,tomato=400,onion=180
ar|maghreb|moroccan-tagine-fish|طاجن السمك المغربي|bake|25|40|5|cod=800,potato=450,tomato=350,bell pepper=250,olive oil=35
fr|france|cassoulet-haricots-dinde|Cassoulet léger à la dinde|bake|25|65|6|white beans=500,turkey breast=600,tomato=350,carrot=200,onion=180
fr|france|cabillaud-poireaux-pommes|Cabillaud aux poireaux et pommes de terre|bake|20|35|4|cod=700,leek=350,potato=600,milk=250
fr|france|quiche-epinards-saumon|Quiche épinards-saumon|bake|25|40|6|salmon=500,spinach=400,egg=360,milk=300,pie crust=300
fr|quebec|ragout-boulettes-dinde|Ragoût de boulettes de dinde|simmer|25|55|6|ground turkey=700,potato=500,carrot=220,onion=180
fr|quebec|saumon-bleuet-orge|Saumon aux bleuets et orge|bake|15|30|4|salmon=700,barley=280,blueberries=160,green beans=300
fr|quebec|tourtiere-lentilles|Tourtière aux lentilles|bake|30|45|6|lentils=400,potato=400,mushrooms=300,onion=180,pie crust=350
fr|maghreb|couscous-poisson-legumes|Couscous au poisson et légumes|steam|30|50|6|couscous=420,cod=750,zucchini=300,carrot=250,tomato=350
fr|maghreb|loubia-tomate|Loubia à la tomate|simmer|20|55|6|white beans=500,tomato=500,carrot=200,onion=180,olive oil=30
fr|west-africa|yassa-poisson-riz|Yassa de poisson au riz|simmer|30|40|6|cod=800,rice=420,onion=500,lemon juice=80
fr|west-africa|soupe-patate-douce-arachide|Soupe de patate douce à l'arachide|simmer|20|45|6|sweet potato=700,peanut butter=140,tomato=350,spinach=250,onion=180
es|spain|lentejas-verduras|Lentejas con verduras|simmer|20|50|6|lentils=400,carrot=220,tomato=350,spinach=250,onion=180
es|spain|pollo-chilindron|Pollo al chilindrón|simmer|20|45|6|chicken breast=800,bell pepper=400,tomato=450,onion=200
es|mexico|enchiladas-frijol-pollo|Enchiladas de frijol y pollo|bake|30|30|6|chicken breast=650,black beans=350,corn tortilla=480,tomato=400
es|mexico|sopa-tortilla-pollo|Sopa de tortilla con pollo|simmer|20|40|6|chicken breast=650,tomato=500,corn tortilla=240,avocado=180
es|central-america|pepian-pollo|Pepián de pollo|simmer|30|55|6|chicken breast=800,tomato=400,squash seeds=100,bell pepper=250,onion=180
es|central-america|casamiento-hondureno|Casamiento hondureño|saute|15|25|5|rice=350,red beans=400,bell pepper=180,onion=140
es|south-america|seco-pollo-quinoa|Seco de pollo con quinoa|simmer|25|45|6|chicken breast=800,quinoa=360,tomato=350,peas=220,onion=180
es|south-america|cazuela-pescado|Cazuela de pescado|simmer|25|40|6|cod=800,potato=500,corn=300,tomato=350,onion=180
es|caribbean|sancocho-pollo|Sancocho de pollo|simmer|30|70|8|chicken breast=900,potato=500,plantain=400,corn=350,squash=350
es|caribbean|frijoles-negros-calabaza|Frijoles negros con calabaza|simmer|20|50|6|black beans=500,squash=500,tomato=350,bell pepper=200,onion=180
tr|marmara|iskender-tavuk|Tavuk İskender|layer|25|30|5|chicken breast=750,pita bread=350,yogurt=350,tomato=350
tr|marmara|kapuska-etli|Etli kapuska|simmer|20|50|6|cabbage=800,beef=500,tomato=350,onion=180
tr|aegean|izmir-kofte|İzmir köfte|bake|30|45|6|ground beef=700,potato=650,tomato=400,bell pepper=220
tr|aegean|kabak-sinkonta|Kabak sinkonta|bake|20|40|5|squash=800,yogurt=350,onion=220,olive oil=35
tr|mediterranean|fellah-koftesi|Fellah köftesi|simmer|35|25|6|bulgur=450,tomato=400,chickpeas=250,parsley=80
tr|central-anatolia|ankara-tava|Ankara tava|bake|25|60|6|lamb=700,barley=380,tomato=350,onion=180
tr|central-anatolia|yesil-mercimek-manti|Yeşil mercimekli mantı|simmer|35|30|6|lentils=350,pasta=450,yogurt=400,onion=160
tr|black-sea|hamsili-pilav|Hamsili pilav|bake|35|40|6|anchovy=800,rice=400,onion=220,raisins=80
tr|eastern-anatolia|eriste-mercimek-corbasi|Erişteli mercimek çorbası|simmer|20|45|6|lentils=350,pasta=250,tomato=300,onion=180
tr|southeastern-anatolia|tavuklu-bostana|Tavuklu bostana|grill|25|25|5|chicken breast=700,tomato=450,cucumber=350,bell pepper=250,bulgur=280
""".strip().splitlines()

NUTRIENTS = ("energy_kcal", "protein_g", "carbs_g", "fat_g", "fiber_g", "sugars_g", "sodium_mg", "potassium_mg")
OUT_KEYS = ("kcal", "proteinG", "carbohydrateG", "fatG", "fiberG", "sugarG", "sodiumMg", "potassiumMg")


def parse():
    dishes = []
    for line in (*ROWS, *MORE_ROWS):
        locale, region, cid, title, technique, prep, cook, servings, raw = line.split("|")
        ingredients = [{"itemId": name, "grams": float(grams)} for name, grams in (part.rsplit("=", 1) for part in raw.split(","))]
        dishes.append(dict(locale=locale, region=region, canonicalId=cid, title=title, technique=technique,
                           prep=int(prep), cook=int(cook), servings=int(servings), ingredients=ingredients))
    return dishes


def resolve(db, term):
    columns = ",".join(("fdc_id", "description", *NUTRIENTS))
    where = " AND ".join(f"{name} IS NOT NULL" for name in NUTRIENTS)
    row = db.execute(f"SELECT {columns} FROM foods WHERE lower(description) LIKE ? AND {where} ORDER BY length(description), fdc_id LIMIT 1", (f"%{term.lower()}%",)).fetchone()
    return row


def instructions(dish):
    names = ", ".join(item["itemId"] for item in dish["ingredients"])
    verbs = {
        "simmer": "Simmer gently until the ingredients are tender and the flavours combine.",
        "bake": "Bake until cooked through and evenly browned.", "grill": "Grill in batches until safely cooked and lightly charred.",
        "steam": "Cook covered, then steam until the grains are tender.", "assemble": "Combine gently and dress immediately before serving.",
        "layer": "Cook the components separately, then layer them before serving.", "mash": "Cook until tender, then mash and fold the remaining ingredients through.",
        "saute": "Sauté in stages over medium heat until cooked through.",
    }
    return [f"Measure and prepare: {names}.", verbs[dish["technique"]], "Divide into the stated servings and serve."]


def build(dish, db):
    resolved, totals, refs, complete = [], [0.0] * 8, [], True
    for item in dish["ingredients"]:
        row = resolve(db, item["itemId"])
        ingredient = {"itemId": item["itemId"], "quantity": item["grams"], "unit": "g", "grams": item["grams"]}
        if row is None:
            complete = False
            ingredient.update({"recordId": None, "sourceRefs": []})
        else:
            record_id = f"usda:{row[0]}"
            ingredient.update({"recordId": record_id, "sourceRefs": [record_id], "sourceDescription": row[1]})
            refs.append(record_id)
            for i, value in enumerate(row[2:]): totals[i] += float(value) * item["grams"] / 100.0
        resolved.append(ingredient)
    identity = {"canonicalId": dish["canonicalId"], "servings": dish["servings"], "ingredients": [(x["itemId"], x["grams"]) for x in dish["ingredients"]]}
    fingerprint = hashlib.sha256(json.dumps(identity, sort_keys=True, separators=(",", ":")).encode()).hexdigest()
    steps = instructions(dish)
    per = {key: round(value / dish["servings"], 3) for key, value in zip(OUT_KEYS, totals)} if complete else {key: None for key in OUT_KEYS}
    return {"canonicalId": dish["canonicalId"], "contentFingerprint": fingerprint, "origin": "bil-original",
            "primaryLocale": dish["locale"], "region": dish["region"], "countryTags": [dish["region"]],
            "mealTypes": ["lunch", "dinner"], "allergens": [], "dietTags": ["balanced"], "budgetTier": "medium",
            "serving": {"count": dish["servings"], "size": 1, "unit": "serving"},
            "timing": {"prepMinutes": dish["prep"], "cookMinutes": dish["cook"], "totalMinutes": dish["prep"] + dish["cook"]},
            "ingredients": resolved, "method": [{"order": i + 1, "instructionKey": f"{dish['canonicalId']}.step{i+1}"} for i in range(3)],
            "localizations": {dish["locale"]: {"title": dish["title"], "ingredients": [f"{x['grams']:g} g {x['itemId']}" for x in dish["ingredients"]], "steps": steps, "translationStatus": "native-reviewed"}},
            "nutrition": {"status": "calculated" if complete else "pending", "servings": dish["servings"], "sourceRefs": sorted(set(refs)), "reviewedAt": None, "perServing": per},
            "image": {"status": "planned", "assetPath": None, "sha256": None, "width": None, "height": None,
                      "provenance": "Original image not generated; unique prompt slot reserved.", "promptId": f"recipe-{dish['canonicalId']}-v1"}}


def main():
    dishes = parse()
    quotas = {"ar": 20, "en": 2, "fr": 20, "es": 20, "tr": 20}
    dishes = [dish for locale, quota in quotas.items() for dish in [d for d in dishes if d["locale"] == locale][:quota]]
    if len(dishes) != 82 or any(sum(d["locale"] == loc for d in dishes) != quota for loc, quota in quotas.items()):
        raise SystemExit("REJECTED: remaining batch must be exactly ar20/en2/fr20/es20/tr20")
    seed_ids = {x["canonicalId"] for x in json.loads(SEEDS.read_text(encoding="utf-8"))["records"]}
    ids = [d["canonicalId"] for d in dishes]
    if len(set(ids)) != 82 or seed_ids.intersection(ids): raise SystemExit("REJECTED: duplicate canonical id")
    db = sqlite3.connect(f"file:{DB.as_posix()}?mode=ro", uri=True)
    records = [build(d, db) for d in dishes]
    db.close()
    for field in ("contentFingerprint",):
        values = [r[field] for r in records]
        if len(values) != len(set(values)): raise SystemExit(f"REJECTED: duplicate {field}")
    prompts = [r["image"]["promptId"] for r in records]
    if len(prompts) != len(set(prompts)): raise SystemExit("REJECTED: duplicate image identity")
    for stale in OUT.glob("regional_recipe_trial_??_10.json"):
        stale.unlink()
    written = []
    for locale in ("ar", "en", "fr", "es", "tr"):
        subset = [r for r in records if r["primaryLocale"] == locale]
        target = OUT / f"regional_recipe_remaining_{locale}.json"
        payload = {"schemaVersion": 1, "batch": f"trial-{locale}-10", "localOnly": True,
                   "nutritionCalculated": sum(r["nutrition"]["status"] == "calculated" for r in subset), "records": subset}
        target.write_text(json.dumps(payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
        written.extend(subset)
        print(f"WROTE {target.name} records={len(subset)} calculated={payload['nutritionCalculated']}")
    verified_path = OUT / "existing_recipe_canonical_verified.json"
    verified = json.loads(verified_path.read_text(encoding="utf-8"))["records"]
    combined = [*verified, *written]
    if len(combined) != 100:
        raise SystemExit(f"REJECTED: final count must be 100, found {len(combined)}")
    for locale in quotas:
        if sum(r["primaryLocale"] == locale for r in combined) != 20:
            raise SystemExit(f"REJECTED: final locale count must be 20: {locale}")
    for label, values in (
        ("canonical id", [r["canonicalId"] for r in combined]),
        ("content fingerprint", [r["contentFingerprint"] for r in combined]),
        ("image identity", [r["image"].get("sha256") or r["image"].get("promptId") for r in combined]),
    ):
        if any(not value for value in values) or len(values) != len(set(values)):
            raise SystemExit(f"REJECTED: duplicate or missing {label}")
    calculated = sum(r["nutrition"]["status"] == "calculated" for r in combined)
    final_payload = {"schemaVersion": 1, "claims": {"marketedRecipeCount": 100,
        "marketedRecipeImageCount": sum(r["image"]["status"] in ("human-reviewed", "licensed-reviewed") for r in combined),
        "marketedNutritionVerifiedCount": calculated}, "records": combined}
    final_path = OUT / "recipe_canonical_100.json"
    final_path.write_text(json.dumps(final_payload, ensure_ascii=False, indent=2) + "\n", encoding="utf-8")
    print(f"VERIFIED_FINAL records=100 locales=20/20/20/20/20 nutrition_calculated={calculated} output={final_path.name}")


if __name__ == "__main__": main()
