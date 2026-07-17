import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'providers/daily_log_provider.dart';

class DailyLogPage extends ConsumerStatefulWidget {
 const DailyLogPage({super.key});

 @override
 ConsumerState<DailyLogPage> createState() => _DailyLogPageState();
}

class _DailyLogPageState extends ConsumerState<DailyLogPage> {
 final weight = TextEditingController();
 final calories = TextEditingController();
 final protein = TextEditingController();
 final carbs = TextEditingController();
 final fats = TextEditingController();
 final water = TextEditingController();
 final notes = TextEditingController();

 @override
 void dispose() {
  weight.dispose();
  calories.dispose();
  protein.dispose();
  carbs.dispose();
  fats.dispose();
  water.dispose();
  notes.dispose();
  super.dispose();
 }

 Future<void> _save() async {
  final repository = ref.read(dailyLogRepositoryProvider);

  await repository.save(
   date: DateTime.now(),
   weight: double.tryParse(weight.text),
   calories: int.tryParse(calories.text),
   protein: int.tryParse(protein.text),
   carbs: int.tryParse(carbs.text),
   fats: int.tryParse(fats.text),
   water: int.tryParse(water.text),
   notes: notes.text.trim().isEmpty ? null : notes.text.trim(),
  );

  final logs = await repository.getAll();
  debugPrint('Saved logs count: ${logs.length}');
  debugPrint(logs.toString());

  if (!mounted) return;

  Navigator.of(context).pop();
 }

 @override
 Widget build(BuildContext context) {
  return Scaffold(
   appBar: AppBar(title: const Text('Daily Log')),
   body: ListView(
    padding: const EdgeInsets.all(16),
    children: [
     _field(weight, 'Weight (kg)'),
     _field(calories, 'Calories'),
     _field(protein, 'Protein'),
     _field(carbs, 'Carbs'),
     _field(fats, 'Fats'),
     _field(water, 'Water (ml)'),
     _field(notes, 'Notes', lines: 4),
     const SizedBox(height: 20),
     FilledButton(
      onPressed: _save,
      child: const Text('Save'),
     ),
    ],
   ),
  );
 }

 Widget _field(
     TextEditingController controller,
     String label, {
      int lines = 1,
     }) {
  return Padding(
   padding: const EdgeInsets.only(bottom: 14),
   child: TextField(
    controller: controller,
    maxLines: lines,
    keyboardType:
    lines == 1 ? TextInputType.number : TextInputType.text,
    decoration: InputDecoration(
     labelText: label,
     border: const OutlineInputBorder(),
    ),
   ),
  );
 }
}