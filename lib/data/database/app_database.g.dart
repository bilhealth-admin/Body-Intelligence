// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $DailyLogsTable extends DailyLogs
    with TableInfo<$DailyLogsTable, DailyLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DailyLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<int> calories = GeneratedColumn<int>(
    'calories',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _proteinMeta = const VerificationMeta(
    'protein',
  );
  @override
  late final GeneratedColumn<int> protein = GeneratedColumn<int>(
    'protein',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _carbsMeta = const VerificationMeta('carbs');
  @override
  late final GeneratedColumn<int> carbs = GeneratedColumn<int>(
    'carbs',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _fatsMeta = const VerificationMeta('fats');
  @override
  late final GeneratedColumn<int> fats = GeneratedColumn<int>(
    'fats',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _waterMeta = const VerificationMeta('water');
  @override
  late final GeneratedColumn<int> water = GeneratedColumn<int>(
    'water',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _notesMeta = const VerificationMeta('notes');
  @override
  late final GeneratedColumn<String> notes = GeneratedColumn<String>(
    'notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sleepHoursMeta = const VerificationMeta(
    'sleepHours',
  );
  @override
  late final GeneratedColumn<double> sleepHours = GeneratedColumn<double>(
    'sleep_hours',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _stepsMeta = const VerificationMeta('steps');
  @override
  late final GeneratedColumn<int> steps = GeneratedColumn<int>(
    'steps',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _exerciseNotesMeta = const VerificationMeta(
    'exerciseNotes',
  );
  @override
  late final GeneratedColumn<String> exerciseNotes = GeneratedColumn<String>(
    'exercise_notes',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    date,
    dayKey,
    weight,
    calories,
    protein,
    carbs,
    fats,
    water,
    notes,
    sleepHours,
    steps,
    exerciseNotes,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'daily_logs';
  @override
  VerificationContext validateIntegrity(
    Insertable<DailyLog> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    }
    if (data.containsKey('protein')) {
      context.handle(
        _proteinMeta,
        protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta),
      );
    }
    if (data.containsKey('carbs')) {
      context.handle(
        _carbsMeta,
        carbs.isAcceptableOrUnknown(data['carbs']!, _carbsMeta),
      );
    }
    if (data.containsKey('fats')) {
      context.handle(
        _fatsMeta,
        fats.isAcceptableOrUnknown(data['fats']!, _fatsMeta),
      );
    }
    if (data.containsKey('water')) {
      context.handle(
        _waterMeta,
        water.isAcceptableOrUnknown(data['water']!, _waterMeta),
      );
    }
    if (data.containsKey('notes')) {
      context.handle(
        _notesMeta,
        notes.isAcceptableOrUnknown(data['notes']!, _notesMeta),
      );
    }
    if (data.containsKey('sleep_hours')) {
      context.handle(
        _sleepHoursMeta,
        sleepHours.isAcceptableOrUnknown(data['sleep_hours']!, _sleepHoursMeta),
      );
    }
    if (data.containsKey('steps')) {
      context.handle(
        _stepsMeta,
        steps.isAcceptableOrUnknown(data['steps']!, _stepsMeta),
      );
    }
    if (data.containsKey('exercise_notes')) {
      context.handle(
        _exerciseNotesMeta,
        exerciseNotes.isAcceptableOrUnknown(
          data['exercise_notes']!,
          _exerciseNotesMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DailyLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DailyLog(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      ),
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}calories'],
      ),
      protein: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}protein'],
      ),
      carbs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}carbs'],
      ),
      fats: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}fats'],
      ),
      water: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}water'],
      ),
      notes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}notes'],
      ),
      sleepHours: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sleep_hours'],
      ),
      steps: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}steps'],
      ),
      exerciseNotes: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}exercise_notes'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $DailyLogsTable createAlias(String alias) {
    return $DailyLogsTable(attachedDatabase, alias);
  }
}

class DailyLog extends DataClass implements Insertable<DailyLog> {
  final int id;
  final String uuid;
  final DateTime date;
  final String dayKey;
  final double? weight;
  final int? calories;
  final int? protein;
  final int? carbs;
  final int? fats;
  final int? water;
  final String? notes;
  final double? sleepHours;
  final int? steps;
  final String? exerciseNotes;
  final DateTime createdAt;
  final DateTime updatedAt;
  const DailyLog({
    required this.id,
    required this.uuid,
    required this.date,
    required this.dayKey,
    this.weight,
    this.calories,
    this.protein,
    this.carbs,
    this.fats,
    this.water,
    this.notes,
    this.sleepHours,
    this.steps,
    this.exerciseNotes,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['date'] = Variable<DateTime>(date);
    map['day_key'] = Variable<String>(dayKey);
    if (!nullToAbsent || weight != null) {
      map['weight'] = Variable<double>(weight);
    }
    if (!nullToAbsent || calories != null) {
      map['calories'] = Variable<int>(calories);
    }
    if (!nullToAbsent || protein != null) {
      map['protein'] = Variable<int>(protein);
    }
    if (!nullToAbsent || carbs != null) {
      map['carbs'] = Variable<int>(carbs);
    }
    if (!nullToAbsent || fats != null) {
      map['fats'] = Variable<int>(fats);
    }
    if (!nullToAbsent || water != null) {
      map['water'] = Variable<int>(water);
    }
    if (!nullToAbsent || notes != null) {
      map['notes'] = Variable<String>(notes);
    }
    if (!nullToAbsent || sleepHours != null) {
      map['sleep_hours'] = Variable<double>(sleepHours);
    }
    if (!nullToAbsent || steps != null) {
      map['steps'] = Variable<int>(steps);
    }
    if (!nullToAbsent || exerciseNotes != null) {
      map['exercise_notes'] = Variable<String>(exerciseNotes);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  DailyLogsCompanion toCompanion(bool nullToAbsent) {
    return DailyLogsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      date: Value(date),
      dayKey: Value(dayKey),
      weight: weight == null && nullToAbsent
          ? const Value.absent()
          : Value(weight),
      calories: calories == null && nullToAbsent
          ? const Value.absent()
          : Value(calories),
      protein: protein == null && nullToAbsent
          ? const Value.absent()
          : Value(protein),
      carbs: carbs == null && nullToAbsent
          ? const Value.absent()
          : Value(carbs),
      fats: fats == null && nullToAbsent ? const Value.absent() : Value(fats),
      water: water == null && nullToAbsent
          ? const Value.absent()
          : Value(water),
      notes: notes == null && nullToAbsent
          ? const Value.absent()
          : Value(notes),
      sleepHours: sleepHours == null && nullToAbsent
          ? const Value.absent()
          : Value(sleepHours),
      steps: steps == null && nullToAbsent
          ? const Value.absent()
          : Value(steps),
      exerciseNotes: exerciseNotes == null && nullToAbsent
          ? const Value.absent()
          : Value(exerciseNotes),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory DailyLog.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DailyLog(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      date: serializer.fromJson<DateTime>(json['date']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      weight: serializer.fromJson<double?>(json['weight']),
      calories: serializer.fromJson<int?>(json['calories']),
      protein: serializer.fromJson<int?>(json['protein']),
      carbs: serializer.fromJson<int?>(json['carbs']),
      fats: serializer.fromJson<int?>(json['fats']),
      water: serializer.fromJson<int?>(json['water']),
      notes: serializer.fromJson<String?>(json['notes']),
      sleepHours: serializer.fromJson<double?>(json['sleepHours']),
      steps: serializer.fromJson<int?>(json['steps']),
      exerciseNotes: serializer.fromJson<String?>(json['exerciseNotes']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'date': serializer.toJson<DateTime>(date),
      'dayKey': serializer.toJson<String>(dayKey),
      'weight': serializer.toJson<double?>(weight),
      'calories': serializer.toJson<int?>(calories),
      'protein': serializer.toJson<int?>(protein),
      'carbs': serializer.toJson<int?>(carbs),
      'fats': serializer.toJson<int?>(fats),
      'water': serializer.toJson<int?>(water),
      'notes': serializer.toJson<String?>(notes),
      'sleepHours': serializer.toJson<double?>(sleepHours),
      'steps': serializer.toJson<int?>(steps),
      'exerciseNotes': serializer.toJson<String?>(exerciseNotes),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  DailyLog copyWith({
    int? id,
    String? uuid,
    DateTime? date,
    String? dayKey,
    Value<double?> weight = const Value.absent(),
    Value<int?> calories = const Value.absent(),
    Value<int?> protein = const Value.absent(),
    Value<int?> carbs = const Value.absent(),
    Value<int?> fats = const Value.absent(),
    Value<int?> water = const Value.absent(),
    Value<String?> notes = const Value.absent(),
    Value<double?> sleepHours = const Value.absent(),
    Value<int?> steps = const Value.absent(),
    Value<String?> exerciseNotes = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => DailyLog(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    date: date ?? this.date,
    dayKey: dayKey ?? this.dayKey,
    weight: weight.present ? weight.value : this.weight,
    calories: calories.present ? calories.value : this.calories,
    protein: protein.present ? protein.value : this.protein,
    carbs: carbs.present ? carbs.value : this.carbs,
    fats: fats.present ? fats.value : this.fats,
    water: water.present ? water.value : this.water,
    notes: notes.present ? notes.value : this.notes,
    sleepHours: sleepHours.present ? sleepHours.value : this.sleepHours,
    steps: steps.present ? steps.value : this.steps,
    exerciseNotes: exerciseNotes.present
        ? exerciseNotes.value
        : this.exerciseNotes,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  DailyLog copyWithCompanion(DailyLogsCompanion data) {
    return DailyLog(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      date: data.date.present ? data.date.value : this.date,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      weight: data.weight.present ? data.weight.value : this.weight,
      calories: data.calories.present ? data.calories.value : this.calories,
      protein: data.protein.present ? data.protein.value : this.protein,
      carbs: data.carbs.present ? data.carbs.value : this.carbs,
      fats: data.fats.present ? data.fats.value : this.fats,
      water: data.water.present ? data.water.value : this.water,
      notes: data.notes.present ? data.notes.value : this.notes,
      sleepHours: data.sleepHours.present
          ? data.sleepHours.value
          : this.sleepHours,
      steps: data.steps.present ? data.steps.value : this.steps,
      exerciseNotes: data.exerciseNotes.present
          ? data.exerciseNotes.value
          : this.exerciseNotes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DailyLog(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('date: $date, ')
          ..write('dayKey: $dayKey, ')
          ..write('weight: $weight, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fats: $fats, ')
          ..write('water: $water, ')
          ..write('notes: $notes, ')
          ..write('sleepHours: $sleepHours, ')
          ..write('steps: $steps, ')
          ..write('exerciseNotes: $exerciseNotes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    date,
    dayKey,
    weight,
    calories,
    protein,
    carbs,
    fats,
    water,
    notes,
    sleepHours,
    steps,
    exerciseNotes,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DailyLog &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.date == this.date &&
          other.dayKey == this.dayKey &&
          other.weight == this.weight &&
          other.calories == this.calories &&
          other.protein == this.protein &&
          other.carbs == this.carbs &&
          other.fats == this.fats &&
          other.water == this.water &&
          other.notes == this.notes &&
          other.sleepHours == this.sleepHours &&
          other.steps == this.steps &&
          other.exerciseNotes == this.exerciseNotes &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class DailyLogsCompanion extends UpdateCompanion<DailyLog> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<DateTime> date;
  final Value<String> dayKey;
  final Value<double?> weight;
  final Value<int?> calories;
  final Value<int?> protein;
  final Value<int?> carbs;
  final Value<int?> fats;
  final Value<int?> water;
  final Value<String?> notes;
  final Value<double?> sleepHours;
  final Value<int?> steps;
  final Value<String?> exerciseNotes;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const DailyLogsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.date = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.weight = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fats = const Value.absent(),
    this.water = const Value.absent(),
    this.notes = const Value.absent(),
    this.sleepHours = const Value.absent(),
    this.steps = const Value.absent(),
    this.exerciseNotes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  DailyLogsCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required DateTime date,
    required String dayKey,
    this.weight = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fats = const Value.absent(),
    this.water = const Value.absent(),
    this.notes = const Value.absent(),
    this.sleepHours = const Value.absent(),
    this.steps = const Value.absent(),
    this.exerciseNotes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : date = Value(date),
       dayKey = Value(dayKey);
  static Insertable<DailyLog> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<DateTime>? date,
    Expression<String>? dayKey,
    Expression<double>? weight,
    Expression<int>? calories,
    Expression<int>? protein,
    Expression<int>? carbs,
    Expression<int>? fats,
    Expression<int>? water,
    Expression<String>? notes,
    Expression<double>? sleepHours,
    Expression<int>? steps,
    Expression<String>? exerciseNotes,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (date != null) 'date': date,
      if (dayKey != null) 'day_key': dayKey,
      if (weight != null) 'weight': weight,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fats != null) 'fats': fats,
      if (water != null) 'water': water,
      if (notes != null) 'notes': notes,
      if (sleepHours != null) 'sleep_hours': sleepHours,
      if (steps != null) 'steps': steps,
      if (exerciseNotes != null) 'exercise_notes': exerciseNotes,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  DailyLogsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<DateTime>? date,
    Value<String>? dayKey,
    Value<double?>? weight,
    Value<int?>? calories,
    Value<int?>? protein,
    Value<int?>? carbs,
    Value<int?>? fats,
    Value<int?>? water,
    Value<String?>? notes,
    Value<double?>? sleepHours,
    Value<int?>? steps,
    Value<String?>? exerciseNotes,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return DailyLogsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      date: date ?? this.date,
      dayKey: dayKey ?? this.dayKey,
      weight: weight ?? this.weight,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      water: water ?? this.water,
      notes: notes ?? this.notes,
      sleepHours: sleepHours ?? this.sleepHours,
      steps: steps ?? this.steps,
      exerciseNotes: exerciseNotes ?? this.exerciseNotes,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (calories.present) {
      map['calories'] = Variable<int>(calories.value);
    }
    if (protein.present) {
      map['protein'] = Variable<int>(protein.value);
    }
    if (carbs.present) {
      map['carbs'] = Variable<int>(carbs.value);
    }
    if (fats.present) {
      map['fats'] = Variable<int>(fats.value);
    }
    if (water.present) {
      map['water'] = Variable<int>(water.value);
    }
    if (notes.present) {
      map['notes'] = Variable<String>(notes.value);
    }
    if (sleepHours.present) {
      map['sleep_hours'] = Variable<double>(sleepHours.value);
    }
    if (steps.present) {
      map['steps'] = Variable<int>(steps.value);
    }
    if (exerciseNotes.present) {
      map['exercise_notes'] = Variable<String>(exerciseNotes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DailyLogsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('date: $date, ')
          ..write('dayKey: $dayKey, ')
          ..write('weight: $weight, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fats: $fats, ')
          ..write('water: $water, ')
          ..write('notes: $notes, ')
          ..write('sleepHours: $sleepHours, ')
          ..write('steps: $steps, ')
          ..write('exerciseNotes: $exerciseNotes, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $UserProfileTable extends UserProfile
    with TableInfo<$UserProfileTable, UserProfileData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfileTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ageMeta = const VerificationMeta('age');
  @override
  late final GeneratedColumn<int> age = GeneratedColumn<int>(
    'age',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _heightMeta = const VerificationMeta('height');
  @override
  late final GeneratedColumn<double> height = GeneratedColumn<double>(
    'height',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentWeightMeta = const VerificationMeta(
    'currentWeight',
  );
  @override
  late final GeneratedColumn<double> currentWeight = GeneratedColumn<double>(
    'current_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetWeightMeta = const VerificationMeta(
    'targetWeight',
  );
  @override
  late final GeneratedColumn<double> targetWeight = GeneratedColumn<double>(
    'target_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _activityLevelMeta = const VerificationMeta(
    'activityLevel',
  );
  @override
  late final GeneratedColumn<String> activityLevel = GeneratedColumn<String>(
    'activity_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _exercisesMeta = const VerificationMeta(
    'exercises',
  );
  @override
  late final GeneratedColumn<bool> exercises = GeneratedColumn<bool>(
    'exercises',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("exercises" IN (0, 1))',
    ),
  );
  static const VerificationMeta _medicalConditionsMeta = const VerificationMeta(
    'medicalConditions',
  );
  @override
  late final GeneratedColumn<String> medicalConditions =
      GeneratedColumn<String>(
        'medical_conditions',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _waistMeta = const VerificationMeta('waist');
  @override
  late final GeneratedColumn<double> waist = GeneratedColumn<double>(
    'waist',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _neckMeta = const VerificationMeta('neck');
  @override
  late final GeneratedColumn<double> neck = GeneratedColumn<double>(
    'neck',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _chestMeta = const VerificationMeta('chest');
  @override
  late final GeneratedColumn<double> chest = GeneratedColumn<double>(
    'chest',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _armMeta = const VerificationMeta('arm');
  @override
  late final GeneratedColumn<double> arm = GeneratedColumn<double>(
    'arm',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _thighMeta = const VerificationMeta('thigh');
  @override
  late final GeneratedColumn<double> thigh = GeneratedColumn<double>(
    'thigh',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    gender,
    age,
    height,
    currentWeight,
    targetWeight,
    activityLevel,
    exercises,
    medicalConditions,
    waist,
    neck,
    chest,
    arm,
    thigh,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profile';
  @override
  VerificationContext validateIntegrity(
    Insertable<UserProfileData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    } else if (isInserting) {
      context.missing(_genderMeta);
    }
    if (data.containsKey('age')) {
      context.handle(
        _ageMeta,
        age.isAcceptableOrUnknown(data['age']!, _ageMeta),
      );
    } else if (isInserting) {
      context.missing(_ageMeta);
    }
    if (data.containsKey('height')) {
      context.handle(
        _heightMeta,
        height.isAcceptableOrUnknown(data['height']!, _heightMeta),
      );
    } else if (isInserting) {
      context.missing(_heightMeta);
    }
    if (data.containsKey('current_weight')) {
      context.handle(
        _currentWeightMeta,
        currentWeight.isAcceptableOrUnknown(
          data['current_weight']!,
          _currentWeightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentWeightMeta);
    }
    if (data.containsKey('target_weight')) {
      context.handle(
        _targetWeightMeta,
        targetWeight.isAcceptableOrUnknown(
          data['target_weight']!,
          _targetWeightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetWeightMeta);
    }
    if (data.containsKey('activity_level')) {
      context.handle(
        _activityLevelMeta,
        activityLevel.isAcceptableOrUnknown(
          data['activity_level']!,
          _activityLevelMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_activityLevelMeta);
    }
    if (data.containsKey('exercises')) {
      context.handle(
        _exercisesMeta,
        exercises.isAcceptableOrUnknown(data['exercises']!, _exercisesMeta),
      );
    } else if (isInserting) {
      context.missing(_exercisesMeta);
    }
    if (data.containsKey('medical_conditions')) {
      context.handle(
        _medicalConditionsMeta,
        medicalConditions.isAcceptableOrUnknown(
          data['medical_conditions']!,
          _medicalConditionsMeta,
        ),
      );
    }
    if (data.containsKey('waist')) {
      context.handle(
        _waistMeta,
        waist.isAcceptableOrUnknown(data['waist']!, _waistMeta),
      );
    }
    if (data.containsKey('neck')) {
      context.handle(
        _neckMeta,
        neck.isAcceptableOrUnknown(data['neck']!, _neckMeta),
      );
    }
    if (data.containsKey('chest')) {
      context.handle(
        _chestMeta,
        chest.isAcceptableOrUnknown(data['chest']!, _chestMeta),
      );
    }
    if (data.containsKey('arm')) {
      context.handle(
        _armMeta,
        arm.isAcceptableOrUnknown(data['arm']!, _armMeta),
      );
    }
    if (data.containsKey('thigh')) {
      context.handle(
        _thighMeta,
        thigh.isAcceptableOrUnknown(data['thigh']!, _thighMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfileData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfileData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      )!,
      age: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}age'],
      )!,
      height: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}height'],
      )!,
      currentWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}current_weight'],
      )!,
      targetWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_weight'],
      )!,
      activityLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}activity_level'],
      )!,
      exercises: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}exercises'],
      )!,
      medicalConditions: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}medical_conditions'],
      ),
      waist: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}waist'],
      ),
      neck: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}neck'],
      ),
      chest: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}chest'],
      ),
      arm: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}arm'],
      ),
      thigh: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}thigh'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $UserProfileTable createAlias(String alias) {
    return $UserProfileTable(attachedDatabase, alias);
  }
}

class UserProfileData extends DataClass implements Insertable<UserProfileData> {
  final int id;
  final String uuid;
  final String gender;
  final int age;
  final double height;
  final double currentWeight;
  final double targetWeight;
  final String activityLevel;
  final bool exercises;
  final String? medicalConditions;
  final double? waist;
  final double? neck;
  final double? chest;
  final double? arm;
  final double? thigh;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String syncStatus;
  const UserProfileData({
    required this.id,
    required this.uuid,
    required this.gender,
    required this.age,
    required this.height,
    required this.currentWeight,
    required this.targetWeight,
    required this.activityLevel,
    required this.exercises,
    this.medicalConditions,
    this.waist,
    this.neck,
    this.chest,
    this.arm,
    this.thigh,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['gender'] = Variable<String>(gender);
    map['age'] = Variable<int>(age);
    map['height'] = Variable<double>(height);
    map['current_weight'] = Variable<double>(currentWeight);
    map['target_weight'] = Variable<double>(targetWeight);
    map['activity_level'] = Variable<String>(activityLevel);
    map['exercises'] = Variable<bool>(exercises);
    if (!nullToAbsent || medicalConditions != null) {
      map['medical_conditions'] = Variable<String>(medicalConditions);
    }
    if (!nullToAbsent || waist != null) {
      map['waist'] = Variable<double>(waist);
    }
    if (!nullToAbsent || neck != null) {
      map['neck'] = Variable<double>(neck);
    }
    if (!nullToAbsent || chest != null) {
      map['chest'] = Variable<double>(chest);
    }
    if (!nullToAbsent || arm != null) {
      map['arm'] = Variable<double>(arm);
    }
    if (!nullToAbsent || thigh != null) {
      map['thigh'] = Variable<double>(thigh);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  UserProfileCompanion toCompanion(bool nullToAbsent) {
    return UserProfileCompanion(
      id: Value(id),
      uuid: Value(uuid),
      gender: Value(gender),
      age: Value(age),
      height: Value(height),
      currentWeight: Value(currentWeight),
      targetWeight: Value(targetWeight),
      activityLevel: Value(activityLevel),
      exercises: Value(exercises),
      medicalConditions: medicalConditions == null && nullToAbsent
          ? const Value.absent()
          : Value(medicalConditions),
      waist: waist == null && nullToAbsent
          ? const Value.absent()
          : Value(waist),
      neck: neck == null && nullToAbsent ? const Value.absent() : Value(neck),
      chest: chest == null && nullToAbsent
          ? const Value.absent()
          : Value(chest),
      arm: arm == null && nullToAbsent ? const Value.absent() : Value(arm),
      thigh: thigh == null && nullToAbsent
          ? const Value.absent()
          : Value(thigh),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      syncStatus: Value(syncStatus),
    );
  }

  factory UserProfileData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfileData(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      gender: serializer.fromJson<String>(json['gender']),
      age: serializer.fromJson<int>(json['age']),
      height: serializer.fromJson<double>(json['height']),
      currentWeight: serializer.fromJson<double>(json['currentWeight']),
      targetWeight: serializer.fromJson<double>(json['targetWeight']),
      activityLevel: serializer.fromJson<String>(json['activityLevel']),
      exercises: serializer.fromJson<bool>(json['exercises']),
      medicalConditions: serializer.fromJson<String?>(
        json['medicalConditions'],
      ),
      waist: serializer.fromJson<double?>(json['waist']),
      neck: serializer.fromJson<double?>(json['neck']),
      chest: serializer.fromJson<double?>(json['chest']),
      arm: serializer.fromJson<double?>(json['arm']),
      thigh: serializer.fromJson<double?>(json['thigh']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'gender': serializer.toJson<String>(gender),
      'age': serializer.toJson<int>(age),
      'height': serializer.toJson<double>(height),
      'currentWeight': serializer.toJson<double>(currentWeight),
      'targetWeight': serializer.toJson<double>(targetWeight),
      'activityLevel': serializer.toJson<String>(activityLevel),
      'exercises': serializer.toJson<bool>(exercises),
      'medicalConditions': serializer.toJson<String?>(medicalConditions),
      'waist': serializer.toJson<double?>(waist),
      'neck': serializer.toJson<double?>(neck),
      'chest': serializer.toJson<double?>(chest),
      'arm': serializer.toJson<double?>(arm),
      'thigh': serializer.toJson<double?>(thigh),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  UserProfileData copyWith({
    int? id,
    String? uuid,
    String? gender,
    int? age,
    double? height,
    double? currentWeight,
    double? targetWeight,
    String? activityLevel,
    bool? exercises,
    Value<String?> medicalConditions = const Value.absent(),
    Value<double?> waist = const Value.absent(),
    Value<double?> neck = const Value.absent(),
    Value<double?> chest = const Value.absent(),
    Value<double?> arm = const Value.absent(),
    Value<double?> thigh = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? syncStatus,
  }) => UserProfileData(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    gender: gender ?? this.gender,
    age: age ?? this.age,
    height: height ?? this.height,
    currentWeight: currentWeight ?? this.currentWeight,
    targetWeight: targetWeight ?? this.targetWeight,
    activityLevel: activityLevel ?? this.activityLevel,
    exercises: exercises ?? this.exercises,
    medicalConditions: medicalConditions.present
        ? medicalConditions.value
        : this.medicalConditions,
    waist: waist.present ? waist.value : this.waist,
    neck: neck.present ? neck.value : this.neck,
    chest: chest.present ? chest.value : this.chest,
    arm: arm.present ? arm.value : this.arm,
    thigh: thigh.present ? thigh.value : this.thigh,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  UserProfileData copyWithCompanion(UserProfileCompanion data) {
    return UserProfileData(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      gender: data.gender.present ? data.gender.value : this.gender,
      age: data.age.present ? data.age.value : this.age,
      height: data.height.present ? data.height.value : this.height,
      currentWeight: data.currentWeight.present
          ? data.currentWeight.value
          : this.currentWeight,
      targetWeight: data.targetWeight.present
          ? data.targetWeight.value
          : this.targetWeight,
      activityLevel: data.activityLevel.present
          ? data.activityLevel.value
          : this.activityLevel,
      exercises: data.exercises.present ? data.exercises.value : this.exercises,
      medicalConditions: data.medicalConditions.present
          ? data.medicalConditions.value
          : this.medicalConditions,
      waist: data.waist.present ? data.waist.value : this.waist,
      neck: data.neck.present ? data.neck.value : this.neck,
      chest: data.chest.present ? data.chest.value : this.chest,
      arm: data.arm.present ? data.arm.value : this.arm,
      thigh: data.thigh.present ? data.thigh.value : this.thigh,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileData(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('gender: $gender, ')
          ..write('age: $age, ')
          ..write('height: $height, ')
          ..write('currentWeight: $currentWeight, ')
          ..write('targetWeight: $targetWeight, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('exercises: $exercises, ')
          ..write('medicalConditions: $medicalConditions, ')
          ..write('waist: $waist, ')
          ..write('neck: $neck, ')
          ..write('chest: $chest, ')
          ..write('arm: $arm, ')
          ..write('thigh: $thigh, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    gender,
    age,
    height,
    currentWeight,
    targetWeight,
    activityLevel,
    exercises,
    medicalConditions,
    waist,
    neck,
    chest,
    arm,
    thigh,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfileData &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.gender == this.gender &&
          other.age == this.age &&
          other.height == this.height &&
          other.currentWeight == this.currentWeight &&
          other.targetWeight == this.targetWeight &&
          other.activityLevel == this.activityLevel &&
          other.exercises == this.exercises &&
          other.medicalConditions == this.medicalConditions &&
          other.waist == this.waist &&
          other.neck == this.neck &&
          other.chest == this.chest &&
          other.arm == this.arm &&
          other.thigh == this.thigh &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.syncStatus == this.syncStatus);
}

class UserProfileCompanion extends UpdateCompanion<UserProfileData> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> gender;
  final Value<int> age;
  final Value<double> height;
  final Value<double> currentWeight;
  final Value<double> targetWeight;
  final Value<String> activityLevel;
  final Value<bool> exercises;
  final Value<String?> medicalConditions;
  final Value<double?> waist;
  final Value<double?> neck;
  final Value<double?> chest;
  final Value<double?> arm;
  final Value<double?> thigh;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> syncStatus;
  const UserProfileCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.gender = const Value.absent(),
    this.age = const Value.absent(),
    this.height = const Value.absent(),
    this.currentWeight = const Value.absent(),
    this.targetWeight = const Value.absent(),
    this.activityLevel = const Value.absent(),
    this.exercises = const Value.absent(),
    this.medicalConditions = const Value.absent(),
    this.waist = const Value.absent(),
    this.neck = const Value.absent(),
    this.chest = const Value.absent(),
    this.arm = const Value.absent(),
    this.thigh = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  UserProfileCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required String gender,
    required int age,
    required double height,
    required double currentWeight,
    required double targetWeight,
    required String activityLevel,
    required bool exercises,
    this.medicalConditions = const Value.absent(),
    this.waist = const Value.absent(),
    this.neck = const Value.absent(),
    this.chest = const Value.absent(),
    this.arm = const Value.absent(),
    this.thigh = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : gender = Value(gender),
       age = Value(age),
       height = Value(height),
       currentWeight = Value(currentWeight),
       targetWeight = Value(targetWeight),
       activityLevel = Value(activityLevel),
       exercises = Value(exercises);
  static Insertable<UserProfileData> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? gender,
    Expression<int>? age,
    Expression<double>? height,
    Expression<double>? currentWeight,
    Expression<double>? targetWeight,
    Expression<String>? activityLevel,
    Expression<bool>? exercises,
    Expression<String>? medicalConditions,
    Expression<double>? waist,
    Expression<double>? neck,
    Expression<double>? chest,
    Expression<double>? arm,
    Expression<double>? thigh,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (gender != null) 'gender': gender,
      if (age != null) 'age': age,
      if (height != null) 'height': height,
      if (currentWeight != null) 'current_weight': currentWeight,
      if (targetWeight != null) 'target_weight': targetWeight,
      if (activityLevel != null) 'activity_level': activityLevel,
      if (exercises != null) 'exercises': exercises,
      if (medicalConditions != null) 'medical_conditions': medicalConditions,
      if (waist != null) 'waist': waist,
      if (neck != null) 'neck': neck,
      if (chest != null) 'chest': chest,
      if (arm != null) 'arm': arm,
      if (thigh != null) 'thigh': thigh,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  UserProfileCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? gender,
    Value<int>? age,
    Value<double>? height,
    Value<double>? currentWeight,
    Value<double>? targetWeight,
    Value<String>? activityLevel,
    Value<bool>? exercises,
    Value<String?>? medicalConditions,
    Value<double?>? waist,
    Value<double?>? neck,
    Value<double?>? chest,
    Value<double?>? arm,
    Value<double?>? thigh,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? syncStatus,
  }) {
    return UserProfileCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      gender: gender ?? this.gender,
      age: age ?? this.age,
      height: height ?? this.height,
      currentWeight: currentWeight ?? this.currentWeight,
      targetWeight: targetWeight ?? this.targetWeight,
      activityLevel: activityLevel ?? this.activityLevel,
      exercises: exercises ?? this.exercises,
      medicalConditions: medicalConditions ?? this.medicalConditions,
      waist: waist ?? this.waist,
      neck: neck ?? this.neck,
      chest: chest ?? this.chest,
      arm: arm ?? this.arm,
      thigh: thigh ?? this.thigh,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (age.present) {
      map['age'] = Variable<int>(age.value);
    }
    if (height.present) {
      map['height'] = Variable<double>(height.value);
    }
    if (currentWeight.present) {
      map['current_weight'] = Variable<double>(currentWeight.value);
    }
    if (targetWeight.present) {
      map['target_weight'] = Variable<double>(targetWeight.value);
    }
    if (activityLevel.present) {
      map['activity_level'] = Variable<String>(activityLevel.value);
    }
    if (exercises.present) {
      map['exercises'] = Variable<bool>(exercises.value);
    }
    if (medicalConditions.present) {
      map['medical_conditions'] = Variable<String>(medicalConditions.value);
    }
    if (waist.present) {
      map['waist'] = Variable<double>(waist.value);
    }
    if (neck.present) {
      map['neck'] = Variable<double>(neck.value);
    }
    if (chest.present) {
      map['chest'] = Variable<double>(chest.value);
    }
    if (arm.present) {
      map['arm'] = Variable<double>(arm.value);
    }
    if (thigh.present) {
      map['thigh'] = Variable<double>(thigh.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfileCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('gender: $gender, ')
          ..write('age: $age, ')
          ..write('height: $height, ')
          ..write('currentWeight: $currentWeight, ')
          ..write('targetWeight: $targetWeight, ')
          ..write('activityLevel: $activityLevel, ')
          ..write('exercises: $exercises, ')
          ..write('medicalConditions: $medicalConditions, ')
          ..write('waist: $waist, ')
          ..write('neck: $neck, ')
          ..write('chest: $chest, ')
          ..write('arm: $arm, ')
          ..write('thigh: $thigh, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $WeightEntriesTable extends WeightEntries
    with TableInfo<$WeightEntriesTable, WeightEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WeightEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _weightMeta = const VerificationMeta('weight');
  @override
  late final GeneratedColumn<double> weight = GeneratedColumn<double>(
    'weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _noteMeta = const VerificationMeta('note');
  @override
  late final GeneratedColumn<String> note = GeneratedColumn<String>(
    'note',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _measurementContextMeta =
      const VerificationMeta('measurementContext');
  @override
  late final GeneratedColumn<String> measurementContext =
      GeneratedColumn<String>(
        'measurement_context',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('differentConditions'),
      );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    date,
    dayKey,
    weight,
    note,
    measurementContext,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'weight_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WeightEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    }
    if (data.containsKey('weight')) {
      context.handle(
        _weightMeta,
        weight.isAcceptableOrUnknown(data['weight']!, _weightMeta),
      );
    } else if (isInserting) {
      context.missing(_weightMeta);
    }
    if (data.containsKey('note')) {
      context.handle(
        _noteMeta,
        note.isAcceptableOrUnknown(data['note']!, _noteMeta),
      );
    }
    if (data.containsKey('measurement_context')) {
      context.handle(
        _measurementContextMeta,
        measurementContext.isAcceptableOrUnknown(
          data['measurement_context']!,
          _measurementContextMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WeightEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WeightEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      ),
      weight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}weight'],
      )!,
      note: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}note'],
      ),
      measurementContext: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}measurement_context'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $WeightEntriesTable createAlias(String alias) {
    return $WeightEntriesTable(attachedDatabase, alias);
  }
}

class WeightEntry extends DataClass implements Insertable<WeightEntry> {
  final int id;
  final String uuid;
  final DateTime date;

  /// Local calendar date used to enforce one logical check-in per day.
  final String? dayKey;
  final double weight;
  final String? note;

  /// Stable, non-localized measurement condition selected by the user.
  final String measurementContext;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String syncStatus;
  const WeightEntry({
    required this.id,
    required this.uuid,
    required this.date,
    this.dayKey,
    required this.weight,
    this.note,
    required this.measurementContext,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['date'] = Variable<DateTime>(date);
    if (!nullToAbsent || dayKey != null) {
      map['day_key'] = Variable<String>(dayKey);
    }
    map['weight'] = Variable<double>(weight);
    if (!nullToAbsent || note != null) {
      map['note'] = Variable<String>(note);
    }
    map['measurement_context'] = Variable<String>(measurementContext);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  WeightEntriesCompanion toCompanion(bool nullToAbsent) {
    return WeightEntriesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      date: Value(date),
      dayKey: dayKey == null && nullToAbsent
          ? const Value.absent()
          : Value(dayKey),
      weight: Value(weight),
      note: note == null && nullToAbsent ? const Value.absent() : Value(note),
      measurementContext: Value(measurementContext),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      syncStatus: Value(syncStatus),
    );
  }

  factory WeightEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WeightEntry(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      date: serializer.fromJson<DateTime>(json['date']),
      dayKey: serializer.fromJson<String?>(json['dayKey']),
      weight: serializer.fromJson<double>(json['weight']),
      note: serializer.fromJson<String?>(json['note']),
      measurementContext: serializer.fromJson<String>(
        json['measurementContext'],
      ),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'date': serializer.toJson<DateTime>(date),
      'dayKey': serializer.toJson<String?>(dayKey),
      'weight': serializer.toJson<double>(weight),
      'note': serializer.toJson<String?>(note),
      'measurementContext': serializer.toJson<String>(measurementContext),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  WeightEntry copyWith({
    int? id,
    String? uuid,
    DateTime? date,
    Value<String?> dayKey = const Value.absent(),
    double? weight,
    Value<String?> note = const Value.absent(),
    String? measurementContext,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? syncStatus,
  }) => WeightEntry(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    date: date ?? this.date,
    dayKey: dayKey.present ? dayKey.value : this.dayKey,
    weight: weight ?? this.weight,
    note: note.present ? note.value : this.note,
    measurementContext: measurementContext ?? this.measurementContext,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  WeightEntry copyWithCompanion(WeightEntriesCompanion data) {
    return WeightEntry(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      date: data.date.present ? data.date.value : this.date,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      weight: data.weight.present ? data.weight.value : this.weight,
      note: data.note.present ? data.note.value : this.note,
      measurementContext: data.measurementContext.present
          ? data.measurementContext.value
          : this.measurementContext,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WeightEntry(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('date: $date, ')
          ..write('dayKey: $dayKey, ')
          ..write('weight: $weight, ')
          ..write('note: $note, ')
          ..write('measurementContext: $measurementContext, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    date,
    dayKey,
    weight,
    note,
    measurementContext,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WeightEntry &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.date == this.date &&
          other.dayKey == this.dayKey &&
          other.weight == this.weight &&
          other.note == this.note &&
          other.measurementContext == this.measurementContext &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.syncStatus == this.syncStatus);
}

class WeightEntriesCompanion extends UpdateCompanion<WeightEntry> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<DateTime> date;
  final Value<String?> dayKey;
  final Value<double> weight;
  final Value<String?> note;
  final Value<String> measurementContext;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> syncStatus;
  const WeightEntriesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.date = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.weight = const Value.absent(),
    this.note = const Value.absent(),
    this.measurementContext = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  WeightEntriesCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.date = const Value.absent(),
    this.dayKey = const Value.absent(),
    required double weight,
    this.note = const Value.absent(),
    this.measurementContext = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : weight = Value(weight);
  static Insertable<WeightEntry> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<DateTime>? date,
    Expression<String>? dayKey,
    Expression<double>? weight,
    Expression<String>? note,
    Expression<String>? measurementContext,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (date != null) 'date': date,
      if (dayKey != null) 'day_key': dayKey,
      if (weight != null) 'weight': weight,
      if (note != null) 'note': note,
      if (measurementContext != null) 'measurement_context': measurementContext,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  WeightEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<DateTime>? date,
    Value<String?>? dayKey,
    Value<double>? weight,
    Value<String?>? note,
    Value<String>? measurementContext,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? syncStatus,
  }) {
    return WeightEntriesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      date: date ?? this.date,
      dayKey: dayKey ?? this.dayKey,
      weight: weight ?? this.weight,
      note: note ?? this.note,
      measurementContext: measurementContext ?? this.measurementContext,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (weight.present) {
      map['weight'] = Variable<double>(weight.value);
    }
    if (note.present) {
      map['note'] = Variable<String>(note.value);
    }
    if (measurementContext.present) {
      map['measurement_context'] = Variable<String>(measurementContext.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WeightEntriesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('date: $date, ')
          ..write('dayKey: $dayKey, ')
          ..write('weight: $weight, ')
          ..write('note: $note, ')
          ..write('measurementContext: $measurementContext, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $FoodsTable extends Foods with TableInfo<$FoodsTable, Food> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FoodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _arabicNameMeta = const VerificationMeta(
    'arabicName',
  );
  @override
  late final GeneratedColumn<String> arabicName = GeneratedColumn<String>(
    'arabic_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _keywordsMeta = const VerificationMeta(
    'keywords',
  );
  @override
  late final GeneratedColumn<String> keywords = GeneratedColumn<String>(
    'keywords',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _barcodeMeta = const VerificationMeta(
    'barcode',
  );
  @override
  late final GeneratedColumn<String> barcode = GeneratedColumn<String>(
    'barcode',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _servingSizeMeta = const VerificationMeta(
    'servingSize',
  );
  @override
  late final GeneratedColumn<double> servingSize = GeneratedColumn<double>(
    'serving_size',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _servingUnitMeta = const VerificationMeta(
    'servingUnit',
  );
  @override
  late final GeneratedColumn<String> servingUnit = GeneratedColumn<String>(
    'serving_unit',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('g'),
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<double> calories = GeneratedColumn<double>(
    'calories',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _proteinMeta = const VerificationMeta(
    'protein',
  );
  @override
  late final GeneratedColumn<double> protein = GeneratedColumn<double>(
    'protein',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _carbsMeta = const VerificationMeta('carbs');
  @override
  late final GeneratedColumn<double> carbs = GeneratedColumn<double>(
    'carbs',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fatsMeta = const VerificationMeta('fats');
  @override
  late final GeneratedColumn<double> fats = GeneratedColumn<double>(
    'fats',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _fiberMeta = const VerificationMeta('fiber');
  @override
  late final GeneratedColumn<double> fiber = GeneratedColumn<double>(
    'fiber',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sugarMeta = const VerificationMeta('sugar');
  @override
  late final GeneratedColumn<double> sugar = GeneratedColumn<double>(
    'sugar',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _potassiumMeta = const VerificationMeta(
    'potassium',
  );
  @override
  late final GeneratedColumn<double> potassium = GeneratedColumn<double>(
    'potassium',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sodiumMeta = const VerificationMeta('sodium');
  @override
  late final GeneratedColumn<double> sodium = GeneratedColumn<double>(
    'sodium',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _calciumMeta = const VerificationMeta(
    'calcium',
  );
  @override
  late final GeneratedColumn<double> calcium = GeneratedColumn<double>(
    'calcium',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _ironMeta = const VerificationMeta('iron');
  @override
  late final GeneratedColumn<double> iron = GeneratedColumn<double>(
    'iron',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _magnesiumMeta = const VerificationMeta(
    'magnesium',
  );
  @override
  late final GeneratedColumn<double> magnesium = GeneratedColumn<double>(
    'magnesium',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _vitaminCMeta = const VerificationMeta(
    'vitaminC',
  );
  @override
  late final GeneratedColumn<double> vitaminC = GeneratedColumn<double>(
    'vitamin_c',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _verifiedMeta = const VerificationMeta(
    'verified',
  );
  @override
  late final GeneratedColumn<bool> verified = GeneratedColumn<bool>(
    'verified',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("verified" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _isCustomMeta = const VerificationMeta(
    'isCustom',
  );
  @override
  late final GeneratedColumn<bool> isCustom = GeneratedColumn<bool>(
    'is_custom',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_custom" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    name,
    arabicName,
    category,
    keywords,
    barcode,
    servingSize,
    servingUnit,
    calories,
    protein,
    carbs,
    fats,
    fiber,
    sugar,
    potassium,
    sodium,
    calcium,
    iron,
    magnesium,
    vitaminC,
    verified,
    isCustom,
    source,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<Food> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('arabic_name')) {
      context.handle(
        _arabicNameMeta,
        arabicName.isAcceptableOrUnknown(data['arabic_name']!, _arabicNameMeta),
      );
    }
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    }
    if (data.containsKey('keywords')) {
      context.handle(
        _keywordsMeta,
        keywords.isAcceptableOrUnknown(data['keywords']!, _keywordsMeta),
      );
    }
    if (data.containsKey('barcode')) {
      context.handle(
        _barcodeMeta,
        barcode.isAcceptableOrUnknown(data['barcode']!, _barcodeMeta),
      );
    }
    if (data.containsKey('serving_size')) {
      context.handle(
        _servingSizeMeta,
        servingSize.isAcceptableOrUnknown(
          data['serving_size']!,
          _servingSizeMeta,
        ),
      );
    }
    if (data.containsKey('serving_unit')) {
      context.handle(
        _servingUnitMeta,
        servingUnit.isAcceptableOrUnknown(
          data['serving_unit']!,
          _servingUnitMeta,
        ),
      );
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    } else if (isInserting) {
      context.missing(_caloriesMeta);
    }
    if (data.containsKey('protein')) {
      context.handle(
        _proteinMeta,
        protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta),
      );
    } else if (isInserting) {
      context.missing(_proteinMeta);
    }
    if (data.containsKey('carbs')) {
      context.handle(
        _carbsMeta,
        carbs.isAcceptableOrUnknown(data['carbs']!, _carbsMeta),
      );
    } else if (isInserting) {
      context.missing(_carbsMeta);
    }
    if (data.containsKey('fats')) {
      context.handle(
        _fatsMeta,
        fats.isAcceptableOrUnknown(data['fats']!, _fatsMeta),
      );
    } else if (isInserting) {
      context.missing(_fatsMeta);
    }
    if (data.containsKey('fiber')) {
      context.handle(
        _fiberMeta,
        fiber.isAcceptableOrUnknown(data['fiber']!, _fiberMeta),
      );
    }
    if (data.containsKey('sugar')) {
      context.handle(
        _sugarMeta,
        sugar.isAcceptableOrUnknown(data['sugar']!, _sugarMeta),
      );
    }
    if (data.containsKey('potassium')) {
      context.handle(
        _potassiumMeta,
        potassium.isAcceptableOrUnknown(data['potassium']!, _potassiumMeta),
      );
    }
    if (data.containsKey('sodium')) {
      context.handle(
        _sodiumMeta,
        sodium.isAcceptableOrUnknown(data['sodium']!, _sodiumMeta),
      );
    }
    if (data.containsKey('calcium')) {
      context.handle(
        _calciumMeta,
        calcium.isAcceptableOrUnknown(data['calcium']!, _calciumMeta),
      );
    }
    if (data.containsKey('iron')) {
      context.handle(
        _ironMeta,
        iron.isAcceptableOrUnknown(data['iron']!, _ironMeta),
      );
    }
    if (data.containsKey('magnesium')) {
      context.handle(
        _magnesiumMeta,
        magnesium.isAcceptableOrUnknown(data['magnesium']!, _magnesiumMeta),
      );
    }
    if (data.containsKey('vitamin_c')) {
      context.handle(
        _vitaminCMeta,
        vitaminC.isAcceptableOrUnknown(data['vitamin_c']!, _vitaminCMeta),
      );
    }
    if (data.containsKey('verified')) {
      context.handle(
        _verifiedMeta,
        verified.isAcceptableOrUnknown(data['verified']!, _verifiedMeta),
      );
    }
    if (data.containsKey('is_custom')) {
      context.handle(
        _isCustomMeta,
        isCustom.isAcceptableOrUnknown(data['is_custom']!, _isCustomMeta),
      );
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Food map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Food(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      arabicName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}arabic_name'],
      ),
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      ),
      keywords: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}keywords'],
      )!,
      barcode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}barcode'],
      ),
      servingSize: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}serving_size'],
      )!,
      servingUnit: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}serving_unit'],
      )!,
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calories'],
      )!,
      protein: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein'],
      )!,
      carbs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs'],
      )!,
      fats: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fats'],
      )!,
      fiber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fiber'],
      )!,
      sugar: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sugar'],
      )!,
      potassium: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}potassium'],
      )!,
      sodium: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sodium'],
      )!,
      calcium: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calcium'],
      )!,
      iron: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}iron'],
      )!,
      magnesium: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}magnesium'],
      )!,
      vitaminC: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}vitamin_c'],
      )!,
      verified: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}verified'],
      )!,
      isCustom: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_custom'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $FoodsTable createAlias(String alias) {
    return $FoodsTable(attachedDatabase, alias);
  }
}

class Food extends DataClass implements Insertable<Food> {
  final int id;
  final String uuid;
  final String name;
  final String? arabicName;
  final String? category;
  final String keywords;
  final String? barcode;
  final double servingSize;
  final String servingUnit;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double fiber;
  final double sugar;
  final double potassium;
  final double sodium;
  final double calcium;
  final double iron;
  final double magnesium;
  final double vitaminC;
  final bool verified;
  final bool isCustom;
  final String source;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String syncStatus;
  const Food({
    required this.id,
    required this.uuid,
    required this.name,
    this.arabicName,
    this.category,
    required this.keywords,
    this.barcode,
    required this.servingSize,
    required this.servingUnit,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
    required this.sugar,
    required this.potassium,
    required this.sodium,
    required this.calcium,
    required this.iron,
    required this.magnesium,
    required this.vitaminC,
    required this.verified,
    required this.isCustom,
    required this.source,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || arabicName != null) {
      map['arabic_name'] = Variable<String>(arabicName);
    }
    if (!nullToAbsent || category != null) {
      map['category'] = Variable<String>(category);
    }
    map['keywords'] = Variable<String>(keywords);
    if (!nullToAbsent || barcode != null) {
      map['barcode'] = Variable<String>(barcode);
    }
    map['serving_size'] = Variable<double>(servingSize);
    map['serving_unit'] = Variable<String>(servingUnit);
    map['calories'] = Variable<double>(calories);
    map['protein'] = Variable<double>(protein);
    map['carbs'] = Variable<double>(carbs);
    map['fats'] = Variable<double>(fats);
    map['fiber'] = Variable<double>(fiber);
    map['sugar'] = Variable<double>(sugar);
    map['potassium'] = Variable<double>(potassium);
    map['sodium'] = Variable<double>(sodium);
    map['calcium'] = Variable<double>(calcium);
    map['iron'] = Variable<double>(iron);
    map['magnesium'] = Variable<double>(magnesium);
    map['vitamin_c'] = Variable<double>(vitaminC);
    map['verified'] = Variable<bool>(verified);
    map['is_custom'] = Variable<bool>(isCustom);
    map['source'] = Variable<String>(source);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  FoodsCompanion toCompanion(bool nullToAbsent) {
    return FoodsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      name: Value(name),
      arabicName: arabicName == null && nullToAbsent
          ? const Value.absent()
          : Value(arabicName),
      category: category == null && nullToAbsent
          ? const Value.absent()
          : Value(category),
      keywords: Value(keywords),
      barcode: barcode == null && nullToAbsent
          ? const Value.absent()
          : Value(barcode),
      servingSize: Value(servingSize),
      servingUnit: Value(servingUnit),
      calories: Value(calories),
      protein: Value(protein),
      carbs: Value(carbs),
      fats: Value(fats),
      fiber: Value(fiber),
      sugar: Value(sugar),
      potassium: Value(potassium),
      sodium: Value(sodium),
      calcium: Value(calcium),
      iron: Value(iron),
      magnesium: Value(magnesium),
      vitaminC: Value(vitaminC),
      verified: Value(verified),
      isCustom: Value(isCustom),
      source: Value(source),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      syncStatus: Value(syncStatus),
    );
  }

  factory Food.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Food(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      name: serializer.fromJson<String>(json['name']),
      arabicName: serializer.fromJson<String?>(json['arabicName']),
      category: serializer.fromJson<String?>(json['category']),
      keywords: serializer.fromJson<String>(json['keywords']),
      barcode: serializer.fromJson<String?>(json['barcode']),
      servingSize: serializer.fromJson<double>(json['servingSize']),
      servingUnit: serializer.fromJson<String>(json['servingUnit']),
      calories: serializer.fromJson<double>(json['calories']),
      protein: serializer.fromJson<double>(json['protein']),
      carbs: serializer.fromJson<double>(json['carbs']),
      fats: serializer.fromJson<double>(json['fats']),
      fiber: serializer.fromJson<double>(json['fiber']),
      sugar: serializer.fromJson<double>(json['sugar']),
      potassium: serializer.fromJson<double>(json['potassium']),
      sodium: serializer.fromJson<double>(json['sodium']),
      calcium: serializer.fromJson<double>(json['calcium']),
      iron: serializer.fromJson<double>(json['iron']),
      magnesium: serializer.fromJson<double>(json['magnesium']),
      vitaminC: serializer.fromJson<double>(json['vitaminC']),
      verified: serializer.fromJson<bool>(json['verified']),
      isCustom: serializer.fromJson<bool>(json['isCustom']),
      source: serializer.fromJson<String>(json['source']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'name': serializer.toJson<String>(name),
      'arabicName': serializer.toJson<String?>(arabicName),
      'category': serializer.toJson<String?>(category),
      'keywords': serializer.toJson<String>(keywords),
      'barcode': serializer.toJson<String?>(barcode),
      'servingSize': serializer.toJson<double>(servingSize),
      'servingUnit': serializer.toJson<String>(servingUnit),
      'calories': serializer.toJson<double>(calories),
      'protein': serializer.toJson<double>(protein),
      'carbs': serializer.toJson<double>(carbs),
      'fats': serializer.toJson<double>(fats),
      'fiber': serializer.toJson<double>(fiber),
      'sugar': serializer.toJson<double>(sugar),
      'potassium': serializer.toJson<double>(potassium),
      'sodium': serializer.toJson<double>(sodium),
      'calcium': serializer.toJson<double>(calcium),
      'iron': serializer.toJson<double>(iron),
      'magnesium': serializer.toJson<double>(magnesium),
      'vitaminC': serializer.toJson<double>(vitaminC),
      'verified': serializer.toJson<bool>(verified),
      'isCustom': serializer.toJson<bool>(isCustom),
      'source': serializer.toJson<String>(source),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  Food copyWith({
    int? id,
    String? uuid,
    String? name,
    Value<String?> arabicName = const Value.absent(),
    Value<String?> category = const Value.absent(),
    String? keywords,
    Value<String?> barcode = const Value.absent(),
    double? servingSize,
    String? servingUnit,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    double? fiber,
    double? sugar,
    double? potassium,
    double? sodium,
    double? calcium,
    double? iron,
    double? magnesium,
    double? vitaminC,
    bool? verified,
    bool? isCustom,
    String? source,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? syncStatus,
  }) => Food(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    name: name ?? this.name,
    arabicName: arabicName.present ? arabicName.value : this.arabicName,
    category: category.present ? category.value : this.category,
    keywords: keywords ?? this.keywords,
    barcode: barcode.present ? barcode.value : this.barcode,
    servingSize: servingSize ?? this.servingSize,
    servingUnit: servingUnit ?? this.servingUnit,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fats: fats ?? this.fats,
    fiber: fiber ?? this.fiber,
    sugar: sugar ?? this.sugar,
    potassium: potassium ?? this.potassium,
    sodium: sodium ?? this.sodium,
    calcium: calcium ?? this.calcium,
    iron: iron ?? this.iron,
    magnesium: magnesium ?? this.magnesium,
    vitaminC: vitaminC ?? this.vitaminC,
    verified: verified ?? this.verified,
    isCustom: isCustom ?? this.isCustom,
    source: source ?? this.source,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Food copyWithCompanion(FoodsCompanion data) {
    return Food(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      name: data.name.present ? data.name.value : this.name,
      arabicName: data.arabicName.present
          ? data.arabicName.value
          : this.arabicName,
      category: data.category.present ? data.category.value : this.category,
      keywords: data.keywords.present ? data.keywords.value : this.keywords,
      barcode: data.barcode.present ? data.barcode.value : this.barcode,
      servingSize: data.servingSize.present
          ? data.servingSize.value
          : this.servingSize,
      servingUnit: data.servingUnit.present
          ? data.servingUnit.value
          : this.servingUnit,
      calories: data.calories.present ? data.calories.value : this.calories,
      protein: data.protein.present ? data.protein.value : this.protein,
      carbs: data.carbs.present ? data.carbs.value : this.carbs,
      fats: data.fats.present ? data.fats.value : this.fats,
      fiber: data.fiber.present ? data.fiber.value : this.fiber,
      sugar: data.sugar.present ? data.sugar.value : this.sugar,
      potassium: data.potassium.present ? data.potassium.value : this.potassium,
      sodium: data.sodium.present ? data.sodium.value : this.sodium,
      calcium: data.calcium.present ? data.calcium.value : this.calcium,
      iron: data.iron.present ? data.iron.value : this.iron,
      magnesium: data.magnesium.present ? data.magnesium.value : this.magnesium,
      vitaminC: data.vitaminC.present ? data.vitaminC.value : this.vitaminC,
      verified: data.verified.present ? data.verified.value : this.verified,
      isCustom: data.isCustom.present ? data.isCustom.value : this.isCustom,
      source: data.source.present ? data.source.value : this.source,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Food(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('arabicName: $arabicName, ')
          ..write('category: $category, ')
          ..write('keywords: $keywords, ')
          ..write('barcode: $barcode, ')
          ..write('servingSize: $servingSize, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fats: $fats, ')
          ..write('fiber: $fiber, ')
          ..write('sugar: $sugar, ')
          ..write('potassium: $potassium, ')
          ..write('sodium: $sodium, ')
          ..write('calcium: $calcium, ')
          ..write('iron: $iron, ')
          ..write('magnesium: $magnesium, ')
          ..write('vitaminC: $vitaminC, ')
          ..write('verified: $verified, ')
          ..write('isCustom: $isCustom, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    uuid,
    name,
    arabicName,
    category,
    keywords,
    barcode,
    servingSize,
    servingUnit,
    calories,
    protein,
    carbs,
    fats,
    fiber,
    sugar,
    potassium,
    sodium,
    calcium,
    iron,
    magnesium,
    vitaminC,
    verified,
    isCustom,
    source,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Food &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.name == this.name &&
          other.arabicName == this.arabicName &&
          other.category == this.category &&
          other.keywords == this.keywords &&
          other.barcode == this.barcode &&
          other.servingSize == this.servingSize &&
          other.servingUnit == this.servingUnit &&
          other.calories == this.calories &&
          other.protein == this.protein &&
          other.carbs == this.carbs &&
          other.fats == this.fats &&
          other.fiber == this.fiber &&
          other.sugar == this.sugar &&
          other.potassium == this.potassium &&
          other.sodium == this.sodium &&
          other.calcium == this.calcium &&
          other.iron == this.iron &&
          other.magnesium == this.magnesium &&
          other.vitaminC == this.vitaminC &&
          other.verified == this.verified &&
          other.isCustom == this.isCustom &&
          other.source == this.source &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.syncStatus == this.syncStatus);
}

class FoodsCompanion extends UpdateCompanion<Food> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> name;
  final Value<String?> arabicName;
  final Value<String?> category;
  final Value<String> keywords;
  final Value<String?> barcode;
  final Value<double> servingSize;
  final Value<String> servingUnit;
  final Value<double> calories;
  final Value<double> protein;
  final Value<double> carbs;
  final Value<double> fats;
  final Value<double> fiber;
  final Value<double> sugar;
  final Value<double> potassium;
  final Value<double> sodium;
  final Value<double> calcium;
  final Value<double> iron;
  final Value<double> magnesium;
  final Value<double> vitaminC;
  final Value<bool> verified;
  final Value<bool> isCustom;
  final Value<String> source;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> syncStatus;
  const FoodsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.name = const Value.absent(),
    this.arabicName = const Value.absent(),
    this.category = const Value.absent(),
    this.keywords = const Value.absent(),
    this.barcode = const Value.absent(),
    this.servingSize = const Value.absent(),
    this.servingUnit = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fats = const Value.absent(),
    this.fiber = const Value.absent(),
    this.sugar = const Value.absent(),
    this.potassium = const Value.absent(),
    this.sodium = const Value.absent(),
    this.calcium = const Value.absent(),
    this.iron = const Value.absent(),
    this.magnesium = const Value.absent(),
    this.vitaminC = const Value.absent(),
    this.verified = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  FoodsCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required String name,
    this.arabicName = const Value.absent(),
    this.category = const Value.absent(),
    this.keywords = const Value.absent(),
    this.barcode = const Value.absent(),
    this.servingSize = const Value.absent(),
    this.servingUnit = const Value.absent(),
    required double calories,
    required double protein,
    required double carbs,
    required double fats,
    this.fiber = const Value.absent(),
    this.sugar = const Value.absent(),
    this.potassium = const Value.absent(),
    this.sodium = const Value.absent(),
    this.calcium = const Value.absent(),
    this.iron = const Value.absent(),
    this.magnesium = const Value.absent(),
    this.vitaminC = const Value.absent(),
    this.verified = const Value.absent(),
    this.isCustom = const Value.absent(),
    this.source = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : name = Value(name),
       calories = Value(calories),
       protein = Value(protein),
       carbs = Value(carbs),
       fats = Value(fats);
  static Insertable<Food> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? name,
    Expression<String>? arabicName,
    Expression<String>? category,
    Expression<String>? keywords,
    Expression<String>? barcode,
    Expression<double>? servingSize,
    Expression<String>? servingUnit,
    Expression<double>? calories,
    Expression<double>? protein,
    Expression<double>? carbs,
    Expression<double>? fats,
    Expression<double>? fiber,
    Expression<double>? sugar,
    Expression<double>? potassium,
    Expression<double>? sodium,
    Expression<double>? calcium,
    Expression<double>? iron,
    Expression<double>? magnesium,
    Expression<double>? vitaminC,
    Expression<bool>? verified,
    Expression<bool>? isCustom,
    Expression<String>? source,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (name != null) 'name': name,
      if (arabicName != null) 'arabic_name': arabicName,
      if (category != null) 'category': category,
      if (keywords != null) 'keywords': keywords,
      if (barcode != null) 'barcode': barcode,
      if (servingSize != null) 'serving_size': servingSize,
      if (servingUnit != null) 'serving_unit': servingUnit,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fats != null) 'fats': fats,
      if (fiber != null) 'fiber': fiber,
      if (sugar != null) 'sugar': sugar,
      if (potassium != null) 'potassium': potassium,
      if (sodium != null) 'sodium': sodium,
      if (calcium != null) 'calcium': calcium,
      if (iron != null) 'iron': iron,
      if (magnesium != null) 'magnesium': magnesium,
      if (vitaminC != null) 'vitamin_c': vitaminC,
      if (verified != null) 'verified': verified,
      if (isCustom != null) 'is_custom': isCustom,
      if (source != null) 'source': source,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  FoodsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? name,
    Value<String?>? arabicName,
    Value<String?>? category,
    Value<String>? keywords,
    Value<String?>? barcode,
    Value<double>? servingSize,
    Value<String>? servingUnit,
    Value<double>? calories,
    Value<double>? protein,
    Value<double>? carbs,
    Value<double>? fats,
    Value<double>? fiber,
    Value<double>? sugar,
    Value<double>? potassium,
    Value<double>? sodium,
    Value<double>? calcium,
    Value<double>? iron,
    Value<double>? magnesium,
    Value<double>? vitaminC,
    Value<bool>? verified,
    Value<bool>? isCustom,
    Value<String>? source,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? syncStatus,
  }) {
    return FoodsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      name: name ?? this.name,
      arabicName: arabicName ?? this.arabicName,
      category: category ?? this.category,
      keywords: keywords ?? this.keywords,
      barcode: barcode ?? this.barcode,
      servingSize: servingSize ?? this.servingSize,
      servingUnit: servingUnit ?? this.servingUnit,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      fiber: fiber ?? this.fiber,
      sugar: sugar ?? this.sugar,
      potassium: potassium ?? this.potassium,
      sodium: sodium ?? this.sodium,
      calcium: calcium ?? this.calcium,
      iron: iron ?? this.iron,
      magnesium: magnesium ?? this.magnesium,
      vitaminC: vitaminC ?? this.vitaminC,
      verified: verified ?? this.verified,
      isCustom: isCustom ?? this.isCustom,
      source: source ?? this.source,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (arabicName.present) {
      map['arabic_name'] = Variable<String>(arabicName.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (keywords.present) {
      map['keywords'] = Variable<String>(keywords.value);
    }
    if (barcode.present) {
      map['barcode'] = Variable<String>(barcode.value);
    }
    if (servingSize.present) {
      map['serving_size'] = Variable<double>(servingSize.value);
    }
    if (servingUnit.present) {
      map['serving_unit'] = Variable<String>(servingUnit.value);
    }
    if (calories.present) {
      map['calories'] = Variable<double>(calories.value);
    }
    if (protein.present) {
      map['protein'] = Variable<double>(protein.value);
    }
    if (carbs.present) {
      map['carbs'] = Variable<double>(carbs.value);
    }
    if (fats.present) {
      map['fats'] = Variable<double>(fats.value);
    }
    if (fiber.present) {
      map['fiber'] = Variable<double>(fiber.value);
    }
    if (sugar.present) {
      map['sugar'] = Variable<double>(sugar.value);
    }
    if (potassium.present) {
      map['potassium'] = Variable<double>(potassium.value);
    }
    if (sodium.present) {
      map['sodium'] = Variable<double>(sodium.value);
    }
    if (calcium.present) {
      map['calcium'] = Variable<double>(calcium.value);
    }
    if (iron.present) {
      map['iron'] = Variable<double>(iron.value);
    }
    if (magnesium.present) {
      map['magnesium'] = Variable<double>(magnesium.value);
    }
    if (vitaminC.present) {
      map['vitamin_c'] = Variable<double>(vitaminC.value);
    }
    if (verified.present) {
      map['verified'] = Variable<bool>(verified.value);
    }
    if (isCustom.present) {
      map['is_custom'] = Variable<bool>(isCustom.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FoodsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('name: $name, ')
          ..write('arabicName: $arabicName, ')
          ..write('category: $category, ')
          ..write('keywords: $keywords, ')
          ..write('barcode: $barcode, ')
          ..write('servingSize: $servingSize, ')
          ..write('servingUnit: $servingUnit, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fats: $fats, ')
          ..write('fiber: $fiber, ')
          ..write('sugar: $sugar, ')
          ..write('potassium: $potassium, ')
          ..write('sodium: $sodium, ')
          ..write('calcium: $calcium, ')
          ..write('iron: $iron, ')
          ..write('magnesium: $magnesium, ')
          ..write('vitaminC: $vitaminC, ')
          ..write('verified: $verified, ')
          ..write('isCustom: $isCustom, ')
          ..write('source: $source, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $MealsTable extends Meals with TableInfo<$MealsTable, Meal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _dateMeta = const VerificationMeta('date');
  @override
  late final GeneratedColumn<DateTime> date = GeneratedColumn<DateTime>(
    'date',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('Meal'),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('other'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    date,
    dayKey,
    name,
    type,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Meal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('date')) {
      context.handle(
        _dateMeta,
        date.isAcceptableOrUnknown(data['date']!, _dateMeta),
      );
    } else if (isInserting) {
      context.missing(_dateMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Meal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Meal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      date: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}date'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $MealsTable createAlias(String alias) {
    return $MealsTable(attachedDatabase, alias);
  }
}

class Meal extends DataClass implements Insertable<Meal> {
  final int id;
  final String uuid;
  final DateTime date;
  final String dayKey;
  final String name;
  final String type;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String syncStatus;
  const Meal({
    required this.id,
    required this.uuid,
    required this.date,
    required this.dayKey,
    required this.name,
    required this.type,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['date'] = Variable<DateTime>(date);
    map['day_key'] = Variable<String>(dayKey);
    map['name'] = Variable<String>(name);
    map['type'] = Variable<String>(type);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  MealsCompanion toCompanion(bool nullToAbsent) {
    return MealsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      date: Value(date),
      dayKey: Value(dayKey),
      name: Value(name),
      type: Value(type),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      syncStatus: Value(syncStatus),
    );
  }

  factory Meal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Meal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      date: serializer.fromJson<DateTime>(json['date']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      name: serializer.fromJson<String>(json['name']),
      type: serializer.fromJson<String>(json['type']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'date': serializer.toJson<DateTime>(date),
      'dayKey': serializer.toJson<String>(dayKey),
      'name': serializer.toJson<String>(name),
      'type': serializer.toJson<String>(type),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  Meal copyWith({
    int? id,
    String? uuid,
    DateTime? date,
    String? dayKey,
    String? name,
    String? type,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? syncStatus,
  }) => Meal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    date: date ?? this.date,
    dayKey: dayKey ?? this.dayKey,
    name: name ?? this.name,
    type: type ?? this.type,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Meal copyWithCompanion(MealsCompanion data) {
    return Meal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      date: data.date.present ? data.date.value : this.date,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      name: data.name.present ? data.name.value : this.name,
      type: data.type.present ? data.type.value : this.type,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Meal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('date: $date, ')
          ..write('dayKey: $dayKey, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    date,
    dayKey,
    name,
    type,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Meal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.date == this.date &&
          other.dayKey == this.dayKey &&
          other.name == this.name &&
          other.type == this.type &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.syncStatus == this.syncStatus);
}

class MealsCompanion extends UpdateCompanion<Meal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<DateTime> date;
  final Value<String> dayKey;
  final Value<String> name;
  final Value<String> type;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> syncStatus;
  const MealsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.date = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  MealsCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required DateTime date,
    required String dayKey,
    this.name = const Value.absent(),
    this.type = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : date = Value(date),
       dayKey = Value(dayKey);
  static Insertable<Meal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<DateTime>? date,
    Expression<String>? dayKey,
    Expression<String>? name,
    Expression<String>? type,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (date != null) 'date': date,
      if (dayKey != null) 'day_key': dayKey,
      if (name != null) 'name': name,
      if (type != null) 'type': type,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  MealsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<DateTime>? date,
    Value<String>? dayKey,
    Value<String>? name,
    Value<String>? type,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? syncStatus,
  }) {
    return MealsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      date: date ?? this.date,
      dayKey: dayKey ?? this.dayKey,
      name: name ?? this.name,
      type: type ?? this.type,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (date.present) {
      map['date'] = Variable<DateTime>(date.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('date: $date, ')
          ..write('dayKey: $dayKey, ')
          ..write('name: $name, ')
          ..write('type: $type, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $MealItemsTable extends MealItems
    with TableInfo<$MealItemsTable, MealItem> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MealItemsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _mealIdMeta = const VerificationMeta('mealId');
  @override
  late final GeneratedColumn<int> mealId = GeneratedColumn<int>(
    'meal_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES meals (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES foods (id) ON DELETE RESTRICT',
    ),
  );
  static const VerificationMeta _quantityMeta = const VerificationMeta(
    'quantity',
  );
  @override
  late final GeneratedColumn<double> quantity = GeneratedColumn<double>(
    'quantity',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(100),
  );
  static const VerificationMeta _caloriesMeta = const VerificationMeta(
    'calories',
  );
  @override
  late final GeneratedColumn<double> calories = GeneratedColumn<double>(
    'calories',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _proteinMeta = const VerificationMeta(
    'protein',
  );
  @override
  late final GeneratedColumn<double> protein = GeneratedColumn<double>(
    'protein',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _carbsMeta = const VerificationMeta('carbs');
  @override
  late final GeneratedColumn<double> carbs = GeneratedColumn<double>(
    'carbs',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fatsMeta = const VerificationMeta('fats');
  @override
  late final GeneratedColumn<double> fats = GeneratedColumn<double>(
    'fats',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _fiberMeta = const VerificationMeta('fiber');
  @override
  late final GeneratedColumn<double> fiber = GeneratedColumn<double>(
    'fiber',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _sodiumMeta = const VerificationMeta('sodium');
  @override
  late final GeneratedColumn<double> sodium = GeneratedColumn<double>(
    'sodium',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _potassiumMeta = const VerificationMeta(
    'potassium',
  );
  @override
  late final GeneratedColumn<double> potassium = GeneratedColumn<double>(
    'potassium',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    mealId,
    foodId,
    quantity,
    calories,
    protein,
    carbs,
    fats,
    fiber,
    sodium,
    potassium,
    createdAt,
    updatedAt,
    deletedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meal_items';
  @override
  VerificationContext validateIntegrity(
    Insertable<MealItem> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('meal_id')) {
      context.handle(
        _mealIdMeta,
        mealId.isAcceptableOrUnknown(data['meal_id']!, _mealIdMeta),
      );
    } else if (isInserting) {
      context.missing(_mealIdMeta);
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('quantity')) {
      context.handle(
        _quantityMeta,
        quantity.isAcceptableOrUnknown(data['quantity']!, _quantityMeta),
      );
    }
    if (data.containsKey('calories')) {
      context.handle(
        _caloriesMeta,
        calories.isAcceptableOrUnknown(data['calories']!, _caloriesMeta),
      );
    }
    if (data.containsKey('protein')) {
      context.handle(
        _proteinMeta,
        protein.isAcceptableOrUnknown(data['protein']!, _proteinMeta),
      );
    }
    if (data.containsKey('carbs')) {
      context.handle(
        _carbsMeta,
        carbs.isAcceptableOrUnknown(data['carbs']!, _carbsMeta),
      );
    }
    if (data.containsKey('fats')) {
      context.handle(
        _fatsMeta,
        fats.isAcceptableOrUnknown(data['fats']!, _fatsMeta),
      );
    }
    if (data.containsKey('fiber')) {
      context.handle(
        _fiberMeta,
        fiber.isAcceptableOrUnknown(data['fiber']!, _fiberMeta),
      );
    }
    if (data.containsKey('sodium')) {
      context.handle(
        _sodiumMeta,
        sodium.isAcceptableOrUnknown(data['sodium']!, _sodiumMeta),
      );
    }
    if (data.containsKey('potassium')) {
      context.handle(
        _potassiumMeta,
        potassium.isAcceptableOrUnknown(data['potassium']!, _potassiumMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MealItem map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MealItem(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      mealId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}meal_id'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      quantity: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}quantity'],
      )!,
      calories: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}calories'],
      )!,
      protein: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}protein'],
      )!,
      carbs: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}carbs'],
      )!,
      fats: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fats'],
      )!,
      fiber: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}fiber'],
      )!,
      sodium: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}sodium'],
      )!,
      potassium: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}potassium'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
    );
  }

  @override
  $MealItemsTable createAlias(String alias) {
    return $MealItemsTable(attachedDatabase, alias);
  }
}

class MealItem extends DataClass implements Insertable<MealItem> {
  final int id;
  final String uuid;
  final int mealId;
  final int foodId;
  final double quantity;
  final double calories;
  final double protein;
  final double carbs;
  final double fats;
  final double fiber;
  final double sodium;
  final double potassium;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  const MealItem({
    required this.id,
    required this.uuid,
    required this.mealId,
    required this.foodId,
    required this.quantity,
    required this.calories,
    required this.protein,
    required this.carbs,
    required this.fats,
    required this.fiber,
    required this.sodium,
    required this.potassium,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['meal_id'] = Variable<int>(mealId);
    map['food_id'] = Variable<int>(foodId);
    map['quantity'] = Variable<double>(quantity);
    map['calories'] = Variable<double>(calories);
    map['protein'] = Variable<double>(protein);
    map['carbs'] = Variable<double>(carbs);
    map['fats'] = Variable<double>(fats);
    map['fiber'] = Variable<double>(fiber);
    map['sodium'] = Variable<double>(sodium);
    map['potassium'] = Variable<double>(potassium);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    return map;
  }

  MealItemsCompanion toCompanion(bool nullToAbsent) {
    return MealItemsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      mealId: Value(mealId),
      foodId: Value(foodId),
      quantity: Value(quantity),
      calories: Value(calories),
      protein: Value(protein),
      carbs: Value(carbs),
      fats: Value(fats),
      fiber: Value(fiber),
      sodium: Value(sodium),
      potassium: Value(potassium),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
    );
  }

  factory MealItem.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MealItem(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      mealId: serializer.fromJson<int>(json['mealId']),
      foodId: serializer.fromJson<int>(json['foodId']),
      quantity: serializer.fromJson<double>(json['quantity']),
      calories: serializer.fromJson<double>(json['calories']),
      protein: serializer.fromJson<double>(json['protein']),
      carbs: serializer.fromJson<double>(json['carbs']),
      fats: serializer.fromJson<double>(json['fats']),
      fiber: serializer.fromJson<double>(json['fiber']),
      sodium: serializer.fromJson<double>(json['sodium']),
      potassium: serializer.fromJson<double>(json['potassium']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'mealId': serializer.toJson<int>(mealId),
      'foodId': serializer.toJson<int>(foodId),
      'quantity': serializer.toJson<double>(quantity),
      'calories': serializer.toJson<double>(calories),
      'protein': serializer.toJson<double>(protein),
      'carbs': serializer.toJson<double>(carbs),
      'fats': serializer.toJson<double>(fats),
      'fiber': serializer.toJson<double>(fiber),
      'sodium': serializer.toJson<double>(sodium),
      'potassium': serializer.toJson<double>(potassium),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
    };
  }

  MealItem copyWith({
    int? id,
    String? uuid,
    int? mealId,
    int? foodId,
    double? quantity,
    double? calories,
    double? protein,
    double? carbs,
    double? fats,
    double? fiber,
    double? sodium,
    double? potassium,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
  }) => MealItem(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    mealId: mealId ?? this.mealId,
    foodId: foodId ?? this.foodId,
    quantity: quantity ?? this.quantity,
    calories: calories ?? this.calories,
    protein: protein ?? this.protein,
    carbs: carbs ?? this.carbs,
    fats: fats ?? this.fats,
    fiber: fiber ?? this.fiber,
    sodium: sodium ?? this.sodium,
    potassium: potassium ?? this.potassium,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
  );
  MealItem copyWithCompanion(MealItemsCompanion data) {
    return MealItem(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      mealId: data.mealId.present ? data.mealId.value : this.mealId,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      quantity: data.quantity.present ? data.quantity.value : this.quantity,
      calories: data.calories.present ? data.calories.value : this.calories,
      protein: data.protein.present ? data.protein.value : this.protein,
      carbs: data.carbs.present ? data.carbs.value : this.carbs,
      fats: data.fats.present ? data.fats.value : this.fats,
      fiber: data.fiber.present ? data.fiber.value : this.fiber,
      sodium: data.sodium.present ? data.sodium.value : this.sodium,
      potassium: data.potassium.present ? data.potassium.value : this.potassium,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MealItem(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('mealId: $mealId, ')
          ..write('foodId: $foodId, ')
          ..write('quantity: $quantity, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fats: $fats, ')
          ..write('fiber: $fiber, ')
          ..write('sodium: $sodium, ')
          ..write('potassium: $potassium, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    mealId,
    foodId,
    quantity,
    calories,
    protein,
    carbs,
    fats,
    fiber,
    sodium,
    potassium,
    createdAt,
    updatedAt,
    deletedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MealItem &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.mealId == this.mealId &&
          other.foodId == this.foodId &&
          other.quantity == this.quantity &&
          other.calories == this.calories &&
          other.protein == this.protein &&
          other.carbs == this.carbs &&
          other.fats == this.fats &&
          other.fiber == this.fiber &&
          other.sodium == this.sodium &&
          other.potassium == this.potassium &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt);
}

class MealItemsCompanion extends UpdateCompanion<MealItem> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<int> mealId;
  final Value<int> foodId;
  final Value<double> quantity;
  final Value<double> calories;
  final Value<double> protein;
  final Value<double> carbs;
  final Value<double> fats;
  final Value<double> fiber;
  final Value<double> sodium;
  final Value<double> potassium;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  const MealItemsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.mealId = const Value.absent(),
    this.foodId = const Value.absent(),
    this.quantity = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fats = const Value.absent(),
    this.fiber = const Value.absent(),
    this.sodium = const Value.absent(),
    this.potassium = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  });
  MealItemsCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required int mealId,
    required int foodId,
    this.quantity = const Value.absent(),
    this.calories = const Value.absent(),
    this.protein = const Value.absent(),
    this.carbs = const Value.absent(),
    this.fats = const Value.absent(),
    this.fiber = const Value.absent(),
    this.sodium = const Value.absent(),
    this.potassium = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
  }) : mealId = Value(mealId),
       foodId = Value(foodId);
  static Insertable<MealItem> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<int>? mealId,
    Expression<int>? foodId,
    Expression<double>? quantity,
    Expression<double>? calories,
    Expression<double>? protein,
    Expression<double>? carbs,
    Expression<double>? fats,
    Expression<double>? fiber,
    Expression<double>? sodium,
    Expression<double>? potassium,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (mealId != null) 'meal_id': mealId,
      if (foodId != null) 'food_id': foodId,
      if (quantity != null) 'quantity': quantity,
      if (calories != null) 'calories': calories,
      if (protein != null) 'protein': protein,
      if (carbs != null) 'carbs': carbs,
      if (fats != null) 'fats': fats,
      if (fiber != null) 'fiber': fiber,
      if (sodium != null) 'sodium': sodium,
      if (potassium != null) 'potassium': potassium,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
    });
  }

  MealItemsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<int>? mealId,
    Value<int>? foodId,
    Value<double>? quantity,
    Value<double>? calories,
    Value<double>? protein,
    Value<double>? carbs,
    Value<double>? fats,
    Value<double>? fiber,
    Value<double>? sodium,
    Value<double>? potassium,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
  }) {
    return MealItemsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      mealId: mealId ?? this.mealId,
      foodId: foodId ?? this.foodId,
      quantity: quantity ?? this.quantity,
      calories: calories ?? this.calories,
      protein: protein ?? this.protein,
      carbs: carbs ?? this.carbs,
      fats: fats ?? this.fats,
      fiber: fiber ?? this.fiber,
      sodium: sodium ?? this.sodium,
      potassium: potassium ?? this.potassium,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (mealId.present) {
      map['meal_id'] = Variable<int>(mealId.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (quantity.present) {
      map['quantity'] = Variable<double>(quantity.value);
    }
    if (calories.present) {
      map['calories'] = Variable<double>(calories.value);
    }
    if (protein.present) {
      map['protein'] = Variable<double>(protein.value);
    }
    if (carbs.present) {
      map['carbs'] = Variable<double>(carbs.value);
    }
    if (fats.present) {
      map['fats'] = Variable<double>(fats.value);
    }
    if (fiber.present) {
      map['fiber'] = Variable<double>(fiber.value);
    }
    if (sodium.present) {
      map['sodium'] = Variable<double>(sodium.value);
    }
    if (potassium.present) {
      map['potassium'] = Variable<double>(potassium.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MealItemsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('mealId: $mealId, ')
          ..write('foodId: $foodId, ')
          ..write('quantity: $quantity, ')
          ..write('calories: $calories, ')
          ..write('protein: $protein, ')
          ..write('carbs: $carbs, ')
          ..write('fats: $fats, ')
          ..write('fiber: $fiber, ')
          ..write('sodium: $sodium, ')
          ..write('potassium: $potassium, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt')
          ..write(')'))
        .toString();
  }
}

class $FavoritesTable extends Favorites
    with TableInfo<$FavoritesTable, Favorite> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FavoritesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'UNIQUE REFERENCES foods (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [id, foodId, createdAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'favorites';
  @override
  VerificationContext validateIntegrity(
    Insertable<Favorite> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    } else if (isInserting) {
      context.missing(_foodIdMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Favorite map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Favorite(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $FavoritesTable createAlias(String alias) {
    return $FavoritesTable(attachedDatabase, alias);
  }
}

class Favorite extends DataClass implements Insertable<Favorite> {
  final int id;
  final int foodId;
  final DateTime createdAt;
  const Favorite({
    required this.id,
    required this.foodId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['food_id'] = Variable<int>(foodId);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  FavoritesCompanion toCompanion(bool nullToAbsent) {
    return FavoritesCompanion(
      id: Value(id),
      foodId: Value(foodId),
      createdAt: Value(createdAt),
    );
  }

  factory Favorite.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Favorite(
      id: serializer.fromJson<int>(json['id']),
      foodId: serializer.fromJson<int>(json['foodId']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'foodId': serializer.toJson<int>(foodId),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Favorite copyWith({int? id, int? foodId, DateTime? createdAt}) => Favorite(
    id: id ?? this.id,
    foodId: foodId ?? this.foodId,
    createdAt: createdAt ?? this.createdAt,
  );
  Favorite copyWithCompanion(FavoritesCompanion data) {
    return Favorite(
      id: data.id.present ? data.id.value : this.id,
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Favorite(')
          ..write('id: $id, ')
          ..write('foodId: $foodId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, foodId, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Favorite &&
          other.id == this.id &&
          other.foodId == this.foodId &&
          other.createdAt == this.createdAt);
}

class FavoritesCompanion extends UpdateCompanion<Favorite> {
  final Value<int> id;
  final Value<int> foodId;
  final Value<DateTime> createdAt;
  const FavoritesCompanion({
    this.id = const Value.absent(),
    this.foodId = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  FavoritesCompanion.insert({
    this.id = const Value.absent(),
    required int foodId,
    this.createdAt = const Value.absent(),
  }) : foodId = Value(foodId);
  static Insertable<Favorite> custom({
    Expression<int>? id,
    Expression<int>? foodId,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (foodId != null) 'food_id': foodId,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  FavoritesCompanion copyWith({
    Value<int>? id,
    Value<int>? foodId,
    Value<DateTime>? createdAt,
  }) {
    return FavoritesCompanion(
      id: id ?? this.id,
      foodId: foodId ?? this.foodId,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FavoritesCompanion(')
          ..write('id: $id, ')
          ..write('foodId: $foodId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $RecentFoodsTable extends RecentFoods
    with TableInfo<$RecentFoodsTable, RecentFood> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RecentFoodsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _foodIdMeta = const VerificationMeta('foodId');
  @override
  late final GeneratedColumn<int> foodId = GeneratedColumn<int>(
    'food_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES foods (id) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _lastUsedAtMeta = const VerificationMeta(
    'lastUsedAt',
  );
  @override
  late final GeneratedColumn<DateTime> lastUsedAt = GeneratedColumn<DateTime>(
    'last_used_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _useCountMeta = const VerificationMeta(
    'useCount',
  );
  @override
  late final GeneratedColumn<int> useCount = GeneratedColumn<int>(
    'use_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  @override
  List<GeneratedColumn> get $columns => [foodId, lastUsedAt, useCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'recent_foods';
  @override
  VerificationContext validateIntegrity(
    Insertable<RecentFood> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('food_id')) {
      context.handle(
        _foodIdMeta,
        foodId.isAcceptableOrUnknown(data['food_id']!, _foodIdMeta),
      );
    }
    if (data.containsKey('last_used_at')) {
      context.handle(
        _lastUsedAtMeta,
        lastUsedAt.isAcceptableOrUnknown(
          data['last_used_at']!,
          _lastUsedAtMeta,
        ),
      );
    }
    if (data.containsKey('use_count')) {
      context.handle(
        _useCountMeta,
        useCount.isAcceptableOrUnknown(data['use_count']!, _useCountMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {foodId};
  @override
  RecentFood map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RecentFood(
      foodId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}food_id'],
      )!,
      lastUsedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}last_used_at'],
      )!,
      useCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}use_count'],
      )!,
    );
  }

  @override
  $RecentFoodsTable createAlias(String alias) {
    return $RecentFoodsTable(attachedDatabase, alias);
  }
}

class RecentFood extends DataClass implements Insertable<RecentFood> {
  final int foodId;
  final DateTime lastUsedAt;
  final int useCount;
  const RecentFood({
    required this.foodId,
    required this.lastUsedAt,
    required this.useCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['food_id'] = Variable<int>(foodId);
    map['last_used_at'] = Variable<DateTime>(lastUsedAt);
    map['use_count'] = Variable<int>(useCount);
    return map;
  }

  RecentFoodsCompanion toCompanion(bool nullToAbsent) {
    return RecentFoodsCompanion(
      foodId: Value(foodId),
      lastUsedAt: Value(lastUsedAt),
      useCount: Value(useCount),
    );
  }

  factory RecentFood.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RecentFood(
      foodId: serializer.fromJson<int>(json['foodId']),
      lastUsedAt: serializer.fromJson<DateTime>(json['lastUsedAt']),
      useCount: serializer.fromJson<int>(json['useCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'foodId': serializer.toJson<int>(foodId),
      'lastUsedAt': serializer.toJson<DateTime>(lastUsedAt),
      'useCount': serializer.toJson<int>(useCount),
    };
  }

  RecentFood copyWith({int? foodId, DateTime? lastUsedAt, int? useCount}) =>
      RecentFood(
        foodId: foodId ?? this.foodId,
        lastUsedAt: lastUsedAt ?? this.lastUsedAt,
        useCount: useCount ?? this.useCount,
      );
  RecentFood copyWithCompanion(RecentFoodsCompanion data) {
    return RecentFood(
      foodId: data.foodId.present ? data.foodId.value : this.foodId,
      lastUsedAt: data.lastUsedAt.present
          ? data.lastUsedAt.value
          : this.lastUsedAt,
      useCount: data.useCount.present ? data.useCount.value : this.useCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RecentFood(')
          ..write('foodId: $foodId, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('useCount: $useCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(foodId, lastUsedAt, useCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RecentFood &&
          other.foodId == this.foodId &&
          other.lastUsedAt == this.lastUsedAt &&
          other.useCount == this.useCount);
}

class RecentFoodsCompanion extends UpdateCompanion<RecentFood> {
  final Value<int> foodId;
  final Value<DateTime> lastUsedAt;
  final Value<int> useCount;
  const RecentFoodsCompanion({
    this.foodId = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.useCount = const Value.absent(),
  });
  RecentFoodsCompanion.insert({
    this.foodId = const Value.absent(),
    this.lastUsedAt = const Value.absent(),
    this.useCount = const Value.absent(),
  });
  static Insertable<RecentFood> custom({
    Expression<int>? foodId,
    Expression<DateTime>? lastUsedAt,
    Expression<int>? useCount,
  }) {
    return RawValuesInsertable({
      if (foodId != null) 'food_id': foodId,
      if (lastUsedAt != null) 'last_used_at': lastUsedAt,
      if (useCount != null) 'use_count': useCount,
    });
  }

  RecentFoodsCompanion copyWith({
    Value<int>? foodId,
    Value<DateTime>? lastUsedAt,
    Value<int>? useCount,
  }) {
    return RecentFoodsCompanion(
      foodId: foodId ?? this.foodId,
      lastUsedAt: lastUsedAt ?? this.lastUsedAt,
      useCount: useCount ?? this.useCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (foodId.present) {
      map['food_id'] = Variable<int>(foodId.value);
    }
    if (lastUsedAt.present) {
      map['last_used_at'] = Variable<DateTime>(lastUsedAt.value);
    }
    if (useCount.present) {
      map['use_count'] = Variable<int>(useCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RecentFoodsCompanion(')
          ..write('foodId: $foodId, ')
          ..write('lastUsedAt: $lastUsedAt, ')
          ..write('useCount: $useCount')
          ..write(')'))
        .toString();
  }
}

class $GoalsTable extends Goals with TableInfo<$GoalsTable, Goal> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GoalsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _profileUuidMeta = const VerificationMeta(
    'profileUuid',
  );
  @override
  late final GeneratedColumn<String> profileUuid = GeneratedColumn<String>(
    'profile_uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES user_profile (uuid) ON DELETE CASCADE',
    ),
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetWeightMeta = const VerificationMeta(
    'targetWeight',
  );
  @override
  late final GeneratedColumn<double> targetWeight = GeneratedColumn<double>(
    'target_weight',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _targetDateMeta = const VerificationMeta(
    'targetDate',
  );
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
    'target_date',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    profileUuid,
    type,
    targetWeight,
    targetDate,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'goals';
  @override
  VerificationContext validateIntegrity(
    Insertable<Goal> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('profile_uuid')) {
      context.handle(
        _profileUuidMeta,
        profileUuid.isAcceptableOrUnknown(
          data['profile_uuid']!,
          _profileUuidMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_profileUuidMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('target_weight')) {
      context.handle(
        _targetWeightMeta,
        targetWeight.isAcceptableOrUnknown(
          data['target_weight']!,
          _targetWeightMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_targetWeightMeta);
    }
    if (data.containsKey('target_date')) {
      context.handle(
        _targetDateMeta,
        targetDate.isAcceptableOrUnknown(data['target_date']!, _targetDateMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Goal map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Goal(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      profileUuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}profile_uuid'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      targetWeight: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}target_weight'],
      )!,
      targetDate: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}target_date'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $GoalsTable createAlias(String alias) {
    return $GoalsTable(attachedDatabase, alias);
  }
}

class Goal extends DataClass implements Insertable<Goal> {
  final int id;
  final String uuid;
  final String profileUuid;
  final String type;
  final double targetWeight;
  final DateTime? targetDate;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String syncStatus;
  const Goal({
    required this.id,
    required this.uuid,
    required this.profileUuid,
    required this.type,
    required this.targetWeight,
    this.targetDate,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['profile_uuid'] = Variable<String>(profileUuid);
    map['type'] = Variable<String>(type);
    map['target_weight'] = Variable<double>(targetWeight);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  GoalsCompanion toCompanion(bool nullToAbsent) {
    return GoalsCompanion(
      id: Value(id),
      uuid: Value(uuid),
      profileUuid: Value(profileUuid),
      type: Value(type),
      targetWeight: Value(targetWeight),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      syncStatus: Value(syncStatus),
    );
  }

  factory Goal.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Goal(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      profileUuid: serializer.fromJson<String>(json['profileUuid']),
      type: serializer.fromJson<String>(json['type']),
      targetWeight: serializer.fromJson<double>(json['targetWeight']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'profileUuid': serializer.toJson<String>(profileUuid),
      'type': serializer.toJson<String>(type),
      'targetWeight': serializer.toJson<double>(targetWeight),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  Goal copyWith({
    int? id,
    String? uuid,
    String? profileUuid,
    String? type,
    double? targetWeight,
    Value<DateTime?> targetDate = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? syncStatus,
  }) => Goal(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    profileUuid: profileUuid ?? this.profileUuid,
    type: type ?? this.type,
    targetWeight: targetWeight ?? this.targetWeight,
    targetDate: targetDate.present ? targetDate.value : this.targetDate,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  Goal copyWithCompanion(GoalsCompanion data) {
    return Goal(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      profileUuid: data.profileUuid.present
          ? data.profileUuid.value
          : this.profileUuid,
      type: data.type.present ? data.type.value : this.type,
      targetWeight: data.targetWeight.present
          ? data.targetWeight.value
          : this.targetWeight,
      targetDate: data.targetDate.present
          ? data.targetDate.value
          : this.targetDate,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Goal(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('profileUuid: $profileUuid, ')
          ..write('type: $type, ')
          ..write('targetWeight: $targetWeight, ')
          ..write('targetDate: $targetDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    profileUuid,
    type,
    targetWeight,
    targetDate,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Goal &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.profileUuid == this.profileUuid &&
          other.type == this.type &&
          other.targetWeight == this.targetWeight &&
          other.targetDate == this.targetDate &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.syncStatus == this.syncStatus);
}

class GoalsCompanion extends UpdateCompanion<Goal> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> profileUuid;
  final Value<String> type;
  final Value<double> targetWeight;
  final Value<DateTime?> targetDate;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> syncStatus;
  const GoalsCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.profileUuid = const Value.absent(),
    this.type = const Value.absent(),
    this.targetWeight = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  GoalsCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required String profileUuid,
    required String type,
    required double targetWeight,
    this.targetDate = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : profileUuid = Value(profileUuid),
       type = Value(type),
       targetWeight = Value(targetWeight);
  static Insertable<Goal> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? profileUuid,
    Expression<String>? type,
    Expression<double>? targetWeight,
    Expression<DateTime>? targetDate,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (profileUuid != null) 'profile_uuid': profileUuid,
      if (type != null) 'type': type,
      if (targetWeight != null) 'target_weight': targetWeight,
      if (targetDate != null) 'target_date': targetDate,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  GoalsCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? profileUuid,
    Value<String>? type,
    Value<double>? targetWeight,
    Value<DateTime?>? targetDate,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? syncStatus,
  }) {
    return GoalsCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      profileUuid: profileUuid ?? this.profileUuid,
      type: type ?? this.type,
      targetWeight: targetWeight ?? this.targetWeight,
      targetDate: targetDate ?? this.targetDate,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (profileUuid.present) {
      map['profile_uuid'] = Variable<String>(profileUuid.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (targetWeight.present) {
      map['target_weight'] = Variable<double>(targetWeight.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GoalsCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('profileUuid: $profileUuid, ')
          ..write('type: $type, ')
          ..write('targetWeight: $targetWeight, ')
          ..write('targetDate: $targetDate, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $WaterEntriesTable extends WaterEntries
    with TableInfo<$WaterEntriesTable, WaterEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $WaterEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _amountMlMeta = const VerificationMeta(
    'amountMl',
  );
  @override
  late final GeneratedColumn<int> amountMl = GeneratedColumn<int>(
    'amount_ml',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    occurredAt,
    dayKey,
    amountMl,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'water_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<WaterEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('amount_ml')) {
      context.handle(
        _amountMlMeta,
        amountMl.isAcceptableOrUnknown(data['amount_ml']!, _amountMlMeta),
      );
    } else if (isInserting) {
      context.missing(_amountMlMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  WaterEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return WaterEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      amountMl: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}amount_ml'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $WaterEntriesTable createAlias(String alias) {
    return $WaterEntriesTable(attachedDatabase, alias);
  }
}

class WaterEntry extends DataClass implements Insertable<WaterEntry> {
  final int id;
  final String uuid;
  final DateTime occurredAt;
  final String dayKey;
  final int amountMl;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String syncStatus;
  const WaterEntry({
    required this.id,
    required this.uuid,
    required this.occurredAt,
    required this.dayKey,
    required this.amountMl,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['day_key'] = Variable<String>(dayKey);
    map['amount_ml'] = Variable<int>(amountMl);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  WaterEntriesCompanion toCompanion(bool nullToAbsent) {
    return WaterEntriesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      occurredAt: Value(occurredAt),
      dayKey: Value(dayKey),
      amountMl: Value(amountMl),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      syncStatus: Value(syncStatus),
    );
  }

  factory WaterEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return WaterEntry(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      amountMl: serializer.fromJson<int>(json['amountMl']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'dayKey': serializer.toJson<String>(dayKey),
      'amountMl': serializer.toJson<int>(amountMl),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  WaterEntry copyWith({
    int? id,
    String? uuid,
    DateTime? occurredAt,
    String? dayKey,
    int? amountMl,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? syncStatus,
  }) => WaterEntry(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    occurredAt: occurredAt ?? this.occurredAt,
    dayKey: dayKey ?? this.dayKey,
    amountMl: amountMl ?? this.amountMl,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  WaterEntry copyWithCompanion(WaterEntriesCompanion data) {
    return WaterEntry(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      amountMl: data.amountMl.present ? data.amountMl.value : this.amountMl,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('WaterEntry(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayKey: $dayKey, ')
          ..write('amountMl: $amountMl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    occurredAt,
    dayKey,
    amountMl,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is WaterEntry &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.occurredAt == this.occurredAt &&
          other.dayKey == this.dayKey &&
          other.amountMl == this.amountMl &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.syncStatus == this.syncStatus);
}

class WaterEntriesCompanion extends UpdateCompanion<WaterEntry> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<DateTime> occurredAt;
  final Value<String> dayKey;
  final Value<int> amountMl;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> syncStatus;
  const WaterEntriesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.amountMl = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  WaterEntriesCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required DateTime occurredAt,
    required String dayKey,
    required int amountMl,
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : occurredAt = Value(occurredAt),
       dayKey = Value(dayKey),
       amountMl = Value(amountMl);
  static Insertable<WaterEntry> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<DateTime>? occurredAt,
    Expression<String>? dayKey,
    Expression<int>? amountMl,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (dayKey != null) 'day_key': dayKey,
      if (amountMl != null) 'amount_ml': amountMl,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  WaterEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<DateTime>? occurredAt,
    Value<String>? dayKey,
    Value<int>? amountMl,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? syncStatus,
  }) {
    return WaterEntriesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      occurredAt: occurredAt ?? this.occurredAt,
      dayKey: dayKey ?? this.dayKey,
      amountMl: amountMl ?? this.amountMl,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (amountMl.present) {
      map['amount_ml'] = Variable<int>(amountMl.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('WaterEntriesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayKey: $dayKey, ')
          ..write('amountMl: $amountMl, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $PreferencesTable extends Preferences
    with TableInfo<$PreferencesTable, Preference> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<Preference> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  Preference map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Preference(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $PreferencesTable createAlias(String alias) {
    return $PreferencesTable(attachedDatabase, alias);
  }
}

class Preference extends DataClass implements Insertable<Preference> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const Preference({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  PreferencesCompanion toCompanion(bool nullToAbsent) {
    return PreferencesCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory Preference.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Preference(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Preference copyWith({String? key, String? value, DateTime? updatedAt}) =>
      Preference(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  Preference copyWithCompanion(PreferencesCompanion data) {
    return Preference(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Preference(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Preference &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class PreferencesCompanion extends UpdateCompanion<Preference> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const PreferencesCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  PreferencesCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<Preference> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  PreferencesCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return PreferencesCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PreferencesCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LifeContextEntriesTable extends LifeContextEntries
    with TableInfo<$LifeContextEntriesTable, LifeContextEntry> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LifeContextEntriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _occurredAtMeta = const VerificationMeta(
    'occurredAt',
  );
  @override
  late final GeneratedColumn<DateTime> occurredAt = GeneratedColumn<DateTime>(
    'occurred_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _typeMeta = const VerificationMeta('type');
  @override
  late final GeneratedColumn<String> type = GeneratedColumn<String>(
    'type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _detailsMeta = const VerificationMeta(
    'details',
  );
  @override
  late final GeneratedColumn<String> details = GeneratedColumn<String>(
    'details',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _useInInsightsMeta = const VerificationMeta(
    'useInInsights',
  );
  @override
  late final GeneratedColumn<bool> useInInsights = GeneratedColumn<bool>(
    'use_in_insights',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("use_in_insights" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    occurredAt,
    dayKey,
    type,
    details,
    useInInsights,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'life_context_entries';
  @override
  VerificationContext validateIntegrity(
    Insertable<LifeContextEntry> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('occurred_at')) {
      context.handle(
        _occurredAtMeta,
        occurredAt.isAcceptableOrUnknown(data['occurred_at']!, _occurredAtMeta),
      );
    } else if (isInserting) {
      context.missing(_occurredAtMeta);
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('type')) {
      context.handle(
        _typeMeta,
        type.isAcceptableOrUnknown(data['type']!, _typeMeta),
      );
    } else if (isInserting) {
      context.missing(_typeMeta);
    }
    if (data.containsKey('details')) {
      context.handle(
        _detailsMeta,
        details.isAcceptableOrUnknown(data['details']!, _detailsMeta),
      );
    }
    if (data.containsKey('use_in_insights')) {
      context.handle(
        _useInInsightsMeta,
        useInInsights.isAcceptableOrUnknown(
          data['use_in_insights']!,
          _useInInsightsMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LifeContextEntry map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LifeContextEntry(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      occurredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}occurred_at'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      type: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}type'],
      )!,
      details: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}details'],
      ),
      useInInsights: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}use_in_insights'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LifeContextEntriesTable createAlias(String alias) {
    return $LifeContextEntriesTable(attachedDatabase, alias);
  }
}

class LifeContextEntry extends DataClass
    implements Insertable<LifeContextEntry> {
  final int id;
  final String uuid;
  final DateTime occurredAt;
  final String dayKey;
  final String type;
  final String? details;
  final bool useInInsights;
  final DateTime createdAt;
  final DateTime updatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String syncStatus;
  const LifeContextEntry({
    required this.id,
    required this.uuid,
    required this.occurredAt,
    required this.dayKey,
    required this.type,
    this.details,
    required this.useInInsights,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
    required this.revision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['occurred_at'] = Variable<DateTime>(occurredAt);
    map['day_key'] = Variable<String>(dayKey);
    map['type'] = Variable<String>(type);
    if (!nullToAbsent || details != null) {
      map['details'] = Variable<String>(details);
    }
    map['use_in_insights'] = Variable<bool>(useInInsights);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LifeContextEntriesCompanion toCompanion(bool nullToAbsent) {
    return LifeContextEntriesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      occurredAt: Value(occurredAt),
      dayKey: Value(dayKey),
      type: Value(type),
      details: details == null && nullToAbsent
          ? const Value.absent()
          : Value(details),
      useInInsights: Value(useInInsights),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      syncStatus: Value(syncStatus),
    );
  }

  factory LifeContextEntry.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LifeContextEntry(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      occurredAt: serializer.fromJson<DateTime>(json['occurredAt']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      type: serializer.fromJson<String>(json['type']),
      details: serializer.fromJson<String?>(json['details']),
      useInInsights: serializer.fromJson<bool>(json['useInInsights']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'occurredAt': serializer.toJson<DateTime>(occurredAt),
      'dayKey': serializer.toJson<String>(dayKey),
      'type': serializer.toJson<String>(type),
      'details': serializer.toJson<String?>(details),
      'useInInsights': serializer.toJson<bool>(useInInsights),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  LifeContextEntry copyWith({
    int? id,
    String? uuid,
    DateTime? occurredAt,
    String? dayKey,
    String? type,
    Value<String?> details = const Value.absent(),
    bool? useInInsights,
    DateTime? createdAt,
    DateTime? updatedAt,
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? syncStatus,
  }) => LifeContextEntry(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    occurredAt: occurredAt ?? this.occurredAt,
    dayKey: dayKey ?? this.dayKey,
    type: type ?? this.type,
    details: details.present ? details.value : this.details,
    useInInsights: useInInsights ?? this.useInInsights,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  LifeContextEntry copyWithCompanion(LifeContextEntriesCompanion data) {
    return LifeContextEntry(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      occurredAt: data.occurredAt.present
          ? data.occurredAt.value
          : this.occurredAt,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      type: data.type.present ? data.type.value : this.type,
      details: data.details.present ? data.details.value : this.details,
      useInInsights: data.useInInsights.present
          ? data.useInInsights.value
          : this.useInInsights,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LifeContextEntry(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayKey: $dayKey, ')
          ..write('type: $type, ')
          ..write('details: $details, ')
          ..write('useInInsights: $useInInsights, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    occurredAt,
    dayKey,
    type,
    details,
    useInInsights,
    createdAt,
    updatedAt,
    deletedAt,
    revision,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LifeContextEntry &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.occurredAt == this.occurredAt &&
          other.dayKey == this.dayKey &&
          other.type == this.type &&
          other.details == this.details &&
          other.useInInsights == this.useInInsights &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.syncStatus == this.syncStatus);
}

class LifeContextEntriesCompanion extends UpdateCompanion<LifeContextEntry> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<DateTime> occurredAt;
  final Value<String> dayKey;
  final Value<String> type;
  final Value<String?> details;
  final Value<bool> useInInsights;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> syncStatus;
  const LifeContextEntriesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.occurredAt = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.type = const Value.absent(),
    this.details = const Value.absent(),
    this.useInInsights = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  LifeContextEntriesCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required DateTime occurredAt,
    required String dayKey,
    required String type,
    this.details = const Value.absent(),
    this.useInInsights = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : occurredAt = Value(occurredAt),
       dayKey = Value(dayKey),
       type = Value(type);
  static Insertable<LifeContextEntry> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<DateTime>? occurredAt,
    Expression<String>? dayKey,
    Expression<String>? type,
    Expression<String>? details,
    Expression<bool>? useInInsights,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (occurredAt != null) 'occurred_at': occurredAt,
      if (dayKey != null) 'day_key': dayKey,
      if (type != null) 'type': type,
      if (details != null) 'details': details,
      if (useInInsights != null) 'use_in_insights': useInInsights,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  LifeContextEntriesCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<DateTime>? occurredAt,
    Value<String>? dayKey,
    Value<String>? type,
    Value<String?>? details,
    Value<bool>? useInInsights,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? syncStatus,
  }) {
    return LifeContextEntriesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      occurredAt: occurredAt ?? this.occurredAt,
      dayKey: dayKey ?? this.dayKey,
      type: type ?? this.type,
      details: details ?? this.details,
      useInInsights: useInInsights ?? this.useInInsights,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (occurredAt.present) {
      map['occurred_at'] = Variable<DateTime>(occurredAt.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (type.present) {
      map['type'] = Variable<String>(type.value);
    }
    if (details.present) {
      map['details'] = Variable<String>(details.value);
    }
    if (useInInsights.present) {
      map['use_in_insights'] = Variable<bool>(useInInsights.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LifeContextEntriesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('occurredAt: $occurredAt, ')
          ..write('dayKey: $dayKey, ')
          ..write('type: $type, ')
          ..write('details: $details, ')
          ..write('useInInsights: $useInInsights, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

class $DecisionMemoriesTable extends DecisionMemories
    with TableInfo<$DecisionMemoriesTable, DecisionMemory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DecisionMemoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _uuidMeta = const VerificationMeta('uuid');
  @override
  late final GeneratedColumn<String> uuid = GeneratedColumn<String>(
    'uuid',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways('UNIQUE'),
    clientDefault: newDatabaseId,
  );
  static const VerificationMeta _dayKeyMeta = const VerificationMeta('dayKey');
  @override
  late final GeneratedColumn<String> dayKey = GeneratedColumn<String>(
    'day_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recommendationKeyMeta = const VerificationMeta(
    'recommendationKey',
  );
  @override
  late final GeneratedColumn<String> recommendationKey =
      GeneratedColumn<String>(
        'recommendation_key',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
    'title',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonMeta = const VerificationMeta('reason');
  @override
  late final GeneratedColumn<String> reason = GeneratedColumn<String>(
    'reason',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _evidenceJsonMeta = const VerificationMeta(
    'evidenceJson',
  );
  @override
  late final GeneratedColumn<String> evidenceJson = GeneratedColumn<String>(
    'evidence_json',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('[]'),
  );
  static const VerificationMeta _confidenceMeta = const VerificationMeta(
    'confidence',
  );
  @override
  late final GeneratedColumn<String> confidence = GeneratedColumn<String>(
    'confidence',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('low'),
  );
  static const VerificationMeta _responseMeta = const VerificationMeta(
    'response',
  );
  @override
  late final GeneratedColumn<String> response = GeneratedColumn<String>(
    'response',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _helpfulnessMeta = const VerificationMeta(
    'helpfulness',
  );
  @override
  late final GeneratedColumn<int> helpfulness = GeneratedColumn<int>(
    'helpfulness',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _surfacedAtMeta = const VerificationMeta(
    'surfacedAt',
  );
  @override
  late final GeneratedColumn<DateTime> surfacedAt = GeneratedColumn<DateTime>(
    'surfaced_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _respondedAtMeta = const VerificationMeta(
    'respondedAt',
  );
  @override
  late final GeneratedColumn<DateTime> respondedAt = GeneratedColumn<DateTime>(
    'responded_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evaluatedAtMeta = const VerificationMeta(
    'evaluatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> evaluatedAt = GeneratedColumn<DateTime>(
    'evaluated_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _deletedAtMeta = const VerificationMeta(
    'deletedAt',
  );
  @override
  late final GeneratedColumn<DateTime> deletedAt = GeneratedColumn<DateTime>(
    'deleted_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _revisionMeta = const VerificationMeta(
    'revision',
  );
  @override
  late final GeneratedColumn<int> revision = GeneratedColumn<int>(
    'revision',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('local'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    uuid,
    dayKey,
    recommendationKey,
    title,
    reason,
    evidenceJson,
    confidence,
    response,
    outcome,
    helpfulness,
    surfacedAt,
    respondedAt,
    evaluatedAt,
    deletedAt,
    revision,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'decision_memories';
  @override
  VerificationContext validateIntegrity(
    Insertable<DecisionMemory> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('uuid')) {
      context.handle(
        _uuidMeta,
        uuid.isAcceptableOrUnknown(data['uuid']!, _uuidMeta),
      );
    }
    if (data.containsKey('day_key')) {
      context.handle(
        _dayKeyMeta,
        dayKey.isAcceptableOrUnknown(data['day_key']!, _dayKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_dayKeyMeta);
    }
    if (data.containsKey('recommendation_key')) {
      context.handle(
        _recommendationKeyMeta,
        recommendationKey.isAcceptableOrUnknown(
          data['recommendation_key']!,
          _recommendationKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_recommendationKeyMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
        _titleMeta,
        title.isAcceptableOrUnknown(data['title']!, _titleMeta),
      );
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('reason')) {
      context.handle(
        _reasonMeta,
        reason.isAcceptableOrUnknown(data['reason']!, _reasonMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonMeta);
    }
    if (data.containsKey('evidence_json')) {
      context.handle(
        _evidenceJsonMeta,
        evidenceJson.isAcceptableOrUnknown(
          data['evidence_json']!,
          _evidenceJsonMeta,
        ),
      );
    }
    if (data.containsKey('confidence')) {
      context.handle(
        _confidenceMeta,
        confidence.isAcceptableOrUnknown(data['confidence']!, _confidenceMeta),
      );
    }
    if (data.containsKey('response')) {
      context.handle(
        _responseMeta,
        response.isAcceptableOrUnknown(data['response']!, _responseMeta),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    }
    if (data.containsKey('helpfulness')) {
      context.handle(
        _helpfulnessMeta,
        helpfulness.isAcceptableOrUnknown(
          data['helpfulness']!,
          _helpfulnessMeta,
        ),
      );
    }
    if (data.containsKey('surfaced_at')) {
      context.handle(
        _surfacedAtMeta,
        surfacedAt.isAcceptableOrUnknown(data['surfaced_at']!, _surfacedAtMeta),
      );
    }
    if (data.containsKey('responded_at')) {
      context.handle(
        _respondedAtMeta,
        respondedAt.isAcceptableOrUnknown(
          data['responded_at']!,
          _respondedAtMeta,
        ),
      );
    }
    if (data.containsKey('evaluated_at')) {
      context.handle(
        _evaluatedAtMeta,
        evaluatedAt.isAcceptableOrUnknown(
          data['evaluated_at']!,
          _evaluatedAtMeta,
        ),
      );
    }
    if (data.containsKey('deleted_at')) {
      context.handle(
        _deletedAtMeta,
        deletedAt.isAcceptableOrUnknown(data['deleted_at']!, _deletedAtMeta),
      );
    }
    if (data.containsKey('revision')) {
      context.handle(
        _revisionMeta,
        revision.isAcceptableOrUnknown(data['revision']!, _revisionMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  List<Set<GeneratedColumn>> get uniqueKeys => [
    {dayKey, recommendationKey},
  ];
  @override
  DecisionMemory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DecisionMemory(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      uuid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}uuid'],
      )!,
      dayKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}day_key'],
      )!,
      recommendationKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}recommendation_key'],
      )!,
      title: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}title'],
      )!,
      reason: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason'],
      )!,
      evidenceJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}evidence_json'],
      )!,
      confidence: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}confidence'],
      )!,
      response: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}response'],
      )!,
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      ),
      helpfulness: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}helpfulness'],
      ),
      surfacedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}surfaced_at'],
      )!,
      respondedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}responded_at'],
      ),
      evaluatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}evaluated_at'],
      ),
      deletedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}deleted_at'],
      ),
      revision: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}revision'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $DecisionMemoriesTable createAlias(String alias) {
    return $DecisionMemoriesTable(attachedDatabase, alias);
  }
}

class DecisionMemory extends DataClass implements Insertable<DecisionMemory> {
  final int id;
  final String uuid;
  final String dayKey;
  final String recommendationKey;
  final String title;
  final String reason;
  final String evidenceJson;
  final String confidence;
  final String response;
  final String? outcome;
  final int? helpfulness;
  final DateTime surfacedAt;
  final DateTime? respondedAt;
  final DateTime? evaluatedAt;
  final DateTime? deletedAt;
  final int revision;
  final String syncStatus;
  const DecisionMemory({
    required this.id,
    required this.uuid,
    required this.dayKey,
    required this.recommendationKey,
    required this.title,
    required this.reason,
    required this.evidenceJson,
    required this.confidence,
    required this.response,
    this.outcome,
    this.helpfulness,
    required this.surfacedAt,
    this.respondedAt,
    this.evaluatedAt,
    this.deletedAt,
    required this.revision,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['uuid'] = Variable<String>(uuid);
    map['day_key'] = Variable<String>(dayKey);
    map['recommendation_key'] = Variable<String>(recommendationKey);
    map['title'] = Variable<String>(title);
    map['reason'] = Variable<String>(reason);
    map['evidence_json'] = Variable<String>(evidenceJson);
    map['confidence'] = Variable<String>(confidence);
    map['response'] = Variable<String>(response);
    if (!nullToAbsent || outcome != null) {
      map['outcome'] = Variable<String>(outcome);
    }
    if (!nullToAbsent || helpfulness != null) {
      map['helpfulness'] = Variable<int>(helpfulness);
    }
    map['surfaced_at'] = Variable<DateTime>(surfacedAt);
    if (!nullToAbsent || respondedAt != null) {
      map['responded_at'] = Variable<DateTime>(respondedAt);
    }
    if (!nullToAbsent || evaluatedAt != null) {
      map['evaluated_at'] = Variable<DateTime>(evaluatedAt);
    }
    if (!nullToAbsent || deletedAt != null) {
      map['deleted_at'] = Variable<DateTime>(deletedAt);
    }
    map['revision'] = Variable<int>(revision);
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  DecisionMemoriesCompanion toCompanion(bool nullToAbsent) {
    return DecisionMemoriesCompanion(
      id: Value(id),
      uuid: Value(uuid),
      dayKey: Value(dayKey),
      recommendationKey: Value(recommendationKey),
      title: Value(title),
      reason: Value(reason),
      evidenceJson: Value(evidenceJson),
      confidence: Value(confidence),
      response: Value(response),
      outcome: outcome == null && nullToAbsent
          ? const Value.absent()
          : Value(outcome),
      helpfulness: helpfulness == null && nullToAbsent
          ? const Value.absent()
          : Value(helpfulness),
      surfacedAt: Value(surfacedAt),
      respondedAt: respondedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(respondedAt),
      evaluatedAt: evaluatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(evaluatedAt),
      deletedAt: deletedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(deletedAt),
      revision: Value(revision),
      syncStatus: Value(syncStatus),
    );
  }

  factory DecisionMemory.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DecisionMemory(
      id: serializer.fromJson<int>(json['id']),
      uuid: serializer.fromJson<String>(json['uuid']),
      dayKey: serializer.fromJson<String>(json['dayKey']),
      recommendationKey: serializer.fromJson<String>(json['recommendationKey']),
      title: serializer.fromJson<String>(json['title']),
      reason: serializer.fromJson<String>(json['reason']),
      evidenceJson: serializer.fromJson<String>(json['evidenceJson']),
      confidence: serializer.fromJson<String>(json['confidence']),
      response: serializer.fromJson<String>(json['response']),
      outcome: serializer.fromJson<String?>(json['outcome']),
      helpfulness: serializer.fromJson<int?>(json['helpfulness']),
      surfacedAt: serializer.fromJson<DateTime>(json['surfacedAt']),
      respondedAt: serializer.fromJson<DateTime?>(json['respondedAt']),
      evaluatedAt: serializer.fromJson<DateTime?>(json['evaluatedAt']),
      deletedAt: serializer.fromJson<DateTime?>(json['deletedAt']),
      revision: serializer.fromJson<int>(json['revision']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'uuid': serializer.toJson<String>(uuid),
      'dayKey': serializer.toJson<String>(dayKey),
      'recommendationKey': serializer.toJson<String>(recommendationKey),
      'title': serializer.toJson<String>(title),
      'reason': serializer.toJson<String>(reason),
      'evidenceJson': serializer.toJson<String>(evidenceJson),
      'confidence': serializer.toJson<String>(confidence),
      'response': serializer.toJson<String>(response),
      'outcome': serializer.toJson<String?>(outcome),
      'helpfulness': serializer.toJson<int?>(helpfulness),
      'surfacedAt': serializer.toJson<DateTime>(surfacedAt),
      'respondedAt': serializer.toJson<DateTime?>(respondedAt),
      'evaluatedAt': serializer.toJson<DateTime?>(evaluatedAt),
      'deletedAt': serializer.toJson<DateTime?>(deletedAt),
      'revision': serializer.toJson<int>(revision),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  DecisionMemory copyWith({
    int? id,
    String? uuid,
    String? dayKey,
    String? recommendationKey,
    String? title,
    String? reason,
    String? evidenceJson,
    String? confidence,
    String? response,
    Value<String?> outcome = const Value.absent(),
    Value<int?> helpfulness = const Value.absent(),
    DateTime? surfacedAt,
    Value<DateTime?> respondedAt = const Value.absent(),
    Value<DateTime?> evaluatedAt = const Value.absent(),
    Value<DateTime?> deletedAt = const Value.absent(),
    int? revision,
    String? syncStatus,
  }) => DecisionMemory(
    id: id ?? this.id,
    uuid: uuid ?? this.uuid,
    dayKey: dayKey ?? this.dayKey,
    recommendationKey: recommendationKey ?? this.recommendationKey,
    title: title ?? this.title,
    reason: reason ?? this.reason,
    evidenceJson: evidenceJson ?? this.evidenceJson,
    confidence: confidence ?? this.confidence,
    response: response ?? this.response,
    outcome: outcome.present ? outcome.value : this.outcome,
    helpfulness: helpfulness.present ? helpfulness.value : this.helpfulness,
    surfacedAt: surfacedAt ?? this.surfacedAt,
    respondedAt: respondedAt.present ? respondedAt.value : this.respondedAt,
    evaluatedAt: evaluatedAt.present ? evaluatedAt.value : this.evaluatedAt,
    deletedAt: deletedAt.present ? deletedAt.value : this.deletedAt,
    revision: revision ?? this.revision,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  DecisionMemory copyWithCompanion(DecisionMemoriesCompanion data) {
    return DecisionMemory(
      id: data.id.present ? data.id.value : this.id,
      uuid: data.uuid.present ? data.uuid.value : this.uuid,
      dayKey: data.dayKey.present ? data.dayKey.value : this.dayKey,
      recommendationKey: data.recommendationKey.present
          ? data.recommendationKey.value
          : this.recommendationKey,
      title: data.title.present ? data.title.value : this.title,
      reason: data.reason.present ? data.reason.value : this.reason,
      evidenceJson: data.evidenceJson.present
          ? data.evidenceJson.value
          : this.evidenceJson,
      confidence: data.confidence.present
          ? data.confidence.value
          : this.confidence,
      response: data.response.present ? data.response.value : this.response,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
      helpfulness: data.helpfulness.present
          ? data.helpfulness.value
          : this.helpfulness,
      surfacedAt: data.surfacedAt.present
          ? data.surfacedAt.value
          : this.surfacedAt,
      respondedAt: data.respondedAt.present
          ? data.respondedAt.value
          : this.respondedAt,
      evaluatedAt: data.evaluatedAt.present
          ? data.evaluatedAt.value
          : this.evaluatedAt,
      deletedAt: data.deletedAt.present ? data.deletedAt.value : this.deletedAt,
      revision: data.revision.present ? data.revision.value : this.revision,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DecisionMemory(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('dayKey: $dayKey, ')
          ..write('recommendationKey: $recommendationKey, ')
          ..write('title: $title, ')
          ..write('reason: $reason, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('confidence: $confidence, ')
          ..write('response: $response, ')
          ..write('outcome: $outcome, ')
          ..write('helpfulness: $helpfulness, ')
          ..write('surfacedAt: $surfacedAt, ')
          ..write('respondedAt: $respondedAt, ')
          ..write('evaluatedAt: $evaluatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    uuid,
    dayKey,
    recommendationKey,
    title,
    reason,
    evidenceJson,
    confidence,
    response,
    outcome,
    helpfulness,
    surfacedAt,
    respondedAt,
    evaluatedAt,
    deletedAt,
    revision,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DecisionMemory &&
          other.id == this.id &&
          other.uuid == this.uuid &&
          other.dayKey == this.dayKey &&
          other.recommendationKey == this.recommendationKey &&
          other.title == this.title &&
          other.reason == this.reason &&
          other.evidenceJson == this.evidenceJson &&
          other.confidence == this.confidence &&
          other.response == this.response &&
          other.outcome == this.outcome &&
          other.helpfulness == this.helpfulness &&
          other.surfacedAt == this.surfacedAt &&
          other.respondedAt == this.respondedAt &&
          other.evaluatedAt == this.evaluatedAt &&
          other.deletedAt == this.deletedAt &&
          other.revision == this.revision &&
          other.syncStatus == this.syncStatus);
}

class DecisionMemoriesCompanion extends UpdateCompanion<DecisionMemory> {
  final Value<int> id;
  final Value<String> uuid;
  final Value<String> dayKey;
  final Value<String> recommendationKey;
  final Value<String> title;
  final Value<String> reason;
  final Value<String> evidenceJson;
  final Value<String> confidence;
  final Value<String> response;
  final Value<String?> outcome;
  final Value<int?> helpfulness;
  final Value<DateTime> surfacedAt;
  final Value<DateTime?> respondedAt;
  final Value<DateTime?> evaluatedAt;
  final Value<DateTime?> deletedAt;
  final Value<int> revision;
  final Value<String> syncStatus;
  const DecisionMemoriesCompanion({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    this.dayKey = const Value.absent(),
    this.recommendationKey = const Value.absent(),
    this.title = const Value.absent(),
    this.reason = const Value.absent(),
    this.evidenceJson = const Value.absent(),
    this.confidence = const Value.absent(),
    this.response = const Value.absent(),
    this.outcome = const Value.absent(),
    this.helpfulness = const Value.absent(),
    this.surfacedAt = const Value.absent(),
    this.respondedAt = const Value.absent(),
    this.evaluatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  });
  DecisionMemoriesCompanion.insert({
    this.id = const Value.absent(),
    this.uuid = const Value.absent(),
    required String dayKey,
    required String recommendationKey,
    required String title,
    required String reason,
    this.evidenceJson = const Value.absent(),
    this.confidence = const Value.absent(),
    this.response = const Value.absent(),
    this.outcome = const Value.absent(),
    this.helpfulness = const Value.absent(),
    this.surfacedAt = const Value.absent(),
    this.respondedAt = const Value.absent(),
    this.evaluatedAt = const Value.absent(),
    this.deletedAt = const Value.absent(),
    this.revision = const Value.absent(),
    this.syncStatus = const Value.absent(),
  }) : dayKey = Value(dayKey),
       recommendationKey = Value(recommendationKey),
       title = Value(title),
       reason = Value(reason);
  static Insertable<DecisionMemory> custom({
    Expression<int>? id,
    Expression<String>? uuid,
    Expression<String>? dayKey,
    Expression<String>? recommendationKey,
    Expression<String>? title,
    Expression<String>? reason,
    Expression<String>? evidenceJson,
    Expression<String>? confidence,
    Expression<String>? response,
    Expression<String>? outcome,
    Expression<int>? helpfulness,
    Expression<DateTime>? surfacedAt,
    Expression<DateTime>? respondedAt,
    Expression<DateTime>? evaluatedAt,
    Expression<DateTime>? deletedAt,
    Expression<int>? revision,
    Expression<String>? syncStatus,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (uuid != null) 'uuid': uuid,
      if (dayKey != null) 'day_key': dayKey,
      if (recommendationKey != null) 'recommendation_key': recommendationKey,
      if (title != null) 'title': title,
      if (reason != null) 'reason': reason,
      if (evidenceJson != null) 'evidence_json': evidenceJson,
      if (confidence != null) 'confidence': confidence,
      if (response != null) 'response': response,
      if (outcome != null) 'outcome': outcome,
      if (helpfulness != null) 'helpfulness': helpfulness,
      if (surfacedAt != null) 'surfaced_at': surfacedAt,
      if (respondedAt != null) 'responded_at': respondedAt,
      if (evaluatedAt != null) 'evaluated_at': evaluatedAt,
      if (deletedAt != null) 'deleted_at': deletedAt,
      if (revision != null) 'revision': revision,
      if (syncStatus != null) 'sync_status': syncStatus,
    });
  }

  DecisionMemoriesCompanion copyWith({
    Value<int>? id,
    Value<String>? uuid,
    Value<String>? dayKey,
    Value<String>? recommendationKey,
    Value<String>? title,
    Value<String>? reason,
    Value<String>? evidenceJson,
    Value<String>? confidence,
    Value<String>? response,
    Value<String?>? outcome,
    Value<int?>? helpfulness,
    Value<DateTime>? surfacedAt,
    Value<DateTime?>? respondedAt,
    Value<DateTime?>? evaluatedAt,
    Value<DateTime?>? deletedAt,
    Value<int>? revision,
    Value<String>? syncStatus,
  }) {
    return DecisionMemoriesCompanion(
      id: id ?? this.id,
      uuid: uuid ?? this.uuid,
      dayKey: dayKey ?? this.dayKey,
      recommendationKey: recommendationKey ?? this.recommendationKey,
      title: title ?? this.title,
      reason: reason ?? this.reason,
      evidenceJson: evidenceJson ?? this.evidenceJson,
      confidence: confidence ?? this.confidence,
      response: response ?? this.response,
      outcome: outcome ?? this.outcome,
      helpfulness: helpfulness ?? this.helpfulness,
      surfacedAt: surfacedAt ?? this.surfacedAt,
      respondedAt: respondedAt ?? this.respondedAt,
      evaluatedAt: evaluatedAt ?? this.evaluatedAt,
      deletedAt: deletedAt ?? this.deletedAt,
      revision: revision ?? this.revision,
      syncStatus: syncStatus ?? this.syncStatus,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (uuid.present) {
      map['uuid'] = Variable<String>(uuid.value);
    }
    if (dayKey.present) {
      map['day_key'] = Variable<String>(dayKey.value);
    }
    if (recommendationKey.present) {
      map['recommendation_key'] = Variable<String>(recommendationKey.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (reason.present) {
      map['reason'] = Variable<String>(reason.value);
    }
    if (evidenceJson.present) {
      map['evidence_json'] = Variable<String>(evidenceJson.value);
    }
    if (confidence.present) {
      map['confidence'] = Variable<String>(confidence.value);
    }
    if (response.present) {
      map['response'] = Variable<String>(response.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (helpfulness.present) {
      map['helpfulness'] = Variable<int>(helpfulness.value);
    }
    if (surfacedAt.present) {
      map['surfaced_at'] = Variable<DateTime>(surfacedAt.value);
    }
    if (respondedAt.present) {
      map['responded_at'] = Variable<DateTime>(respondedAt.value);
    }
    if (evaluatedAt.present) {
      map['evaluated_at'] = Variable<DateTime>(evaluatedAt.value);
    }
    if (deletedAt.present) {
      map['deleted_at'] = Variable<DateTime>(deletedAt.value);
    }
    if (revision.present) {
      map['revision'] = Variable<int>(revision.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DecisionMemoriesCompanion(')
          ..write('id: $id, ')
          ..write('uuid: $uuid, ')
          ..write('dayKey: $dayKey, ')
          ..write('recommendationKey: $recommendationKey, ')
          ..write('title: $title, ')
          ..write('reason: $reason, ')
          ..write('evidenceJson: $evidenceJson, ')
          ..write('confidence: $confidence, ')
          ..write('response: $response, ')
          ..write('outcome: $outcome, ')
          ..write('helpfulness: $helpfulness, ')
          ..write('surfacedAt: $surfacedAt, ')
          ..write('respondedAt: $respondedAt, ')
          ..write('evaluatedAt: $evaluatedAt, ')
          ..write('deletedAt: $deletedAt, ')
          ..write('revision: $revision, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DailyLogsTable dailyLogs = $DailyLogsTable(this);
  late final $UserProfileTable userProfile = $UserProfileTable(this);
  late final $WeightEntriesTable weightEntries = $WeightEntriesTable(this);
  late final $FoodsTable foods = $FoodsTable(this);
  late final $MealsTable meals = $MealsTable(this);
  late final $MealItemsTable mealItems = $MealItemsTable(this);
  late final $FavoritesTable favorites = $FavoritesTable(this);
  late final $RecentFoodsTable recentFoods = $RecentFoodsTable(this);
  late final $GoalsTable goals = $GoalsTable(this);
  late final $WaterEntriesTable waterEntries = $WaterEntriesTable(this);
  late final $PreferencesTable preferences = $PreferencesTable(this);
  late final $LifeContextEntriesTable lifeContextEntries =
      $LifeContextEntriesTable(this);
  late final $DecisionMemoriesTable decisionMemories = $DecisionMemoriesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    dailyLogs,
    userProfile,
    weightEntries,
    foods,
    meals,
    mealItems,
    favorites,
    recentFoods,
    goals,
    waterEntries,
    preferences,
    lifeContextEntries,
    decisionMemories,
  ];
  @override
  StreamQueryUpdateRules get streamUpdateRules => const StreamQueryUpdateRules([
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'meals',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('meal_items', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'foods',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('favorites', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'foods',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('recent_foods', kind: UpdateKind.delete)],
    ),
    WritePropagation(
      on: TableUpdateQuery.onTableName(
        'user_profile',
        limitUpdateKind: UpdateKind.delete,
      ),
      result: [TableUpdate('goals', kind: UpdateKind.delete)],
    ),
  ]);
}

typedef $$DailyLogsTableCreateCompanionBuilder =
    DailyLogsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required DateTime date,
      required String dayKey,
      Value<double?> weight,
      Value<int?> calories,
      Value<int?> protein,
      Value<int?> carbs,
      Value<int?> fats,
      Value<int?> water,
      Value<String?> notes,
      Value<double?> sleepHours,
      Value<int?> steps,
      Value<String?> exerciseNotes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$DailyLogsTableUpdateCompanionBuilder =
    DailyLogsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<DateTime> date,
      Value<String> dayKey,
      Value<double?> weight,
      Value<int?> calories,
      Value<int?> protein,
      Value<int?> carbs,
      Value<int?> fats,
      Value<int?> water,
      Value<String?> notes,
      Value<double?> sleepHours,
      Value<int?> steps,
      Value<String?> exerciseNotes,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

class $$DailyLogsTableFilterComposer
    extends Composer<_$AppDatabase, $DailyLogsTable> {
  $$DailyLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get fats => $composableBuilder(
    column: $table.fats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get water => $composableBuilder(
    column: $table.water,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sleepHours => $composableBuilder(
    column: $table.sleepHours,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get exerciseNotes => $composableBuilder(
    column: $table.exerciseNotes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DailyLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $DailyLogsTable> {
  $$DailyLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get fats => $composableBuilder(
    column: $table.fats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get water => $composableBuilder(
    column: $table.water,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get notes => $composableBuilder(
    column: $table.notes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sleepHours => $composableBuilder(
    column: $table.sleepHours,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get steps => $composableBuilder(
    column: $table.steps,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get exerciseNotes => $composableBuilder(
    column: $table.exerciseNotes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DailyLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DailyLogsTable> {
  $$DailyLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<int> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<int> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<int> get carbs =>
      $composableBuilder(column: $table.carbs, builder: (column) => column);

  GeneratedColumn<int> get fats =>
      $composableBuilder(column: $table.fats, builder: (column) => column);

  GeneratedColumn<int> get water =>
      $composableBuilder(column: $table.water, builder: (column) => column);

  GeneratedColumn<String> get notes =>
      $composableBuilder(column: $table.notes, builder: (column) => column);

  GeneratedColumn<double> get sleepHours => $composableBuilder(
    column: $table.sleepHours,
    builder: (column) => column,
  );

  GeneratedColumn<int> get steps =>
      $composableBuilder(column: $table.steps, builder: (column) => column);

  GeneratedColumn<String> get exerciseNotes => $composableBuilder(
    column: $table.exerciseNotes,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$DailyLogsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DailyLogsTable,
          DailyLog,
          $$DailyLogsTableFilterComposer,
          $$DailyLogsTableOrderingComposer,
          $$DailyLogsTableAnnotationComposer,
          $$DailyLogsTableCreateCompanionBuilder,
          $$DailyLogsTableUpdateCompanionBuilder,
          (DailyLog, BaseReferences<_$AppDatabase, $DailyLogsTable, DailyLog>),
          DailyLog,
          PrefetchHooks Function()
        > {
  $$DailyLogsTableTableManager(_$AppDatabase db, $DailyLogsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DailyLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DailyLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DailyLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<double?> weight = const Value.absent(),
                Value<int?> calories = const Value.absent(),
                Value<int?> protein = const Value.absent(),
                Value<int?> carbs = const Value.absent(),
                Value<int?> fats = const Value.absent(),
                Value<int?> water = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> sleepHours = const Value.absent(),
                Value<int?> steps = const Value.absent(),
                Value<String?> exerciseNotes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DailyLogsCompanion(
                id: id,
                uuid: uuid,
                date: date,
                dayKey: dayKey,
                weight: weight,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                water: water,
                notes: notes,
                sleepHours: sleepHours,
                steps: steps,
                exerciseNotes: exerciseNotes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required DateTime date,
                required String dayKey,
                Value<double?> weight = const Value.absent(),
                Value<int?> calories = const Value.absent(),
                Value<int?> protein = const Value.absent(),
                Value<int?> carbs = const Value.absent(),
                Value<int?> fats = const Value.absent(),
                Value<int?> water = const Value.absent(),
                Value<String?> notes = const Value.absent(),
                Value<double?> sleepHours = const Value.absent(),
                Value<int?> steps = const Value.absent(),
                Value<String?> exerciseNotes = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => DailyLogsCompanion.insert(
                id: id,
                uuid: uuid,
                date: date,
                dayKey: dayKey,
                weight: weight,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                water: water,
                notes: notes,
                sleepHours: sleepHours,
                steps: steps,
                exerciseNotes: exerciseNotes,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DailyLogsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DailyLogsTable,
      DailyLog,
      $$DailyLogsTableFilterComposer,
      $$DailyLogsTableOrderingComposer,
      $$DailyLogsTableAnnotationComposer,
      $$DailyLogsTableCreateCompanionBuilder,
      $$DailyLogsTableUpdateCompanionBuilder,
      (DailyLog, BaseReferences<_$AppDatabase, $DailyLogsTable, DailyLog>),
      DailyLog,
      PrefetchHooks Function()
    >;
typedef $$UserProfileTableCreateCompanionBuilder =
    UserProfileCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required String gender,
      required int age,
      required double height,
      required double currentWeight,
      required double targetWeight,
      required String activityLevel,
      required bool exercises,
      Value<String?> medicalConditions,
      Value<double?> waist,
      Value<double?> neck,
      Value<double?> chest,
      Value<double?> arm,
      Value<double?> thigh,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });
typedef $$UserProfileTableUpdateCompanionBuilder =
    UserProfileCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> gender,
      Value<int> age,
      Value<double> height,
      Value<double> currentWeight,
      Value<double> targetWeight,
      Value<String> activityLevel,
      Value<bool> exercises,
      Value<String?> medicalConditions,
      Value<double?> waist,
      Value<double?> neck,
      Value<double?> chest,
      Value<double?> arm,
      Value<double?> thigh,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });

final class $$UserProfileTableReferences
    extends BaseReferences<_$AppDatabase, $UserProfileTable, UserProfileData> {
  $$UserProfileTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$GoalsTable, List<Goal>> _goalsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.goals,
    aliasName: 'user_profile__uuid__goals__profile_uuid',
  );

  $$GoalsTableProcessedTableManager get goalsRefs {
    final manager = $$GoalsTableTableManager($_db, $_db.goals).filter(
      (f) => f.profileUuid.uuid.sqlEquals($_itemColumn<String>('uuid')!),
    );

    final cache = $_typedResult.readTableOrNull(_goalsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$UserProfileTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get currentWeight => $composableBuilder(
    column: $table.currentWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetWeight => $composableBuilder(
    column: $table.targetWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get exercises => $composableBuilder(
    column: $table.exercises,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get medicalConditions => $composableBuilder(
    column: $table.medicalConditions,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get waist => $composableBuilder(
    column: $table.waist,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get neck => $composableBuilder(
    column: $table.neck,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get chest => $composableBuilder(
    column: $table.chest,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get arm => $composableBuilder(
    column: $table.arm,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get thigh => $composableBuilder(
    column: $table.thigh,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> goalsRefs(
    Expression<bool> Function($$GoalsTableFilterComposer f) f,
  ) {
    final $$GoalsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.profileUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableFilterComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserProfileTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get age => $composableBuilder(
    column: $table.age,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get height => $composableBuilder(
    column: $table.height,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get currentWeight => $composableBuilder(
    column: $table.currentWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetWeight => $composableBuilder(
    column: $table.targetWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get exercises => $composableBuilder(
    column: $table.exercises,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get medicalConditions => $composableBuilder(
    column: $table.medicalConditions,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get waist => $composableBuilder(
    column: $table.waist,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get neck => $composableBuilder(
    column: $table.neck,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get chest => $composableBuilder(
    column: $table.chest,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get arm => $composableBuilder(
    column: $table.arm,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get thigh => $composableBuilder(
    column: $table.thigh,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$UserProfileTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfileTable> {
  $$UserProfileTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<int> get age =>
      $composableBuilder(column: $table.age, builder: (column) => column);

  GeneratedColumn<double> get height =>
      $composableBuilder(column: $table.height, builder: (column) => column);

  GeneratedColumn<double> get currentWeight => $composableBuilder(
    column: $table.currentWeight,
    builder: (column) => column,
  );

  GeneratedColumn<double> get targetWeight => $composableBuilder(
    column: $table.targetWeight,
    builder: (column) => column,
  );

  GeneratedColumn<String> get activityLevel => $composableBuilder(
    column: $table.activityLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get exercises =>
      $composableBuilder(column: $table.exercises, builder: (column) => column);

  GeneratedColumn<String> get medicalConditions => $composableBuilder(
    column: $table.medicalConditions,
    builder: (column) => column,
  );

  GeneratedColumn<double> get waist =>
      $composableBuilder(column: $table.waist, builder: (column) => column);

  GeneratedColumn<double> get neck =>
      $composableBuilder(column: $table.neck, builder: (column) => column);

  GeneratedColumn<double> get chest =>
      $composableBuilder(column: $table.chest, builder: (column) => column);

  GeneratedColumn<double> get arm =>
      $composableBuilder(column: $table.arm, builder: (column) => column);

  GeneratedColumn<double> get thigh =>
      $composableBuilder(column: $table.thigh, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  Expression<T> goalsRefs<T extends Object>(
    Expression<T> Function($$GoalsTableAnnotationComposer a) f,
  ) {
    final $$GoalsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.uuid,
      referencedTable: $db.goals,
      getReferencedColumn: (t) => t.profileUuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$GoalsTableAnnotationComposer(
            $db: $db,
            $table: $db.goals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$UserProfileTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $UserProfileTable,
          UserProfileData,
          $$UserProfileTableFilterComposer,
          $$UserProfileTableOrderingComposer,
          $$UserProfileTableAnnotationComposer,
          $$UserProfileTableCreateCompanionBuilder,
          $$UserProfileTableUpdateCompanionBuilder,
          (UserProfileData, $$UserProfileTableReferences),
          UserProfileData,
          PrefetchHooks Function({bool goalsRefs})
        > {
  $$UserProfileTableTableManager(_$AppDatabase db, $UserProfileTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfileTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfileTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfileTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> gender = const Value.absent(),
                Value<int> age = const Value.absent(),
                Value<double> height = const Value.absent(),
                Value<double> currentWeight = const Value.absent(),
                Value<double> targetWeight = const Value.absent(),
                Value<String> activityLevel = const Value.absent(),
                Value<bool> exercises = const Value.absent(),
                Value<String?> medicalConditions = const Value.absent(),
                Value<double?> waist = const Value.absent(),
                Value<double?> neck = const Value.absent(),
                Value<double?> chest = const Value.absent(),
                Value<double?> arm = const Value.absent(),
                Value<double?> thigh = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => UserProfileCompanion(
                id: id,
                uuid: uuid,
                gender: gender,
                age: age,
                height: height,
                currentWeight: currentWeight,
                targetWeight: targetWeight,
                activityLevel: activityLevel,
                exercises: exercises,
                medicalConditions: medicalConditions,
                waist: waist,
                neck: neck,
                chest: chest,
                arm: arm,
                thigh: thigh,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required String gender,
                required int age,
                required double height,
                required double currentWeight,
                required double targetWeight,
                required String activityLevel,
                required bool exercises,
                Value<String?> medicalConditions = const Value.absent(),
                Value<double?> waist = const Value.absent(),
                Value<double?> neck = const Value.absent(),
                Value<double?> chest = const Value.absent(),
                Value<double?> arm = const Value.absent(),
                Value<double?> thigh = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => UserProfileCompanion.insert(
                id: id,
                uuid: uuid,
                gender: gender,
                age: age,
                height: height,
                currentWeight: currentWeight,
                targetWeight: targetWeight,
                activityLevel: activityLevel,
                exercises: exercises,
                medicalConditions: medicalConditions,
                waist: waist,
                neck: neck,
                chest: chest,
                arm: arm,
                thigh: thigh,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$UserProfileTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({goalsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (goalsRefs) db.goals],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (goalsRefs)
                    await $_getPrefetchedData<
                      UserProfileData,
                      $UserProfileTable,
                      Goal
                    >(
                      currentTable: table,
                      referencedTable: $$UserProfileTableReferences
                          ._goalsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$UserProfileTableReferences(db, table, p0).goalsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where(
                            (e) => e.profileUuid == item.uuid,
                          ),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$UserProfileTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $UserProfileTable,
      UserProfileData,
      $$UserProfileTableFilterComposer,
      $$UserProfileTableOrderingComposer,
      $$UserProfileTableAnnotationComposer,
      $$UserProfileTableCreateCompanionBuilder,
      $$UserProfileTableUpdateCompanionBuilder,
      (UserProfileData, $$UserProfileTableReferences),
      UserProfileData,
      PrefetchHooks Function({bool goalsRefs})
    >;
typedef $$WeightEntriesTableCreateCompanionBuilder =
    WeightEntriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<DateTime> date,
      Value<String?> dayKey,
      required double weight,
      Value<String?> note,
      Value<String> measurementContext,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });
typedef $$WeightEntriesTableUpdateCompanionBuilder =
    WeightEntriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<DateTime> date,
      Value<String?> dayKey,
      Value<double> weight,
      Value<String?> note,
      Value<String> measurementContext,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });

class $$WeightEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WeightEntriesTable> {
  $$WeightEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get measurementContext => $composableBuilder(
    column: $table.measurementContext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WeightEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WeightEntriesTable> {
  $$WeightEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get weight => $composableBuilder(
    column: $table.weight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get note => $composableBuilder(
    column: $table.note,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get measurementContext => $composableBuilder(
    column: $table.measurementContext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WeightEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WeightEntriesTable> {
  $$WeightEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<double> get weight =>
      $composableBuilder(column: $table.weight, builder: (column) => column);

  GeneratedColumn<String> get note =>
      $composableBuilder(column: $table.note, builder: (column) => column);

  GeneratedColumn<String> get measurementContext => $composableBuilder(
    column: $table.measurementContext,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$WeightEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WeightEntriesTable,
          WeightEntry,
          $$WeightEntriesTableFilterComposer,
          $$WeightEntriesTableOrderingComposer,
          $$WeightEntriesTableAnnotationComposer,
          $$WeightEntriesTableCreateCompanionBuilder,
          $$WeightEntriesTableUpdateCompanionBuilder,
          (
            WeightEntry,
            BaseReferences<_$AppDatabase, $WeightEntriesTable, WeightEntry>,
          ),
          WeightEntry,
          PrefetchHooks Function()
        > {
  $$WeightEntriesTableTableManager(_$AppDatabase db, $WeightEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WeightEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WeightEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WeightEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> dayKey = const Value.absent(),
                Value<double> weight = const Value.absent(),
                Value<String?> note = const Value.absent(),
                Value<String> measurementContext = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => WeightEntriesCompanion(
                id: id,
                uuid: uuid,
                date: date,
                dayKey: dayKey,
                weight: weight,
                note: note,
                measurementContext: measurementContext,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String?> dayKey = const Value.absent(),
                required double weight,
                Value<String?> note = const Value.absent(),
                Value<String> measurementContext = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => WeightEntriesCompanion.insert(
                id: id,
                uuid: uuid,
                date: date,
                dayKey: dayKey,
                weight: weight,
                note: note,
                measurementContext: measurementContext,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WeightEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WeightEntriesTable,
      WeightEntry,
      $$WeightEntriesTableFilterComposer,
      $$WeightEntriesTableOrderingComposer,
      $$WeightEntriesTableAnnotationComposer,
      $$WeightEntriesTableCreateCompanionBuilder,
      $$WeightEntriesTableUpdateCompanionBuilder,
      (
        WeightEntry,
        BaseReferences<_$AppDatabase, $WeightEntriesTable, WeightEntry>,
      ),
      WeightEntry,
      PrefetchHooks Function()
    >;
typedef $$FoodsTableCreateCompanionBuilder =
    FoodsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required String name,
      Value<String?> arabicName,
      Value<String?> category,
      Value<String> keywords,
      Value<String?> barcode,
      Value<double> servingSize,
      Value<String> servingUnit,
      required double calories,
      required double protein,
      required double carbs,
      required double fats,
      Value<double> fiber,
      Value<double> sugar,
      Value<double> potassium,
      Value<double> sodium,
      Value<double> calcium,
      Value<double> iron,
      Value<double> magnesium,
      Value<double> vitaminC,
      Value<bool> verified,
      Value<bool> isCustom,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });
typedef $$FoodsTableUpdateCompanionBuilder =
    FoodsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> name,
      Value<String?> arabicName,
      Value<String?> category,
      Value<String> keywords,
      Value<String?> barcode,
      Value<double> servingSize,
      Value<String> servingUnit,
      Value<double> calories,
      Value<double> protein,
      Value<double> carbs,
      Value<double> fats,
      Value<double> fiber,
      Value<double> sugar,
      Value<double> potassium,
      Value<double> sodium,
      Value<double> calcium,
      Value<double> iron,
      Value<double> magnesium,
      Value<double> vitaminC,
      Value<bool> verified,
      Value<bool> isCustom,
      Value<String> source,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });

final class $$FoodsTableReferences
    extends BaseReferences<_$AppDatabase, $FoodsTable, Food> {
  $$FoodsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealItemsTable, List<MealItem>>
  _mealItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealItems,
    aliasName: 'foods__id__meal_items__food_id',
  );

  $$MealItemsTableProcessedTableManager get mealItemsRefs {
    final manager = $$MealItemsTableTableManager(
      $_db,
      $_db.mealItems,
    ).filter((f) => f.foodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$FavoritesTable, List<Favorite>>
  _favoritesRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.favorites,
    aliasName: 'foods__id__favorites__food_id',
  );

  $$FavoritesTableProcessedTableManager get favoritesRefs {
    final manager = $$FavoritesTableTableManager(
      $_db,
      $_db.favorites,
    ).filter((f) => f.foodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_favoritesRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }

  static MultiTypedResultKey<$RecentFoodsTable, List<RecentFood>>
  _recentFoodsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.recentFoods,
    aliasName: 'foods__id__recent_foods__food_id',
  );

  $$RecentFoodsTableProcessedTableManager get recentFoodsRefs {
    final manager = $$RecentFoodsTableTableManager(
      $_db,
      $_db.recentFoods,
    ).filter((f) => f.foodId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_recentFoodsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$FoodsTableFilterComposer extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get arabicName => $composableBuilder(
    column: $table.arabicName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fats => $composableBuilder(
    column: $table.fats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fiber => $composableBuilder(
    column: $table.fiber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sugar => $composableBuilder(
    column: $table.sugar,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get potassium => $composableBuilder(
    column: $table.potassium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sodium => $composableBuilder(
    column: $table.sodium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get calcium => $composableBuilder(
    column: $table.calcium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get iron => $composableBuilder(
    column: $table.iron,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get magnesium => $composableBuilder(
    column: $table.magnesium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get vitaminC => $composableBuilder(
    column: $table.vitaminC,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealItemsRefs(
    Expression<bool> Function($$MealItemsTableFilterComposer f) f,
  ) {
    final $$MealItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealItems,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealItemsTableFilterComposer(
            $db: $db,
            $table: $db.mealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> favoritesRefs(
    Expression<bool> Function($$FavoritesTableFilterComposer f) f,
  ) {
    final $$FavoritesTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableFilterComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<bool> recentFoodsRefs(
    Expression<bool> Function($$RecentFoodsTableFilterComposer f) f,
  ) {
    final $$RecentFoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recentFoods,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecentFoodsTableFilterComposer(
            $db: $db,
            $table: $db.recentFoods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodsTableOrderingComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get arabicName => $composableBuilder(
    column: $table.arabicName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get keywords => $composableBuilder(
    column: $table.keywords,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get barcode => $composableBuilder(
    column: $table.barcode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fats => $composableBuilder(
    column: $table.fats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fiber => $composableBuilder(
    column: $table.fiber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sugar => $composableBuilder(
    column: $table.sugar,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get potassium => $composableBuilder(
    column: $table.potassium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sodium => $composableBuilder(
    column: $table.sodium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get calcium => $composableBuilder(
    column: $table.calcium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get iron => $composableBuilder(
    column: $table.iron,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get magnesium => $composableBuilder(
    column: $table.magnesium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get vitaminC => $composableBuilder(
    column: $table.vitaminC,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get verified => $composableBuilder(
    column: $table.verified,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isCustom => $composableBuilder(
    column: $table.isCustom,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$FoodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $FoodsTable> {
  $$FoodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get arabicName => $composableBuilder(
    column: $table.arabicName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get keywords =>
      $composableBuilder(column: $table.keywords, builder: (column) => column);

  GeneratedColumn<String> get barcode =>
      $composableBuilder(column: $table.barcode, builder: (column) => column);

  GeneratedColumn<double> get servingSize => $composableBuilder(
    column: $table.servingSize,
    builder: (column) => column,
  );

  GeneratedColumn<String> get servingUnit => $composableBuilder(
    column: $table.servingUnit,
    builder: (column) => column,
  );

  GeneratedColumn<double> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<double> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<double> get carbs =>
      $composableBuilder(column: $table.carbs, builder: (column) => column);

  GeneratedColumn<double> get fats =>
      $composableBuilder(column: $table.fats, builder: (column) => column);

  GeneratedColumn<double> get fiber =>
      $composableBuilder(column: $table.fiber, builder: (column) => column);

  GeneratedColumn<double> get sugar =>
      $composableBuilder(column: $table.sugar, builder: (column) => column);

  GeneratedColumn<double> get potassium =>
      $composableBuilder(column: $table.potassium, builder: (column) => column);

  GeneratedColumn<double> get sodium =>
      $composableBuilder(column: $table.sodium, builder: (column) => column);

  GeneratedColumn<double> get calcium =>
      $composableBuilder(column: $table.calcium, builder: (column) => column);

  GeneratedColumn<double> get iron =>
      $composableBuilder(column: $table.iron, builder: (column) => column);

  GeneratedColumn<double> get magnesium =>
      $composableBuilder(column: $table.magnesium, builder: (column) => column);

  GeneratedColumn<double> get vitaminC =>
      $composableBuilder(column: $table.vitaminC, builder: (column) => column);

  GeneratedColumn<bool> get verified =>
      $composableBuilder(column: $table.verified, builder: (column) => column);

  GeneratedColumn<bool> get isCustom =>
      $composableBuilder(column: $table.isCustom, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  Expression<T> mealItemsRefs<T extends Object>(
    Expression<T> Function($$MealItemsTableAnnotationComposer a) f,
  ) {
    final $$MealItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealItems,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> favoritesRefs<T extends Object>(
    Expression<T> Function($$FavoritesTableAnnotationComposer a) f,
  ) {
    final $$FavoritesTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.favorites,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FavoritesTableAnnotationComposer(
            $db: $db,
            $table: $db.favorites,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }

  Expression<T> recentFoodsRefs<T extends Object>(
    Expression<T> Function($$RecentFoodsTableAnnotationComposer a) f,
  ) {
    final $$RecentFoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.recentFoods,
      getReferencedColumn: (t) => t.foodId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$RecentFoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.recentFoods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$FoodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FoodsTable,
          Food,
          $$FoodsTableFilterComposer,
          $$FoodsTableOrderingComposer,
          $$FoodsTableAnnotationComposer,
          $$FoodsTableCreateCompanionBuilder,
          $$FoodsTableUpdateCompanionBuilder,
          (Food, $$FoodsTableReferences),
          Food,
          PrefetchHooks Function({
            bool mealItemsRefs,
            bool favoritesRefs,
            bool recentFoodsRefs,
          })
        > {
  $$FoodsTableTableManager(_$AppDatabase db, $FoodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> arabicName = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> keywords = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<double> servingSize = const Value.absent(),
                Value<String> servingUnit = const Value.absent(),
                Value<double> calories = const Value.absent(),
                Value<double> protein = const Value.absent(),
                Value<double> carbs = const Value.absent(),
                Value<double> fats = const Value.absent(),
                Value<double> fiber = const Value.absent(),
                Value<double> sugar = const Value.absent(),
                Value<double> potassium = const Value.absent(),
                Value<double> sodium = const Value.absent(),
                Value<double> calcium = const Value.absent(),
                Value<double> iron = const Value.absent(),
                Value<double> magnesium = const Value.absent(),
                Value<double> vitaminC = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => FoodsCompanion(
                id: id,
                uuid: uuid,
                name: name,
                arabicName: arabicName,
                category: category,
                keywords: keywords,
                barcode: barcode,
                servingSize: servingSize,
                servingUnit: servingUnit,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                fiber: fiber,
                sugar: sugar,
                potassium: potassium,
                sodium: sodium,
                calcium: calcium,
                iron: iron,
                magnesium: magnesium,
                vitaminC: vitaminC,
                verified: verified,
                isCustom: isCustom,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required String name,
                Value<String?> arabicName = const Value.absent(),
                Value<String?> category = const Value.absent(),
                Value<String> keywords = const Value.absent(),
                Value<String?> barcode = const Value.absent(),
                Value<double> servingSize = const Value.absent(),
                Value<String> servingUnit = const Value.absent(),
                required double calories,
                required double protein,
                required double carbs,
                required double fats,
                Value<double> fiber = const Value.absent(),
                Value<double> sugar = const Value.absent(),
                Value<double> potassium = const Value.absent(),
                Value<double> sodium = const Value.absent(),
                Value<double> calcium = const Value.absent(),
                Value<double> iron = const Value.absent(),
                Value<double> magnesium = const Value.absent(),
                Value<double> vitaminC = const Value.absent(),
                Value<bool> verified = const Value.absent(),
                Value<bool> isCustom = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => FoodsCompanion.insert(
                id: id,
                uuid: uuid,
                name: name,
                arabicName: arabicName,
                category: category,
                keywords: keywords,
                barcode: barcode,
                servingSize: servingSize,
                servingUnit: servingUnit,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                fiber: fiber,
                sugar: sugar,
                potassium: potassium,
                sodium: sodium,
                calcium: calcium,
                iron: iron,
                magnesium: magnesium,
                vitaminC: vitaminC,
                verified: verified,
                isCustom: isCustom,
                source: source,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$FoodsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback:
              ({
                mealItemsRefs = false,
                favoritesRefs = false,
                recentFoodsRefs = false,
              }) {
                return PrefetchHooks(
                  db: db,
                  explicitlyWatchedTables: [
                    if (mealItemsRefs) db.mealItems,
                    if (favoritesRefs) db.favorites,
                    if (recentFoodsRefs) db.recentFoods,
                  ],
                  addJoins: null,
                  getPrefetchedDataCallback: (items) async {
                    return [
                      if (mealItemsRefs)
                        await $_getPrefetchedData<Food, $FoodsTable, MealItem>(
                          currentTable: table,
                          referencedTable: $$FoodsTableReferences
                              ._mealItemsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodsTableReferences(
                                db,
                                table,
                                p0,
                              ).mealItemsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.foodId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (favoritesRefs)
                        await $_getPrefetchedData<Food, $FoodsTable, Favorite>(
                          currentTable: table,
                          referencedTable: $$FoodsTableReferences
                              ._favoritesRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodsTableReferences(
                                db,
                                table,
                                p0,
                              ).favoritesRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.foodId == item.id,
                              ),
                          typedResults: items,
                        ),
                      if (recentFoodsRefs)
                        await $_getPrefetchedData<
                          Food,
                          $FoodsTable,
                          RecentFood
                        >(
                          currentTable: table,
                          referencedTable: $$FoodsTableReferences
                              ._recentFoodsRefsTable(db),
                          managerFromTypedResult: (p0) =>
                              $$FoodsTableReferences(
                                db,
                                table,
                                p0,
                              ).recentFoodsRefs,
                          referencedItemsForCurrentItem:
                              (item, referencedItems) => referencedItems.where(
                                (e) => e.foodId == item.id,
                              ),
                          typedResults: items,
                        ),
                    ];
                  },
                );
              },
        ),
      );
}

typedef $$FoodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FoodsTable,
      Food,
      $$FoodsTableFilterComposer,
      $$FoodsTableOrderingComposer,
      $$FoodsTableAnnotationComposer,
      $$FoodsTableCreateCompanionBuilder,
      $$FoodsTableUpdateCompanionBuilder,
      (Food, $$FoodsTableReferences),
      Food,
      PrefetchHooks Function({
        bool mealItemsRefs,
        bool favoritesRefs,
        bool recentFoodsRefs,
      })
    >;
typedef $$MealsTableCreateCompanionBuilder =
    MealsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required DateTime date,
      required String dayKey,
      Value<String> name,
      Value<String> type,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });
typedef $$MealsTableUpdateCompanionBuilder =
    MealsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<DateTime> date,
      Value<String> dayKey,
      Value<String> name,
      Value<String> type,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });

final class $$MealsTableReferences
    extends BaseReferences<_$AppDatabase, $MealsTable, Meal> {
  $$MealsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$MealItemsTable, List<MealItem>>
  _mealItemsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.mealItems,
    aliasName: 'meals__id__meal_items__meal_id',
  );

  $$MealItemsTableProcessedTableManager get mealItemsRefs {
    final manager = $$MealItemsTableTableManager(
      $_db,
      $_db.mealItems,
    ).filter((f) => f.mealId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_mealItemsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$MealsTableFilterComposer extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> mealItemsRefs(
    Expression<bool> Function($$MealItemsTableFilterComposer f) f,
  ) {
    final $$MealItemsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealItems,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealItemsTableFilterComposer(
            $db: $db,
            $table: $db.mealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get date => $composableBuilder(
    column: $table.date,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MealsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealsTable> {
  $$MealsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get date =>
      $composableBuilder(column: $table.date, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  Expression<T> mealItemsRefs<T extends Object>(
    Expression<T> Function($$MealItemsTableAnnotationComposer a) f,
  ) {
    final $$MealItemsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.mealItems,
      getReferencedColumn: (t) => t.mealId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealItemsTableAnnotationComposer(
            $db: $db,
            $table: $db.mealItems,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$MealsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealsTable,
          Meal,
          $$MealsTableFilterComposer,
          $$MealsTableOrderingComposer,
          $$MealsTableAnnotationComposer,
          $$MealsTableCreateCompanionBuilder,
          $$MealsTableUpdateCompanionBuilder,
          (Meal, $$MealsTableReferences),
          Meal,
          PrefetchHooks Function({bool mealItemsRefs})
        > {
  $$MealsTableTableManager(_$AppDatabase db, $MealsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<DateTime> date = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => MealsCompanion(
                id: id,
                uuid: uuid,
                date: date,
                dayKey: dayKey,
                name: name,
                type: type,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required DateTime date,
                required String dayKey,
                Value<String> name = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => MealsCompanion.insert(
                id: id,
                uuid: uuid,
                date: date,
                dayKey: dayKey,
                name: name,
                type: type,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$MealsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({mealItemsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (mealItemsRefs) db.mealItems],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (mealItemsRefs)
                    await $_getPrefetchedData<Meal, $MealsTable, MealItem>(
                      currentTable: table,
                      referencedTable: $$MealsTableReferences
                          ._mealItemsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$MealsTableReferences(db, table, p0).mealItemsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.mealId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$MealsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealsTable,
      Meal,
      $$MealsTableFilterComposer,
      $$MealsTableOrderingComposer,
      $$MealsTableAnnotationComposer,
      $$MealsTableCreateCompanionBuilder,
      $$MealsTableUpdateCompanionBuilder,
      (Meal, $$MealsTableReferences),
      Meal,
      PrefetchHooks Function({bool mealItemsRefs})
    >;
typedef $$MealItemsTableCreateCompanionBuilder =
    MealItemsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required int mealId,
      required int foodId,
      Value<double> quantity,
      Value<double> calories,
      Value<double> protein,
      Value<double> carbs,
      Value<double> fats,
      Value<double> fiber,
      Value<double> sodium,
      Value<double> potassium,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
    });
typedef $$MealItemsTableUpdateCompanionBuilder =
    MealItemsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<int> mealId,
      Value<int> foodId,
      Value<double> quantity,
      Value<double> calories,
      Value<double> protein,
      Value<double> carbs,
      Value<double> fats,
      Value<double> fiber,
      Value<double> sodium,
      Value<double> potassium,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
    });

final class $$MealItemsTableReferences
    extends BaseReferences<_$AppDatabase, $MealItemsTable, MealItem> {
  $$MealItemsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $MealsTable _mealIdTable(_$AppDatabase db) =>
      db.meals.createAlias('meal_items__meal_id__meals__id');

  $$MealsTableProcessedTableManager get mealId {
    final $_column = $_itemColumn<int>('meal_id')!;

    final manager = $$MealsTableTableManager(
      $_db,
      $_db.meals,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_mealIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static $FoodsTable _foodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('meal_items__food_id__foods__id');

  $$FoodsTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<int>('food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$MealItemsTableFilterComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fats => $composableBuilder(
    column: $table.fats,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get fiber => $composableBuilder(
    column: $table.fiber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get sodium => $composableBuilder(
    column: $table.sodium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get potassium => $composableBuilder(
    column: $table.potassium,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$MealsTableFilterComposer get mealId {
    final $$MealsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableFilterComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodsTableFilterComposer get foodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealItemsTableOrderingComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get quantity => $composableBuilder(
    column: $table.quantity,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get calories => $composableBuilder(
    column: $table.calories,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get protein => $composableBuilder(
    column: $table.protein,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get carbs => $composableBuilder(
    column: $table.carbs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fats => $composableBuilder(
    column: $table.fats,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get fiber => $composableBuilder(
    column: $table.fiber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get sodium => $composableBuilder(
    column: $table.sodium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get potassium => $composableBuilder(
    column: $table.potassium,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$MealsTableOrderingComposer get mealId {
    final $$MealsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableOrderingComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodsTableOrderingComposer get foodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealItemsTableAnnotationComposer
    extends Composer<_$AppDatabase, $MealItemsTable> {
  $$MealItemsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<double> get quantity =>
      $composableBuilder(column: $table.quantity, builder: (column) => column);

  GeneratedColumn<double> get calories =>
      $composableBuilder(column: $table.calories, builder: (column) => column);

  GeneratedColumn<double> get protein =>
      $composableBuilder(column: $table.protein, builder: (column) => column);

  GeneratedColumn<double> get carbs =>
      $composableBuilder(column: $table.carbs, builder: (column) => column);

  GeneratedColumn<double> get fats =>
      $composableBuilder(column: $table.fats, builder: (column) => column);

  GeneratedColumn<double> get fiber =>
      $composableBuilder(column: $table.fiber, builder: (column) => column);

  GeneratedColumn<double> get sodium =>
      $composableBuilder(column: $table.sodium, builder: (column) => column);

  GeneratedColumn<double> get potassium =>
      $composableBuilder(column: $table.potassium, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  $$MealsTableAnnotationComposer get mealId {
    final $$MealsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.mealId,
      referencedTable: $db.meals,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$MealsTableAnnotationComposer(
            $db: $db,
            $table: $db.meals,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  $$FoodsTableAnnotationComposer get foodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$MealItemsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MealItemsTable,
          MealItem,
          $$MealItemsTableFilterComposer,
          $$MealItemsTableOrderingComposer,
          $$MealItemsTableAnnotationComposer,
          $$MealItemsTableCreateCompanionBuilder,
          $$MealItemsTableUpdateCompanionBuilder,
          (MealItem, $$MealItemsTableReferences),
          MealItem,
          PrefetchHooks Function({bool mealId, bool foodId})
        > {
  $$MealItemsTableTableManager(_$AppDatabase db, $MealItemsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MealItemsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MealItemsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MealItemsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<int> mealId = const Value.absent(),
                Value<int> foodId = const Value.absent(),
                Value<double> quantity = const Value.absent(),
                Value<double> calories = const Value.absent(),
                Value<double> protein = const Value.absent(),
                Value<double> carbs = const Value.absent(),
                Value<double> fats = const Value.absent(),
                Value<double> fiber = const Value.absent(),
                Value<double> sodium = const Value.absent(),
                Value<double> potassium = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => MealItemsCompanion(
                id: id,
                uuid: uuid,
                mealId: mealId,
                foodId: foodId,
                quantity: quantity,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                fiber: fiber,
                sodium: sodium,
                potassium: potassium,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required int mealId,
                required int foodId,
                Value<double> quantity = const Value.absent(),
                Value<double> calories = const Value.absent(),
                Value<double> protein = const Value.absent(),
                Value<double> carbs = const Value.absent(),
                Value<double> fats = const Value.absent(),
                Value<double> fiber = const Value.absent(),
                Value<double> sodium = const Value.absent(),
                Value<double> potassium = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
              }) => MealItemsCompanion.insert(
                id: id,
                uuid: uuid,
                mealId: mealId,
                foodId: foodId,
                quantity: quantity,
                calories: calories,
                protein: protein,
                carbs: carbs,
                fats: fats,
                fiber: fiber,
                sodium: sodium,
                potassium: potassium,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$MealItemsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({mealId = false, foodId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (mealId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.mealId,
                                referencedTable: $$MealItemsTableReferences
                                    ._mealIdTable(db),
                                referencedColumn: $$MealItemsTableReferences
                                    ._mealIdTable(db)
                                    .id,
                              )
                              as T;
                    }
                    if (foodId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.foodId,
                                referencedTable: $$MealItemsTableReferences
                                    ._foodIdTable(db),
                                referencedColumn: $$MealItemsTableReferences
                                    ._foodIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$MealItemsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MealItemsTable,
      MealItem,
      $$MealItemsTableFilterComposer,
      $$MealItemsTableOrderingComposer,
      $$MealItemsTableAnnotationComposer,
      $$MealItemsTableCreateCompanionBuilder,
      $$MealItemsTableUpdateCompanionBuilder,
      (MealItem, $$MealItemsTableReferences),
      MealItem,
      PrefetchHooks Function({bool mealId, bool foodId})
    >;
typedef $$FavoritesTableCreateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> id,
      required int foodId,
      Value<DateTime> createdAt,
    });
typedef $$FavoritesTableUpdateCompanionBuilder =
    FavoritesCompanion Function({
      Value<int> id,
      Value<int> foodId,
      Value<DateTime> createdAt,
    });

final class $$FavoritesTableReferences
    extends BaseReferences<_$AppDatabase, $FavoritesTable, Favorite> {
  $$FavoritesTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoodsTable _foodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('favorites__food_id__foods__id');

  $$FoodsTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<int>('food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$FavoritesTableFilterComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodsTableFilterComposer get foodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableOrderingComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodsTableOrderingComposer get foodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableAnnotationComposer
    extends Composer<_$AppDatabase, $FavoritesTable> {
  $$FavoritesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  $$FoodsTableAnnotationComposer get foodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$FavoritesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $FavoritesTable,
          Favorite,
          $$FavoritesTableFilterComposer,
          $$FavoritesTableOrderingComposer,
          $$FavoritesTableAnnotationComposer,
          $$FavoritesTableCreateCompanionBuilder,
          $$FavoritesTableUpdateCompanionBuilder,
          (Favorite, $$FavoritesTableReferences),
          Favorite,
          PrefetchHooks Function({bool foodId})
        > {
  $$FavoritesTableTableManager(_$AppDatabase db, $FavoritesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FavoritesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FavoritesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FavoritesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> foodId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => FavoritesCompanion(
                id: id,
                foodId: foodId,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int foodId,
                Value<DateTime> createdAt = const Value.absent(),
              }) => FavoritesCompanion.insert(
                id: id,
                foodId: foodId,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$FavoritesTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({foodId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (foodId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.foodId,
                                referencedTable: $$FavoritesTableReferences
                                    ._foodIdTable(db),
                                referencedColumn: $$FavoritesTableReferences
                                    ._foodIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$FavoritesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $FavoritesTable,
      Favorite,
      $$FavoritesTableFilterComposer,
      $$FavoritesTableOrderingComposer,
      $$FavoritesTableAnnotationComposer,
      $$FavoritesTableCreateCompanionBuilder,
      $$FavoritesTableUpdateCompanionBuilder,
      (Favorite, $$FavoritesTableReferences),
      Favorite,
      PrefetchHooks Function({bool foodId})
    >;
typedef $$RecentFoodsTableCreateCompanionBuilder =
    RecentFoodsCompanion Function({
      Value<int> foodId,
      Value<DateTime> lastUsedAt,
      Value<int> useCount,
    });
typedef $$RecentFoodsTableUpdateCompanionBuilder =
    RecentFoodsCompanion Function({
      Value<int> foodId,
      Value<DateTime> lastUsedAt,
      Value<int> useCount,
    });

final class $$RecentFoodsTableReferences
    extends BaseReferences<_$AppDatabase, $RecentFoodsTable, RecentFood> {
  $$RecentFoodsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $FoodsTable _foodIdTable(_$AppDatabase db) =>
      db.foods.createAlias('recent_foods__food_id__foods__id');

  $$FoodsTableProcessedTableManager get foodId {
    final $_column = $_itemColumn<int>('food_id')!;

    final manager = $$FoodsTableTableManager(
      $_db,
      $_db.foods,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_foodIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$RecentFoodsTableFilterComposer
    extends Composer<_$AppDatabase, $RecentFoodsTable> {
  $$RecentFoodsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnFilters(column),
  );

  $$FoodsTableFilterComposer get foodId {
    final $$FoodsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableFilterComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecentFoodsTableOrderingComposer
    extends Composer<_$AppDatabase, $RecentFoodsTable> {
  $$RecentFoodsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get useCount => $composableBuilder(
    column: $table.useCount,
    builder: (column) => ColumnOrderings(column),
  );

  $$FoodsTableOrderingComposer get foodId {
    final $$FoodsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableOrderingComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecentFoodsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RecentFoodsTable> {
  $$RecentFoodsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<DateTime> get lastUsedAt => $composableBuilder(
    column: $table.lastUsedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get useCount =>
      $composableBuilder(column: $table.useCount, builder: (column) => column);

  $$FoodsTableAnnotationComposer get foodId {
    final $$FoodsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.foodId,
      referencedTable: $db.foods,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$FoodsTableAnnotationComposer(
            $db: $db,
            $table: $db.foods,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$RecentFoodsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RecentFoodsTable,
          RecentFood,
          $$RecentFoodsTableFilterComposer,
          $$RecentFoodsTableOrderingComposer,
          $$RecentFoodsTableAnnotationComposer,
          $$RecentFoodsTableCreateCompanionBuilder,
          $$RecentFoodsTableUpdateCompanionBuilder,
          (RecentFood, $$RecentFoodsTableReferences),
          RecentFood,
          PrefetchHooks Function({bool foodId})
        > {
  $$RecentFoodsTableTableManager(_$AppDatabase db, $RecentFoodsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RecentFoodsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RecentFoodsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RecentFoodsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> foodId = const Value.absent(),
                Value<DateTime> lastUsedAt = const Value.absent(),
                Value<int> useCount = const Value.absent(),
              }) => RecentFoodsCompanion(
                foodId: foodId,
                lastUsedAt: lastUsedAt,
                useCount: useCount,
              ),
          createCompanionCallback:
              ({
                Value<int> foodId = const Value.absent(),
                Value<DateTime> lastUsedAt = const Value.absent(),
                Value<int> useCount = const Value.absent(),
              }) => RecentFoodsCompanion.insert(
                foodId: foodId,
                lastUsedAt: lastUsedAt,
                useCount: useCount,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$RecentFoodsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({foodId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (foodId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.foodId,
                                referencedTable: $$RecentFoodsTableReferences
                                    ._foodIdTable(db),
                                referencedColumn: $$RecentFoodsTableReferences
                                    ._foodIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$RecentFoodsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RecentFoodsTable,
      RecentFood,
      $$RecentFoodsTableFilterComposer,
      $$RecentFoodsTableOrderingComposer,
      $$RecentFoodsTableAnnotationComposer,
      $$RecentFoodsTableCreateCompanionBuilder,
      $$RecentFoodsTableUpdateCompanionBuilder,
      (RecentFood, $$RecentFoodsTableReferences),
      RecentFood,
      PrefetchHooks Function({bool foodId})
    >;
typedef $$GoalsTableCreateCompanionBuilder =
    GoalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required String profileUuid,
      required String type,
      required double targetWeight,
      Value<DateTime?> targetDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });
typedef $$GoalsTableUpdateCompanionBuilder =
    GoalsCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> profileUuid,
      Value<String> type,
      Value<double> targetWeight,
      Value<DateTime?> targetDate,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });

final class $$GoalsTableReferences
    extends BaseReferences<_$AppDatabase, $GoalsTable, Goal> {
  $$GoalsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $UserProfileTable _profileUuidTable(_$AppDatabase db) =>
      db.userProfile.createAlias('goals__profile_uuid__user_profile__uuid');

  $$UserProfileTableProcessedTableManager get profileUuid {
    final $_column = $_itemColumn<String>('profile_uuid')!;

    final manager = $$UserProfileTableTableManager(
      $_db,
      $_db.userProfile,
    ).filter((f) => f.uuid.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_profileUuidTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$GoalsTableFilterComposer extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get targetWeight => $composableBuilder(
    column: $table.targetWeight,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  $$UserProfileTableFilterComposer get profileUuid {
    final $$UserProfileTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileUuid,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfileTableFilterComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalsTableOrderingComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get targetWeight => $composableBuilder(
    column: $table.targetWeight,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  $$UserProfileTableOrderingComposer get profileUuid {
    final $$UserProfileTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileUuid,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfileTableOrderingComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GoalsTable> {
  $$GoalsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<double> get targetWeight => $composableBuilder(
    column: $table.targetWeight,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
    column: $table.targetDate,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  $$UserProfileTableAnnotationComposer get profileUuid {
    final $$UserProfileTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.profileUuid,
      referencedTable: $db.userProfile,
      getReferencedColumn: (t) => t.uuid,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$UserProfileTableAnnotationComposer(
            $db: $db,
            $table: $db.userProfile,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$GoalsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GoalsTable,
          Goal,
          $$GoalsTableFilterComposer,
          $$GoalsTableOrderingComposer,
          $$GoalsTableAnnotationComposer,
          $$GoalsTableCreateCompanionBuilder,
          $$GoalsTableUpdateCompanionBuilder,
          (Goal, $$GoalsTableReferences),
          Goal,
          PrefetchHooks Function({bool profileUuid})
        > {
  $$GoalsTableTableManager(_$AppDatabase db, $GoalsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GoalsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GoalsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GoalsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> profileUuid = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<double> targetWeight = const Value.absent(),
                Value<DateTime?> targetDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => GoalsCompanion(
                id: id,
                uuid: uuid,
                profileUuid: profileUuid,
                type: type,
                targetWeight: targetWeight,
                targetDate: targetDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required String profileUuid,
                required String type,
                required double targetWeight,
                Value<DateTime?> targetDate = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => GoalsCompanion.insert(
                id: id,
                uuid: uuid,
                profileUuid: profileUuid,
                type: type,
                targetWeight: targetWeight,
                targetDate: targetDate,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$GoalsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({profileUuid = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (profileUuid) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.profileUuid,
                                referencedTable: $$GoalsTableReferences
                                    ._profileUuidTable(db),
                                referencedColumn: $$GoalsTableReferences
                                    ._profileUuidTable(db)
                                    .uuid,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$GoalsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GoalsTable,
      Goal,
      $$GoalsTableFilterComposer,
      $$GoalsTableOrderingComposer,
      $$GoalsTableAnnotationComposer,
      $$GoalsTableCreateCompanionBuilder,
      $$GoalsTableUpdateCompanionBuilder,
      (Goal, $$GoalsTableReferences),
      Goal,
      PrefetchHooks Function({bool profileUuid})
    >;
typedef $$WaterEntriesTableCreateCompanionBuilder =
    WaterEntriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required DateTime occurredAt,
      required String dayKey,
      required int amountMl,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });
typedef $$WaterEntriesTableUpdateCompanionBuilder =
    WaterEntriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<DateTime> occurredAt,
      Value<String> dayKey,
      Value<int> amountMl,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });

class $$WaterEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $WaterEntriesTable> {
  $$WaterEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get amountMl => $composableBuilder(
    column: $table.amountMl,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$WaterEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $WaterEntriesTable> {
  $$WaterEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get amountMl => $composableBuilder(
    column: $table.amountMl,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$WaterEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $WaterEntriesTable> {
  $$WaterEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<int> get amountMl =>
      $composableBuilder(column: $table.amountMl, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$WaterEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $WaterEntriesTable,
          WaterEntry,
          $$WaterEntriesTableFilterComposer,
          $$WaterEntriesTableOrderingComposer,
          $$WaterEntriesTableAnnotationComposer,
          $$WaterEntriesTableCreateCompanionBuilder,
          $$WaterEntriesTableUpdateCompanionBuilder,
          (
            WaterEntry,
            BaseReferences<_$AppDatabase, $WaterEntriesTable, WaterEntry>,
          ),
          WaterEntry,
          PrefetchHooks Function()
        > {
  $$WaterEntriesTableTableManager(_$AppDatabase db, $WaterEntriesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$WaterEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$WaterEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$WaterEntriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<int> amountMl = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => WaterEntriesCompanion(
                id: id,
                uuid: uuid,
                occurredAt: occurredAt,
                dayKey: dayKey,
                amountMl: amountMl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required DateTime occurredAt,
                required String dayKey,
                required int amountMl,
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => WaterEntriesCompanion.insert(
                id: id,
                uuid: uuid,
                occurredAt: occurredAt,
                dayKey: dayKey,
                amountMl: amountMl,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$WaterEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $WaterEntriesTable,
      WaterEntry,
      $$WaterEntriesTableFilterComposer,
      $$WaterEntriesTableOrderingComposer,
      $$WaterEntriesTableAnnotationComposer,
      $$WaterEntriesTableCreateCompanionBuilder,
      $$WaterEntriesTableUpdateCompanionBuilder,
      (
        WaterEntry,
        BaseReferences<_$AppDatabase, $WaterEntriesTable, WaterEntry>,
      ),
      WaterEntry,
      PrefetchHooks Function()
    >;
typedef $$PreferencesTableCreateCompanionBuilder =
    PreferencesCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$PreferencesTableUpdateCompanionBuilder =
    PreferencesCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$PreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $PreferencesTable> {
  $$PreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$PreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PreferencesTable,
          Preference,
          $$PreferencesTableFilterComposer,
          $$PreferencesTableOrderingComposer,
          $$PreferencesTableAnnotationComposer,
          $$PreferencesTableCreateCompanionBuilder,
          $$PreferencesTableUpdateCompanionBuilder,
          (
            Preference,
            BaseReferences<_$AppDatabase, $PreferencesTable, Preference>,
          ),
          Preference,
          PrefetchHooks Function()
        > {
  $$PreferencesTableTableManager(_$AppDatabase db, $PreferencesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PreferencesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PreferencesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PreferencesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => PreferencesCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PreferencesTable,
      Preference,
      $$PreferencesTableFilterComposer,
      $$PreferencesTableOrderingComposer,
      $$PreferencesTableAnnotationComposer,
      $$PreferencesTableCreateCompanionBuilder,
      $$PreferencesTableUpdateCompanionBuilder,
      (
        Preference,
        BaseReferences<_$AppDatabase, $PreferencesTable, Preference>,
      ),
      Preference,
      PrefetchHooks Function()
    >;
typedef $$LifeContextEntriesTableCreateCompanionBuilder =
    LifeContextEntriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required DateTime occurredAt,
      required String dayKey,
      required String type,
      Value<String?> details,
      Value<bool> useInInsights,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });
typedef $$LifeContextEntriesTableUpdateCompanionBuilder =
    LifeContextEntriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<DateTime> occurredAt,
      Value<String> dayKey,
      Value<String> type,
      Value<String?> details,
      Value<bool> useInInsights,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });

class $$LifeContextEntriesTableFilterComposer
    extends Composer<_$AppDatabase, $LifeContextEntriesTable> {
  $$LifeContextEntriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get useInInsights => $composableBuilder(
    column: $table.useInInsights,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LifeContextEntriesTableOrderingComposer
    extends Composer<_$AppDatabase, $LifeContextEntriesTable> {
  $$LifeContextEntriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get type => $composableBuilder(
    column: $table.type,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get details => $composableBuilder(
    column: $table.details,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get useInInsights => $composableBuilder(
    column: $table.useInInsights,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LifeContextEntriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LifeContextEntriesTable> {
  $$LifeContextEntriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<DateTime> get occurredAt => $composableBuilder(
    column: $table.occurredAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<String> get type =>
      $composableBuilder(column: $table.type, builder: (column) => column);

  GeneratedColumn<String> get details =>
      $composableBuilder(column: $table.details, builder: (column) => column);

  GeneratedColumn<bool> get useInInsights => $composableBuilder(
    column: $table.useInInsights,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$LifeContextEntriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LifeContextEntriesTable,
          LifeContextEntry,
          $$LifeContextEntriesTableFilterComposer,
          $$LifeContextEntriesTableOrderingComposer,
          $$LifeContextEntriesTableAnnotationComposer,
          $$LifeContextEntriesTableCreateCompanionBuilder,
          $$LifeContextEntriesTableUpdateCompanionBuilder,
          (
            LifeContextEntry,
            BaseReferences<
              _$AppDatabase,
              $LifeContextEntriesTable,
              LifeContextEntry
            >,
          ),
          LifeContextEntry,
          PrefetchHooks Function()
        > {
  $$LifeContextEntriesTableTableManager(
    _$AppDatabase db,
    $LifeContextEntriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LifeContextEntriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LifeContextEntriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LifeContextEntriesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<DateTime> occurredAt = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<String> type = const Value.absent(),
                Value<String?> details = const Value.absent(),
                Value<bool> useInInsights = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => LifeContextEntriesCompanion(
                id: id,
                uuid: uuid,
                occurredAt: occurredAt,
                dayKey: dayKey,
                type: type,
                details: details,
                useInInsights: useInInsights,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required DateTime occurredAt,
                required String dayKey,
                required String type,
                Value<String?> details = const Value.absent(),
                Value<bool> useInInsights = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => LifeContextEntriesCompanion.insert(
                id: id,
                uuid: uuid,
                occurredAt: occurredAt,
                dayKey: dayKey,
                type: type,
                details: details,
                useInInsights: useInInsights,
                createdAt: createdAt,
                updatedAt: updatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LifeContextEntriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LifeContextEntriesTable,
      LifeContextEntry,
      $$LifeContextEntriesTableFilterComposer,
      $$LifeContextEntriesTableOrderingComposer,
      $$LifeContextEntriesTableAnnotationComposer,
      $$LifeContextEntriesTableCreateCompanionBuilder,
      $$LifeContextEntriesTableUpdateCompanionBuilder,
      (
        LifeContextEntry,
        BaseReferences<
          _$AppDatabase,
          $LifeContextEntriesTable,
          LifeContextEntry
        >,
      ),
      LifeContextEntry,
      PrefetchHooks Function()
    >;
typedef $$DecisionMemoriesTableCreateCompanionBuilder =
    DecisionMemoriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      required String dayKey,
      required String recommendationKey,
      required String title,
      required String reason,
      Value<String> evidenceJson,
      Value<String> confidence,
      Value<String> response,
      Value<String?> outcome,
      Value<int?> helpfulness,
      Value<DateTime> surfacedAt,
      Value<DateTime?> respondedAt,
      Value<DateTime?> evaluatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });
typedef $$DecisionMemoriesTableUpdateCompanionBuilder =
    DecisionMemoriesCompanion Function({
      Value<int> id,
      Value<String> uuid,
      Value<String> dayKey,
      Value<String> recommendationKey,
      Value<String> title,
      Value<String> reason,
      Value<String> evidenceJson,
      Value<String> confidence,
      Value<String> response,
      Value<String?> outcome,
      Value<int?> helpfulness,
      Value<DateTime> surfacedAt,
      Value<DateTime?> respondedAt,
      Value<DateTime?> evaluatedAt,
      Value<DateTime?> deletedAt,
      Value<int> revision,
      Value<String> syncStatus,
    });

class $$DecisionMemoriesTableFilterComposer
    extends Composer<_$AppDatabase, $DecisionMemoriesTable> {
  $$DecisionMemoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get recommendationKey => $composableBuilder(
    column: $table.recommendationKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get response => $composableBuilder(
    column: $table.response,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get helpfulness => $composableBuilder(
    column: $table.helpfulness,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get surfacedAt => $composableBuilder(
    column: $table.surfacedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get respondedAt => $composableBuilder(
    column: $table.respondedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get evaluatedAt => $composableBuilder(
    column: $table.evaluatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DecisionMemoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $DecisionMemoriesTable> {
  $$DecisionMemoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get uuid => $composableBuilder(
    column: $table.uuid,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get dayKey => $composableBuilder(
    column: $table.dayKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get recommendationKey => $composableBuilder(
    column: $table.recommendationKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get title => $composableBuilder(
    column: $table.title,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reason => $composableBuilder(
    column: $table.reason,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get response => $composableBuilder(
    column: $table.response,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get helpfulness => $composableBuilder(
    column: $table.helpfulness,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get surfacedAt => $composableBuilder(
    column: $table.surfacedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get respondedAt => $composableBuilder(
    column: $table.respondedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get evaluatedAt => $composableBuilder(
    column: $table.evaluatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get deletedAt => $composableBuilder(
    column: $table.deletedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get revision => $composableBuilder(
    column: $table.revision,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DecisionMemoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DecisionMemoriesTable> {
  $$DecisionMemoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get uuid =>
      $composableBuilder(column: $table.uuid, builder: (column) => column);

  GeneratedColumn<String> get dayKey =>
      $composableBuilder(column: $table.dayKey, builder: (column) => column);

  GeneratedColumn<String> get recommendationKey => $composableBuilder(
    column: $table.recommendationKey,
    builder: (column) => column,
  );

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<String> get reason =>
      $composableBuilder(column: $table.reason, builder: (column) => column);

  GeneratedColumn<String> get evidenceJson => $composableBuilder(
    column: $table.evidenceJson,
    builder: (column) => column,
  );

  GeneratedColumn<String> get confidence => $composableBuilder(
    column: $table.confidence,
    builder: (column) => column,
  );

  GeneratedColumn<String> get response =>
      $composableBuilder(column: $table.response, builder: (column) => column);

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);

  GeneratedColumn<int> get helpfulness => $composableBuilder(
    column: $table.helpfulness,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get surfacedAt => $composableBuilder(
    column: $table.surfacedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get respondedAt => $composableBuilder(
    column: $table.respondedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get evaluatedAt => $composableBuilder(
    column: $table.evaluatedAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get deletedAt =>
      $composableBuilder(column: $table.deletedAt, builder: (column) => column);

  GeneratedColumn<int> get revision =>
      $composableBuilder(column: $table.revision, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$DecisionMemoriesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DecisionMemoriesTable,
          DecisionMemory,
          $$DecisionMemoriesTableFilterComposer,
          $$DecisionMemoriesTableOrderingComposer,
          $$DecisionMemoriesTableAnnotationComposer,
          $$DecisionMemoriesTableCreateCompanionBuilder,
          $$DecisionMemoriesTableUpdateCompanionBuilder,
          (
            DecisionMemory,
            BaseReferences<
              _$AppDatabase,
              $DecisionMemoriesTable,
              DecisionMemory
            >,
          ),
          DecisionMemory,
          PrefetchHooks Function()
        > {
  $$DecisionMemoriesTableTableManager(
    _$AppDatabase db,
    $DecisionMemoriesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DecisionMemoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DecisionMemoriesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DecisionMemoriesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                Value<String> dayKey = const Value.absent(),
                Value<String> recommendationKey = const Value.absent(),
                Value<String> title = const Value.absent(),
                Value<String> reason = const Value.absent(),
                Value<String> evidenceJson = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<String> response = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int?> helpfulness = const Value.absent(),
                Value<DateTime> surfacedAt = const Value.absent(),
                Value<DateTime?> respondedAt = const Value.absent(),
                Value<DateTime?> evaluatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => DecisionMemoriesCompanion(
                id: id,
                uuid: uuid,
                dayKey: dayKey,
                recommendationKey: recommendationKey,
                title: title,
                reason: reason,
                evidenceJson: evidenceJson,
                confidence: confidence,
                response: response,
                outcome: outcome,
                helpfulness: helpfulness,
                surfacedAt: surfacedAt,
                respondedAt: respondedAt,
                evaluatedAt: evaluatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> uuid = const Value.absent(),
                required String dayKey,
                required String recommendationKey,
                required String title,
                required String reason,
                Value<String> evidenceJson = const Value.absent(),
                Value<String> confidence = const Value.absent(),
                Value<String> response = const Value.absent(),
                Value<String?> outcome = const Value.absent(),
                Value<int?> helpfulness = const Value.absent(),
                Value<DateTime> surfacedAt = const Value.absent(),
                Value<DateTime?> respondedAt = const Value.absent(),
                Value<DateTime?> evaluatedAt = const Value.absent(),
                Value<DateTime?> deletedAt = const Value.absent(),
                Value<int> revision = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
              }) => DecisionMemoriesCompanion.insert(
                id: id,
                uuid: uuid,
                dayKey: dayKey,
                recommendationKey: recommendationKey,
                title: title,
                reason: reason,
                evidenceJson: evidenceJson,
                confidence: confidence,
                response: response,
                outcome: outcome,
                helpfulness: helpfulness,
                surfacedAt: surfacedAt,
                respondedAt: respondedAt,
                evaluatedAt: evaluatedAt,
                deletedAt: deletedAt,
                revision: revision,
                syncStatus: syncStatus,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DecisionMemoriesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DecisionMemoriesTable,
      DecisionMemory,
      $$DecisionMemoriesTableFilterComposer,
      $$DecisionMemoriesTableOrderingComposer,
      $$DecisionMemoriesTableAnnotationComposer,
      $$DecisionMemoriesTableCreateCompanionBuilder,
      $$DecisionMemoriesTableUpdateCompanionBuilder,
      (
        DecisionMemory,
        BaseReferences<_$AppDatabase, $DecisionMemoriesTable, DecisionMemory>,
      ),
      DecisionMemory,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DailyLogsTableTableManager get dailyLogs =>
      $$DailyLogsTableTableManager(_db, _db.dailyLogs);
  $$UserProfileTableTableManager get userProfile =>
      $$UserProfileTableTableManager(_db, _db.userProfile);
  $$WeightEntriesTableTableManager get weightEntries =>
      $$WeightEntriesTableTableManager(_db, _db.weightEntries);
  $$FoodsTableTableManager get foods =>
      $$FoodsTableTableManager(_db, _db.foods);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db, _db.meals);
  $$MealItemsTableTableManager get mealItems =>
      $$MealItemsTableTableManager(_db, _db.mealItems);
  $$FavoritesTableTableManager get favorites =>
      $$FavoritesTableTableManager(_db, _db.favorites);
  $$RecentFoodsTableTableManager get recentFoods =>
      $$RecentFoodsTableTableManager(_db, _db.recentFoods);
  $$GoalsTableTableManager get goals =>
      $$GoalsTableTableManager(_db, _db.goals);
  $$WaterEntriesTableTableManager get waterEntries =>
      $$WaterEntriesTableTableManager(_db, _db.waterEntries);
  $$PreferencesTableTableManager get preferences =>
      $$PreferencesTableTableManager(_db, _db.preferences);
  $$LifeContextEntriesTableTableManager get lifeContextEntries =>
      $$LifeContextEntriesTableTableManager(_db, _db.lifeContextEntries);
  $$DecisionMemoriesTableTableManager get decisionMemories =>
      $$DecisionMemoriesTableTableManager(_db, _db.decisionMemories);
}
