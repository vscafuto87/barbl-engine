import 'dart:convert';
import 'dart:io';

import 'package:json_schema/json_schema.dart';
import 'package:yaml/yaml.dart';

import '../generate/generate_plan.dart';
import '../generate/result.dart';
import '../kb/knowledge_base.dart';
import '../kb/models.dart' show emphasisRuleId;
import 'bundle_builder.dart';

/// Esito di un caso d'oro.
class EvalCase {
  EvalCase(this.id, this.failures);

  final String id;
  final List<String> failures;

  bool get passed => failures.isEmpty;
}

Object? _toPlain(Object? v) {
  if (v is Map) {
    return <String, Object?>{
      for (final e in v.entries) e.key.toString(): _toPlain(e.value),
    };
  }
  if (v is List) {
    return <Object?>[for (final e in v) _toPlain(e)];
  }
  return v;
}

/// Errori di validazione di [plan] rispetto allo schema in [schemaFile];
/// lista vuota se il piano è valido.
List<String> planSchemaErrors(Object? plan, File schemaFile) {
  final schemaJson = jsonDecode(schemaFile.readAsStringSync());
  final schema = JsonSchema.create(schemaJson);
  final instance = jsonDecode(jsonEncode(plan));
  final results = schema.validate(instance);
  if (results.isValid) return <String>[];
  return <String>[for (final e in results.errors) e.toString()];
}

num? _num(Object? v) => v is num ? v : null;

String _describe(Object? v) => v == null ? 'null' : '$v';

void _checkSplit(
  Map<String, Object?> plan,
  Map<String, Object?> expect,
  List<String> failures,
) {
  if (expect.containsKey('split') && plan['split'] != expect['split']) {
    failures.add(
      'split: atteso ${expect['split']}, ottenuto ${plan['split']}',
    );
  }
  if (expect.containsKey('sessions')) {
    final actual = (plan['sessions'] as List).length;
    if (actual != _num(expect['sessions'])) {
      failures.add('sessions: atteso ${expect['sessions']}, ottenuto $actual');
    }
  }
  if (expect.containsKey('scheduleDays')) {
    final actual = <String>[
      for (final s in plan['schedule'] as List) (s as Map)['day'] as String,
    ];
    final wanted = <String>[
      for (final d in expect['scheduleDays'] as List) d.toString(),
    ];
    if (actual.join(',') != wanted.join(',')) {
      failures.add(
        'scheduleDays: atteso ${wanted.join(',')}, ottenuto ${actual.join(',')}',
      );
    }
  }
}

void _unknownKeys(
  Map<Object?, Object?> map,
  Set<String> allowed,
  String path,
  List<String> failures,
) {
  for (final k in map.keys) {
    if (!allowed.contains(k.toString())) {
      failures.add('$path.$k: chiave non gestita');
    }
  }
}

void _checkMesocycle(
  Map<String, Object?> plan,
  Map<String, Object?> expect,
  List<String> failures,
) {
  if (!expect.containsKey('mesocycle')) return;
  final wanted = expect['mesocycle'];
  if (wanted is! Map) {
    failures.add('expect.mesocycle: forma non valida');
    return;
  }
  _unknownKeys(
    wanted,
    const {'weeks', 'lastWeekType', 'rirTargetByWeek'},
    'expect.mesocycle',
    failures,
  );
  final weeks = <Map>[
    for (final w in (plan['mesocycle'] as Map)['weeks'] as List) w as Map,
  ];
  if (wanted.containsKey('weeks') && weeks.length != _num(wanted['weeks'])) {
    failures.add(
      'mesocycle.weeks: atteso ${wanted['weeks']}, ottenuto ${weeks.length}',
    );
  }
  if (wanted.containsKey('lastWeekType')) {
    final actual = weeks.isEmpty ? null : weeks.last['type'];
    if (actual != wanted['lastWeekType']) {
      failures.add(
        'mesocycle.lastWeekType: atteso ${wanted['lastWeekType']}, '
        'ottenuto ${_describe(actual)}',
      );
    }
  }
  if (!wanted.containsKey('rirTargetByWeek')) return;
  final rirRaw = wanted['rirTargetByWeek'];
  if (rirRaw is! Map) {
    failures.add('expect.mesocycle.rirTargetByWeek: forma non valida');
    return;
  }
  for (final e in rirRaw.entries) {
    final number = int.tryParse(e.key.toString());
    if (number == null) {
      failures.add(
        'expect.mesocycle.rirTargetByWeek.${e.key}: settimana non numerica',
      );
      continue;
    }
    Map? week;
    for (final w in weeks) {
      if (w['number'] == number) week = w;
    }
    if (week == null) {
      failures.add('mesocycle.rirTargetByWeek: settimana ${e.key} assente');
    } else if (_num(week['rirTarget']) != _num(e.value) ||
        (week['rirTarget'] == null) != (e.value == null)) {
      failures.add(
        'mesocycle.rirTargetByWeek.${e.key}: atteso ${_describe(e.value)}, '
        'ottenuto ${_describe(week['rirTarget'])}',
      );
    }
  }
}

void _checkInitialLoad(
  Map<String, Object?> plan,
  Map<String, Object?> expect,
  List<String> failures,
) {
  if (!expect.containsKey('initialLoad')) return;
  final raw = expect['initialLoad'];
  if (raw is! Map) {
    failures.add('expect.initialLoad: forma non valida');
    return;
  }
  final byId = <String, List<Map>>{};
  for (final s in plan['sessions'] as List) {
    for (final b in (s as Map)['blocks'] as List) {
      for (final e in (b as Map)['exercises'] as List) {
        final m = e as Map;
        final initial = m['initialLoad'];
        if (initial is Map) {
          byId.putIfAbsent(m['exerciseId'] as String, () => <Map>[]).add(initial);
        }
      }
    }
  }
  for (final entry in raw.entries) {
    final id = entry.key.toString();
    final want = entry.value;
    if (want is! Map) {
      failures.add('expect.initialLoad.$id: forma non valida');
      continue;
    }
    _unknownKeys(want, const {'kg', 'source'}, 'expect.initialLoad.$id', failures);
    if (!want.containsKey('kg') || !want.containsKey('source')) {
      failures.add('expect.initialLoad.$id: servono kg e source');
      continue;
    }
    final occurrences = byId[id];
    if (occurrences == null) {
      failures.add('initialLoad.$id: esercizio assente dal piano');
      continue;
    }
    for (final actual in occurrences) {
      if (_num(actual['kg']) != _num(want['kg']) ||
          (actual['kg'] == null) != (want['kg'] == null)) {
        failures.add(
          'initialLoad.$id.kg: atteso ${_describe(want['kg'])}, '
          'ottenuto ${_describe(actual['kg'])}',
        );
      }
      if (actual['source'] != want['source']) {
        failures.add(
          'initialLoad.$id.source: atteso ${_describe(want['source'])}, '
          'ottenuto ${_describe(actual['source'])}',
        );
      }
    }
  }
}

void _checkWeeklySets(
  Map<String, Object?> plan,
  Map<String, Object?> expect,
  KnowledgeBase kb,
  List<String> failures,
) {
  if (!expect.containsKey('weeklySetsAtLeast')) return;
  final raw = expect['weeklySetsAtLeast'];
  if (raw is! Map) {
    failures.add('expect.weeklySetsAtLeast: forma non valida');
    return;
  }
  _unknownKeys(
    raw,
    const {'counting', 'values'},
    'expect.weeklySetsAtLeast',
    failures,
  );
  final counting = raw['counting'];
  if (counting != 'fractional') {
    failures.add('weeklySetsAtLeast.counting: $counting non supportato');
    return;
  }
  final values = raw['values'];
  if (values is! Map || values.isEmpty) {
    failures.add('expect.weeklySetsAtLeast.values: forma non valida');
    return;
  }
  final totals = <String, double>{};
  for (final s in plan['sessions'] as List) {
    for (final b in (s as Map)['blocks'] as List) {
      for (final e in (b as Map)['exercises'] as List) {
        final m = e as Map;
        final sets = _num(m['sets']);
        if (sets == null) continue;
        final muscles = m['muscles'] as List;
        for (var i = 0; i < muscles.length; i++) {
          final weight = i == 0 ? kb.primaryWeight : kb.secondaryWeight;
          final key = muscles[i].toString();
          totals[key] = (totals[key] ?? 0) + sets * weight;
        }
      }
    }
  }
  for (final e in values.entries) {
    final muscle = e.key.toString();
    final minimum = _num(e.value);
    final actual = totals[muscle] ?? 0;
    if (minimum == null || actual + 1e-9 < minimum) {
      failures.add(
        'weeklySetsAtLeast.$muscle: atteso almeno ${_describe(e.value)}, '
        'ottenuto $actual',
      );
    }
  }
}

/// Esercizi aggiunti per enfasi (con la regola `EMPHASIS`), per seduta e in
/// ordine: devono coincidere con `expect.emphasisExercises`; senza la chiave
/// il piano non ne deve avere.
void _checkEmphasisExercises(
  Map<String, Object?> plan,
  Map<String, Object?> expect,
  List<String> failures,
) {
  final actual = <String, List<String>>{};
  for (final s in plan['sessions'] as List) {
    final session = s as Map;
    for (final b in session['blocks'] as List) {
      for (final e in (b as Map)['exercises'] as List) {
        final m = e as Map;
        if ((m['rules'] as List).contains(emphasisRuleId)) {
          actual
              .putIfAbsent(session['id'] as String, () => <String>[])
              .add(m['exerciseId'] as String);
        }
      }
    }
  }
  final raw = expect['emphasisExercises'];
  if (raw == null) {
    if (actual.isNotEmpty) {
      failures.add('emphasisExercises: atteso nessuno, ottenuto $actual');
    }
    return;
  }
  if (raw is! Map) {
    failures.add('expect.emphasisExercises: forma non valida');
    return;
  }
  final wanted = <String, List<String>>{};
  for (final e in raw.entries) {
    final list = e.value;
    if (list is! List) {
      failures.add('expect.emphasisExercises.${e.key}: forma non valida');
      return;
    }
    wanted[e.key.toString()] = [for (final x in list) x.toString()];
  }
  final sessions = {...actual.keys, ...wanted.keys}.toList()..sort();
  for (final id in sessions) {
    final a = (actual[id] ?? const <String>[]).join(',');
    final w = (wanted[id] ?? const <String>[]).join(',');
    if (a != w) {
      failures.add('emphasisExercises.$id: atteso [$w], ottenuto [$a]');
    }
  }
}

const Set<String> _knownKeys = {
  'split',
  'sessions',
  'scheduleDays',
  'mesocycle',
  'initialLoad',
  'weeklySetsAtLeast',
  'emphasisExercises',
  'validAgainst',
};

EvalCase _runCase(File file, Directory kbDir, KnowledgeBase kb) {
  final name = file.uri.pathSegments.last;
  final failures = <String>[];
  var id = name;
  try {
    final data = _toPlain(loadYaml(file.readAsStringSync()));
    if (data is! Map<String, Object?>) {
      return EvalCase(id, <String>['$name: il file non contiene una mappa']);
    }
    id = data['id'] is String ? data['id']! as String : name;
    final profilePath = data['profile'];
    final expectRaw = data['expect'];
    if (profilePath is! String || expectRaw is! Map<String, Object?>) {
      return EvalCase(id, <String>['profile o expect mancanti']);
    }
    for (final k in expectRaw.keys) {
      if (!_knownKeys.contains(k)) failures.add('expect.$k: chiave non gestita');
    }
    final profileFile = File('${kbDir.path}/$profilePath');
    if (!profileFile.existsSync()) {
      return EvalCase(id, <String>['profilo non trovato: $profilePath']);
    }
    final profileJson = jsonDecode(profileFile.readAsStringSync());
    if (profileJson is! Map<String, Object?>) {
      return EvalCase(id, <String>['il profilo non è un oggetto JSON']);
    }
    final result = generatePlan(profileJson, kb);
    if (result is InvalidProfile) {
      failures.add('profilo non valido: ${result.errors.join('; ')}');
      return EvalCase(id, failures);
    }
    if (result is NotCovered) {
      failures.add(
        'non coperto (${result.reason.name}): ${result.detail}',
      );
      return EvalCase(id, failures);
    }
    final plan = (result as Generated).plan;
    _checkSplit(plan, expectRaw, failures);
    _checkMesocycle(plan, expectRaw, failures);
    _checkInitialLoad(plan, expectRaw, failures);
    _checkWeeklySets(plan, expectRaw, kb, failures);
    _checkEmphasisExercises(plan, expectRaw, failures);
    final schemaPath = expectRaw['validAgainst'];
    if (schemaPath is String) {
      final schemaFile = File('${kbDir.path}/$schemaPath');
      if (!schemaFile.existsSync()) {
        failures.add('validAgainst: schema non trovato: $schemaPath');
      } else {
        for (final e in planSchemaErrors(plan, schemaFile)) {
          failures.add('validAgainst: $e');
        }
      }
    }
  } catch (e) {
    failures.add('errore imprevisto: $e');
  }
  return EvalCase(id, failures);
}

/// Genera il piano di ogni caso d'oro in `kb/golden/*.yaml` e controlla le
/// chiavi `expect`.
List<EvalCase> runEval(Directory kbDir) {
  final built = buildBundle(kbDir);
  if (built.errors.isNotEmpty) {
    return <EvalCase>[EvalCase('bundle', built.errors)];
  }
  final KnowledgeBase kb;
  try {
    kb = KnowledgeBase.fromJson(built.json);
  } catch (e) {
    return <EvalCase>[EvalCase('bundle', <String>['pacchetto illeggibile: $e'])];
  }
  final goldenDir = Directory('${kbDir.path}/golden');
  if (!goldenDir.existsSync()) {
    return <EvalCase>[EvalCase('golden', <String>['cartella golden mancante'])];
  }
  final files = <File>[
    for (final e in goldenDir.listSync(followLinks: false))
      if (e is File && e.path.endsWith('.yaml')) e,
  ]..sort((a, b) => a.path.compareTo(b.path));
  if (files.isEmpty) {
    return <EvalCase>[
      EvalCase('golden', <String>['nessun caso in kb/golden']),
    ];
  }
  return <EvalCase>[for (final f in files) _runCase(f, kbDir, kb)];
}
