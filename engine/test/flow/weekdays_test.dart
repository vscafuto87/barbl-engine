/// Giorni scelti dall'utente (profilo 1.5) con la KB vera: le sedute vanno ai
/// giorni scelti, il resto del piano non cambia.
library;

import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:barbl_engine/src/bundle/eval_runner.dart';
import 'package:test/test.dart';

late KnowledgeBase kb;
final planSchema = File('../kb/contract/plan.schema.json');

Map<String, Object?> _golden(String name) =>
    jsonDecode(File('../kb/golden/$name').readAsStringSync())
        as Map<String, Object?>;

Map<String, Object?> _plan(Map<String, Object?> profile) {
  final result = generatePlan(profile, kb);
  expect(result, isA<Generated>());
  final plan = (result as Generated).plan;
  expect(planSchemaErrors(plan, planSchema), isEmpty);
  return plan;
}

List<String> _days(Map<String, Object?> plan) => [
  for (final e in plan['schedule']! as List) (e as Map)['day'] as String,
];

List<String> _sessions(Map<String, Object?> plan) => [
  for (final e in plan['schedule']! as List) (e as Map)['sessionId'] as String,
];

void main() {
  setUpAll(() {
    final built = buildBundle(Directory('../kb'));
    expect(built.errors, isEmpty);
    kb = KnowledgeBase.fromJson(built.json);
  });

  for (final name in [
    'profile-3d.json',
    'profile-example.json',
    'profile-5d-45min.json',
  ]) {
    test(
      '$name: con giorni uguali a quelli predefiniti il piano è identico',
      () {
        final base = _plan(_golden(name));
        final withDays = _golden(name)
          ..['schemaVersion'] = '1.5'
          ..['weekdays'] = _days(base);
        expect(jsonEncode(_plan(withDays)), jsonEncode(base));
      },
    );

    test('$name: i giorni scelti prendono le sedute nello stesso ordine', () {
      final base = _plan(_golden(name));
      final n = _days(base).length;
      final chosen = ['tue', 'wed', 'thu', 'sat', 'sun'].sublist(0, n);
      final json = _golden(name)
        ..['schemaVersion'] = '1.5'
        ..['weekdays'] = chosen.reversed.toList();
      final plan = _plan(json);
      expect(_days(plan), chosen);
      expect(_sessions(plan), _sessions(base));
      // Cambia solo il calendario.
      expect(
        jsonEncode({...plan, 'schedule': null}),
        jsonEncode({...base, 'schedule': null}),
      );
    });
  }

  test(
    'un numero di giorni diverso da daysPerWeek è un profilo non valido',
    () {
      final json = _golden('profile-3d.json')
        ..['schemaVersion'] = '1.5'
        ..['weekdays'] = ['mon', 'tue'];
      expect(generatePlan(json, kb), isA<InvalidProfile>());
    },
  );
}
