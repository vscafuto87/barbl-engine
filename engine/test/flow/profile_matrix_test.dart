/// Eval a matrice: ogni profilo valido dell'enum dello schema del profilo
/// (3 giorni x 4 durate x 3 obiettivi x 3 palestre x 3 livelli = 324) con la KB
/// vera dà o un piano che rispetta le proprietà attese o un rifiuto motivato,
/// mai un'eccezione. In più la dimensione enfasi (4 varianti per un livello:
/// 432 profili). Vedi `docs/eval-matrice.md`.
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

/// Muscoli controllati in più per giorni a settimana: il template a 5 giorni
/// porta anche spalle, femorali e glutei alla soglia (Task 2 del piano del
/// template a 5 giorni); a 3 e 4 giorni restano sotto e non sono controllati.
const Map<int, List<String>> _extraVolumeMusclesByDays = {
  5: ['shoulders', 'hamstrings', 'glutes'],
};

/// Obiettivi per cui si controlla la soglia di volume.
const Set<String> _bandGoals = {'muscle_gain', 'both'};

/// Muscoli in deficit noto, con il conflitto che li spiega. Non sono
/// controllati; ogni voce va tolta quando il conflitto si chiude.
const Map<String, String> _knownDeficits = {
  // Un solo esercizio da 3 serie a settimana nel template a 4 giorni, nessuno
  // slot in quello a 3 giorni, due esercizi (6 serie) in quello a 5 giorni.
  'calves': 'C-CALVES-BAND',
};

/// Combinazioni con una violazione nota: chiave del profilo -> motivo. Il test
/// di quella combinazione viene saltato. Vuota se la matrice è pulita.
const Map<String, String> _skipped = {};

/// Copertura attesa per (giorni, obiettivo, durata): `covered` oppure il nome di
/// `NotCoveredReason`. Vale per ogni palestra e livello. Va cambiata solo di
/// proposito, insieme alla KB.
const Map<(int, String, int), String> _expectedCoverage = {
  (3, 'muscle_gain', 45): 'covered',
  (3, 'muscle_gain', 60): 'covered',
  (3, 'muscle_gain', 75): 'covered',
  (3, 'muscle_gain', 90): 'covered',
  (3, 'strength', 45): 'covered',
  (3, 'strength', 60): 'covered',
  (3, 'strength', 75): 'covered',
  (3, 'strength', 90): 'covered',
  (3, 'both', 45): 'covered',
  (3, 'both', 60): 'covered',
  (3, 'both', 75): 'covered',
  (3, 'both', 90): 'covered',
  (4, 'muscle_gain', 45): 'covered',
  (4, 'muscle_gain', 60): 'covered',
  (4, 'muscle_gain', 75): 'covered',
  (4, 'muscle_gain', 90): 'covered',
  (4, 'strength', 45): 'covered',
  (4, 'strength', 60): 'covered',
  (4, 'strength', 75): 'covered',
  (4, 'strength', 90): 'covered',
  (4, 'both', 45): 'covered',
  (4, 'both', 60): 'covered',
  (4, 'both', 75): 'covered',
  (4, 'both', 90): 'covered',
  (5, 'muscle_gain', 45): 'covered',
  (5, 'muscle_gain', 60): 'covered',
  (5, 'muscle_gain', 75): 'covered',
  (5, 'muscle_gain', 90): 'covered',
  (5, 'strength', 45): 'covered',
  (5, 'strength', 60): 'covered',
  (5, 'strength', 75): 'covered',
  (5, 'strength', 90): 'covered',
  (5, 'both', 45): 'covered',
  (5, 'both', 60): 'covered',
  (5, 'both', 75): 'covered',
  (5, 'both', 90): 'covered',
};

/// Varianti di `emphasis` della matrice dell'enfasi (la variante «nessuna» è
/// la matrice di base): ciascuna delle tre e la coppia glutei e braccia.
const List<List<String>> _emphasisVariants = [
  ['glutes_hamstrings'],
  ['shoulders'],
  ['arms'],
  ['glutes_hamstrings', 'arms'],
];

/// Unico livello della matrice dell'enfasi: l'enfasi non dipende dal livello.
const String _emphasisExperience = '6_months_2_years';

class _Combo {
  _Combo(
    this.days,
    this.duration,
    this.goal,
    this.gym,
    this.experience, [
    this.emphasis = const [],
  ]);

  final int days;
  final int duration;
  final String goal;
  final String gym;
  final String experience;
  final List<String> emphasis;

  String get key =>
      '${days}d-$goal-${duration}min-$gym-$experience'
      '${emphasis.isEmpty ? '' : '-${emphasis.join('+')}'}';

  /// Lo stesso profilo senza enfasi.
  _Combo get base => _Combo(days, duration, goal, gym, experience);

  Map<String, int> get knownReps => {
    for (final l in _knownLoadsByExperience[experience]!)
      if (l['kg'] != null && l['reps'] != null)
        l['exerciseId']! as String: (l['reps']! as num).toInt(),
  };

  Map<String, double> get knownKg => {
    for (final l in _knownLoadsByExperience[experience]!)
      if (l['kg'] != null)
        l['exerciseId']! as String: (l['kg']! as num).toDouble(),
  };
}

// Costante di formato di Epley, solo per la verifica della conversione.
const int _epleyDivisor = 30;

final List<_Combo> _combos = [
  for (final d in _days)
    for (final dur in _durations)
      for (final g in _goals)
        for (final gym in _gymTypes)
          for (final x in _experiences) _Combo(d, dur, g, gym, x),
];

final List<_Combo> _emphasisCombos = [
  for (final d in _days)
    for (final dur in _durations)
      for (final g in _goals)
        for (final gym in _gymTypes)
          for (final e in _emphasisVariants)
            _Combo(d, dur, g, gym, _emphasisExperience, e),
];

late KnowledgeBase _kb;
late Map<String, List<String>> _equipmentByGym;
late num _bandMin;
late num _trialLimit;
final File _planSchema = File('../kb/contract/plan.schema.json');

/// Esito di un profilo: il risultato oppure l'errore lanciato.
final Map<String, Object> _outcomes = {};

Map<String, Object?> _profileJson(_Combo c) => {
  'schemaVersion': c.emphasis.isEmpty ? '1.0' : '1.2',
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
  if (c.emphasis.isNotEmpty) 'emphasis': c.emphasis,
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
  final knownReps = c.knownReps;
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
      final reps = knownReps[id];
      if (reps == null) {
        if (source != 'profile' || kg?.toDouble() != known[id]) {
          out.add('$id: carico noto ${known[id]} ma initialLoad $kg/$source');
        }
      } else {
        // Carico con ripetizioni: convertito. Mai oltre il massimale stimato
        // di quella serie, multiplo del passo, mai nullo.
        final step = kbExercise.stepKg;
        final e1rm = known[id]! * (1 + reps / _epleyDivisor);
        if (source != 'estimate' ||
            kg == null ||
            kg <= 0 ||
            kg > e1rm ||
            (step != null && (kg / step) % 1 != 0)) {
          out.add('$id: carico noto ${known[id]} x $reps ma initialLoad '
              '$kg/$source');
        }
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
  // Una seduta accorciata per la durata (P-TIME-TRIM) può lasciare un muscolo
  // sotto la soglia: il compromesso è dichiarato in C-TIME-VOLUME.
  if (_trimmed(c, plan)) return out;
  for (final muscle in [
    ..._volumeMuscles,
    ...?_extraVolumeMusclesByDays[c.days],
  ]) {
    final sets = totals[muscle] ?? 0;
    if (sets + 1e-9 < _bandMin) {
      out.add('volume $muscle: $sets serie frazionarie sotto la soglia $_bandMin');
    }
  }
  return out;
}

/// Vero se il motore ha tolto slot per far stare le sedute nella durata: il
/// piano ha meno esercizi dello stesso profilo con la durata massima.
bool _trimmed(_Combo c, Map<String, Object?> plan) {
  final now = _generate(c.base);
  final long = _generate(
    _Combo(c.days, _durations.last, c.goal, c.gym, c.experience),
  );
  if (now is! Generated || long is! Generated) return false;
  return _exercisesOf(now.plan).length < _exercisesOf(long.plan).length;
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

/// Id del template di un piano (`id` = template e tipo di palestra).
String _templateOf(_Combo c, Map<String, Object?> plan) {
  final id = plan['id']! as String;
  return id.substring(0, id.length - c.gym.length - 1);
}

/// Esercizi aggiunti per enfasi (regola `EMPHASIS`) per seduta.
Map<String, int> _emphasisCounts(Map<String, Object?> plan) {
  final out = <String, int>{};
  for (final s in plan['sessions']! as List<Object?>) {
    final m = s! as Map<String, Object?>;
    for (final b in m['blocks']! as List<Object?>) {
      for (final e
          in (b! as Map<String, Object?>)['exercises']! as List<Object?>) {
        final rules = (e! as Map<String, Object?>)['rules']! as List<Object?>;
        if (rules.contains(emphasisRuleId)) {
          out.update(m['id']! as String, (n) => n + 1, ifAbsent: () => 1);
        }
      }
    }
  }
  return out;
}

/// Posti delle enfasi del profilo nel template, per seduta.
Map<String, int> _placementCounts(_Combo c, String template) {
  final out = <String, int>{};
  for (final e in c.emphasis) {
    for (final p in _kb.emphases[e]!.placements[template] ?? const []) {
      out.update(p.session, (n) => n + 1, ifAbsent: () => 1);
    }
  }
  return out;
}

/// Violazioni proprie dell'enfasi: volume del distretto non sotto il piano
/// senza enfasi; esercizi aggiunti non oltre i posti; un posto non applicato
/// solo se la seduta non ha spazio per le sue serie (durata).
List<String> _emphasisViolations(
  _Combo c,
  Map<String, Object?> plan,
  Map<String, Object?> basePlan,
) {
  final out = <String>[];
  final withEmphasis = _weeklySets(plan);
  final withoutEmphasis = _weeklySets(basePlan);
  for (final e in c.emphasis) {
    for (final m in _kb.emphases[e]!.muscles) {
      if ((withEmphasis[m] ?? 0) + 1e-9 < (withoutEmphasis[m] ?? 0)) {
        out.add('enfasi $e, $m: ${withEmphasis[m]} serie sotto le ${withoutEmphasis[m]} '
            'senza enfasi');
      }
    }
  }
  final template = _templateOf(c, plan);
  final placed = _placementCounts(c, template);
  final added = _emphasisCounts(plan);
  final prescription = _prescriptionOf(c.goal);
  final slotMinutes =
      prescription.roles['accessory']!.sets * prescription.minutesPerSet;
  for (final s in plan['sessions']! as List<Object?>) {
    final m = s! as Map<String, Object?>;
    final id = m['id']! as String;
    final want = placed[id] ?? 0;
    final got = added[id] ?? 0;
    if (got > want) out.add('seduta $id: $got esercizi di enfasi, posti $want');
    final minutes = m['estimatedDurationMin']! as num;
    if (got < want && minutes + slotMinutes <= c.duration) {
      out.add('seduta $id: ${want - got} posti non applicati con $minutes '
          'min su ${c.duration}: la durata non lo spiega');
    }
  }
  return out;
}

KbPrescription _prescriptionOf(String goal) =>
    ([..._kb.prescriptions]..sort((a, b) => a.id.compareTo(b.id)))
        .firstWhere((p) => p.appliesTo.contains(goal));

/// Posti applicati e posti totali dell'enfasi per «template durata», sui
/// profili coperti della matrice dell'enfasi. Va cambiata solo di proposito,
/// insieme alla KB (`kb/emphasis/`, template o prescrizioni).
const Map<String, (int, int)> _expectedEmphasis = {
  'full_body_3d 45': (0, 90),
  'full_body_3d 60': (42, 90),
  'full_body_3d 75': (81, 90),
  'full_body_3d 90': (90, 90),
  'upper_lower_4d 45': (0, 90),
  'upper_lower_4d 60': (36, 90),
  'upper_lower_4d 75': (72, 90),
  'upper_lower_4d 90': (90, 90),
  'ppl_ul_5d 45': (0, 72),
  'ppl_ul_5d 60': (63, 72),
  'ppl_ul_5d 75': (72, 72),
  'ppl_ul_5d 90': (72, 72),
};

/// Conteggi dell'enfasi: posti applicati e totali per «template durata», e
/// profili coperti con tutti, alcuni o nessun posto applicato.
({Map<String, (int, int)> byKey, int all, int some, int none})
_emphasisStats() {
  final byKey = <String, (int, int)>{};
  var all = 0, some = 0, none = 0;
  for (final c in _emphasisCombos) {
    final outcome = _outcomes[c.key];
    if (outcome is! Generated) continue;
    final template = _templateOf(c, outcome.plan);
    final k = '$template ${c.duration}';
    final a = _emphasisCounts(outcome.plan).values.fold(0, (x, y) => x + y);
    final t = _placementCounts(c, template).values.fold(0, (x, y) => x + y);
    final prev = byKey[k] ?? (0, 0);
    byKey[k] = (prev.$1 + a, prev.$2 + t);
    if (a == t) {
      all++;
    } else if (a == 0) {
      none++;
    } else {
      some++;
    }
  }
  return (byKey: byKey, all: all, some: some, none: none);
}

String _emphasisReport() {
  final stats = _emphasisStats();
  final keys = stats.byKey.keys.toList()..sort();
  return [
    'Enfasi (${_emphasisCombos.length} profili, livello $_emphasisExperience):',
    for (final k in keys)
      '  ${k.padRight(20)} posti applicati '
          '${stats.byKey[k]!.$1}/${stats.byKey[k]!.$2}',
    '  profili coperti: ${stats.all} con tutti i posti, ${stats.some} con '
        'alcuni, ${stats.none} con nessuno (durata)',
  ].join('\n');
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

    for (final c in [..._combos, ..._emphasisCombos]) {
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

  test('la matrice dell\'enfasi ha 432 profili', () {
    expect(_emphasisCombos, hasLength(432));
    expect(_emphasisCombos.map((c) => c.key).toSet(), hasLength(432));
    expect(
      _emphasisCombos.map((c) => c.key).toSet().intersection(
        _combos.map((c) => c.key).toSet(),
      ),
      isEmpty,
    );
  });

  group('profili con enfasi', () {
    for (final c in _emphasisCombos) {
      test(c.key, () {
        final outcome = _outcomes[c.key]!;
        expect(outcome, isNot(isA<String>()), reason: '$outcome');
        expect(outcome, isNot(isA<InvalidProfile>()));
        // L'enfasi non cambia la copertura.
        final base = _outcomes[c.base.key]!;
        expect(_label(outcome), _label(base));
        if (outcome is NotCovered) {
          expect(outcome.reason, (base as NotCovered).reason);
          return;
        }
        final plan = (outcome as Generated).plan;
        final violations = [
          ..._planViolations(c, plan),
          ..._emphasisViolations(c, plan, (base as Generated).plan),
        ];
        expect(violations, isEmpty, reason: violations.join('\n'));

        final again = generatePlan(_profileJson(c), _kb);
        expect(again, isA<Generated>());
        expect(jsonEncode((again as Generated).plan), jsonEncode(plan));
      });
    }
  });

  test('conteggi dell\'enfasi', () {
    // ignore: avoid_print
    print(_emphasisReport());
    final stats = _emphasisStats();
    expect(stats.byKey, _expectedEmphasis);
    expect(stats.all + stats.some + stats.none,
        _emphasisCombos.where((c) => _outcomes[c.key] is Generated).length);
    expect((stats.all, stats.some, stats.none), (249, 39, 144));
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
