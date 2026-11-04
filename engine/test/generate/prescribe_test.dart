import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/choose_exercises.dart';
import 'package:barbl_engine/src/generate/prescribe.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _role(
  int sets, {
  int upper = 150,
  int lower = 180,
}) => {
  'sets': sets,
  'reps': {'min': 6, 'max': 8},
  'restSeconds': {'upper': upper, 'lower': lower},
  'rirFollowsMesocycle': true,
  'warmup': true,
};

KnowledgeBase _kb({int mainSets = 4, Map<String, Object?>? prescriptions}) =>
    KnowledgeBase.fromJson(
      minimalBundle(
        prescriptions:
            prescriptions ??
            {
              'muscle_gain': {
                'id': 'muscle_gain',
                'appliesTo': ['muscle_gain'],
                'roles': {
                  'main': _role(mainSets),
                  'accessory': _role(3, upper: 90, lower: 100),
                },
                'supersetRestSeconds': 75,
                'timeBudget': {'minutesPerSet': 3},
              },
            },
      ),
    );

ChosenSession _session(
  KnowledgeBase kb, {
  String focus = 'legs',
  String blockType = 'single',
  List<String> roles = const ['main'],
  ({int min, int max})? repsOverride,
  bool askLoad = false,
}) {
  final exercise = kb.exercises['squat']!;
  final slots = <ChosenSlot>[
    for (final role in roles)
      ChosenSlot(
        KbSlot(
          pattern: 'squat',
          role: role,
          candidates: const ['squat'],
          askLoad: askLoad,
          repsOverride: repsOverride,
        ),
        exercise,
      ),
  ];
  return ChosenSession(
    KbSession(
      id: 'lower_a',
      nameIt: 'Lower A',
      focus: focus,
      blocks: const [],
    ),
    [ChosenBlock(blockType, null, slots)],
  );
}

List<PrescribedSession> _ok(Result<List<PrescribedSession>> r) {
  expect(r, isA<Ok<List<PrescribedSession>>>());
  return (r as Ok<List<PrescribedSession>>).value;
}

NotCovered _rejected(Result<List<PrescribedSession>> r) {
  expect(r, isA<Rejected<List<PrescribedSession>>>());
  return (r as Rejected<List<PrescribedSession>>).reason;
}

void main() {
  test('seduta legs: recupero restLower e valori del ruolo', () {
    final kb = _kb();
    final sessions = _ok(
      prescribe([_session(kb, askLoad: true)], testProfile(), kb),
    );
    final block = sessions.single.blocks.single;
    final ex = block.exercises.single;
    expect(ex.restSeconds, 180);
    expect(block.restSeconds, isNull);
    expect(ex.sets, 4);
    expect(ex.repsMin, 6);
    expect(ex.repsMax, 8);
    expect(ex.warmup, isTrue);
    expect(ex.rirFollowsMesocycle, isTrue);
    expect(ex.askLoad, isTrue);
    expect(ex.role, 'main');
    expect(sessions.single.estimatedDurationMin, 12);
  });

  test('seduta upper_body: recupero restUpper', () {
    final kb = _kb();
    final sessions = _ok(
      prescribe([_session(kb, focus: 'upper_body')], testProfile(), kb),
    );
    expect(sessions.single.blocks.single.exercises.single.restSeconds, 150);
  });

  test('superset: esercizi senza recupero, blocco con supersetRestSeconds', () {
    final kb = _kb();
    final sessions = _ok(
      prescribe(
        [
          _session(
            kb,
            blockType: 'superset',
            roles: const ['accessory', 'accessory'],
          ),
        ],
        testProfile(),
        kb,
      ),
    );
    final block = sessions.single.blocks.single;
    expect(block.restSeconds, 75);
    expect(block.exercises.map((e) => e.restSeconds), [null, null]);
    expect(sessions.single.estimatedDurationMin, 18);
  });

  test('repsOverride dello slot vince sull\'intervallo del ruolo', () {
    final kb = _kb();
    final sessions = _ok(
      prescribe(
        [_session(kb, repsOverride: (min: 10, max: 12))],
        testProfile(),
        kb,
      ),
    );
    final ex = sessions.single.blocks.single.exercises.single;
    expect(ex.repsMin, 10);
    expect(ex.repsMax, 12);
  });

  test('durata uguale al limite: Ok', () {
    final kb = _kb(mainSets: 19);
    final sessions = _ok(
      prescribe(
        [_session(kb)],
        testProfile(sessionDurationMin: 57),
        kb,
      ),
    );
    expect(sessions.single.estimatedDurationMin, 57);
  });

  test('durata oltre il limite di un minuto: Rejected duration', () {
    final kb = _kb(mainSets: 19);
    final reason = _rejected(
      prescribe(
        [_session(kb)],
        testProfile(sessionDurationMin: 56),
        kb,
      ),
    );
    expect(reason.reason, NotCoveredReason.duration);
    expect(
      reason.detail,
      'session=lower_a estimated=57 min exceeds limit=56 min',
    );
  });

  test('nessuna prescrizione per l\'obiettivo: Rejected goal', () {
    final kb = _kb();
    final reason = _rejected(
      prescribe([_session(kb)], testProfile(goal: 'strength'), kb),
    );
    expect(reason.reason, NotCoveredReason.goal);
    expect(reason.detail, contains('strength'));
  });

  test('con due prescrizioni vale la prima per id', () {
    final kb = _kb(
      prescriptions: {
        'b_rx': {
          'id': 'b_rx',
          'appliesTo': ['muscle_gain'],
          'roles': {'main': _role(5)},
          'supersetRestSeconds': 60,
          'timeBudget': {'minutesPerSet': 3},
        },
        'a_rx': {
          'id': 'a_rx',
          'appliesTo': ['muscle_gain'],
          'roles': {'main': _role(2)},
          'supersetRestSeconds': 60,
          'timeBudget': {'minutesPerSet': 3},
        },
      },
    );
    final sessions = _ok(prescribe([_session(kb)], testProfile(), kb));
    expect(sessions.single.blocks.single.exercises.single.sets, 2);
  });

  test('ruolo assente nella prescrizione: Rejected goal', () {
    final kb = _kb();
    final reason = _rejected(
      prescribe([_session(kb, roles: const ['secondary'])], testProfile(), kb),
    );
    expect(reason.reason, NotCoveredReason.goal);
    expect(
      reason.detail,
      'role secondary missing in prescription muscle_gain (session lower_a)',
    );
  });

  test('focus sconosciuto (invariante del template): StateError', () {
    final kb = _kb();
    expect(
      () => prescribe([_session(kb, focus: 'neck')], testProfile(), kb),
      throwsA(isA<StateError>()),
    );
  });

  test('seduta full_body: il recupero segue la regione del pattern', () {
    final kb = KnowledgeBase.fromJson(
      minimalBundle(
        exercises: {
          'squat': {
            'id': 'squat',
            'name': {'it': 'Squat', 'en': 'Squat'},
            'equipment': 'barbell',
            'requires': ['barbell', 'rack'],
            'pattern': 'squat',
            'muscles': {'primary': 'quadriceps'},
            'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'trial_set'},
          },
          'bench': {
            'id': 'bench',
            'name': {'it': 'Panca', 'en': 'Bench'},
            'equipment': 'barbell',
            'requires': ['barbell', 'bench'],
            'pattern': 'horizontal_push',
            'muscles': {'primary': 'chest'},
            'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'trial_set'},
          },
        },
      ),
    );
    ChosenSlot slot(String pattern, String id) => ChosenSlot(
      KbSlot(
        pattern: pattern,
        role: 'main',
        candidates: [id],
        askLoad: false,
        repsOverride: null,
      ),
      kb.exercises[id]!,
    );
    final chosen = ChosenSession(
      KbSession(
        id: 'full_a',
        nameIt: 'Full A',
        focus: 'full_body',
        blocks: const [],
      ),
      [
        ChosenBlock('single', null, [slot('horizontal_push', 'bench')]),
        ChosenBlock('single', null, [slot('squat', 'squat')]),
      ],
    );
    final sessions = _ok(prescribe([chosen], testProfile(), kb));
    final rests = [
      for (final b in sessions.single.blocks)
        for (final e in b.exercises) e.restSeconds,
    ];
    expect(rests, [150, 180]);
  });
}
