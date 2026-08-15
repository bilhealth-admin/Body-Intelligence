import 'package:body_intelligence_log/features/nutrition/repositories/usda_core_catalog_repository.dart';
import 'package:sqlite3/sqlite3.dart';

Future<void> main() async {
  final repo=UsdaCoreCatalogRepository.open('assets/catalogs/bil_food_core.sqlite');
  final db=sqlite3.open('assets/catalogs/bil_food_core.sqlite',mode:OpenMode.readOnly);
  const q=['olive oil','freekeh cooked','peas green cooked','potato cooked','pepper sweet red raw','turkey ground cooked','kidney beans cooked','black beans cooked','pinto beans cooked','white beans cooked','eggplant cooked','split peas cooked','turkey breast roasted','celery raw','corn sweet cooked','trout cooked','green beans cooked','maple syrup','turkey sausage cooked','hake cooked','corn tortilla','avocado raw'];
  const cols=['energy_kcal','protein_g','carbs_g','fat_g','fiber_g','sugars_g','sodium_mg','potassium_mg'];
  for(final query in q){ print('\n$query'); for(final h in await repo.searchUnified(query,limit:5)){final id=int.parse(h.food.id.substring(5));final r=db.select('SELECT * FROM foods WHERE fdc_id=?',[id]).single; final missing=cols.where((c)=>r[c]==null).join(',');print('$id\t${r['description']}\tmissing=$missing');}}
  for(final pattern in ['%Oil, olive, salad or cooking%','%Potatoes, boiled%','%Celery, raw%','%Tortillas, ready-to-bake or -fry, corn%','%Avocados, raw%','%Fish, hake%','%freekeh%']){print('\nPATTERN $pattern');final rows=db.select("SELECT fdc_id,description FROM foods WHERE description LIKE ? AND energy_kcal IS NOT NULL AND protein_g IS NOT NULL AND carbs_g IS NOT NULL AND fat_g IS NOT NULL AND fiber_g IS NOT NULL AND sugars_g IS NOT NULL AND sodium_mg IS NOT NULL AND potassium_mg IS NOT NULL LIMIT 10",[pattern]);for(final r in rows)print('${r['fdc_id']}\t${r['description']}');}
  repo.close();db.close();
}
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures
