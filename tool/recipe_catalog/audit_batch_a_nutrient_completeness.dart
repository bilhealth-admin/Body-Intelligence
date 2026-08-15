import 'package:sqlite3/sqlite3.dart';

void main() {
  final db = sqlite3.open('assets/catalogs/bil_food_core.sqlite', mode: OpenMode.readOnly);
  const ids = [174284,790646,2258586,170923,173647,2259793,2346396,1105897,2346563,173757,321360,2346406,170416,167747,173424,171956,2685583,167746,331960,169704,2346407,172420,168462,2262108,174915,168917];
  const cols = ['energy_kcal','protein_g','carbs_g','fat_g','fiber_g','sugars_g','sodium_mg','potassium_mg'];
  for (final id in ids) {
    final r = db.select('SELECT * FROM foods WHERE fdc_id=?',[id]).single;
    final missing = cols.where((c)=>r[c] == null).join(',');
    print('$id\t${r['description']}\tmissing=$missing');
  }
  const terms = ['lentil','carrot','yogurt, plain','oats','almond','tomato','cucumber','zucchini','chicken%breast','cabbage','tahini'];
  for (final term in terms) {
    final rows = db.select("SELECT fdc_id,description FROM foods WHERE lower(description) LIKE ? AND energy_kcal IS NOT NULL AND protein_g IS NOT NULL AND carbs_g IS NOT NULL AND fat_g IS NOT NULL AND fiber_g IS NOT NULL AND sugars_g IS NOT NULL AND sodium_mg IS NOT NULL AND potassium_mg IS NOT NULL LIMIT 5", ['%$term%']);
    print('\n$term');
    for (final r in rows) print('${r['fdc_id']}\t${r['description']}');
  }
  for (final pattern in ['%almonds, dry roasted, without salt%','%Nuts, almonds, raw%','%Tomatoes, red, ripe, raw%','%Cabbage, raw%','%breast, meat only, cooked, roasted%','%oats, regular%']) {
    final rows = db.select("SELECT fdc_id,description FROM foods WHERE description LIKE ? AND energy_kcal IS NOT NULL AND protein_g IS NOT NULL AND carbs_g IS NOT NULL AND fat_g IS NOT NULL AND fiber_g IS NOT NULL AND sugars_g IS NOT NULL AND sodium_mg IS NOT NULL AND potassium_mg IS NOT NULL LIMIT 10", [pattern]);
    print('\n$pattern'); for (final r in rows) print('${r['fdc_id']}\t${r['description']}');
  }
  db.close();
}
// ignore_for_file: avoid_print, curly_braces_in_flow_control_structures
