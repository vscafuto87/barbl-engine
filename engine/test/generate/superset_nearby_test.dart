import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/choose_exercises.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _exercise(String id, String equipment, String pattern) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'equipment': equipment,
  'requires': switch (equipment) {
    'dumbbell' => ['dumbbells'],
    'cable' => ['cables'],
    _ => ['machines'],
  },
  'pattern': pattern,
  'muscles': {'primary': 'shoulders'},
  'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'manual'},
};

const _proximity = {
  'portableRequires': ['dumbbells', 'bench'],
  'sharedStation': ['cable', 'barbell', 'smith_machine'],
};

/// Un superset: rear delt (solo [first]) e polpacci ([second], equivalenti).
KnowledgeBase _kb(
  List<String> first,
  List<String> second, {
  bool withProximity = true,
}) {
  final bundle = minimalBundle(
    exercises: {
      'face_pull': _exercise('face_pull', 'cable', 'squat'),
      'reverse_pec_deck': _exercise('reverse_pec_deck', 'machine', 'squat'),
      'db_rear_delt': _exercise('db_rear_delt', 'dumbbell', 'squat'),
      'donkey_calf': _exercise('donkey_calf', 'machine', 'squat'),
      'seated_calf': _exercise('seated_calf', 'machine', 'squat'),
      'db_calf': _exercise('db_calf', 'dumbbell', 'squat'),
      'cable_calf': _exercise('cable_calf', 'cable', 'squat'),
    },
    templates: {
      't1': {
        'id': 't1',
        'split': 'upper_lower',
        'daysPerWeek': 4,
        'goals': ['muscle_gain'],
        'defaultSchedule': {'mon': 'pull'},
        'sessions': [
          {
            'id': 'pull',
            'name': {'it': 'Pull', 'en': 'Pull'},
            'focus': 'upper_body',
            'blocks': [
              {
                'type': 'superset',
                'label': 'A',
                'slots': [
                  {
                    'pattern': 'squat',
                    'role': 'accessory',
                    'equivalent': first.length,
                    'candidates': first,
                  },
                  {
                    'pattern': 'squat',
                    'role': 'accessory',
                    'equivalent': second.length,
                    'candidates': second,
                  },
                ],
              },
            ],
          },
        ],
      },
    },
  );
  if (withProximity) {
    bundle['equipment'] = {'supersetProximity': _proximity};
  }
  return KnowledgeBase.fromJson(bundle);
}

/// Gli esercizi del superset per ogni profilo di prova (semi diversi).
List<List<String>> _pairs(KnowledgeBase kb) => [
  for (var d = 30; d <= 120; d += 15)
    [
      for (final s in (chooseExercises(
        kb.templates.single,
        testProfile(
          sessionDurationMin: d,
          equipment: const {'cables', 'dumbbells', 'machines'},
        ),
        kb,
      ) as Ok<List<ChosenSession>>).value.single.blocks.single.slots)
        s.exercise.id,
    ],
];

void main() {
  group('superset con attrezzi vicini (P-SUPERSET-NEARBY)', () {
    test('al cavo si abbina il polpaccio con i manubri, non la macchina', () {
      final kb = _kb(['face_pull'], ['donkey_calf', 'seated_calf', 'db_calf']);
      for (final pair in _pairs(kb)) {
        expect(pair, ['face_pull', 'db_calf']);
      }
    });

    test('due esercizi al cavo vanno nella stessa stazione', () {
      final kb = _kb(['face_pull'], ['donkey_calf', 'cable_calf']);
      for (final pair in _pairs(kb)) {
        expect(pair, ['face_pull', 'cable_calf']);
      }
    });

    test('dopo un esercizio con i manubri ogni candidato va bene', () {
      final kb = _kb(['db_rear_delt'], ['donkey_calf', 'seated_calf']);
      final seconds = {for (final p in _pairs(kb)) p[1]};
      expect(seconds, {'donkey_calf', 'seated_calf'});
    });

    test('senza un candidato vicino la scelta resta quella di sempre', () {
      final kb = _kb(['reverse_pec_deck'], ['donkey_calf', 'seated_calf']);
      final plain = _kb(
        ['reverse_pec_deck'],
        ['donkey_calf', 'seated_calf'],
        withProximity: false,
      );
      expect(_pairs(kb), _pairs(plain));
    });

    test('senza supersetProximity nella KB la scelta non cambia', () {
      final kb = _kb(
        ['face_pull'],
        ['donkey_calf', 'seated_calf', 'db_calf'],
        withProximity: false,
      );
      final seconds = {for (final p in _pairs(kb)) p[1]};
      expect(seconds.length, greaterThan(1));
    });
  });
}
