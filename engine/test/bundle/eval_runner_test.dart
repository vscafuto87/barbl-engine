import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:barbl_engine/src/bundle/eval_runner.dart';
import 'package:test/test.dart';

void copyDir(Directory from, Directory to) {
  to.createSync(recursive: true);
  for (final e in from.listSync(followLinks: false)) {
    final name = e.uri.pathSegments.where((s) => s.isNotEmpty).last;
    if (e is Directory) {
      copyDir(e, Directory('${to.path}/$name'));
    } else if (e is File) {
      e.copySync('${to.path}/$name');
    }
  }
}

void main() {
  test('il caso d\'oro 01 passa sulla KB vera', () {
    final cases = runEval(Directory('../kb'));
    expect(cases, isNotEmpty);
    final first = cases.firstWhere((c) => c.id == 'golden-01');
    expect(first.failures, isEmpty);
    expect(first.passed, isTrue);
  });

  test('un expect.sessions sbagliato fa fallire il caso con il motivo', () {
    final tmp = Directory.systemTemp.createTempSync('eval_copy');
    addTearDown(() => tmp.deleteSync(recursive: true));
    copyDir(Directory('../kb'), tmp);
    final f = File('${tmp.path}/golden/01-intermediate-4d-muscle.yaml');
    final text = f.readAsStringSync();
    expect(text.contains('sessions: 4'), isTrue);
    f.writeAsStringSync(text.replaceFirst('sessions: 4', 'sessions: 5'));
    final cases = runEval(tmp);
    final c = cases.firstWhere((c) => c.id == 'golden-01');
    expect(c.passed, isFalse);
    expect(c.failures.any((m) => m.contains('sessions')), isTrue);
  });

  const goldenName = 'golden/01-intermediate-4d-muscle.yaml';

  /// Copia della KB con il caso d'oro 01 modificato da [edit].
  EvalCase editedCase(String Function(String) edit, {void Function(Directory)? also}) {
    final tmp = Directory.systemTemp.createTempSync('eval_copy');
    addTearDown(() => tmp.deleteSync(recursive: true));
    copyDir(Directory('../kb'), tmp);
    final f = File('${tmp.path}/$goldenName');
    f.writeAsStringSync(edit(f.readAsStringSync()));
    if (also != null) also(tmp);
    return runEval(tmp).firstWhere((c) => c.id == 'golden-01');
  }

  String replaceOnce(String text, String from, String to) {
    expect(text.contains(from), isTrue, reason: from);
    return text.replaceFirst(from, to);
  }

  String replaceSection(String text, String from, String until, String to) {
    final a = text.indexOf(from);
    final b = text.indexOf(until);
    expect(a >= 0 && b > a, isTrue);
    return text.substring(0, a) + to + text.substring(b);
  }

  bool mentions(EvalCase c, String word) =>
      c.failures.any((m) => m.contains(word));

  test('il caso d\'oro 05 (enfasi) passa sulla KB vera', () {
    final c = runEval(Directory('../kb')).firstWhere((c) => c.id == 'golden-05');
    expect(c.failures, isEmpty);
  });

  test('emphasisExercises sbagliato o mancante fa fallire', () {
    EvalCase run05(String Function(String) edit) {
      final tmp = Directory.systemTemp.createTempSync('eval_copy');
      addTearDown(() => tmp.deleteSync(recursive: true));
      copyDir(Directory('../kb'), tmp);
      final f = File(
        '${tmp.path}/golden/05-intermediate-5d-60min-emphasis.yaml',
      );
      f.writeAsStringSync(edit(f.readAsStringSync()));
      return runEval(tmp).firstWhere((c) => c.id == 'golden-05');
    }

    final wrong = run05(
      (t) => replaceOnce(t, '- dumbbell_curl', '- barbell_curl'),
    );
    expect(wrong.passed, isFalse);
    expect(mentions(wrong, 'emphasisExercises.pull'), isTrue);

    final missing = run05(
      (t) => replaceSection(t, '  emphasisExercises:', '  weeklySetsAtLeast:', ''),
    );
    expect(missing.passed, isFalse);
    expect(mentions(missing, 'emphasisExercises'), isTrue);
  });

  test('una chiave sconosciuta in expect fa fallire', () {
    final c = editedCase((t) => replaceOnce(t, 'expect:\n', 'expect:\n  bogus: 1\n'));
    expect(c.passed, isFalse);
    expect(mentions(c, 'bogus'), isTrue);
  });

  test('una chiave sconosciuta dentro mesocycle fa fallire', () {
    final c = editedCase((t) => replaceOnce(
        t, 'lastWeekType: deload', 'lastWeekType: deload\n    lastWeekTyp: x'));
    expect(c.passed, isFalse);
    expect(mentions(c, 'lastWeekTyp'), isTrue);
  });

  test('una chiave sconosciuta dentro weeklySetsAtLeast e initialLoad fa fallire', () {
    final a = editedCase((t) => replaceOnce(
        t, 'counting: fractional', 'counting: fractional\n    extra: 1'));
    expect(mentions(a, 'extra'), isTrue);
    final b = editedCase((t) => replaceOnce(
        t, 'kg: 80\n', 'kg: 80\n      weird: 1\n'));
    expect(mentions(b, 'weird'), isTrue);
  });

  test('un initialLoad malformato fa fallire', () {
    final c = editedCase((t) =>
        replaceSection(t, '  initialLoad:', '  weeklySetsAtLeast:', '  initialLoad: nope\n'));
    expect(c.passed, isFalse);
    expect(mentions(c, 'initialLoad'), isTrue);
  });

  test('mesocycle e weeklySetsAtLeast malformati fanno fallire', () {
    final a = editedCase((t) =>
        replaceSection(t, '  mesocycle:', '  initialLoad:', '  mesocycle: 5\n'));
    expect(mentions(a, 'mesocycle'), isTrue);
    final b = editedCase((t) => replaceSection(
        t, '  weeklySetsAtLeast:', '  validAgainst:', '  weeklySetsAtLeast: 3\n'));
    expect(mentions(b, 'weeklySetsAtLeast'), isTrue);
  });

  test('un carico iniziale diverso fa fallire', () {
    final c = editedCase((t) => replaceOnce(t, 'kg: 80\n', 'kg: 81\n'));
    expect(c.passed, isFalse);
    expect(mentions(c, 'barbell_bench_press'), isTrue);
  });

  test('un volume sotto il minimo fa fallire', () {
    final c = editedCase((t) => replaceOnce(t, 'back: 10', 'back: 999'));
    expect(c.passed, isFalse);
    expect(mentions(c, 'back'), isTrue);
  });

  test('un validAgainst che non passa fa fallire', () {
    final c = editedCase(
      (t) => replaceOnce(t, 'validAgainst: contract/plan.schema.json',
          'validAgainst: contract/impossible.schema.json'),
      also: (dir) => File('${dir.path}/contract/impossible.schema.json')
          .writeAsStringSync('{"type":"object","required":["nonexistent"]}'),
    );
    expect(c.passed, isFalse);
    expect(mentions(c, 'validAgainst'), isTrue);
  });

  test('una cartella golden senza casi è un fallimento', () {
    final tmp = Directory.systemTemp.createTempSync('eval_empty');
    addTearDown(() => tmp.deleteSync(recursive: true));
    copyDir(Directory('../kb'), tmp);
    for (final e in Directory('${tmp.path}/golden').listSync()) {
      if (e is File && e.path.endsWith('.yaml')) e.deleteSync();
    }
    final cases = runEval(tmp);
    expect(cases, hasLength(1));
    expect(cases.single.passed, isFalse);
  });

  test('planSchemaErrors segnala un piano a cui manca un campo', () {
    final built = buildBundle(Directory('../kb'));
    final kb = KnowledgeBase.fromJson(built.json);
    final profile = jsonDecode(
      File('../kb/golden/profile-example.json').readAsStringSync(),
    ) as Map<String, Object?>;
    final result = generatePlan(profile, kb);
    final plan = Map<String, Object?>.from((result as Generated).plan);
    final schema = File('../kb/contract/plan.schema.json');
    expect(planSchemaErrors(plan, schema), isEmpty);
    final copy = jsonDecode(jsonEncode(plan)) as Map<String, Object?>;
    final firstExercise = ((((copy['sessions']! as List).first
            as Map)['blocks'] as List).first as Map)['exercises'] as List;
    (firstExercise.first as Map)['equipment'] = 'kettlebell';
    expect(planSchemaErrors(copy, schema), isNotEmpty);
    final copy2 = jsonDecode(jsonEncode(plan)) as Map<String, Object?>;
    ((copy2['parameters']! as Map)['progression']! as Map)['extraKey'] = 1;
    expect(planSchemaErrors(copy2, schema), isNotEmpty);
    plan.remove('sessions');
    expect(planSchemaErrors(plan, schema), isNotEmpty);
  });
}
