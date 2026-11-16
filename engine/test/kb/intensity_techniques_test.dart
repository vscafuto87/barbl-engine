import 'package:barbl_engine/barbl_engine.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';

Matcher _rejects(String part) => throwsA(
  isA<KbFormatException>().having((e) => e.message, 'message', contains(part)),
);

Map<String, Object?> _exercise(
  String id, {
  List<String> requires = const ['dumbbells'],
  bool heavy = false,
}) => {
  'id': id,
  'name': {'it': id, 'en': id},
  'equipment': 'dumbbell',
  'requires': requires,
  'pattern': 'squat',
  'muscles': {'primary': 'quadriceps'},
  'loading': {'stepKg': 2.5, 'whenLoadUnknown': 'manual'},
  if (heavy) 'heavyCompound': true,
};

Map<String, Object?> _slot(
  String role, {
  String? lastSet,
  List<String> candidates = const ['curl'],
}) => {
  'pattern': 'squat',
  'role': role,
  'candidates': candidates,
  'lastSet': ?lastSet,
};

Map<String, Object?> _single(Map<String, Object?> slot) => {
  'type': 'single',
  'slots': [slot],
};

Map<String, Object?> _superset(List<Map<String, Object?>> slots) => {
  'type': 'superset',
  'label': 'A',
  'slots': slots,
};

/// KB minima con una seduta fatta dei blocchi [blocks], le palestre `full` e
/// `dumbbells` e, se [maxTechniques] non è nullo, il gruppo
/// `intensityTechniques` con il tetto per seduta.
Map<String, Object?> _bundle(
  List<Map<String, Object?>> blocks, {
  int? maxTechniques = 1,
  Map<String, Object?>? prescriptions,
}) {
  final json = minimalBundle(
    prescriptions: prescriptions,
    exercises: {
      'squat': _exercise('squat', requires: ['barbell', 'rack'], heavy: true),
      'curl': _exercise('curl'),
      'leg_press': _exercise('leg_press', requires: ['machines']),
    },
    templates: {
      'adv': {
        'id': 'adv',
        'split': 'upper_lower',
        'daysPerWeek': 4,
        'goals': ['muscle_gain'],
        'experience': ['over_2_years'],
        'defaultSchedule': {'mon': 'lower_a'},
        'sessions': [
          {
            'id': 'lower_a',
            'name': {'it': 'Lower A', 'en': 'Lower A'},
            'focus': 'legs',
            'blocks': blocks,
          },
        ],
      },
    },
  );
  json['equipment'] = {
    'gymTypes': {
      'full': ['barbell', 'rack', 'dumbbells', 'machines'],
      'dumbbells': ['dumbbells'],
    },
  };
  if (maxTechniques != null) {
    (json['parameters']! as Map)['intensityTechniques'] = {
      'group': 'intensityTechniques',
      'target': 'parameters',
      'values': <String, Object?>{},
      'provisional': true,
      'principles': ['P-1'],
      'engineConstraints': {'maxTechniquesPerSession': maxTechniques},
    };
  }
  return json;
}

void main() {
  group('campi del livello avanzato', () {
    test('KB valida: esperienza, lastSet, heavyCompound e tempo', () {
      final kb = KnowledgeBase.fromJson(
        _bundle(
          [
            _single(_slot('main', candidates: ['squat'])),
            _single(_slot('accessory', lastSet: 'drop_set')),
            _superset([
              _slot('secondary', lastSet: 'failure'),
              _slot('accessory', lastSet: 'failure'),
            ]),
          ],
          prescriptions: {
            'adv': {
              'id': 'adv',
              'appliesTo': ['muscle_gain'],
              'experience': ['over_2_years'],
              'roles': {
                'main': {
                  'sets': 3,
                  'reps': {'min': 6, 'max': 8},
                  'restSeconds': {'upper': 150, 'lower': 180},
                  'rirFollowsMesocycle': true,
                  'warmup': true,
                },
              },
              'supersetRestSeconds': 120,
              'timeBudget': {
                'minutesPerSet': 3,
                'techniqueMinutes': {'drop_set': 1, 'myo_reps': 2},
              },
            },
          },
        ),
      );
      final t = kb.templates.single;
      expect(t.experience, ['over_2_years']);
      final blocks = t.sessions.single.blocks;
      expect(blocks[0].slots.single.lastSet, isNull);
      expect(blocks[1].slots.single.lastSet, 'drop_set');
      expect(blocks[2].slots.first.lastSet, 'failure');
      expect(kb.exercises['squat']!.heavyCompound, isTrue);
      expect(kb.exercises['curl']!.heavyCompound, isFalse);
      final p = kb.prescriptions.single;
      expect(p.experience, ['over_2_years']);
      expect(p.techniqueMinutes, {'drop_set': 1, 'myo_reps': 2});
      expect(kb.gymTypes['dumbbells'], ['dumbbells']);
    });

    test('senza i campi nuovi valgono i predefiniti', () {
      final kb = KnowledgeBase.fromJson(minimalBundle());
      expect(kb.templates.single.experience, isEmpty);
      expect(kb.prescriptions.single.experience, isEmpty);
      expect(kb.prescriptions.single.techniqueMinutes, isEmpty);
      expect(
        kb.templates.single.sessions.single.blocks.single.slots.single.lastSet,
        isNull,
      );
      expect(kb.exercises['squat']!.heavyCompound, isFalse);
    });
  });

  group('regole delle tecniche dell\'ultima serie', () {
    test('un valore sconosciuto di lastSet', () {
      expect(
        () => KnowledgeBase.fromJson(
          _bundle([_single(_slot('accessory', lastSet: 'rest_pause'))]),
        ),
        _rejects('templates.adv.sessions[0].blocks[0].slots[0].lastSet'),
      );
    });

    test('lastSet vietato su role main', () {
      expect(
        () => KnowledgeBase.fromJson(
          _bundle([_single(_slot('main', lastSet: 'failure'))]),
        ),
        _rejects(
          'templates.adv.lower_a.blocks[0].slots[0].lastSet: vietato '
          'su role main',
        ),
      );
    });

    test('drop_set e myo_reps solo su accessory', () {
      for (final technique in ['drop_set', 'myo_reps']) {
        expect(
          () => KnowledgeBase.fromJson(
            _bundle([_single(_slot('secondary', lastSet: technique))]),
          ),
          _rejects(
            'templates.adv.lower_a.blocks[0].slots[0].lastSet: '
            '$technique solo su role accessory',
          ),
        );
      }
    });

    test('drop_set e myo_reps solo in un blocco single', () {
      expect(
        () => KnowledgeBase.fromJson(
          _bundle([
            _superset([
              _slot('accessory', lastSet: 'myo_reps'),
              _slot('accessory'),
            ]),
          ]),
        ),
        _rejects(
          'templates.adv.lower_a.blocks[0].slots[0].lastSet: '
          'myo_reps solo in un blocco single',
        ),
      );
    });

    test('al più maxTechniquesPerSession drop_set e myo_reps per seduta', () {
      final blocks = [
        _single(_slot('accessory', lastSet: 'drop_set')),
        _single(_slot('accessory', lastSet: 'myo_reps')),
        _single(_slot('accessory', lastSet: 'failure')),
      ];
      expect(
        () => KnowledgeBase.fromJson(_bundle(blocks)),
        _rejects(
          'templates.adv.lower_a: 2 slot con drop_set o myo_reps, '
          'al più 1',
        ),
      );
      expect(
        () => KnowledgeBase.fromJson(_bundle(blocks, maxTechniques: 2)),
        returnsNormally,
      );
    });

    test('drop_set o myo_reps senza il tetto nella KB', () {
      expect(
        () => KnowledgeBase.fromJson(
          _bundle([
            _single(_slot('accessory', lastSet: 'drop_set')),
          ], maxTechniques: null),
        ),
        _rejects(
          'parameters.intensityTechniques.engineConstraints.'
          'maxTechniquesPerSession',
        ),
      );
    });

    test('lastSet vietato se il primo disponibile per una palestra è '
        'heavyCompound', () {
      // Palestra full: squat (pesante); palestra dumbbells: curl.
      expect(
        () => KnowledgeBase.fromJson(
          _bundle([
            _single(
              _slot(
                'secondary',
                lastSet: 'failure',
                candidates: ['squat', 'curl'],
              ),
            ),
          ]),
        ),
        _rejects(
          'templates.adv.lower_a.blocks[0].slots[0].lastSet: il primo '
          'candidato per la palestra full (squat) è heavyCompound',
        ),
      );
      // Un pesante che nessuna palestra sceglie per primo non conta.
      expect(
        () => KnowledgeBase.fromJson(
          _bundle([
            _single(
              _slot(
                'secondary',
                lastSet: 'failure',
                candidates: ['leg_press', 'curl', 'squat'],
              ),
            ),
          ]),
        ),
        returnsNormally,
      );
    });
  });
}
