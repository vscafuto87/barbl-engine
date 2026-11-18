/// Piano a 6 giorni per il livello avanzato (KB 0.33.0, template
/// `advanced_ppl_6d`) con la KB vera: sei sedute Push / Pull / Gambe × 2 da
/// lunedì a sabato, le regole dei piani avanzati e nessun muscolo primario in
/// due giorni consecutivi. Chi non è avanzato non è coperto.
library;

import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:barbl_engine/src/bundle/eval_runner.dart';
import 'package:test/test.dart';
import 'package:yaml/yaml.dart';

const String _templateId = 'advanced_ppl_6d';
const List<String> _sessionIds = [
  'push_a',
  'pull_a',
  'legs_a',
  'push_b',
  'pull_b',
  'legs_b',
];
const List<String> _weekDays = [
  'mon',
  'tue',
  'wed',
  'thu',
  'fri',
  'sat',
  'sun',
];
const List<int> _durations = [45, 60, 75, 90];
const List<String> _goals = ['muscle_gain', 'both', 'strength'];
const List<String> _gyms = ['full', 'home', 'dumbbells'];

/// Muscoli con la fascia di volume controllata (massa ed entrambi).
const List<String> _bandMuscles = [
  'chest',
  'back',
  'shoulders',
  'quadriceps',
  'hamstrings',
  'glutes',
  'biceps',
  'triceps',
];

late KnowledgeBase _kb;
late Map<String, List<String>> _equipmentByGym;
late num _bandMin;
late num _bandMax;
final File _planSchema = File('../kb/contract/plan.schema.json');

Map<String, Object?> _profile({
  String goal = 'muscle_gain',
  String gym = 'full',
  int duration = 60,
  String experience = 'over_2_years',
  int? variantSeed,
  List<String> emphasis = const [],
}) => {
  'schemaVersion': '1.6',
  'goal': goal,
  'gym': {
    'type': gym,
    'equipment': _equipmentByGym[gym],
    'barKg': 20,
    'platesKg': [25, 20, 15, 10, 5, 2.5, 1.25],
  },
  'daysPerWeek': 6,
  'sessionDurationMin': duration,
  'experience': experience,
  'knownLoads': <Object?>[],
  'variantSeed': ?variantSeed,
  if (emphasis.isNotEmpty) 'emphasis': emphasis,
};

Map<String, Object?> _plan(Map<String, Object?> profile) {
  final r = generatePlan(profile, _kb);
  expect(r, isA<Generated>(), reason: r is NotCovered ? r.detail : '$r');
  return (r as Generated).plan;
}

List<Map<String, Object?>> _sessions(Map<String, Object?> plan) => [
  for (final s in plan['sessions']! as List) s as Map<String, Object?>,
];

List<Map<String, Object?>> _exercisesOf(Map<String, Object?> session) => [
  for (final b in session['blocks']! as List)
    for (final e in (b as Map)['exercises'] as List) e as Map<String, Object?>,
];

Map<String, double> _weeklySets(Map<String, Object?> plan) {
  final out = <String, double>{};
  for (final s in _sessions(plan)) {
    for (final e in _exercisesOf(s)) {
      final sets = (e['sets']! as num).toDouble();
      final muscles = e['muscles']! as List;
      for (var i = 0; i < muscles.length; i++) {
        final w = i == 0 ? _kb.primaryWeight : _kb.secondaryWeight;
        out.update(
          muscles[i] as String,
          (v) => v + sets * w,
          ifAbsent: () => sets * w,
        );
      }
    }
  }
  return out;
}

/// Giorno della settimana (indice) di ogni seduta del calendario.
Map<String, int> _dayOf(Map<String, Object?> plan) => {
  for (final e in plan['schedule']! as List)
    (e as Map)['sessionId'] as String: _weekDays.indexOf(e['day'] as String),
};

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    _kb = KnowledgeBase.fromJson(built.json);
    final vocab = loadYaml(
      File('../kb/vocab/equipment.yaml').readAsStringSync(),
    ) as YamlMap;
    _equipmentByGym = {
      for (final e in (vocab['gymTypes'] as YamlMap).entries)
        e.key as String: [for (final x in e.value as YamlList) x as String],
    };
    final band = _kb.parameterGroups['belowBand']!;
    _bandMin = band.values['bandMin']! as num;
    _bandMax = band.values['bandMax']! as num;
  });

  test('il template esiste solo per over_2_years', () {
    final t = _kb.templates.singleWhere((t) => t.id == _templateId);
    expect(t.daysPerWeek, 6);
    expect(t.experience, ['over_2_years']);
    expect(t.goals.toSet(), {'muscle_gain', 'both', 'strength'});
    expect([for (final s in t.sessions) s.id], _sessionIds);
    // Nessuna tecnica dell'ultima serie su uno slot principale.
    for (final s in t.sessions) {
      for (final b in s.blocks) {
        for (final slot in b.slots) {
          if (slot.role == roleMain) {
            expect(slot.lastSet, isNull, reason: '${s.id} ${slot.pattern}');
          }
        }
      }
    }
  });

  for (final goal in _goals) {
    for (final gym in _gyms) {
      for (final duration in _durations) {
        test('$goal $gym $duration min: piano a 6 giorni valido', () {
          final plan = _plan(
            _profile(goal: goal, gym: gym, duration: duration),
          );
          expect(planSchemaErrors(plan, _planSchema), isEmpty);
          expect(plan['schemaVersion'], '3.3');
          expect(plan['id'], '$_templateId-$gym');
          expect(plan['split'], 'push_pull_legs');
          expect([for (final s in _sessions(plan)) s['id']], _sessionIds);
          expect(
            [
              for (final e in plan['schedule']! as List)
                '${(e as Map)['day']}:${e['sessionId']}',
            ],
            [
              for (var i = 0; i < _sessionIds.length; i++)
                '${_weekDays[i]}:${_sessionIds[i]}',
            ],
          );

          for (final s in _sessions(plan)) {
            expect(
              s['estimatedDurationMin']! as num,
              lessThanOrEqualTo(duration),
              reason: '${s['id']}',
            );
            final exercises = _exercisesOf(s);
            for (final e in exercises) {
              final lastSet = e['lastSet'] as String?;
              if (lastSet == null) continue;
              final kbEx = _kb.exercises[e['exerciseId']]!;
              expect(kbEx.heavyCompound, isFalse, reason: kbEx.id);
              expect(kbEx.noFailure, isFalse, reason: kbEx.id);
              if (goal == 'strength') expect(lastSet, 'failure');
            }
            if (duration >= 60) {
              expect(
                exercises.where((e) => e['lastSet'] != null),
                isNotEmpty,
                reason: '${s['id']}: nessuna tecnica a $duration minuti',
              );
              expect(
                (s['blocks']! as List).where(
                  (b) => (b as Map)['type'] == 'superset',
                ),
                isNotEmpty,
                reason: '${s['id']}: nessun superset',
              );
            }
          }

          // Tecniche solo nelle settimane di carico, mai nello scarico.
          final weeks = (plan['mesocycle']! as Map)['weeks'] as List;
          final lastLoad =
              (weeks.lastWhere((w) => (w as Map)['type'] == 'load')
                      as Map)['number']
                  as int;
          final techniques =
              (plan['parameters']! as Map)['intensityTechniques'] as Map;
          expect(techniques['fromWeek'] as int, lessThanOrEqualTo(lastLoad));
          expect((weeks.last as Map)['type'], 'deload');

          // Finisher dell'addome in due sedute non consecutive.
          final days = _dayOf(plan);
          final withCore = [
            for (final s in _sessions(plan))
              if (_exercisesOf(s).any((e) => e['optional'] == true))
                s['id']! as String,
          ];
          expect(withCore, hasLength(2));
          expect((days[withCore[0]]! - days[withCore[1]]!).abs(), isNot(1));

          // Nessun muscolo primario in due giorni consecutivi.
          final primaries = {
            for (final s in _sessions(plan))
              s['id']! as String: {
                for (final e in _exercisesOf(s))
                  (e['muscles']! as List).first as String,
              },
          };
          for (final a in _sessionIds) {
            for (final b in _sessionIds) {
              if (days[b]! - days[a]! != 1) continue;
              expect(
                primaries[a]!.intersection(primaries[b]!),
                isEmpty,
                reason: '$a e $b in giorni consecutivi',
              );
            }
          }

          // Volume nella fascia per massa ed entrambi, da 60 minuti.
          if (goal != 'strength' && duration >= 60) {
            final weekly = _weeklySets(plan);
            for (final m in _bandMuscles) {
              final v = weekly[m] ?? 0;
              expect(
                v,
                inInclusiveRange(_bandMin, _bandMax),
                reason: '$m: $v serie frazionarie a settimana',
              );
            }
          }

          // Determinismo.
          final again = generatePlan(
            _profile(goal: goal, gym: gym, duration: duration),
            _kb,
          );
          expect(jsonEncode((again as Generated).plan), jsonEncode(plan));
        });
      }
    }
  }

  for (final emphasis in emphasisValues) {
    test('enfasi $emphasis a 75 minuti: posti applicati, nessun primario in '
        'giorni consecutivi', () {
      final plan = _plan(_profile(duration: 75, emphasis: [emphasis]));
      final added = [
        for (final s in _sessions(plan))
          for (final e in _exercisesOf(s))
            if ((e['rules']! as List).contains(emphasisRuleId)) e,
      ];
      expect(added, isNotEmpty);
      final days = _dayOf(plan);
      final primaries = {
        for (final s in _sessions(plan))
          s['id']! as String: {
            for (final e in _exercisesOf(s))
              (e['muscles']! as List).first as String,
          },
      };
      for (final a in _sessionIds) {
        for (final b in _sessionIds) {
          if (days[b]! - days[a]! != 1) continue;
          expect(primaries[a]!.intersection(primaries[b]!), isEmpty);
        }
      }
    });
  }

  test('due semi diversi danno piani diversi', () {
    List<String> ids(Map<String, Object?> plan) => [
      for (final s in _sessions(plan))
        for (final e in _exercisesOf(s)) e['exerciseId']! as String,
    ];
    final a = _plan(_profile(variantSeed: 1));
    final b = _plan(_profile(variantSeed: 7));
    expect(ids(a).join(','), isNot(ids(b).join(',')));
  });

  for (final experience in ['6_months_2_years', 'under_6_months']) {
    for (final goal in _goals) {
      test('$experience $goal a 6 giorni: non coperto', () {
        final r = generatePlan(
          _profile(goal: goal, experience: experience),
          _kb,
        );
        expect(r, isA<NotCovered>());
        expect((r as NotCovered).detail.trim(), isNotEmpty);
      });
    }
  }
}
