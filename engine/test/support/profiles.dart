import 'package:barbl_engine/barbl_engine.dart';

/// Profilo di prova con valori ragionevoli, sostituibili per campo.
Profile testProfile({
  String goal = 'muscle_gain',
  int daysPerWeek = 4,
  Set<String> equipment = const {'barbell', 'rack', 'bench'},
}) => Profile(
  goal: goal,
  gymType: 'full',
  equipment: equipment,
  barKg: 20,
  platesKg: const [25, 20, 10, 5, 2.5, 1.25],
  daysPerWeek: daysPerWeek,
  sessionDurationMin: 60,
  experience: 'over_2_years',
  knownLoads: const {},
);
