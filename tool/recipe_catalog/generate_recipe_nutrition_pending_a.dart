import 'dart:convert';
import 'dart:io';
import 'package:sqlite3/sqlite3.dart';

const sourcePath='artifacts/meal_catalog/recipe_canonical_100.json';
const outputPath='artifacts/meal_catalog/recipe_nutrition_pending_a.json';
const nutrientColumns=<String,String>{'kcal':'energy_kcal','proteinG':'protein_g','carbohydrateG':'carbs_g','fatG':'fat_g','fiberG':'fiber_g','sugarG':'sugars_g','sodiumMg':'sodium_mg','potassiumMg':'potassium_mg'};
const fdc=<String,int>{'chicken breast':171477,'onion':790646,'olive oil':171413,'pita bread':174915,'rice':169704,'yogurt':171284,'peas':170420,'chickpeas':173757,'tomato':170457,'cod':171956,'potato':170440,'bell pepper':170108,'ground turkey':171506,'kidney beans':175194,'black beans':173735,'pinto beans':175200,'white beans':175203,'eggplant':169229,'zucchini':169291,'split peas':172429,'turkey breast':171496,'carrot':168568,'celery':169988,'corn':169999,'trout':173718,'quinoa':168917,'green beans':169141,'maple syrup':169661,'turkey sausage':173871,'spinach':168462,'corn tortilla':175036,'cabbage':169975,'avocado':171705};

void main(){
 final source=jsonDecode(File(sourcePath).readAsStringSync()) as Map<String,dynamic>;
 final selected=(source['records'] as List).cast<Map<String,dynamic>>().where((r)=>(r['nutrition'] as Map)['status']=='pending').take(17).toList();
 final db=sqlite3.open('assets/catalogs/bil_food_core.sqlite',mode:OpenMode.readOnly);
 try{
  final out=selected.map((r){
   final blocked=<String>[]; final totals={for(final k in nutrientColumns.keys)k:0.0};
   final formulation=(r['ingredients'] as List).cast<Map<String,dynamic>>().map((i){
    final item=i['itemId'] as String; final id=fdc[item]; final grams=(i['grams'] as num).toDouble();
    if(id==null){blocked.add(item);return {'itemId':item,'grams':grams,'recordId':null,'sourceRefs':<String>[],'matchStatus':'blocked-no-local-usda-match'};}
    final rows=db.select('SELECT * FROM foods WHERE fdc_id=?',[id]); if(rows.length!=1)throw StateError('FDC $id missing/duplicated'); final row=rows.single;
    final per100=<String,double>{}; for(final e in nutrientColumns.entries){final v=row[e.value];if(v is! num)throw StateError('FDC $id lacks ${e.value}');per100[e.key]=v.toDouble();totals[e.key]=totals[e.key]!+v.toDouble()*grams/100;}
    return {'itemId':item,'quantity':grams,'unit':'g','grams':grams,'recordId':'usda:$id','fdcId':id,'sourceRefs':['usda:$id'],'sourceDescription':row['description'],'matchStatus':'selected','nutrientsPer100g':per100};
   }).toList();
   final servings=((r['serving'] as Map)['count'] as num).toDouble();
   return {'canonicalId':r['canonicalId'],'status':blocked.isEmpty?'verified-calculation':'blocked','blockedIngredientIds':blocked,'servings':servings,'formulation':formulation,'nutritionPerServing':blocked.isEmpty?{for(final e in totals.entries)e.key:_round(e.value/servings)}:{for(final k in nutrientColumns.keys)k:null},'calculationRevision':'bil-usda-local-pending-a-v1','timing':r['timing'],'method':r['method']};
  }).toList();
  File(outputPath).writeAsStringSync('${const JsonEncoder.withIndent('  ').convert({'schemaVersion':1,'batch':'pending-a','selection':'first 17 nutrition.status=pending','sourcePath':sourcePath,'recordCount':out.length,'calculationPolicy':{'formula':'sum(per100g * grams / 100) / servings','missingMatchPolicy':'blocked-not-zero'},'records':out})}\n');
 }finally{db.close();}
}
double _round(double v)=>(v*100).round()/100;
