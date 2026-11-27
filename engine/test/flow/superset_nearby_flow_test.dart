/// Vicinanza degli attrezzi nei superset (P-SUPERSET-NEARBY, KB 0.36.0) con
/// la KB vera: in palestra completa ogni superset dei piani generati si fa
/// nello stesso posto (cavo con cavo, bilanciere con bilanciere, multipower
/// con multipower, o un esercizio con i manubri).
library;

import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

late KnowledgeBase _kb;

/// La stessa KB senza `supersetProximity`: la scelta di prima.
late KnowledgeBase _plainKb;
late Map<String, List<String>> _equipmentByGym;

Map<String, Object?> _profile({
  required int days,
  required String experience,
  required int duration,
  required String goal,
  required String gym,
  required int seed,
}) => {
  'schemaVersion': days == 6 ? '1.6' : '1.3',
  'goal': goal,
  'gym': {
    'type': gym,
    'equipment': _equipmentByGym[gym],
    'barKg': 20,
    'platesKg': [25, 20, 15, 10, 5, 2.5, 1.25],
  },
  'daysPerWeek': days,
  'sessionDurationMin': duration,
  'experience': experience,
  'knownLoads': <Object?>[],
  'variantSeed': seed,
};

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    _kb = KnowledgeBase.fromJson(built.json);
    final plain = Map<String, Object?>.of(built.json);
    final equipment = Map<String, Object?>.of(
      plain['equipment']! as Map<String, Object?>,
    )..remove('supersetProximity');
    plain['equipment'] = equipment;
    _plainKb = KnowledgeBase.fromJson(plain);
    final vocab = loadYaml(
      File('../kb/vocab/equipment.yaml').readAsStringSync(),
    ) as YamlMap;
    _equipmentByGym = {
      for (final e in (vocab['gymTypes'] as YamlMap).entries)
        e.key as String: [for (final x in e.value as YamlList) x as String],
    };
  });

  test('i superset lontani calano e il face pull non va con una macchina', () {
    final near = _farPairs(_kb);
    final before = _farPairs(_plainKb);
    expect(near.pairs, before.pairs);
    expect(near.pairs, greaterThan(0));
    // Restano solo le coppie senza un candidato equivalente vicino (per
    // esempio leg curl e leg extension, due macchine).
    expect(near.far.length, lessThan(before.far.length ~/ 2));
    expect(
      near.far.where((p) => p.contains('face_pull')),
      isEmpty,
      reason: near.far.join('\n'),
    );
    expect(
      before.far.where((p) => p.contains('face_pull')),
      isNotEmpty,
      reason: 'prima il face pull finiva con una macchina',
    );
  });
}

/// Le coppie dei superset con attrezzi lontani (secondo [_kb]) nei piani
/// generati con [kb] in palestra completa, e quanti superset ci sono.
({List<String> far, int pairs}) _farPairs(KnowledgeBase kb) {
  final far = <String>[];
  var pairs = 0;
  for (final experience in ['6_months_2_years', 'over_2_years']) {
    for (final days in [3, 4, 5, 6]) {
      if (days == 6 && experience != 'over_2_years') continue;
      for (final goal in ['muscle_gain', 'both', 'strength']) {
        for (final duration in [45, 60, 75, 90]) {
          for (var seed = 0; seed < 8; seed++) {
            final r = generatePlan(
              _profile(
                days: days,
                experience: experience,
                duration: duration,
                goal: goal,
                gym: 'full',
                seed: seed,
              ),
              kb,
            );
            if (r is! Generated) continue;
            for (final s in r.plan['sessions']! as List) {
              for (final b in (s as Map)['blocks'] as List) {
                final block = b as Map;
                if (block['type'] != 'superset') continue;
                final ex = [
                  for (final e in block['exercises'] as List)
                    _kb.exercises[(e as Map)['exerciseId']]!,
                ];
                pairs++;
                for (var i = 1; i < ex.length; i++) {
                  if (!_kb.nearby(ex[0], ex[i])) {
                    far.add('${s['id']}: ${ex[0].id} + ${ex[i].id}');
                  }
                }
              }
            }
          }
        }
      }
    }
  }
  return (far: far, pairs: pairs);
}
