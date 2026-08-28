import 'diet_macro_plan.dart';
import 'nutrition_pathway.dart';
import 'pathways/carb_cycling.dart';
import 'pathways/dash.dart';
import 'pathways/high_protein.dart';
import 'pathways/keto.dart';
import 'pathways/lean_mass.dart';
import 'pathways/low_carb.dart';
import 'pathways/mediterranean.dart';
import 'pathways/plant_forward.dart';
import 'pathways/pregnancy.dart';
import 'pathways/psmf.dart';
import 'pathways/smart_fat_loss.dart';

const nutritionPathways = <NutritionPathway>[
  carbCyclingPathway,
  smartFatLossPathway,
  leanMassPathway,
  mediterraneanPathway,
  highProteinPathway,
  plantForwardPathway,
  dashPathway,
  lowCarbPathway,
  ketoPathway,
  pregnancyPathway,
  psmfPathway,
];

final dietPresets = <String, DietPreset>{
  carbCyclingPreset.pathwayId: carbCyclingPreset,
  smartFatLossPreset.pathwayId: smartFatLossPreset,
  leanMassPreset.pathwayId: leanMassPreset,
  mediterraneanPreset.pathwayId: mediterraneanPreset,
  highProteinPreset.pathwayId: highProteinPreset,
  plantForwardPreset.pathwayId: plantForwardPreset,
  dashPreset.pathwayId: dashPreset,
  lowCarbPreset.pathwayId: lowCarbPreset,
  ketoPreset.pathwayId: ketoPreset,
  pregnancyPreset.pathwayId: pregnancyPreset,
};
