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
  final json =
      jsonDecode(File('../kb/golden/profile-example.json').readAsStringSync())
          as Map<String, Object?>;
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

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    kb = KnowledgeBase.fromJson(built.json);
  });

  test('i casi d\'oro passano', () {
    final cases = runEval(Directory('../kb'));
    expect(cases.where((c) => !c.passed).map((c) => '${c.id} ${c.failures}'),
        isEmpty);
  });

  test('il caso 02 (3 giorni, full body) genera un piano valido', () {
    final json =
        jsonDecode(File('../kb/golden/profile-3d.json').readAsStringSync())
            as Map<String, Object?>;
    final p = plan(json);
    final sessions = (p['sessions']! as List).cast<Map>();
    expect(sessions, hasLength(3));
    expect(sessions.map((s) => s['focus']), everyElement('full_body'));
    expect(p['split'], 'full_body');
  });

  test('3 giorni con home e dumbbells: nessuno slot vuoto', () {
    final base =
        jsonDecode(File('../kb/golden/profile-3d.json').readAsStringSync())
            as Map<String, Object?>;
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
    final home = plan(profile(
      gymType: 'home',
      equipment: ['barbell', 'rack', 'bench', 'dumbbells'],
    ));
    final dumbbells = plan(profile(
      gymType: 'dumbbells',
      equipment: ['dumbbells', 'bench'],
    ));
    final encoded = {jsonEncode(full), jsonEncode(home), jsonEncode(dumbbells)};
    expect(encoded, hasLength(3));
  });

  test('giorni e durata non coperti', () {
    expect(notCovered(profile(daysPerWeek: 5)).reason, NotCoveredReason.days);
    expect(
      notCovered(profile(daysPerWeek: 5, goal: 'strength')).reason,
      NotCoveredReason.days,
    );
    expect(
      notCovered(profile(daysPerWeek: 3, sessionDurationMin: 45)).reason,
      NotCoveredReason.duration,
    );
    expect(notCovered(profile(sessionDurationMin: 45)).reason,
        NotCoveredReason.duration);
  });

  test('forza a 45 e 60 minuti: rifiuto per durata, non un\'eccezione', () {
    for (final days in [3, 4]) {
      for (final minutes in [45, 60]) {
        final r = notCovered(profile(
          daysPerWeek: days,
          goal: 'strength',
          sessionDurationMin: minutes,
        ));
        expect(r.reason, NotCoveredReason.duration, reason: '$days $minutes');
        expect(r.detail, isNotEmpty);
      }
    }
  });

  test('forza a 3 e 4 giorni da 75 minuti: piano completo in ogni palestra',
      () {
    for (final days in [3, 4]) {
      for (final gym in [
        ('full', <String>[
          'barbell',
          'rack',
          'bench',
          'dumbbells',
          'machines',
          'cables',
          'smith_machine',
        ]),
        ('home', ['barbell', 'rack', 'bench', 'dumbbells']),
        ('dumbbells', ['dumbbells', 'bench']),
      ]) {
        final p = plan(profile(
          daysPerWeek: days,
          goal: 'strength',
          sessionDurationMin: 75,
          gymType: gym.$1,
          equipment: gym.$2,
        ));
        expect(p['goal'], 'strength');
        expect((p['sessions']! as List), hasLength(days));
        for (final s in p['sessions']! as List) {
          expect((s as Map)['estimatedDurationMin'] as num,
              lessThanOrEqualTo(75));
        }
      }
    }
  });

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

    final strength =
        plan(profile(goal: 'strength', sessionDurationMin: 75));
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
    final p = plan(profile(
      goal: 'strength',
      sessionDurationMin: 75,
      noKnownLoads: true,
    ));
    expect(
      trialExercises(p),
      {'barbell_bench_press', 'military_press', 'squat'},
    );
  });

  test('un profilo senza gym è non valido', () {
    expect(generatePlan(profile(noGym: true), kb), isA<InvalidProfile>());
  });

  test('senza carichi noti la prova è solo degli slot che la ammettono', () {
    final p = plan(profile(noKnownLoads: true));
    expect(
      trialExercises(p),
      {'barbell_bench_press', 'military_press', 'squat'},
    );
  });

  test('piano 3.0: i quattro esercizi chiave hanno askLoad e nome {it, en}',
      () {
    final p = plan(profile());
    expect(p['schemaVersion'], '3.0');
    expect(
      askLoadExercises(p),
      {'barbell_bench_press', 'dumbbell_row', 'military_press', 'squat'},
    );
    for (final s in p['sessions']! as List) {
      for (final b in (s as Map)['blocks'] as List) {
        for (final e in (b as Map)['exercises'] as List) {
          final name = (e as Map)['name'] as Map;
          expect(name.keys, containsAll(['it', 'en']));
        }
      }
    }
  });

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

  test('engineVersion coincide con la versione di pubspec.yaml', () {
    final text = File('pubspec.yaml').readAsStringSync();
    final match = RegExp(r'^version:\s*(\S+)\s*$', multiLine: true)
        .firstMatch(text);
    expect(match, isNotNull);
    expect(engineVersion, match!.group(1));
  });
}
