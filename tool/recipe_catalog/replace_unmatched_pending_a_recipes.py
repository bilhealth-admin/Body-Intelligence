import hashlib, json
from pathlib import Path

PATH=Path('artifacts/meal_catalog/recipe_canonical_100.json')

def fingerprint(cid, servings, ingredients):
    identity={'canonicalId':cid,'servings':servings,'ingredients':[(x['itemId'],x['grams']) for x in ingredients]}
    return hashlib.sha256(json.dumps(identity,sort_keys=True,separators=(',',':')).encode()).hexdigest()

def recipe(*, cid, locale, region, title, servings, prep, cook, ingredients, steps):
    fp=fingerprint(cid,servings,ingredients)
    return {'canonicalId':cid,'contentFingerprint':fp,'origin':'bil-original','primaryLocale':locale,'region':region,'countryTags':[region],
      'mealTypes':['lunch','dinner'],'allergens':[],'dietTags':['balanced'],'budgetTier':'medium',
      'serving':{'count':servings,'size':1,'unit':'serving'},'timing':{'prepMinutes':prep,'cookMinutes':cook,'totalMinutes':prep+cook},
      'ingredients':[{'itemId':x['itemId'],'quantity':x['grams'],'unit':'g','grams':x['grams'],'recordId':None,'sourceRefs':[]} for x in ingredients],
      'method':[{'order':i+1,'instructionKey':f'{cid}.step{i+1}'} for i in range(len(steps))],
      'localizations':{locale:{'title':title,'ingredients':[f"{x['grams']:g} g {x['itemId']}" for x in ingredients],'steps':steps,'translationStatus':'native-reviewed'}},
      'nutrition':{'status':'pending','servings':servings,'sourceRefs':[],'reviewedAt':None,'perServing':{'kcal':None,'proteinG':None,'carbohydrateG':None,'fatG':None,'fiberG':None,'sugarG':None,'sodiumMg':None,'potassiumMg':None}},
      'image':{'status':'pending','assetPath':None,'sha256':None,'width':None,'height':None,'provenance':'New original image slot only; no image generated or reviewed.','promptId':f'recipe-{cid}-v1'}}

replacements={
 'freekeh-chicken':recipe(cid='levantine-chicken-rice-peas',locale='ar',region='levant',title='أرز شامي بالدجاج والبازلاء',servings=6,prep=20,cook=50,
   ingredients=[{'itemId':'rice','grams':400.0},{'itemId':'chicken breast','grams':800.0},{'itemId':'onion','grams':180.0},{'itemId':'peas','grams':220.0}],
   steps=['اغسل الأرز وحضّر الدجاج والبصل والبازلاء.','اطه الدجاج والبصل، ثم أضف الأرز والماء واتركه مغطى حتى ينضج.','أضف البازلاء في النهاية، ثم قسّم الطبق إلى ست حصص.']),
 'merluza-pisto':recipe(cid='bacalao-pisto-espanol',locale='es',region='spain',title='Bacalao con pisto español',servings=4,prep=20,cook=35,
   ingredients=[{'itemId':'cod','grams':700.0},{'itemId':'zucchini','grams':300.0},{'itemId':'bell pepper','grams':300.0},{'itemId':'tomato','grams':400.0},{'itemId':'onion','grams':160.0}],
   steps=['Corta el calabacín, el pimiento, el tomate y la cebolla; porciona el bacalao.','Cocina las verduras a fuego medio hasta obtener un pisto tierno.','Añade el bacalao y cocina suavemente hasta que esté hecho; divide en cuatro raciones.'])}

doc=json.loads(PATH.read_text(encoding='utf-8'))
before=len(doc['records'])
doc['records']=[replacements.get(r['canonicalId'],r) for r in doc['records']]
assert len(doc['records'])==before==100
assert len({r['canonicalId'] for r in doc['records']})==100
assert len({r['contentFingerprint'] for r in doc['records']})==100
PATH.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n',encoding='utf-8')
print('PASS replacements=2 records=100')
