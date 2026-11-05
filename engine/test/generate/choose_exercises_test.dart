import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/choose_exercises.dart';
import 'package:barbl_engine/src/generate/result.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _exercise(String id, List<String> requires) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'equipment': requires.isEmpty ? 'bodyweight' : requires.first,
  'requires': requires,
  'pattern': 'squat',
  'muscles': {'primary': 'quadriceps'},
  'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'trial_set'},
};

KnowledgeBase _kb() => KnowledgeBase.fromJson(
  minimalBundle(
    exercises: {
      'squat': _exercise('squat', ['barbell', 'rack']),
      'db_squat': _exercise('db_squat', ['dumbbells']),
    },
    templates: {
      't1': {
        'id': 't1',
        'split': 'upper_lower',
        'daysPerWeek': 4,
        'goals': ['muscle_gain'],
        'defaultSchedule': {'mon': 'lower_a'},
        'sessions': [
          {
            'id': 'lower_a',
            'name': {'it': 'Lower A', 'en': 'Lower A'},
            'focus': 'legs',
            'blocks': [
              {
                'type': 'single',
                'slots': [
                  {
                    'pattern': 'squat',
                    'role': 'main',
                    'candidates': ['squat', 'db_squat'],
                  },
                ],
              },
            ],
          },
        ],
      },
    },
  ),
);

Result<List<ChosenSession>> _choose(Set<String> equipment) {
  final kb = _kb();
  return chooseExercises(
    kb.templates.single,
    testProfile(equipment: equipment),
    kb,
  );
}

String _firstId(Result<List<ChosenSession>> r) =>
    (r as Ok<List<ChosenSession>>)
        .value
        .single
        .blocks
        .single
        .slots
        .single
        .exercise
        .id;

void _expectNoEquipment(Result<List<ChosenSession>> r) {
  expect(r, isA<Rejected<List<ChosenSession>>>());
  final reason = (r as Rejected<List<ChosenSession>>).reason;
  expect(reason.reason, NotCoveredReason.equipment);
  expect(reason.detail, contains('lower_a'));
  expect(reason.detail, contains('squat'));
}

void main() {
  _stableHashTests();
  group('chooseExercises', () {
    test('sceglie il primo candidato disponibile', () {
      expect(_firstId(_choose({'barbell', 'rack', 'bench'})), 'squat');
    });

    test('salta il bilanciere senza rack e sceglie il manubrio', () {
      expect(_firstId(_choose({'dumbbells', 'bench'})), 'db_squat');
    });

    test('attrezzatura vuota: NotCovered(equipment)', () {
      _expectNoEquipment(_choose(<String>{}));
    });

    test('duplicato e valore sconosciuto: stesso esito del caso vuoto', () {
      _expectNoEquipment(
        _choose(Set<String>.of(['barbell', 'barbell', 'jetpack'])),
      );
    });

    test('un valore sconosciuto accanto a quelli buoni è ignorato', () {
      expect(_firstId(_choose({'barbell', 'rack', 'jetpack'})), 'squat');
    });
  });
}


void _stableHashTests() {
  group('stableHash', () {
    test('FNV-1a a 32 bit, valore noto', () {
      expect(stableHash('a'), 0xe40c292c);
      expect(stableHash(''), 0x811c9dc5);
    });
  });
}
