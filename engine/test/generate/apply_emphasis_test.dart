import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/apply_emphasis.dart';
import 'package:barbl_engine/src/generate/choose_exercises.dart';
import 'package:barbl_engine/src/generate/prescribe.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _exercise(
  String id,
  String pattern,
  List<String> requires,
) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'equipment': 'barbell',
  'requires': requires,
  'pattern': pattern,
  'muscles': {'primary': 'quadriceps'},
  'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'manual'},
};

Map<String, Object?> _session(String id, String focus, String exercise) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'focus': focus,
  'blocks': [
    {
      'type': 'single',
      'slots': [
        {
          'pattern': exercise == 'bench' ? 'horizontal_push' : 'squat',
          'role': 'main',
          'candidates': [exercise],
        },
      ],
    },
  ],
};

Map<String, Object?> _role(int sets) => {
  'sets': sets,
  'reps': {'min': 8, 'max': 12},
  'restSeconds': {'upper': 90, 'lower': 120},
  'rirFollowsMesocycle': true,
  'warmup': false,
};

Map<String, Object?> _placement(
  String session,
  String pattern,
  List<String> candidates, {
  String role = 'accessory',
}) => {
  'session': session,
  'slot': {'pattern': pattern, 'role': role, 'candidates': candidates},
};

Map<String, Object?> _emphasis(
  String id,
  List<Map<String, Object?>> placements,
) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'muscles': ['quadriceps'],
  'placements': {if (placements.isNotEmpty) 't1': placements},
  'principles': ['P-1'],
  'provisional': true,
};

/// KB con due sedute da 4 serie (principale) e 5 minuti per serie: 20 minuti
/// ciascuna; uno slot complementare aggiunge 3 serie, cioè 15 minuti.
KnowledgeBase _kb({Map<String, Object?>? emphasis}) => KnowledgeBase.fromJson(
  minimalBundle(
    exercises: {
      'squat': _exercise('squat', 'squat', ['barbell', 'rack']),
      'goblet': _exercise('goblet', 'squat', ['dumbbells']),
      'bench': _exercise('bench', 'horizontal_push', ['barbell', 'bench']),
      'fly': _exercise('fly', 'horizontal_push', ['cables']),
    },
    templates: {
      't1': {
        'id': 't1',
        'split': 'upper_lower',
        'daysPerWeek': 4,
        'goals': ['muscle_gain'],
        'defaultSchedule': {'mon': 'lower_a', 'thu': 'upper_a'},
        'sessions': [
          _session('lower_a', 'legs', 'squat'),
          _session('upper_a', 'upper_body', 'bench'),
        ],
      },
    },
    prescriptions: {
      'muscle_gain': {
        'id': 'muscle_gain',
        'appliesTo': ['muscle_gain'],
        'roles': {'main': _role(4), 'accessory': _role(3)},
        'supersetRestSeconds': 120,
        'timeBudget': {'minutesPerSet': 5},
      },
    },
    emphasis:
        emphasis ??
        {
          'glutes_hamstrings': _emphasis('glutes_hamstrings', [
            _placement('lower_a', 'squat', ['goblet', 'squat']),
          ]),
          'shoulders': _emphasis('shoulders', [
            _placement('upper_a', 'horizontal_push', ['fly', 'bench']),
            _placement('lower_a', 'squat', ['squat']),
          ]),
          'arms': _emphasis('arms', [
            _placement('upper_a', 'horizontal_push', ['bench']),
          ]),
        },
  ),
);

const Set<String> _allEquipment = {
  'barbell',
  'rack',
  'bench',
  'dumbbells',
  'cables',
};

({List<ChosenSession> base, List<ChosenSession> result}) _run(
  KnowledgeBase kb, {
  List<String> emphasis = const [],
  int minutes = 60,
  Set<String> equipment = _allEquipment,
}) {
  final profile = testProfile(
    equipment: equipment,
    sessionDurationMin: minutes,
    emphasis: emphasis,
  );
  final template = kb.templates.single;
  final base =
      (chooseExercises(template, profile, kb) as Ok<List<ChosenSession>>)
          .value;
  final prescription =
      (selectPrescription(profile, kb) as Ok<KbPrescription>).value;
  return (
    base: base,
    result: applyEmphasis(base, template, profile, prescription, kb),
  );
}

/// Esercizi aggiunti per enfasi, per seduta, in ordine.
Map<String, List<String>> _added(List<ChosenSession> sessions) => {
  for (final s in sessions)
    s.session.id: [
      for (final b in s.blocks)
        for (final slot in b.slots)
          if (slot.fromEmphasis) slot.exercise.id,
    ],
};

void main() {
  test('senza enfasi le sedute restano le stesse', () {
    final r = _run(_kb());
    expect(r.result, same(r.base));
  });

  test('aggiunge lo slot in coda alla seduta, in un blocco singolo', () {
    final r = _run(_kb(), emphasis: ['glutes_hamstrings']);
    final lower = r.result.first;
    expect(lower.session.id, 'lower_a');
    expect(lower.blocks, hasLength(2));
    expect(lower.blocks.first, same(r.base.first.blocks.first));
    final added = lower.blocks.last;
    expect(added.type, 'single');
    expect(added.label, isNull);
    expect(added.slots.single.fromEmphasis, isTrue);
    expect(added.slots.single.slot.role, 'accessory');
    // Primo candidato disponibile nella palestra.
    expect(added.slots.single.exercise.id, 'goblet');
    // La seduta senza posti resta la stessa.
    expect(r.result.last, same(r.base.last));
    // Gli slot del template non sono marcati.
    expect(r.base.first.blocks.single.slots.single.fromEmphasis, isFalse);
  });

  test('senza attrezzatura per il primo candidato sceglie il successivo', () {
    final r = _run(
      _kb(),
      emphasis: ['glutes_hamstrings'],
      equipment: {'barbell', 'rack', 'bench'},
    );
    expect(_added(r.result)['lower_a'], ['squat']);
  });

  test('uno slot senza candidati disponibili si salta', () {
    final kb = _kb(emphasis: {
      'arms': _emphasis('arms', [
        _placement('upper_a', 'horizontal_push', ['fly']),
        _placement('lower_a', 'squat', ['goblet']),
      ]),
    });
    final r = _run(kb, emphasis: ['arms'], equipment: {'barbell', 'rack', 'bench', 'dumbbells'});
    // Senza cavi `fly` non è disponibile; il goblet di lower_a sì.
    expect(_added(r.result), {'lower_a': ['goblet'], 'upper_a': <String>[]});
  });

  test('salta lo slot che porterebbe la seduta oltre la durata', () {
    // 20 minuti di base + 15 = 35.
    final over = _run(_kb(), emphasis: ['glutes_hamstrings'], minutes: 30);
    expect(over.result, same(over.base));
    final exact = _run(_kb(), emphasis: ['glutes_hamstrings'], minutes: 35);
    expect(_added(exact.result)['lower_a'], ['goblet']);
  });

  test('ordine stabile: prima l\'ordine del profilo, poi quello dei posti', () {
    // Con 35 minuti nella seduta upper_a entra un solo slot: il primo.
    final a = _run(_kb(), emphasis: ['shoulders', 'arms'], minutes: 35);
    expect(_added(a.result), {
      'lower_a': ['squat'],
      'upper_a': ['fly'],
    });
    final b = _run(_kb(), emphasis: ['arms', 'shoulders'], minutes: 35);
    expect(_added(b.result), {
      'lower_a': ['squat'],
      'upper_a': ['bench'],
    });
    // Con 50 minuti entrano entrambi, nello stesso ordine.
    final c = _run(_kb(), emphasis: ['arms', 'shoulders'], minutes: 50);
    expect(_added(c.result)['upper_a'], ['bench', 'fly']);
    // Lo stesso profilo dà sempre lo stesso esito.
    final again = _run(_kb(), emphasis: ['arms', 'shoulders'], minutes: 50);
    expect(_added(again.result), _added(c.result));
  });

  test('al massimo uno slot per seduta e per enfasi', () {
    final r = _run(_kb(), emphasis: ['shoulders'], minutes: 90);
    expect(_added(r.result), {
      'lower_a': ['squat'],
      'upper_a': ['fly'],
    });
  });

  test('un template senza posti per l\'enfasi non cambia', () {
    final kb = _kb(emphasis: {'arms': _emphasis('arms', const [])});
    final r = _run(kb, emphasis: ['arms']);
    expect(r.result, same(r.base));
  });

  test('un\'enfasi assente dalla KB si ignora', () {
    final kb = _kb(emphasis: {
      'arms': _emphasis('arms', [
        _placement('upper_a', 'horizontal_push', ['bench']),
      ]),
    });
    final r = _run(kb, emphasis: ['shoulders']);
    expect(r.result, same(r.base));
  });

  test('un ruolo assente dalla prescrizione si salta', () {
    final kb = _kb(emphasis: {
      'arms': _emphasis('arms', [
        _placement('upper_a', 'horizontal_push', ['bench'], role: 'secondary'),
      ]),
    });
    final r = _run(kb, emphasis: ['arms']);
    expect(r.result, same(r.base));
  });

  group('nel piano', () {
    Map<String, Object?> plan(KnowledgeBase kb, List<String>? emphasis) {
      final r = generatePlan(
        testProfileJson(
          equipment: _allEquipment.toList()..sort(),
          sessionDurationMin: 60,
          emphasis: emphasis,
        ),
        kb,
      );
      expect(r, isA<Generated>());
      return (r as Generated).plan;
    }

    List<Map<String, Object?>> exercises(Map<String, Object?> plan) => [
      for (final s in plan['sessions']! as List<Object?>)
        for (final b in (s! as Map)['blocks'] as List<Object?>)
          for (final e in (b! as Map)['exercises'] as List<Object?>)
            (e! as Map).cast<String, Object?>(),
    ];

    List<Object?> ruleIds(Map<String, Object?> plan) => [
      for (final r in plan['rationales']! as List<Object?>)
        (r! as Map)['ruleId'],
    ];

    test('EMPHASIS solo sugli esercizi aggiunti e la motivazione nel piano', () {
      final p = plan(_kb(), ['glutes_hamstrings']);
      final all = exercises(p);
      expect(all.map((e) => e['exerciseId']), ['squat', 'goblet', 'bench']);
      for (final e in all) {
        final rules = e['rules']! as List<Object?>;
        expect(rules.contains('EMPHASIS'), e['exerciseId'] == 'goblet',
            reason: '${e['exerciseId']}');
        expect(rules, contains('PROG-DOUBLE'));
      }
      final goblet = all[1];
      expect(goblet['sets'], 3);
      expect(goblet.containsKey('askLoad'), isFalse);
      expect(goblet['restSeconds'], 120);
      expect(ruleIds(p), contains('EMPHASIS'));
      final emphasisRationale = (p['rationales']! as List<Object?>)
          .cast<Map>()
          .singleWhere((r) => r['ruleId'] == 'EMPHASIS');
      expect(emphasisRationale['level'], 'session');
      // Durata con le serie aggiunte: (4 + 3) × 5.
      final lower = (p['sessions']! as List<Object?>).first! as Map;
      expect(lower['estimatedDurationMin'], 35);
    });

    test('senza enfasi applicata la motivazione EMPHASIS non c\'è', () {
      final none = plan(_kb(), null);
      expect(ruleIds(none), isNot(contains('EMPHASIS')));
      final empty = plan(_kb(), const []);
      expect(ruleIds(empty), isNot(contains('EMPHASIS')));
      for (final e in exercises(none)) {
        expect(e['rules'], isNot(contains('EMPHASIS')));
      }
    });

    test('un\'enfasi non valida nel profilo è InvalidProfile', () {
      final r = generatePlan(testProfileJson(emphasis: ['calves']), _kb());
      expect(r, isA<InvalidProfile>());
      expect((r as InvalidProfile).errors.single, startsWith('emphasis'));
    });
  });
}
