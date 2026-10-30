import 'package:barbl_engine/barbl_engine.dart';
import 'package:test/test.dart';

Map<String, Object?> minimalBundle() => {
  'bundleFormat': 1,
  'rulesVersion': '9.9.9',
  'kbCommit': 'abc123',
  'muscles': <String, Object?>{},
  'setWeights': {'primary': 1, 'secondary': 0.5},
  'patterns': <String, Object?>{},
  'equipment': <String, Object?>{},
  'sources': {
    's1': {
      'id': 's1',
      'type': 'position_stand',
      'tier': 1,
      'title': 'Fonte',
      'reference': 'Rivista 1:2',
      'use': 'public',
    },
  },
  'principles': {
    'P-1': {
      'id': 'P-1',
      'sources': [
        {
          'id': 's1',
          'pages': [865],
          'access': 'full_text',
        },
      ],
    },
  },
  'exercises': {
    'squat': {
      'id': 'squat',
      'name': {'it': 'Squat', 'en': 'Squat'},
      'equipment': 'barbell',
      'requires': ['barbell', 'rack'],
      'pattern': 'squat',
      'muscles': {
        'primary': 'quadriceps',
        'secondary': ['glutes'],
      },
      'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'trial_set'},
    },
  },
  'templates': {
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
                  'askLoad': true,
                  'candidates': ['squat'],
                },
              ],
            },
          ],
        },
      ],
    },
  },
  'prescriptions': {
    'muscle_gain': {
      'id': 'muscle_gain',
      'appliesTo': ['muscle_gain'],
      'roles': {
        'main': {
          'sets': 4,
          'reps': {'min': 6, 'max': 8},
          'restSeconds': {'upper': 150, 'lower': 180},
          'rirFollowsMesocycle': true,
          'warmup': true,
        },
      },
      'supersetRestSeconds': 120,
      'timeBudget': {'minutesPerSet': 3},
    },
  },
  'parameters': {
    'progression': {
      'group': 'progression',
      'target': 'parameters',
      'ruleId': 'PROG-DOUBLE',
      'values': {'stepKg': 2.5},
      'provisional': true,
      'principles': ['P-1'],
    },
    'tired': {
      'group': 'tired',
      'target': 'parameters',
      'values': {'loadPct': -5},
      'provisional': true,
    },
    'mesocycle': {
      'group': 'mesocycle',
      'target': 'mesocycle',
      'values': {'weeks': <Object?>[]},
      'provisional': true,
      'engineConstraints': {'x': 1},
    },
  },
  'rationales': {
    'PROG-DOUBLE': {
      'ruleId': 'PROG-DOUBLE',
      'key': 'progression.double',
      'level': 'set',
      'everyExercise': true,
      'text': {'it': 'Testo', 'en': 'Text'},
      'exampleValues': {'stepKg': 2.5},
      'sourcesFrom': 'parameters/progression',
    },
  },
};

void main() {
  group('KnowledgeBase.fromJson', () {
    test('legge un pacchetto minimo', () {
      final kb = KnowledgeBase.fromJson(minimalBundle());
      expect(kb.rulesVersion, '9.9.9');
      expect(kb.kbCommit, 'abc123');
      expect(kb.primaryWeight, 1.0);
      expect(kb.secondaryWeight, 0.5);
      expect(kb.exercises['squat']!.stepKg, 2.5);
      expect(kb.exercises['squat']!.secondaryMuscles, ['glutes']);
      final slot = kb
          .templates.single.sessions.single.blocks.single.slots.single;
      expect(slot.askLoad, true);
      expect(slot.repsOverride, isNull);
      expect(kb.prescriptions.single.roles['main']!.restLower, 180);
      expect(kb.prescriptions.single.minutesPerSet, 3);
      expect(kb.parameterGroups.keys, hasLength(3));
      expect(kb.parameterGroups['tired']!.ruleId, isNull);
      expect(kb.parameterGroups['mesocycle']!.engineConstraints, {'x': 1});
      expect(kb.rationales.single.everyExercise, true);
      expect(kb.principles['P-1']!.sources, ['s1']);
      expect(kb.sources['s1']!.tier, 1);
    });

    test('bundleFormat diverso da 1 lancia KbFormatException', () {
      final json = minimalBundle()..['bundleFormat'] = 2;
      expect(() => KnowledgeBase.fromJson(json), throwsA(isA<KbFormatException>()));
    });

    test('una chiave mancante lancia con il nome della chiave', () {
      final json = minimalBundle()..remove('exercises');
      expect(
        () => KnowledgeBase.fromJson(json),
        throwsA(
          isA<KbFormatException>().having(
            (e) => e.message,
            'message',
            contains('exercises'),
          ),
        ),
      );
    });

    test('un tipo sbagliato indica il percorso del campo', () {
      final json = minimalBundle();
      final ex = (json['exercises'] as Map)['squat'] as Map;
      (ex['loading'] as Map)['stepKg'] = 'due';
      expect(
        () => KnowledgeBase.fromJson(json),
        throwsA(
          isA<KbFormatException>().having(
            (e) => e.message,
            'message',
            contains('stepKg'),
          ),
        ),
      );
    });
  });
}
