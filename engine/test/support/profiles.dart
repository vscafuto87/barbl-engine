import 'package:barbl_engine/barbl_engine.dart';

/// Profilo di prova con valori ragionevoli, sostituibili per campo.
Profile testProfile({
  String goal = 'muscle_gain',
  int daysPerWeek = 4,
  Set<String> equipment = const {'barbell', 'rack', 'bench'},
  int sessionDurationMin = 60,
}) => Profile(
  goal: goal,
  gymType: 'full',
  equipment: equipment,
  barKg: 20,
  platesKg: const [25, 20, 10, 5, 2.5, 1.25],
  daysPerWeek: daysPerWeek,
  sessionDurationMin: sessionDurationMin,
  experience: 'over_2_years',
  knownLoads: const {},
);

/// Profilo JSON del contratto, valido per la KB minima.
Map<String, Object?> testProfileJson({
  String goal = 'muscle_gain',
  int daysPerWeek = 4,
  List<String> equipment = const ['barbell', 'rack', 'bench'],
  int sessionDurationMin = 60,
  List<Map<String, Object?>> knownLoads = const [],
}) => {
  'schemaVersion': '1.0',
  'goal': goal,
  'gym': {
    'type': 'full',
    'equipment': equipment,
    'barKg': 20,
    'platesKg': [25, 20, 10, 5, 2.5, 1.25],
  },
  'daysPerWeek': daysPerWeek,
  'sessionDurationMin': sessionDurationMin,
  'experience': 'over_2_years',
  'knownLoads': knownLoads,
};
