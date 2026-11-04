/// Eval a matrice: ogni profilo valido dell'enum dello schema del profilo
/// (3 giorni x 4 durate x 3 obiettivi x 3 palestre x 3 livelli = 324) con la KB
/// vera dà o un piano che rispetta le proprietà attese o un rifiuto motivato,
/// mai un'eccezione. Vedi `docs/eval-matrice.md`.
library;

import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:barbl_engine/src/bundle/eval_runner.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

// Dimensioni della matrice: gli enum di kb/contract/profile.schema.json.
const List<int> _days = [3, 4, 5];
const List<int> _durations = [45, 60, 75, 90];
const List<String> _goals = ['muscle_gain', 'strength', 'both'];
const List<String> _gymTypes = ['full', 'home', 'dumbbells'];
const List<String> _experiences = [
  'under_6_months',
  '6_months_2_years',
  'over_2_years',
];

/// Carichi noti per livello (un valore `null` è «Non lo so»): il principiante
/// non ne ha, gli altri due sì.
const Map<String, List<Map<String, Object?>>> _knownLoadsByExperience = {
  'under_6_months': [],
  '6_months_2_years': [
    {'exerciseId': 'barbell_bench_press', 'kg': 80, 'reps': 8},
    {'exerciseId': 'squat', 'kg': null, 'reps': null},
  ],
  'over_2_years': [
    {'exerciseId': 'barbell_bench_press', 'kg': 100, 'reps': 6},
    {'exerciseId': 'dumbbell_row', 'kg': 40, 'reps': 10},
    {'exerciseId': 'military_press', 'kg': 60, 'reps': 7},
    {'exerciseId': 'squat', 'kg': 120, 'reps': 5},
  ],
};

/// Muscoli per cui la soglia di volume è una proprietà (stessi del caso d'oro).
/// Vale per gli obiettivi di [_bandGoals]: la fascia di `belowBand` è
/// dell'ipertrofia (`P-VOL-MIN-10`); per la forza il volume utile è molto più
/// basso (`P-VOL-DOSE-STR`) e il principale a 3 serie porta petto, dorso e
/// quadricipiti a 9 (`C-STRENGTH-VOLUME`).
const List<String> _volumeMuscles = [
  'chest',
  'back',
  'quadriceps',
  'biceps',
  'triceps',
];

/// Obiettivi per cui si controlla la soglia di volume.
const Set<String> _bandGoals = {'muscle_gain', 'both'};

/// Muscoli in deficit noto, con il conflitto che li spiega. Non sono
/// controllati; ogni voce va tolta quando il conflitto si chiude.
const Map<String, String> _knownDeficits = {
  // Un solo esercizio da 3 serie a settimana nel template a 4 giorni, nessuno
  // slot in quello a 3 giorni.
  'calves': 'C-CALVES-BAND',
};

/// Combinazioni con una violazione nota: chiave del profilo -> motivo. Il test
/// di quella combinazione viene saltato. Vuota se la matrice è pulita.
const Map<String, String> _skipped = {};

/// Copertura attesa per (giorni, obiettivo, durata): `covered` oppure il nome di
/// `NotCoveredReason`. Vale per ogni palestra e livello. Va cambiata solo di
/// proposito, insieme alla KB.
const Map<(int, String, int), String> _expectedCoverage = {
  (3, 'muscle_gain', 45): 'duration',
  (3, 'muscle_gain', 60): 'covered',
  (3, 'muscle_gain', 75): 'covered',
  (3, 'muscle_gain', 90): 'covered',
  (3, 'strength', 45): 'duration',
  (3, 'strength', 60): 'duration',
  (3, 'strength', 75): 'covered',
  (3, 'strength', 90): 'covered',
  (3, 'both', 45): 'duration',
  (3, 'both', 60): 'covered',
  (3, 'both', 75): 'covered',
  (3, 'both', 90): 'covered',
  (4, 'muscle_gain', 45): 'duration',
  (4, 'muscle_gain', 60): 'covered',
  (4, 'muscle_gain', 75): 'covered',
  (4, 'muscle_gain', 90): 'covered',
  (4, 'strength', 45): 'duration',
  (4, 'strength', 60): 'duration',
  (4, 'strength', 75): 'covered',
  (4, 'strength', 90): 'covered',
  (4, 'both', 45): 'duration',
  (4, 'both', 60): 'covered',
  (4, 'both', 75): 'covered',
  (4, 'both', 90): 'covered',
  (5, 'muscle_gain', 45): 'covered',
  (5, 'muscle_gain', 60): 'covered',
  (5, 'muscle_gain', 75): 'covered',
  (5, 'muscle_gain', 90): 'covered',
  (5, 'strength', 45): 'goal',
  (5, 'strength', 60): 'goal',
  (5, 'strength', 75): 'goal',
  (5, 'strength', 90): 'goal',
  (5, 'both', 45): 'covered',
  (5, 'both', 60): 'covered',
  (5, 'both', 75): 'covered',
  (5, 'both', 90): 'covered',
};

class _Combo {
  _Combo(this.days, this.duration, this.goal, this.gym, this.experience);

  final int days;
  final int duration;
  final String goal;
  final String gym;
  final String experience;

  String get key => '${days}d-$goal-${duration}min-$gym-$experience';

  Map<String, double> get knownKg => {
    for (final l in _knownLoadsByExperience[experience]!)
      if (l['kg'] != null)
        l['exerciseId']! as String: (l['kg']! as num).toDouble(),
  };
}

final List<_Combo> _combos = [
  for (final d in _days)
    for (final dur in _durations)
      for (final g in _goals)
        for (final gym in _gymTypes)
          for (final x in _experiences) _Combo(d, dur, g, gym, x),
];

late KnowledgeBase _kb;
late Map<String, List<String>> _equipmentByGym;
late num _bandMin;
late num _trialLimit;
final File _planSchema = File('../kb/contract/plan.schema.json');

/// Esito di un profilo: il risultato oppure l'errore lanciato.
final Map<String, Object> _outcomes = {};

Map<String, Object?> _profileJson(_Combo c) => {
  'schemaVersion': '1.0',
  'goal': c.goal,
  'gym': {
    'type': c.gym,
    'equipment': _equipmentByGym[c.gym],
    'barKg': 20,
    'platesKg': [25, 20, 15, 10, 5, 2.5, 1.25],
  },
  'daysPerWeek': c.days,
  'sessionDurationMin': c.duration,
  'experience': c.experience,
  'knownLoads': [
    for (final l in _knownLoadsByExperience[c.experience]!)
      Map<String, Object?>.of(l),
  ],
};

Object _generate(_Combo c) {
  try {
    return generatePlan(_profileJson(c), _kb);
  } catch (e, st) {
    return 'eccezione: $e\n$st';
  }
}

String _label(Object outcome) {
  if (outcome is Generated) return 'covered';
  if (outcome is NotCovered) return outcome.reason.name;
  if (outcome is InvalidProfile) return 'invalid';
  return 'exception';
}

Iterable<Map<String, Object?>> _exercisesOf(Map<String, Object?> plan) sync* {
  for (final s in plan['sessions']! as List<Object?>) {
    for (final b in (s! as Map<String, Object?>)['blocks']! as List<Object?>) {
      for (final e
          in (b! as Map<String, Object?>)['exercises']! as List<Object?>) {
        yield e! as Map<String, Object?>;
      }
    }
  }
}

/// Violazioni delle proprietà di un piano generato per [c]; vuota se rispetta
/// tutto.
List<String> _planViolations(_Combo c, Map<String, Object?> plan) {
  final out = <String>[];

  for (final e in planSchemaErrors(plan, _planSchema)) {
    out.add('schema: $e');
  }
  if (plan['schemaVersion'] != '3.0') {
    out.add('schemaVersion ${plan['schemaVersion']} invece di 3.0');
  }

  for (final s in plan['sessions']! as List<Object?>) {
    final m = s! as Map<String, Object?>;
    final minutes = m['estimatedDurationMin']! as num;
    if (minutes > c.duration) {
      out.add('seduta ${m['id']}: $minutes min oltre il limite ${c.duration}');
    }
  }

  final equipment = _equipmentByGym[c.gym]!.toSet();
  final ruleIds = {
    for (final r in plan['rationales']! as List<Object?>)
      (r! as Map<String, Object?>)['ruleId']! as String,
  };
  final known = c.knownKg;
  final loadsById = <String, String>{};
  for (final e in _exercisesOf(plan)) {
    final id = e['exerciseId']! as String;
    final kbExercise = _kb.exercises[id];
    if (kbExercise == null) {
      out.add('$id: esercizio assente dalla KB');
      continue;
    }
    final missing = kbExercise.requires.where((r) => !equipment.contains(r));
    if (missing.isNotEmpty) {
      out.add('$id: richiede ${missing.join(', ')}, assente dalla palestra');
    }
    for (final rule in e['rules']! as List<Object?>) {
      if (!ruleIds.contains(rule)) out.add('$id: regola $rule senza motivazione');
    }
    final name = e['name'];
    if (name is! Map ||
        name['it'] is! String ||
        (name['it'] as String).isEmpty ||
        name['en'] is! String ||
        (name['en'] as String).isEmpty) {
      out.add('$id: nome senza it o en');
    }

    final load = e['initialLoad']! as Map<String, Object?>;
    final kg = load['kg'] as num?;
    final source = load['source'];
    loadsById.putIfAbsent(id, () => '$kg/$source');
    if (loadsById[id] != '$kg/$source') {
      out.add('$id: carichi iniziali diversi tra le occorrenze');
    }
    if (known.containsKey(id)) {
      if (source != 'profile' || kg?.toDouble() != known[id]) {
        out.add('$id: carico noto ${known[id]} ma initialLoad $kg/$source');
      }
    } else if (kg != null) {
      out.add('$id: kg $kg senza un carico noto nel profilo');
    } else if (source != 'trial_set' && source != 'manual') {
      out.add('$id: kg nullo con source $source');
    }
    if (source == 'trial_set' && kbExercise.whenLoadUnknown != 'trial_set') {
      out.add('$id: prova non ammessa dalla KB (${kbExercise.whenLoadUnknown})');
    }
    if (e['askLoad'] == true && source == null) {
      out.add('$id: askLoad senza source');
    }
  }

  // Serie di prova solo se ripetizioni minime + RIR più alto delle settimane
  // di carico restano entro `maxRepsPlusRir` (stessa regola del motore).
  final weeks = [
    for (final w
        in (plan['mesocycle']! as Map<String, Object?>)['weeks']!
            as List<Object?>)
      w! as Map<String, Object?>,
  ];
  final loadRirs = [
    for (final w in weeks)
      if (w['type'] == 'load') w['rirTarget']! as num,
  ];
  final maxLoadRir = loadRirs.reduce((a, b) => a > b ? a : b);
  for (final e in _exercisesOf(plan)) {
    final load = e['initialLoad']! as Map<String, Object?>;
    if (load['source'] != 'trial_set') continue;
    final repsMin = (e['reps']! as Map<String, Object?>)['min']! as num;
    if (repsMin + maxLoadRir > _trialLimit) {
      out.add('${e['exerciseId']}: prova con $repsMin + $maxLoadRir oltre '
          '$_trialLimit');
    }
  }

  final totals = _weeklySets(plan);
  if (!_bandGoals.contains(c.goal)) return out;
  for (final muscle in _volumeMuscles) {
    final sets = totals[muscle] ?? 0;
    if (sets + 1e-9 < _bandMin) {
      out.add('volume $muscle: $sets serie frazionarie sotto la soglia $_bandMin');
    }
  }
  return out;
}

/// Serie frazionarie settimanali per muscolo (primario 1, secondari 0,5 dalla KB).
Map<String, double> _weeklySets(Map<String, Object?> plan) {
  final totals = <String, double>{};
  for (final e in _exercisesOf(plan)) {
    final sets = e['sets']! as num;
    final muscles = e['muscles']! as List<Object?>;
    for (var i = 0; i < muscles.length; i++) {
      final weight = i == 0 ? _kb.primaryWeight : _kb.secondaryWeight;
      final m = muscles[i]! as String;
      totals[m] = (totals[m] ?? 0) + sets * weight;
    }
  }
  return totals;
}

String _coverageTable() {
  final lines = <String>[];
  final counts = <String, int>{};
  for (final c in _combos) {
    counts.update(_label(_outcomes[c.key]!), (n) => n + 1, ifAbsent: () => 1);
  }
  lines.add('Copertura della matrice (${_combos.length} profili):');
  for (final d in _days) {
    for (final g in _goals) {
      final cells = [
        for (final dur in _durations)
          '$dur:${_label(_outcomes[_Combo(d, dur, g, 'full', _experiences.first).key]!)}',
      ];
      lines.add('  $d giorni, ${g.padRight(11)} ${cells.join('  ')}');
    }
  }
  lines.add('Totali per esito:');
  for (final e in (counts.entries.toList()
    ..sort((a, b) => a.key.compareTo(b.key)))) {
    lines.add('  ${e.key.padRight(10)} ${e.value}');
  }
  return lines.join('\n');
}

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    _kb = KnowledgeBase.fromJson(built.json);

    final vocab = loadYaml(File('../kb/vocab/equipment.yaml').readAsStringSync())
        as YamlMap;
    final gymTypes = vocab['gymTypes'] as YamlMap;
    _equipmentByGym = {
      for (final e in gymTypes.entries)
        e.key as String: [for (final x in e.value as YamlList) x as String],
    };
    expect(_equipmentByGym.keys.toSet(), _gymTypes.toSet());

    // Soglia del principio P-VOL-MIN-10, come la espone il gruppo belowBand.
    final band = _kb.parameterGroups['belowBand']!;
    expect(band.principles, contains('P-VOL-MIN-10'));
    _bandMin = band.values['bandMin']! as num;
    _trialLimit =
        _kb.parameterGroups['trialLoad']!.engineConstraints['maxRepsPlusRir']!
            as num;

    for (final c in _combos) {
      _outcomes[c.key] = _generate(c);
    }
  });

  test('la matrice ha 324 profili', () {
    expect(_combos, hasLength(324));
    expect(_combos.map((c) => c.key).toSet(), hasLength(324));
  });

  group('profili', () {
    for (final c in _combos) {
      test(
        c.key,
        () {
          final outcome = _outcomes[c.key]!;
          expect(outcome, isNot(isA<String>()), reason: '$outcome');
          expect(outcome, isNot(isA<InvalidProfile>()));
          if (outcome is NotCovered) {
            expect(outcome.detail.trim(), isNotEmpty);
            expect(NotCoveredReason.values, contains(outcome.reason));
            return;
          }
          final plan = (outcome as Generated).plan;
          final violations = _planViolations(c, plan);
          expect(violations, isEmpty, reason: violations.join('\n'));

          // Determinismo: stesso profilo (costruito da capo), stesso JSON.
          final again = generatePlan(_profileJson(c), _kb);
          expect(again, isA<Generated>());
          expect(jsonEncode((again as Generated).plan), jsonEncode(plan));
        },
        skip: _skipped[c.key],
      );
    }
  });

  test('la copertura coincide con la mappa attesa', () {
    // ignore: avoid_print
    print(_coverageTable());
    final diffs = <String>[];
    for (final c in _combos) {
      final expected = _expectedCoverage[(c.days, c.goal, c.duration)];
      final actual = _label(_outcomes[c.key]!);
      if (actual != expected) {
        diffs.add('${c.key}: atteso $expected, ottenuto $actual');
      }
    }
    expect(_expectedCoverage, hasLength(_days.length * _goals.length * _durations.length));
    expect(diffs, isEmpty, reason: diffs.join('\n'));
  });

  test('la mappa dei deficit noti cita conflitti della KB', () {
    final text = File('../kb/conflicts.yaml').readAsStringSync();
    for (final e in _knownDeficits.entries) {
      expect(text, contains('id: ${e.value}'), reason: e.key);
    }
  });
}
