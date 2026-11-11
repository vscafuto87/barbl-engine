import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/choose_exercises.dart';
import 'package:barbl_engine/src/generate/extend_to_duration.dart';
import 'package:barbl_engine/src/generate/prescribe.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _exercise(
  String id,
  String pattern,
  String primary, {
  List<String> secondary = const [],
  List<String> requires = const ['dumbbells'],
}) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'equipment': 'dumbbell',
  'requires': requires,
  'pattern': pattern,
  'muscles': {'primary': primary, 'secondary': secondary},
  'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'manual'},
};

Map<String, Object?> _role(int sets) => {
  'sets': sets,
  'reps': {'min': 8, 'max': 12},
  'restSeconds': {'upper': 90, 'lower': 120},
  'rirFollowsMesocycle': true,
  'warmup': false,
};

Map<String, Object?> _session(
  String id,
  String focus,
  String pattern,
  String ex,
) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'focus': focus,
  'blocks': [
    {
      'type': 'single',
      'slots': [
        {
          'pattern': pattern,
          'role': 'main',
          'candidates': [ex],
        },
      ],
    },
  ],
};

Map<String, Object?> _extension(
  String session,
  String pattern,
  List<String> candidates, {
  String role = 'accessory',
  int? equivalent,
}) => {
  'session': session,
  'slot': {
    'pattern': pattern,
    'role': role,
    'candidates': candidates,
    'equivalent': ?equivalent,
  },
};

/// KB con due sedute da 4 serie e 5 minuti per serie (20 minuti); un'estensione
/// aggiunge 3 serie, cioè 15 minuti. [cap] è il tetto di volume di
/// `belowBand`.
KnowledgeBase _kb(List<Map<String, Object?>> extensions, {num cap = 16}) {
  final json = minimalBundle(
    exercises: {
      'squat': _exercise('squat', 'squat', 'quadriceps', requires: ['barbell']),
      'bench': _exercise(
        'bench',
        'horizontal_push',
        'chest',
        secondary: ['triceps'],
      ),
      'lateral': _exercise('lateral', 'lateral_raise', 'shoulders'),
      'lateral2': _exercise('lateral2', 'lateral_raise', 'shoulders'),
      'lateral3': _exercise('lateral3', 'lateral_raise', 'shoulders'),
      'calf': _exercise('calf', 'calf_raise', 'calves'),
      'fly': _exercise('fly', 'chest_isolation', 'chest'),
      'curl': _exercise(
        'curl',
        'elbow_flexion',
        'biceps',
        requires: ['cables'],
      ),
    },
    templates: {
      't1': {
        'id': 't1',
        'split': 'upper_lower',
        'daysPerWeek': 2,
        'goals': ['muscle_gain'],
        'defaultSchedule': {'mon': 'lower_a', 'thu': 'upper_a'},
        'sessions': [
          _session('lower_a', 'legs', 'squat', 'squat'),
          _session('upper_a', 'upper_body', 'horizontal_push', 'bench'),
        ],
        'extensions': extensions,
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
  );
  (json['parameters']! as Map<String, Object?>)['belowBand'] = {
    'group': 'belowBand',
    'target': 'parameters',
    'values': {'bandMax': cap},
    'provisional': true,
    'principles': ['P-1'],
  };
  (json['rationales']! as Map<String, Object?>)['TIME-EXTEND'] = {
    'ruleId': 'TIME-EXTEND',
    'key': 'time.extended',
    'level': 'session',
    'text': {'it': 'Estensione', 'en': 'Extension'},
    'principles': ['P-1'],
  };
  return KnowledgeBase.fromJson(json);
}

const Set<String> _equipment = {'barbell', 'dumbbells', 'cables'};

({List<ChosenSession> base, List<ChosenSession> result}) _run(
  KnowledgeBase kb, {
  int minutes = 60,
  List<String> emphasis = const [],
  Set<String> equipment = _equipment,
}) {
  final profile = testProfile(
    equipment: equipment,
    sessionDurationMin: minutes,
    emphasis: emphasis,
  );
  final template = kb.templates.single;
  final base =
      (chooseExercises(template, profile, kb) as Ok<List<ChosenSession>>).value;
  final prescription =
      (selectPrescription(profile, kb) as Ok<KbPrescription>).value;
  return (
    base: base,
    result: extendToDuration(base, template, profile, prescription, kb),
  );
}

/// Esercizi aggiunti dalle estensioni, per seduta, in ordine.
Map<String, List<String>> _added(List<ChosenSession> sessions) => {
  for (final s in sessions)
    s.session.id: [
      for (final b in s.blocks)
        for (final slot in b.slots)
          if (slot.fromExtension) slot.exercise.id,
    ],
};

void main() {
  test('senza estensioni le sedute restano le stesse', () {
    final r = _run(_kb(const []));
    expect(r.result, same(r.base));
  });

  test('aggiunge lo slot in coda, in un blocco singolo e marcato', () {
    final r = _run(
      _kb([
        _extension('lower_a', 'calf_raise', ['calf']),
      ]),
    );
    final lower = r.result.first;
    expect(lower.blocks, hasLength(2));
    expect(lower.blocks.first, same(r.base.first.blocks.first));
    final added = lower.blocks.last;
    expect(added.type, 'single');
    expect(added.slots.single.fromExtension, isTrue);
    expect(added.slots.single.fromEmphasis, isFalse);
    expect(added.slots.single.exercise.id, 'calf');
    expect(r.result.last, same(r.base.last));
    expect(r.base.first.blocks.single.slots.single.fromExtension, isFalse);
  });

  test('entra solo se la seduta resta nel tempo (limite incluso)', () {
    final kb = _kb([
      _extension('lower_a', 'calf_raise', ['calf']),
    ]);
    // 4 + 3 serie × 5 minuti = 35.
    expect(_added(_run(kb, minutes: 35).result)['lower_a'], ['calf']);
    expect(_added(_run(kb, minutes: 34).result)['lower_a'], isEmpty);
  });

  test('non ripete un pattern che la seduta ha già', () {
    final r = _run(
      _kb([
        _extension('upper_a', 'horizontal_push', ['bench', 'fly']),
        _extension('upper_a', 'chest_isolation', ['fly']),
        _extension('upper_a', 'chest_isolation', ['fly']),
      ]),
      minutes: 90,
    );
    // Il pattern horizontal_push c'è già; chest_isolation entra una volta.
    expect(_added(r.result)['upper_a'], ['fly']);
  });

  test('non supera il tetto di volume dei muscoli dell\'esercizio', () {
    final kb = _kb([
      _extension('lower_a', 'lateral_raise', ['lateral']),
      _extension('upper_a', 'lateral_raise', ['lateral2']),
    ], cap: 5);
    // Ogni estensione dà 3 serie alle spalle: la prima porta a 3, la
    // seconda a 6, oltre il tetto di 5.
    final r = _run(kb, minutes: 90);
    expect(_added(r.result), {
      'lower_a': ['lateral'],
      'upper_a': <String>[],
    });
  });

  test('un esercizio che porta il muscolo oltre il tetto non entra', () {
    // `bench` dà 4 serie al petto; `fly` ne darebbe altre 3: con un tetto di 4
    // il petto sarebbe a 7.
    final kb = _kb([
      _extension('upper_a', 'chest_isolation', ['fly']),
    ], cap: 4);
    expect(_added(_run(kb, minutes: 90).result)['upper_a'], isEmpty);
  });

  test('le estensioni si valutano nell\'ordine della KB', () {
    // Tempo per una sola estensione: vince la prima.
    final r = _run(
      _kb([
        _extension('lower_a', 'calf_raise', ['calf']),
        _extension('lower_a', 'lateral_raise', ['lateral']),
      ]),
      minutes: 35,
    );
    expect(_added(r.result)['lower_a'], ['calf']);
  });

  test('con l\'enfasi, le estensioni del distretto passano per prime', () {
    final json = minimalBundle(
      exercises: {
        'squat': _exercise(
          'squat',
          'squat',
          'quadriceps',
          requires: ['barbell'],
        ),
        'bench': _exercise(
          'bench',
          'horizontal_push',
          'chest',
          secondary: ['triceps'],
        ),
        'lateral': _exercise('lateral', 'lateral_raise', 'shoulders'),
        'fly': _exercise('fly', 'chest_isolation', 'chest'),
      },
      templates: {
        't1': {
          'id': 't1',
          'split': 'upper_lower',
          'daysPerWeek': 2,
          'goals': ['muscle_gain'],
          'defaultSchedule': {'mon': 'lower_a', 'thu': 'upper_a'},
          'sessions': [
            _session('lower_a', 'legs', 'squat', 'squat'),
            _session('upper_a', 'upper_body', 'horizontal_push', 'bench'),
          ],
          'extensions': [
            _extension('lower_a', 'lateral_raise', ['lateral']),
            _extension('lower_a', 'chest_isolation', ['fly']),
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
      emphasis: {
        'chest':
            testEmphasis(id: 'chest', sessions: const [], role: 'accessory')
              ..['muscles'] = ['chest']
              ..['placements'] = <String, Object?>{},
      },
    );
    (json['parameters']! as Map<String, Object?>)['belowBand'] = {
      'group': 'belowBand',
      'target': 'parameters',
      'values': {'bandMax': 16},
      'provisional': true,
      'principles': ['P-1'],
    };
    (json['rationales']! as Map<String, Object?>)['TIME-EXTEND'] = {
      'ruleId': 'TIME-EXTEND',
      'key': 'time.extended',
      'level': 'session',
      'text': {'it': 'Estensione', 'en': 'Extension'},
      'principles': ['P-1'],
    };
    final kb = KnowledgeBase.fromJson(json);
    final profile = testProfile(
      equipment: _equipment,
      sessionDurationMin: 35,
      emphasis: ['chest'],
    );
    final template = kb.templates.single;
    final base = (chooseExercises(
      template,
      profile,
      kb,
    ) as Ok<List<ChosenSession>>).value;
    final prescription =
        (selectPrescription(profile, kb) as Ok<KbPrescription>).value;
    final out = extendToDuration(base, template, profile, prescription, kb);
    expect(_added(out)['lower_a'], ['fly']);
  });

  test('preferisce un esercizio che la settimana non usa ancora', () {
    final r = _run(
      _kb([
        _extension('lower_a', 'lateral_raise', [
          'lateral',
          'lateral2',
        ], equivalent: 2),
        _extension('upper_a', 'lateral_raise', [
          'lateral',
          'lateral2',
        ], equivalent: 2),
      ]),
      minutes: 90,
    );
    final lower = _added(r.result)['lower_a']!.single;
    final upper = _added(r.result)['upper_a']!.single;
    expect(lower, isNot(upper));
  });

  test('senza candidato disponibile l\'estensione si salta', () {
    final r = _run(
      _kb([
        _extension('upper_a', 'elbow_flexion', ['curl']),
      ]),
      minutes: 90,
      equipment: {'barbell', 'dumbbells'},
    );
    expect(r.result, same(r.base));
  });

  test('è deterministica', () {
    final kb = _kb([
      _extension('lower_a', 'lateral_raise', [
        'lateral',
        'lateral2',
        'lateral3',
      ], equivalent: 3),
    ]);
    expect(_added(_run(kb).result), _added(_run(kb).result));
  });

  test('l\'esercizio è nel piano con la regola TIME-EXTEND', () {
    final kb = _kb([
      _extension('lower_a', 'calf_raise', ['calf']),
    ]);
    final plan = (generatePlanForProfile(
      testProfile(
        equipment: _equipment,
        daysPerWeek: 2,
        sessionDurationMin: 90,
      ),
      kb,
    ) as Generated).plan;
    final lower = (plan['sessions']! as List).first as Map;
    final ids = [
      for (final b in lower['blocks'] as List)
        for (final e in (b as Map)['exercises'] as List)
          if (((e as Map)['rules']! as List).contains(extensionRuleId))
            e['exerciseId'],
    ];
    expect(ids, ['calf']);
    expect([
      for (final r in plan['rationales']! as List) (r as Map)['ruleId'],
    ], contains(extensionRuleId));
  });

  test('un piano senza estensioni applicate non cita TIME-EXTEND', () {
    final kb = _kb([
      _extension('lower_a', 'calf_raise', ['calf']),
    ]);
    final plan = (generatePlanForProfile(
      testProfile(
        equipment: _equipment,
        daysPerWeek: 2,
        sessionDurationMin: 25,
      ),
      kb,
    ) as Generated).plan;
    expect([
      for (final r in plan['rationales']! as List) (r as Map)['ruleId'],
    ], isNot(contains(extensionRuleId)));
  });
}
