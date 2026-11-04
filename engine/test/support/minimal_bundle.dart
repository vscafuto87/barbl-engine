/// KB minima condivisa dai test (pacchetto JSON letto da `KnowledgeBase.fromJson`).
Map<String, Object?> minimalBundle({
  Map<String, Object?>? templates,
  Map<String, Object?>? exercises,
  Map<String, Object?>? prescriptions,
  Map<String, Object?>? emphasis,
}) => {
  'bundleFormat': 1,
  if (emphasis != null) 'emphasis': emphasis,
  'rulesVersion': '9.9.9',
  'kbCommit': 'abc123',
  'muscles': <String, Object?>{},
  'setWeights': {'primary': 1, 'secondary': 0.5},
  'patterns': [
    {'id': 'squat', 'region': 'lower'},
    {'id': 'horizontal_push', 'region': 'upper'},
  ],
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
  'exercises': exercises ?? {
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
  'templates': templates ?? {
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
  'prescriptions': prescriptions ?? {
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
    if (emphasis != null) 'EMPHASIS': emphasisRationale(),
  },
};

/// Motivazione `EMPHASIS` per la KB minima.
Map<String, Object?> emphasisRationale() => {
  'ruleId': 'EMPHASIS',
  'key': 'emphasis.added',
  'level': 'session',
  'text': {'it': 'Enfasi', 'en': 'Emphasis'},
  'principles': ['P-1'],
};

/// Un'enfasi per la KB minima: uno slot per seduta di [sessions] nel
/// template [template].
Map<String, Object?> testEmphasis({
  String id = 'glutes_hamstrings',
  String template = 't1',
  List<String> sessions = const ['lower_a'],
  String pattern = 'squat',
  String role = 'main',
  List<String> candidates = const ['squat'],
}) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'muscles': ['quadriceps'],
  'placements': {
    template: [
      for (final s in sessions)
        {
          'session': s,
          'slot': {
            'pattern': pattern,
            'role': role,
            'candidates': candidates,
          },
        },
    ],
  },
  'principles': ['P-1'],
  'provisional': true,
};
