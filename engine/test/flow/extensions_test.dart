/// Estensioni, riscaldamento e principianti con la KB vera, sulla matrice dei
/// profili: nessuna seduta oltre la durata, nessun muscolo oltre il tetto,
/// più tempo non dà meno lavoro, i principianti.
library;

import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:test/test.dart';

late KnowledgeBase kb;
late Map<String, Object?> kbJson;

const _gyms = <String, List<String>>{
  'full': [
    'barbell',
    'rack',
    'bench',
    'dumbbells',
    'machines',
    'cables',
    'smith_machine',
    'pull_up_bar',
    'dip_station',
  ],
  'home': ['barbell', 'rack', 'bench', 'dumbbells'],
  'dumbbells': ['dumbbells', 'bench'],
};

Map<String, Object?> _profile({
  required String goal,
  required String gym,
  required int days,
  required int minutes,
  String experience = '6_months_2_years',
}) => {
  'schemaVersion': '1.1',
  'goal': goal,
  'gym': {
    'type': gym,
    'equipment': _gyms[gym],
    'barKg': 20,
    'platesKg': [25, 20, 15, 10, 5, 2.5, 1.25],
  },
  'daysPerWeek': days,
  'sessionDurationMin': minutes,
  'experience': experience,
  'knownLoads': <Object?>[],
};

Map<String, Object?> _plan(Map<String, Object?> profile) {
  final r = generatePlan(profile, kb);
  expect(r, isA<Generated>(), reason: jsonEncode(profile));
  return (r as Generated).plan;
}

Iterable<Map<String, Object?>> _exercises(Map<String, Object?> plan) sync* {
  for (final s in plan['sessions']! as List) {
    for (final b in (s as Map)['blocks'] as List) {
      for (final e in (b as Map)['exercises'] as List) {
        yield (e as Map).cast<String, Object?>();
      }
    }
  }
}

Map<String, double> _volume(Map<String, Object?> plan) {
  final totals = <String, double>{};
  for (final e in _exercises(plan)) {
    final muscles = e['muscles']! as List;
    for (var i = 0; i < muscles.length; i++) {
      final key = muscles[i] as String;
      final weight = i == 0 ? kb.primaryWeight : kb.secondaryWeight;
      totals[key] = (totals[key] ?? 0) + (e['sets']! as num) * weight;
    }
  }
  return totals;
}

int _extensions(Map<String, Object?> plan) =>
    _exercises(plan)
        .where((e) => (e['rules']! as List).contains(extensionRuleId))
        .length;

int _sets(Map<String, Object?> plan) =>
    _exercises(plan).fold(0, (a, e) => a + (e['sets']! as num).toInt());

const _durations = [45, 60, 75, 90];
const _goals = ['muscle_gain', 'strength', 'both'];

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    kbJson = built.json;
    kb = KnowledgeBase.fromJson(built.json);
  });

  group('estensioni sulla matrice', () {
    for (final goal in _goals) {
      for (final gym in _gyms.keys) {
        for (final days in const [3, 4, 5]) {
          test('$goal, $gym, $days giorni', () {
            Map<String, Object?>? previous;
            for (final minutes in _durations) {
              final plan = _plan(
                _profile(goal: goal, gym: gym, days: days, minutes: minutes),
              );
              final where = '$minutes min';
              for (final s in plan['sessions']! as List) {
                expect(
                  (s as Map)['estimatedDurationMin'] as int,
                  lessThanOrEqualTo(minutes),
                  reason: '$where, ${s['id']}',
                );
              }
              final cap = kb.weeklyVolumeCap!;
              _volume(plan).forEach((muscle, v) {
                expect(v, lessThanOrEqualTo(cap), reason: '$where, $muscle');
              });
              if (previous != null) {
                expect(
                  _sets(plan),
                  greaterThanOrEqualTo(_sets(previous)),
                  reason: 'serie a $where',
                );
                expect(
                  _extensions(plan),
                  greaterThanOrEqualTo(_extensions(previous)),
                  reason: 'estensioni a $where',
                );
              }
              previous = plan;
            }
          });
        }
      }
    }

    test('con 75 e 90 minuti il piano usa il tempo in più', () {
      for (final goal in const ['muscle_gain', 'both']) {
        for (final days in const [3, 4]) {
          final at60 = _plan(
            _profile(goal: goal, gym: 'full', days: days, minutes: 60),
          );
          final at90 = _plan(
            _profile(goal: goal, gym: 'full', days: days, minutes: 90),
          );
          expect(_sets(at90), greaterThan(_sets(at60)), reason: '$goal $days');
        }
      }
    });

    test('a 60 minuti spalle e polpacci hanno il loro lavoro', () {
      final four = _volume(
        _plan(_profile(goal: 'muscle_gain', gym: 'full', days: 4, minutes: 60)),
      );
      final three = _volume(
        _plan(_profile(goal: 'muscle_gain', gym: 'full', days: 3, minutes: 60)),
      );
      expect(four['shoulders'], greaterThanOrEqualTo(6));
      expect(three['shoulders'], greaterThanOrEqualTo(6));
      expect(three['calves'], greaterThanOrEqualTo(3));
      // Il finisher facoltativo non toglie tempo alle estensioni
      // (`countsTowardDuration: false`, `P-CORE-FINISHER`).
      expect(four['abs'], 4);
      expect(three['abs'], 4);
    });

    test('il finisher c\'è a ogni durata, ultimo, e non conta nel tempo', () {
      for (final goal in _goals) {
        for (final gym in _gyms.keys) {
          for (final days in const [3, 4, 5]) {
            for (final minutes in _durations) {
              final plan = _plan(
                _profile(goal: goal, gym: gym, days: days, minutes: minutes),
              );
              final where = '$goal $gym $days giorni $minutes min';
              var finishers = 0;
              for (final s in plan['sessions']! as List) {
                final exercises = [
                  for (final b in (s as Map)['blocks'] as List)
                    for (final e in (b as Map)['exercises'] as List)
                      (e as Map).cast<String, Object?>(),
                ];
                final optional = [
                  for (var k = 0; k < exercises.length; k++)
                    if (exercises[k]['optional'] == true) k,
                ];
                finishers += optional.length;
                if (optional.isNotEmpty) {
                  expect(optional, [exercises.length - 1], reason: where);
                }
                // La durata stimata conta solo gli esercizi non facoltativi.
                final timed = exercises
                    .where((e) => e['optional'] != true)
                    .fold<int>(0, (a, e) => a + (e['sets']! as num).toInt());
                expect(
                  s['estimatedDurationMin'],
                  timed *
                      kb.prescriptions
                          .firstWhere((p) => p.appliesTo.contains(goal))
                          .minutesPerSet,
                  reason: where,
                );
              }
              expect(finishers, 2, reason: where);
            }
          }
        }
      }
    });

    test('le estensioni portano la regola e la motivazione, solo se usate', () {
      for (final minutes in _durations) {
        final plan = _plan(
          _profile(goal: 'muscle_gain', gym: 'full', days: 4, minutes: minutes),
        );
        final ids = [
          for (final r in plan['rationales']! as List) (r as Map)['ruleId'],
        ];
        expect(
          ids.contains(extensionRuleId),
          _extensions(plan) > 0,
          reason: '$minutes min',
        );
      }
    });

    test('con 45 minuti non si aggiunge nulla: il piano è quello di prima', () {
      final plan = _plan(
        _profile(goal: 'muscle_gain', gym: 'full', days: 4, minutes: 45),
      );
      expect(_extensions(plan), 0);
    });
  });

  group('riscaldamento sui multiarticolari', () {
    test('principale sempre; complementare solo il primo del pattern', () {
      for (final goal in _goals) {
        for (final days in const [3, 4, 5]) {
          final plan = _plan(
            _profile(goal: goal, gym: 'full', days: days, minutes: 60),
          );
          for (final s in plan['sessions']! as List) {
            final seen = <String>{};
            for (final b in (s as Map)['blocks'] as List) {
              for (final e in (b as Map)['exercises'] as List) {
                final ex = kb.exercises[(e as Map)['exerciseId']]!;
                final first = seen.add(ex.pattern);
                final rules = e['rules']! as List;
                final added =
                    rules.contains(extensionRuleId) ||
                    rules.contains(emphasisRuleId);
                final where = '$goal $days giorni ${s['id']} ${ex.id}';
                if (!ex.isCompound) {
                  expect(e['warmup'], isFalse, reason: where);
                } else if (!added) {
                  // Multiarticolare del template: il primo del pattern ha il
                  // riscaldamento (principale o complementare), i successivi no.
                  expect(e['warmup'], first, reason: where);
                }
              }
            }
          }
        }
      }
    });

    test('un complementare multiarticolare ha il riscaldamento', () {
      final plan = _plan(
        _profile(goal: 'muscle_gain', gym: 'full', days: 4, minutes: 60),
      );
      final withWarmup = _exercises(plan)
          .where((e) => e['warmup'] == true)
          .map((e) => e['exerciseId'])
          .toList();
      expect(withWarmup.length, greaterThan(4));
      expect(withWarmup, contains('barbell_bench_press'));
    });
  });

  group('principianti', () {
    test('il RIR non scende sotto 2 nelle settimane di carico', () {
      for (final goal in _goals) {
        final plan = _plan(
          _profile(
            goal: goal,
            gym: 'full',
            days: 4,
            minutes: 60,
            experience: 'under_6_months',
          ),
        );
        final rirs = [
          for (final w in (plan['mesocycle']! as Map)['weeks'] as List)
            (w as Map)['rirTarget'],
        ];
        expect(rirs, [3, 3, 2, 2, 4], reason: goal);
      }
    });

    test('chi ha più esperienza ha il mesociclo di prima', () {
      for (final level in const ['6_months_2_years', 'over_2_years']) {
        final plan = _plan(
          _profile(
            goal: 'muscle_gain',
            gym: 'full',
            days: 4,
            minutes: 60,
            experience: level,
          ),
        );
        final rirs = [
          for (final w in (plan['mesocycle']! as Map)['weeks'] as List)
            (w as Map)['rirTarget'],
        ];
        expect(rirs, [3, 3, 2, 1, 4], reason: level);
      }
    });

    test('nessun esercizio impegnativo se l\'attrezzatura offre altro', () {
      for (final goal in _goals) {
        for (final gym in _gyms.keys) {
          for (final days in const [3, 4, 5]) {
            for (final minutes in _durations) {
              final plan = _plan(
                _profile(
                  goal: goal,
                  gym: gym,
                  days: days,
                  minutes: minutes,
                  experience: 'under_6_months',
                ),
              );
              final high = [
                for (final e in _exercises(plan))
                  if (kb.exercises[e['exerciseId']]!.technicalDemandHigh)
                    e['exerciseId'],
              ];
              expect(
                high,
                isEmpty,
                reason: '$goal $gym $days giorni $minutes min',
              );
            }
          }
        }
      }
    });
  });
}
