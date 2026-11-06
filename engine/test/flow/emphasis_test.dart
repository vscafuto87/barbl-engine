/// Enfasi con la KB vera: piani senza enfasi invariati, piani con enfasi
/// validi, durata rispettata, ordine stabile, palestra a soli manubri.
library;

import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:barbl_engine/src/bundle/eval_runner.dart';
import 'package:test/test.dart';

late KnowledgeBase kb;

/// La stessa KB senza enfasi e senza la motivazione EMPHASIS: dà i piani di
/// prima dell'enfasi.
late KnowledgeBase kbWithoutEmphasis;
final planSchema = File('../kb/contract/plan.schema.json');

const List<String> _full = [
  'barbell',
  'rack',
  'bench',
  'dumbbells',
  'machines',
  'cables',
  'smith_machine',
];
const List<String> _dumbbells = ['dumbbells', 'bench'];

Map<String, Object?> _golden(String name) =>
    jsonDecode(File('../kb/golden/$name').readAsStringSync())
        as Map<String, Object?>;

Map<String, Object?> profile({
  int days = 5,
  int minutes = 60,
  String goal = 'muscle_gain',
  String gymType = 'full',
  List<String> equipment = _full,
  List<String>? emphasis,
}) {
  final json = _golden('profile-5d-45min.json');
  json['daysPerWeek'] = days;
  json['sessionDurationMin'] = minutes;
  json['goal'] = goal;
  final gym = json['gym']! as Map<String, Object?>;
  gym['type'] = gymType;
  gym['equipment'] = equipment;
  if (emphasis != null) {
    json['schemaVersion'] = '1.2';
    json['emphasis'] = emphasis;
  }
  return json;
}

Map<String, Object?> plan(Map<String, Object?> profileJson) {
  final result = generatePlan(profileJson, kb);
  expect(result, isA<Generated>());
  final generated = (result as Generated).plan;
  expect(planSchemaErrors(generated, planSchema), isEmpty);
  return generated;
}

/// Esercizi aggiunti per enfasi (con la regola EMPHASIS), per seduta.
Map<String, List<String>> emphasisExercises(Map<String, Object?> p) {
  final out = <String, List<String>>{};
  for (final s in p['sessions']! as List) {
    final m = s as Map;
    for (final b in m['blocks'] as List) {
      for (final e in (b as Map)['exercises'] as List) {
        final ex = e as Map;
        if ((ex['rules'] as List).contains('EMPHASIS')) {
          out
              .putIfAbsent(m['id'] as String, () => [])
              .add(ex['exerciseId'] as String);
        }
      }
    }
  }
  return out;
}

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    kb = KnowledgeBase.fromJson(built.json);
    final without = Map<String, Object?>.of(built.json)..remove('emphasis');
    without['rationales'] = Map<String, Object?>.of(
      built.json['rationales']! as Map<String, Object?>,
    )..remove('EMPHASIS');
    kbWithoutEmphasis = KnowledgeBase.fromJson(without);
    expect(kbWithoutEmphasis.emphases, isEmpty);
  });

  test('senza enfasi il piano è identico a quello di una KB senza enfasi', () {
    for (final name in [
      'profile-example.json',
      'profile-3d.json',
      'profile-4d-strength.json',
      'profile-5d-45min.json',
    ]) {
      final json = _golden(name);
      final before = generatePlan(json, kbWithoutEmphasis);
      final now = generatePlan(json, kb);
      expect(before, isA<Generated>(), reason: name);
      expect(now, isA<Generated>(), reason: name);
      final expected = jsonEncode((before as Generated).plan);
      expect(jsonEncode((now as Generated).plan), expected, reason: name);

      // Profilo 1.2 con emphasis vuota: stesso piano.
      final empty = _golden(name)
        ..['schemaVersion'] = '1.2'
        ..['emphasis'] = <Object?>[];
      final withEmpty = generatePlan(empty, kb) as Generated;
      expect(jsonEncode(withEmpty.plan), expected, reason: name);
    }
  });

  test('5 giorni da 60 minuti, glutei e femorali più braccia', () {
    final p = plan(profile(emphasis: ['glutes_hamstrings', 'arms']));
    expect(emphasisExercises(p), {
      'upper': ['overhead_cable_triceps_extension'],
      'pull': ['dumbbell_curl'],
      'legs': ['barbell_hip_thrust'],
    });
    for (final s in p['sessions']! as List) {
      expect((s as Map)['estimatedDurationMin'] as num, lessThanOrEqualTo(60));
    }
    final ruleIds = [
      for (final r in p['rationales']! as List) (r as Map)['ruleId'],
    ];
    expect(ruleIds, contains('EMPHASIS'));
  });

  test('sedute già piene a 45 minuti: nessuna eccezione, nessuna enfasi', () {
    for (final emphasis in [
      ['glutes_hamstrings'],
      ['shoulders'],
      ['arms'],
      ['glutes_hamstrings', 'arms'],
    ]) {
      final p = plan(profile(minutes: 45, emphasis: emphasis));
      for (final s in p['sessions']! as List) {
        expect(
          (s as Map)['estimatedDurationMin'] as num,
          lessThanOrEqualTo(45),
        );
      }
      expect(emphasisExercises(p), isEmpty, reason: '$emphasis');
      final ruleIds = [
        for (final r in p['rationales']! as List) (r as Map)['ruleId'],
      ];
      expect(ruleIds, isNot(contains('EMPHASIS')));
    }
  });

  test('due enfasi sulla stessa seduta: ordine del profilo e durata', () {
    // Upper (15 serie) ha un posto per le spalle e uno per le braccia: a 60
    // minuti ne entra uno solo, il primo nell'ordine del profilo.
    final a = plan(profile(emphasis: ['shoulders', 'arms']));
    expect(emphasisExercises(a)['upper'], ['dumbbell_rear_delt_fly']);
    final b = plan(profile(emphasis: ['arms', 'shoulders']));
    expect(emphasisExercises(b)['upper'], ['overhead_cable_triceps_extension']);
    // A 75 minuti entrano entrambi, nello stesso ordine.
    final c = plan(profile(minutes: 75, emphasis: ['arms', 'shoulders']));
    expect(emphasisExercises(c)['upper'], [
      'overhead_cable_triceps_extension',
      'dumbbell_rear_delt_fly',
    ]);
    for (final s in c['sessions']! as List) {
      expect((s as Map)['estimatedDurationMin'] as num, lessThanOrEqualTo(75));
    }
  });

  test('palestra a soli manubri: ogni posto ha un esercizio disponibile', () {
    final templateByDays = {for (final t in kb.templates) t.daysPerWeek: t.id};
    for (final days in [3, 4, 5]) {
      for (final emphasis in kb.emphases.keys) {
        final p = plan(
          profile(
            days: days,
            minutes: 90,
            gymType: 'dumbbells',
            equipment: _dumbbells,
            emphasis: [emphasis],
          ),
        );
        final placements =
            kb.emphases[emphasis]!.placements[templateByDays[days]]!;
        final added = emphasisExercises(p);
        // Eccezioni: con i soli manubri la seduta ha già tutti gli esercizi
        // disponibili del posto, e l'enfasi non li ripete.
        final skipped =
            const {
              '4 back': {'upper_a', 'upper_b'},
              '5 back': {'pull', 'upper'},
            }['$days $emphasis'] ??
            const <String>{};
        expect(
          added.values.expand((e) => e),
          hasLength(placements.length - skipped.length),
          reason: '$days $emphasis',
        );
        expect(added.keys.toSet(), {
          for (final pl in placements)
            if (!skipped.contains(pl.session)) pl.session,
        });
        for (final id in added.values.expand((e) => e)) {
          expect(
            kb.exercises[id]!.requires.every(_dumbbells.contains),
            isTrue,
            reason: '$days $emphasis $id',
          );
        }
      }
    }
  });

  test('forza: l\'enfasi usa la prescrizione dell\'obiettivo', () {
    final p = plan(
      profile(days: 4, minutes: 90, goal: 'strength', emphasis: ['arms']),
    );
    expect(emphasisExercises(p), {
      'upper_a': ['cable_curl'],
      'upper_b': ['overhead_cable_triceps_extension'],
    });
    final accessory = kb.prescriptions
        .singleWhere((x) => x.id == 'strength')
        .roles['accessory']!;
    for (final s in p['sessions']! as List) {
      for (final b in (s as Map)['blocks'] as List) {
        for (final e in (b as Map)['exercises'] as List) {
          final ex = e as Map;
          if (!(ex['rules'] as List).contains('EMPHASIS')) continue;
          expect(ex['sets'], accessory.sets);
          expect((ex['reps'] as Map)['min'], accessory.repsMin);
          expect((ex['reps'] as Map)['max'], accessory.repsMax);
        }
      }
      expect((s['estimatedDurationMin']) as num, lessThanOrEqualTo(90));
    }
  });

  test('l\'enfasi non ripete un esercizio della seduta', () {
    const gyms = {
      'full': _full,
      'home': ['barbell', 'rack', 'bench', 'dumbbells'],
      'dumbbells': _dumbbells,
    };
    final dup = <String>[];
    for (final days in [3, 4, 5]) {
      for (final gym in gyms.entries) {
        for (final emphasis in kb.emphases.keys) {
          for (final seed in [null, 1, 2, 3]) {
            final json = profile(
              days: days,
              minutes: 90,
              gymType: gym.key,
              equipment: gym.value,
              emphasis: [emphasis],
            );
            if (seed != null) {
              json['schemaVersion'] = '1.3';
              json['variantSeed'] = seed;
            }
            final p = plan(json);
            for (final s in p['sessions']! as List) {
              final all = <String>[];
              final added = <String>[];
              for (final b in (s as Map)['blocks'] as List) {
                for (final e in (b as Map)['exercises'] as List) {
                  final ex = e as Map;
                  final id = ex['exerciseId'] as String;
                  all.add(id);
                  if ((ex['rules'] as List).contains('EMPHASIS')) added.add(id);
                }
              }
              if (added.any((id) => all.where((x) => x == id).length > 1)) {
                dup.add(
                  '$days, ${gym.key}, $emphasis, $seed, ${s['id']}: $all',
                );
              }
            }
          }
        }
      }
    }
    expect(dup, isEmpty, reason: dup.join('\n'));
  });
}
