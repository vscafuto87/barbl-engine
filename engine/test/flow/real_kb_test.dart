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

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    kb = KnowledgeBase.fromJson(built.json);
  });

  test('il caso d\'oro 01 passa', () {
    final cases = runEval(Directory('../kb'));
    expect(cases.where((c) => !c.passed).map((c) => '${c.id} ${c.failures}'),
        isEmpty);
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

  test('giorni, obiettivo e durata non coperti', () {
    expect(notCovered(profile(daysPerWeek: 3)).reason, NotCoveredReason.days);
    expect(notCovered(profile(daysPerWeek: 5)).reason, NotCoveredReason.days);
    expect(notCovered(profile(goal: 'strength')).reason,
        NotCoveredReason.goal);
    expect(notCovered(profile(sessionDurationMin: 45)).reason,
        NotCoveredReason.duration);
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
