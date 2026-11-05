import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:barbl_engine/src/bundle/eval_runner.dart';
import 'package:barbl_engine/src/version.dart';
import 'package:test/test.dart';

late KnowledgeBase kb;
final planSchema = File('../kb/contract/plan.schema.json');

Map<String, Object?> profile({
  String? gymType,
  List<String>? equipment,
  int? daysPerWeek,
  String? goal,
  int? sessionDurationMin,
  bool noKnownLoads = false,
  bool noGym = false,
}) {
  final json = jsonDecode(
    File('../kb/golden/profile-example.json').readAsStringSync(),
  ) as Map<String, Object?>;
  final gym = json['gym']! as Map<String, Object?>;
  if (gymType != null) gym['type'] = gymType;
  if (equipment != null) gym['equipment'] = equipment;
  if (daysPerWeek != null) json['daysPerWeek'] = daysPerWeek;
  if (goal != null) json['goal'] = goal;
  if (sessionDurationMin != null) {
    json['sessionDurationMin'] = sessionDurationMin;
  }
  if (noKnownLoads) json['knownLoads'] = <Object?>[];
  if (noGym) json.remove('gym');
  return json;
}

Map<String, Object?> plan(Map<String, Object?> profileJson) {
  final result = generatePlan(profileJson, kb);
  expect(result, isA<Generated>());
  final generated = (result as Generated).plan;
  expect(planSchemaErrors(generated, planSchema), isEmpty);
  return generated;
}

NotCovered notCovered(Map<String, Object?> profileJson) {
  final result = generatePlan(profileJson, kb);
  expect(result, isA<NotCovered>());
  return result as NotCovered;
}

Set<String> trialExercises(Map<String, Object?> p) {
  final out = <String>{};
  for (final s in p['sessions']! as List) {
    for (final b in (s as Map)['blocks'] as List) {
      for (final e in (b as Map)['exercises'] as List) {
        final m = e as Map;
        if ((m['initialLoad'] as Map)['source'] == 'trial_set') {
          out.add(m['exerciseId'] as String);
        }
      }
    }
  }
  return out;
}

Set<String> askLoadExercises(Map<String, Object?> p) {
  final out = <String>{};
  for (final s in p['sessions']! as List) {
    for (final b in (s as Map)['blocks'] as List) {
      for (final e in (b as Map)['exercises'] as List) {
        final m = e as Map;
        if (m['askLoad'] == true) out.add(m['exerciseId'] as String);
      }
    }
  }
  return out;
}

const _compoundPatterns = {
  'horizontal_push',
  'horizontal_pull',
  'vertical_push',
  'vertical_pull',
  'squat',
  'hinge',
  'lunge',
  'hip_extension',
};

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    kb = KnowledgeBase.fromJson(built.json);
  });

  test('i casi d\'oro passano', () {
    final cases = runEval(Directory('../kb'));
    expect(
      cases.where((c) => !c.passed).map((c) => '${c.id} ${c.failures}'),
      isEmpty,
    );
  });

  test('il caso 02 (3 giorni, full body) genera un piano valido', () {
    final json = jsonDecode(
      File('../kb/golden/profile-3d.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final p = plan(json);
    final sessions = (p['sessions']! as List).cast<Map>();
    expect(sessions, hasLength(3));
    expect(sessions.map((s) => s['focus']), everyElement('full_body'));
    expect(p['split'], 'full_body');
    final move = (p['parameters']! as Map)['move']! as Map;
    expect((move['minRestHours']! as Map)['fullBody'], 48);
    expect(move['shiftsWeek'], false);
  });

  test('3 giorni con home e dumbbells: nessuno slot vuoto', () {
    final base = jsonDecode(
      File('../kb/golden/profile-3d.json').readAsStringSync(),
    ) as Map<String, Object?>;
    for (final gym in [
      ('home', ['barbell', 'rack', 'bench', 'dumbbells']),
      ('dumbbells', ['dumbbells', 'bench']),
    ]) {
      final json = jsonDecode(jsonEncode(base)) as Map<String, Object?>;
      final jsonGym = json['gym']! as Map<String, Object?>;
      jsonGym['type'] = gym.$1;
      jsonGym['equipment'] = gym.$2;
      final p = plan(json);
      expect((p['sessions']! as List), hasLength(3));
    }
  });

  test('full, home e dumbbells danno tre piani validi e diversi', () {
    final full = plan(profile());
    final home = plan(
      profile(
        gymType: 'home',
        equipment: ['barbell', 'rack', 'bench', 'dumbbells'],
      ),
    );
    final dumbbells = plan(
      profile(gymType: 'dumbbells', equipment: ['dumbbells', 'bench']),
    );
    final encoded = {jsonEncode(full), jsonEncode(home), jsonEncode(dumbbells)};
    expect(encoded, hasLength(3));
  });

  test('forza a 5 giorni e 45 minuti a 3 e 4 giorni: ora coperti', () {
    for (final p in [
      profile(daysPerWeek: 5, goal: 'strength'),
      profile(daysPerWeek: 3, sessionDurationMin: 45),
      profile(sessionDurationMin: 45),
    ]) {
      expect(plan(p)['schemaVersion'], '3.0');
    }
  });

  test('una palestra senza attrezzi adatti resta non coperta', () {
    expect(
      notCovered(profile(equipment: ['cables'])).reason,
      NotCoveredReason.equipment,
    );
  });

  test('5 giorni a 45 minuti: piano completo in ogni palestra', () {
    for (final goal in ['muscle_gain', 'both']) {
      for (final gym in [
        (
          'full',
          <String>[
            'barbell',
            'rack',
            'bench',
            'dumbbells',
            'machines',
            'cables',
            'smith_machine',
          ],
        ),
        ('home', ['barbell', 'rack', 'bench', 'dumbbells']),
        ('dumbbells', ['dumbbells', 'bench']),
      ]) {
        final p = plan(
          profile(
            daysPerWeek: 5,
            goal: goal,
            sessionDurationMin: 45,
            gymType: gym.$1,
            equipment: gym.$2,
          ),
        );
        expect(p['split'], 'push_pull_legs');
        final sessions = (p['sessions']! as List).cast<Map>();
        expect(sessions, hasLength(5));
        for (final s in sessions) {
          expect(
            s['estimatedDurationMin'] as num,
            lessThanOrEqualTo(45),
            reason: '${gym.$1} ${s['id']}',
          );
          final exercises = [
            for (final b in s['blocks'] as List)
              ...(b as Map)['exercises'] as List,
          ];
          expect(exercises, isNotEmpty, reason: '${gym.$1} ${s['id']}');
        }
        expect((p['schedule']! as List), hasLength(5));
      }
    }
  });

  test('le sedute a 45 e 60 minuti stanno nella durata e non restano vuote',
      () {
    for (final days in [3, 4]) {
      for (final goal in ['muscle_gain', 'strength']) {
        for (final minutes in [45, 60]) {
          final p = plan(
            profile(daysPerWeek: days, goal: goal, sessionDurationMin: minutes),
          );
          for (final s in p['sessions']! as List) {
            final m = s as Map;
            expect(m['estimatedDurationMin'] as num, lessThanOrEqualTo(minutes),
                reason: '$days $goal $minutes ${m['id']}');
            // Si tolgono slot, non si svuota la seduta.
            final count = [
              for (final b in m['blocks'] as List)
                ...(b as Map)['exercises'] as List,
            ].length;
            expect(count, greaterThanOrEqualTo(3),
                reason: '$days $goal $minutes ${m['id']}');
          }
        }
      }
    }
  });

  test(
    'forza a 3 e 4 giorni da 75 minuti: piano completo in ogni palestra',
    () {
      for (final days in [3, 4]) {
        for (final gym in [
          (
            'full',
            <String>[
              'barbell',
              'rack',
              'bench',
              'dumbbells',
              'machines',
              'cables',
              'smith_machine',
            ],
          ),
          ('home', ['barbell', 'rack', 'bench', 'dumbbells']),
          ('dumbbells', ['dumbbells', 'bench']),
        ]) {
          final p = plan(
            profile(
              daysPerWeek: days,
              goal: 'strength',
              sessionDurationMin: 75,
              gymType: gym.$1,
              equipment: gym.$2,
            ),
          );
          expect(p['goal'], 'strength');
          expect((p['sessions']! as List), hasLength(days));
          for (final s in p['sessions']! as List) {
            expect(
              (s as Map)['estimatedDurationMin'] as num,
              lessThanOrEqualTo(75),
            );
          }
        }
      }
    },
  );

  test('forza: il principale ha ripetizioni più basse della massa', () {
    int benchRepsMin(Map<String, Object?> p) {
      for (final s in p['sessions']! as List) {
        for (final b in (s as Map)['blocks'] as List) {
          for (final e in (b as Map)['exercises'] as List) {
            final m = e as Map;
            if (m['exerciseId'] == 'barbell_bench_press') {
              return ((m['reps'] as Map)['min'] as num).toInt();
            }
          }
        }
      }
      throw StateError('panca assente');
    }

    final strength = plan(profile(goal: 'strength', sessionDurationMin: 75));
    final muscle = plan(profile(sessionDurationMin: 75));
    expect(benchRepsMin(strength), lessThan(benchRepsMin(muscle)));
  });

  test('both resta sulla prescrizione della massa', () {
    for (final days in [3, 4]) {
      final both = plan(profile(daysPerWeek: days, goal: 'both'));
      final muscle = plan(profile(daysPerWeek: days, goal: 'muscle_gain'));
      both['goal'] = muscle['goal'];
      expect(jsonEncode(both), jsonEncode(muscle));
    }
  });

  test('forza senza carichi noti: la prova resta ammessa per gli askLoad', () {
    final p = plan(
      profile(goal: 'strength', sessionDurationMin: 75, noKnownLoads: true),
    );
    expect(trialExercises(p), {
      'barbell_bench_press',
      'military_press',
      'squat',
    });
  });

  test('un piano senza enfasi non ha la motivazione EMPHASIS', () {
    final p = plan(profile());
    final ruleIds = [
      for (final r in p['rationales']! as List) (r as Map)['ruleId'],
    ];
    expect(ruleIds, isNot(contains('EMPHASIS')));
    expect(ruleIds, hasLength(kb.rationales.length - 1));
  });

  test('un profilo senza gym è non valido', () {
    expect(generatePlan(profile(noGym: true), kb), isA<InvalidProfile>());
  });

  test('senza carichi noti la prova è solo degli slot che la ammettono', () {
    final p = plan(profile(noKnownLoads: true));
    expect(trialExercises(p), {
      'barbell_bench_press',
      'military_press',
      'squat',
    });
  });

  test(
    'piano 3.0: i quattro esercizi chiave hanno askLoad e nome {it, en}',
    () {
      final p = plan(profile());
      expect(p['schemaVersion'], '3.0');
      expect(askLoadExercises(p), {
        'barbell_bench_press',
        'dumbbell_row',
        'military_press',
        'squat',
      });
      for (final s in p['sessions']! as List) {
        for (final b in (s as Map)['blocks'] as List) {
          for (final e in (b as Map)['exercises'] as List) {
            final name = (e as Map)['name'] as Map;
            expect(name.keys, containsAll(['it', 'en']));
          }
        }
      }
    },
  );

  test('stesso profilo e KB ricostruita due volte danno lo stesso JSON', () {
    String once() {
      final built = buildBundle(Directory('../kb'));
      expect(built.errors, isEmpty);
      final fresh = KnowledgeBase.fromJson(built.json);
      final result = generatePlan(profile(), fresh);
      return jsonEncode((result as Generated).plan);
    }

    expect(once(), once());
  });

  test('senza attrezzatura sufficiente il profilo non è coperto', () {
    expect(
      notCovered(profile(equipment: ['bench'])).reason,
      NotCoveredReason.equipment,
    );
  });

  test(
    'le alternative sono sostituti della KB, eseguibili e fuori dalla seduta',
    () {
      var total = 0;
      for (final gym in [
        (
          'full',
          <String>[
            'barbell',
            'rack',
            'bench',
            'dumbbells',
            'machines',
            'cables',
            'smith_machine',
          ],
        ),
        ('home', ['barbell', 'rack', 'bench', 'dumbbells']),
        ('dumbbells', ['dumbbells', 'bench']),
      ]) {
        final p = plan(profile(gymType: gym.$1, equipment: gym.$2));
        for (final s in p['sessions']! as List) {
          final inSession = <String>{
            for (final b in (s as Map)['blocks'] as List)
              for (final e in (b as Map)['exercises'] as List)
                (e as Map)['exerciseId'] as String,
          };
          for (final b in s['blocks'] as List) {
            for (final e in (b as Map)['exercises'] as List) {
              final m = e as Map;
              final alts = (m['alternatives'] as List?) ?? const [];
              final allowed = kb.exercises[m['exerciseId']]!.substitutes;
              for (final a in alts.cast<Map>()) {
                total++;
                final id = a['exerciseId'] as String;
                expect(allowed, contains(id), reason: '${m['exerciseId']}');
                expect(inSession, isNot(contains(id)));
                expect(
                  kb.exercises[id]!.requires.every(gym.$2.contains),
                  isTrue,
                  reason: '$id in ${gym.$1}',
                );
                expect(a['initialLoad'], {'kg': null, 'source': 'manual'});
              }
            }
          }
        }
      }
      expect(total, greaterThan(0));
    },
  );

  group('varietà dei piani', () {
    Set<String> ids(Map<String, Object?> p) => {
      for (final s in p['sessions']! as List)
        for (final b in (s as Map)['blocks'] as List)
          for (final e in (b as Map)['exercises'] as List)
            (e as Map)['exerciseId'] as String,
    };

    test(
      'stesso profilo, stesso piano; i carichi noti non cambiano gli esercizi',
      () {
        final a = plan(profile());
        expect(plan(profile()), a);
        expect(ids(plan(profile(noKnownLoads: true))), ids(a));
      },
    );

    test(
      'il seme dà piani diversi e validi; lo stesso seme lo stesso piano',
      () {
        Map<String, Object?> seeded(int seed, {String goal = 'muscle_gain'}) =>
            plan(
              profile(goal: goal)
                ..['variantSeed'] = seed
                ..['schemaVersion'] = '1.3',
            );
        final plans = {
          for (var i = 0; i < 12; i++) ids(seeded(i)).toList().join(','),
        };
        expect(plans.length, greaterThan(4));
        expect(ids(seeded(7)), ids(seeded(7)));
      },
    );

    test('per la forza il seme cambia solo l\'isolamento', () {
      Set<String> mainIds(Map<String, Object?> p) => {
        for (final s in p['sessions']! as List)
          for (final b in (s as Map)['blocks'] as List)
            for (final e in (b as Map)['exercises'] as List)
              if (_compoundPatterns.contains(
                kb.exercises[(e as Map)['exerciseId']]!.pattern,
              ))
                e['exerciseId'] as String,
      };
      final base = mainIds(
        plan(profile(goal: 'strength', sessionDurationMin: 75)),
      );
      for (var i = 0; i < 8; i++) {
        final p = plan(
          profile(goal: 'strength', sessionDurationMin: 75)
            ..['variantSeed'] = i
            ..['schemaVersion'] = '1.3',
        );
        expect(mainIds(p), base);
      }
    });

    test('un seme non valido è rifiutato', () {
      for (final bad in <Object>[-1, 2147483648, 1.5, '3']) {
        final result = generatePlan(profile()..['variantSeed'] = bad, kb);
        expect(result, isA<InvalidProfile>());
      }
    });

    test('profili diversi possono avere esercizi di isolamento diversi', () {
      final seen = <String>{};
      for (final level in const [
        'under_6_months',
        '6_months_2_years',
        'over_2_years',
      ]) {
        for (final days in const [3, 4, 5]) {
          final json = profile(daysPerWeek: days, goal: 'muscle_gain')
            ..['experience'] = level;
          seen.add(ids(plan(json)).toList().join(','));
        }
      }
      expect(seen.length, greaterThan(3));
      // Dentro un piano gli esercizi restano quelli del pool dichiarato.
      final all = ids(plan(profile()));
      expect(all.where(kb.exercises.containsKey).length, all.length);
    });
  });

  test('engineVersion coincide con la versione di pubspec.yaml', () {
    final text = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(
      r'^version:\s*(\S+)\s*$',
      multiLine: true,
    ).firstMatch(text);
    expect(match, isNotNull);
    expect(engineVersion, match!.group(1));
  });
}
