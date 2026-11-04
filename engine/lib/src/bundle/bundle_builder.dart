import 'dart:io';

import 'package:yaml/yaml.dart';

/// Esito di [buildBundle]: il pacchetto JSON e gli errori trovati.
class BundleResult {
  BundleResult(this.json, this.errors);

  final Map<String, Object?> json;
  final List<String> errors;
}

/// Un file YAML letto: percorso relativo alla KB e contenuto già convertito.
class _Doc {
  _Doc(this.path, this.data);

  final String path;
  final Map<String, Object?> data;
}

/// Converte ricorsivamente YamlMap/YamlList in Map/List Dart, con le chiavi
/// delle mappe ordinate (le liste mantengono l'ordine).
Object? _plain(Object? v) {
  if (v is Map) {
    final keys = v.keys.map((k) => k.toString()).toList()..sort();
    final byKey = <String, Object?>{
      for (final e in v.entries) e.key.toString(): e.value,
    };
    return <String, Object?>{for (final k in keys) k: _plain(byKey[k])};
  }
  if (v is List) {
    return <Object?>[for (final e in v) _plain(e)];
  }
  return v;
}

Map<String, Object?> _sortedMap(Map<String, Object?> m) {
  final keys = m.keys.toList()..sort();
  return <String, Object?>{for (final k in keys) k: m[k]};
}

String _relative(Directory root, File f) {
  var rootPath = root.path.replaceAll('\\', '/');
  if (!rootPath.endsWith('/')) rootPath = '$rootPath/';
  final p = f.path.replaceAll('\\', '/');
  return p.startsWith(rootPath) ? p.substring(rootPath.length) : p;
}

Map<String, Object?>? _asMapOrNull(Object? v) =>
    v is Map<String, Object?> ? v : null;

List<Object?> _asListOrEmpty(Object? v) =>
    v is List ? List<Object?>.from(v) : <Object?>[];

List<String> _stringList(Object? v) => [
  for (final e in _asListOrEmpty(v))
    if (e is String) e,
];

/// Legge un file YAML; in caso di errore lo registra e restituisce null.
Map<String, Object?>? _readYaml(
  Directory kb,
  File file,
  List<String> errors,
) {
  final rel = _relative(kb, file);
  try {
    final parsed = loadYaml(file.readAsStringSync());
    final plain = _plain(parsed);
    if (plain is Map<String, Object?>) return plain;
    errors.add('$rel: il file non contiene una mappa');
  } on YamlException catch (e) {
    errors.add('$rel: YAML non valido (${e.message})');
  } on FileSystemException catch (e) {
    errors.add('$rel: file non leggibile (${e.message})');
  }
  return null;
}

List<_Doc> _readDir(
  Directory kb,
  String name,
  List<String> errors, {
  required bool recursive,
}) {
  final dir = Directory('${kb.path}/$name');
  if (!dir.existsSync()) {
    errors.add('$name: cartella mancante');
    return [];
  }
  final files = <File>[
    for (final e in dir.listSync(recursive: recursive, followLinks: false))
      if (e is File && e.path.endsWith('.yaml')) e,
  ];
  // Percorsi ordinati per un esito stabile.
  files.sort((a, b) => _relative(kb, a).compareTo(_relative(kb, b)));
  final docs = <_Doc>[];
  for (final f in files) {
    final data = _readYaml(kb, f, errors);
    if (data != null) docs.add(_Doc(_relative(kb, f), data));
  }
  return docs;
}

/// Indicizza i documenti per il campo [keyField]; segnala id mancanti o doppi.
Map<String, Object?> _index(
  List<_Doc> docs,
  String keyField,
  List<String> errors,
) {
  final out = <String, Object?>{};
  final origin = <String, String>{};
  for (final d in docs) {
    final id = d.data[keyField];
    if (id is! String || id.isEmpty) {
      errors.add('${d.path}: campo $keyField mancante');
      continue;
    }
    if (out.containsKey(id)) {
      errors.add(
        '${d.path}: $keyField $id già definito in ${origin[id]}',
      );
      continue;
    }
    out[id] = d.data;
    origin[id] = d.path;
  }
  return _sortedMap(out);
}

Map<String, Object?>? _readVocab(
  Directory kb,
  String file,
  List<String> errors,
) {
  final f = File('${kb.path}/vocab/$file');
  if (!f.existsSync()) {
    errors.add('vocab/$file: file mancante');
    return null;
  }
  return _readYaml(kb, f, errors);
}

/// Id degli elementi di una lista di mappe `{id: ...}`.
Set<String> _ids(Object? list) => {
  for (final e in _asListOrEmpty(list))
    if (e is Map && e['id'] is String) e['id'] as String,
};

/// Costruisce il pacchetto JSON della KB in [kbDir] e controlla i riferimenti.
BundleResult buildBundle(Directory kbDir, {String? kbCommit}) {
  final errors = <String>[];

  final versionFile = File('${kbDir.path}/VERSION');
  var rulesVersion = '';
  if (versionFile.existsSync()) {
    rulesVersion = versionFile.readAsStringSync().trim();
  } else {
    errors.add('VERSION: file mancante');
  }

  final musclesVocab = _readVocab(kbDir, 'muscles.yaml', errors);
  final patternsVocab = _readVocab(kbDir, 'patterns.yaml', errors);
  final equipmentVocab = _readVocab(kbDir, 'equipment.yaml', errors);

  final muscles = _asListOrEmpty(musclesVocab?['muscles']);
  final setWeights =
      _asMapOrNull(musclesVocab?['setWeights']) ?? <String, Object?>{};
  final patterns = _asListOrEmpty(patternsVocab?['patterns']);
  final profileEquipment = _asListOrEmpty(equipmentVocab?['profileEquipment']);
  final planEquipment = _asListOrEmpty(equipmentVocab?['planEquipment']);
  final gymTypes =
      _asMapOrNull(equipmentVocab?['gymTypes']) ?? <String, Object?>{};

  final sourceDocs = _readDir(kbDir, 'sources', errors, recursive: false);
  final principleDocs = _readDir(kbDir, 'principles', errors, recursive: true);
  final exerciseDocs = _readDir(kbDir, 'exercises', errors, recursive: true);
  final templateDocs = _readDir(kbDir, 'templates', errors, recursive: false);
  final prescriptionDocs = _readDir(
    kbDir,
    'prescriptions',
    errors,
    recursive: false,
  );
  final parameterDocs = _readDir(kbDir, 'parameters', errors, recursive: false);
  final rationaleDocs = _readDir(kbDir, 'rationales', errors, recursive: false);

  final sources = _index(sourceDocs, 'id', errors);
  final principles = _index(principleDocs, 'id', errors);
  final exercises = _index(exerciseDocs, 'id', errors);
  final templates = _index(templateDocs, 'id', errors);
  final prescriptions = _index(prescriptionDocs, 'id', errors);
  final parameters = _index(parameterDocs, 'group', errors);
  final rationales = _index(rationaleDocs, 'ruleId', errors);

  final muscleIds = _ids(muscles);
  final patternIds = _ids(patterns);
  final profileEquipmentIds = _ids(profileEquipment);
  final planEquipmentIds = {
    for (final e in planEquipment)
      if (e is String) e,
  };

  // Ruoli definiti da almeno una prescrizione.
  final roleIds = <String>{};
  for (final p in prescriptions.values) {
    final roles = _asMapOrNull(_asMapOrNull(p)?['roles']);
    if (roles != null) roleIds.addAll(roles.keys);
  }

  // Esercizi.
  for (final d in exerciseDocs) {
    final id = d.data['id'];
    if (id is! String) continue;
    final ctx = '${d.path}: esercizio $id';
    final pattern = d.data['pattern'];
    if (pattern is String && !patternIds.contains(pattern)) {
      errors.add('$ctx: pattern $pattern non esiste in vocab/patterns.yaml');
    }
    final equipment = d.data['equipment'];
    if (equipment is String && !planEquipmentIds.contains(equipment)) {
      errors.add('$ctx: equipment $equipment non esiste in planEquipment');
    }
    for (final r in _stringList(d.data['requires'])) {
      if (!profileEquipmentIds.contains(r)) {
        errors.add('$ctx: requires $r non esiste in profileEquipment');
      }
    }
    for (final s in _stringList(d.data['substitutes'])) {
      if (!exercises.containsKey(s)) {
        errors.add('$ctx: sostituto $s non è un esercizio');
      }
    }
    final m = _asMapOrNull(d.data['muscles']);
    if (m != null) {
      final primary = m['primary'];
      if (primary is String && !muscleIds.contains(primary)) {
        errors.add('$ctx: muscolo $primary non esiste in vocab/muscles.yaml');
      }
      for (final s in _stringList(m['secondary'])) {
        if (!muscleIds.contains(s)) {
          errors.add('$ctx: muscolo $s non esiste in vocab/muscles.yaml');
        }
      }
    }
  }

  // Template.
  for (final d in templateDocs) {
    final tid = d.data['id'];
    if (tid is! String) continue;
    for (final session in _asListOrEmpty(d.data['sessions'])) {
      final s = _asMapOrNull(session);
      if (s == null) continue;
      final sid = s['id'];
      final sctx = '${d.path}: template $tid, seduta $sid';
      final focus = s['focus'];
      if (focus != 'upper_body' && focus != 'legs' && focus != 'full_body') {
        errors.add(
          '$sctx: focus $focus: focus senza colonna di recupero '
          '(ammessi upper_body, legs e full_body)',
        );
      }
      for (final block in _asListOrEmpty(s['blocks'])) {
        final b = _asMapOrNull(block);
        if (b == null) continue;
        for (final slot in _asListOrEmpty(b['slots'])) {
          final sl = _asMapOrNull(slot);
          if (sl == null) continue;
          final pattern = sl['pattern'];
          if (pattern is String && !patternIds.contains(pattern)) {
            errors.add(
              '$sctx: slot con pattern $pattern non esiste in '
              'vocab/patterns.yaml',
            );
          }
          final role = sl['role'];
          if (role is String && !roleIds.contains(role)) {
            errors.add(
              '$sctx: slot $pattern con ruolo $role senza prescrizione',
            );
          }
          for (final c in _stringList(sl['candidates'])) {
            if (!exercises.containsKey(c)) {
              errors.add(
                '$sctx: slot $pattern, candidato $c non è un esercizio',
              );
            }
          }
        }
      }
    }
    for (final ss in _asListOrEmpty(d.data['structureSources'])) {
      final id = _asMapOrNull(ss)?['id'];
      if (id is String && !sources.containsKey(id)) {
        errors.add('${d.path}: template $tid, fonte $id non esiste');
      }
    }
    for (final p in _stringList(d.data['principles'])) {
      if (!principles.containsKey(p)) {
        errors.add('${d.path}: template $tid, principio $p non esiste');
      }
    }
  }

  // Prescrizioni.
  for (final d in prescriptionDocs) {
    for (final p in _stringList(d.data['principles'])) {
      if (!principles.containsKey(p)) {
        errors.add(
          '${d.path}: prescrizione ${d.data['id']}, principio $p non esiste',
        );
      }
    }
  }

  // Gruppi di parametri.
  for (final d in parameterDocs) {
    for (final p in _stringList(d.data['principles'])) {
      if (!principles.containsKey(p)) {
        errors.add(
          '${d.path}: gruppo ${d.data['group']}, principio $p non esiste',
        );
      }
    }
  }

  // Motivazioni.
  for (final d in rationaleDocs) {
    final rid = d.data['ruleId'];
    for (final p in _stringList(d.data['principles'])) {
      if (!principles.containsKey(p)) {
        errors.add('${d.path}: motivazione $rid, principio $p non esiste');
      }
    }
    final from = d.data['sourcesFrom'];
    if (from is String) {
      const prefix = 'parameters/';
      if (!from.startsWith(prefix) ||
          !parameters.containsKey(from.substring(prefix.length))) {
        errors.add(
          '${d.path}: motivazione $rid, sourcesFrom $from non punta a un '
          'gruppo di parametri esistente',
        );
      }
    }
  }

  // Principi.
  for (final d in principleDocs) {
    final pid = d.data['id'];
    for (final s in _asListOrEmpty(d.data['sources'])) {
      final sid = _asMapOrNull(s)?['id'];
      if (sid is String && !sources.containsKey(sid)) {
        errors.add('${d.path}: principio $pid, fonte $sid non esiste');
      }
    }
  }

  final json = <String, Object?>{
    'bundleFormat': 1,
    'equipment': _sortedMap(<String, Object?>{
      'gymTypes': gymTypes,
      'plan': planEquipment,
      'profile': [
        for (final e in profileEquipment)
          if (e is Map && e['id'] is String) e['id'] as String,
      ],
    }),
    'exercises': exercises,
    'kbCommit': kbCommit,
    'muscles': [for (final e in muscles) _plain(e)],
    'parameters': parameters,
    'patterns': [for (final e in patterns) _plain(e)],
    'prescriptions': prescriptions,
    'principles': principles,
    'rationales': rationales,
    'rulesVersion': rulesVersion,
    'setWeights': _plain(setWeights),
    'sources': sources,
    'templates': templates,
  };
  return BundleResult(_sortedMap(json), errors);
}
