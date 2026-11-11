import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/generate/plan_parameters.dart';
import 'package:test/test.dart';

import '../support/minimal_bundle.dart';
import '../support/profiles.dart';

Map<String, Object?> _week(int number, String type, int rir) => {
  'number': number,
  'type': type,
  'rirTarget': rir,
};

KnowledgeBase _kb({Map<String, Object?>? minRir}) {
  final json = minimalBundle();
  ((json['parameters']! as Map)['mesocycle']!
      as Map)['values'] = <String, Object?>{
    'weeks': [
      _week(1, 'load', 3),
      _week(2, 'load', 3),
      _week(3, 'load', 2),
      _week(4, 'load', 1),
      _week(5, 'deload', 4),
    ],
    'minRirTargetByExperience': ?minRir,
  };
  return KnowledgeBase.fromJson(json);
}

List<Object?> _rirs(Map<String, Object?> mesocycle) => [
  for (final w in mesocycle['weeks']! as List) (w as Map)['rirTarget'],
];

void main() {
  group('buildMesocycle e il livello di esperienza', () {
    test('senza un minimo nella KB il mesociclo è quello della KB', () {
      final kb = _kb();
      for (final level in const [
        'under_6_months',
        '6_months_2_years',
        'over_2_years',
      ]) {
        final m = buildMesocycle(kb, testProfile(experience: level));
        expect(_rirs(m), [3, 3, 2, 1, 4], reason: level);
      }
    });

    test('chi ha meno di sei mesi non scende sotto il RIR minimo', () {
      final kb = _kb(minRir: {'under_6_months': 2});
      final m = buildMesocycle(kb, testProfile(experience: 'under_6_months'));
      // Le settimane di carico sotto il minimo salgono; lo scarico no.
      expect(_rirs(m), [3, 3, 2, 2, 4]);
    });

    test('gli altri livelli restano com\'erano', () {
      final kb = _kb(minRir: {'under_6_months': 2});
      for (final level in const ['6_months_2_years', 'over_2_years']) {
        final m = buildMesocycle(kb, testProfile(experience: level));
        expect(_rirs(m), [3, 3, 2, 1, 4], reason: level);
      }
    });

    test('un minimo più alto della settimana di scarico non la tocca', () {
      final kb = _kb(minRir: {'under_6_months': 5});
      final m = buildMesocycle(kb, testProfile(experience: 'under_6_months'));
      expect(_rirs(m), [5, 5, 5, 5, 4]);
    });

    test('il tipo e il numero delle settimane non cambiano', () {
      final kb = _kb(minRir: {'under_6_months': 2});
      final m = buildMesocycle(kb, testProfile(experience: 'under_6_months'));
      expect(
        [
          for (final w in m['weeks']! as List)
            ((w as Map)['number'], w['type']),
        ],
        [(1, 'load'), (2, 'load'), (3, 'load'), (4, 'load'), (5, 'deload')],
      );
    });
  });
}
