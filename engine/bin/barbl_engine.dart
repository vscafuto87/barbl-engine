import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/barbl_engine.dart';
import 'package:barbl_engine/src/bundle/bundle_builder.dart';
import 'package:barbl_engine/src/bundle/eval_runner.dart';

const _usage = '''
Uso:
  barbl_engine bundle --kb <cartella> --out <file> [--kb-commit <sha>]
  barbl_engine generate --profile <file> [--bundle <file> | --kb <cartella>]
  barbl_engine eval [--kb <cartella>]''';

Map<String, String> _parseOptions(List<String> rest) {
  final options = <String, String>{};
  for (var i = 0; i < rest.length; i++) {
    final a = rest[i];
    if (a.startsWith('--') && i + 1 < rest.length) {
      options[a.substring(2)] = rest[i + 1];
      i++;
    } else {
      stderr.writeln('Argomento non valido: $a');
      stderr.writeln(_usage);
      exit(64);
    }
  }
  return options;
}

Future<void> main(List<String> args) async {
  if (args.isEmpty) {
    stderr.writeln(_usage);
    exit(64);
  }
  final options = _parseOptions(args.sublist(1));
  switch (args.first) {
    case 'bundle':
      _bundle(options);
    case 'generate':
      _generate(options);
    case 'eval':
      _eval(options);
    default:
      stderr.writeln(_usage);
      exit(64);
  }
}

Directory _kbDirOrExit(String path) {
  final dir = Directory(path);
  if (!dir.existsSync()) {
    stderr.writeln('Cartella della KB non trovata: $path');
    exit(1);
  }
  return dir;
}

void _bundle(Map<String, String> options) {
  final kb = options['kb'];
  final out = options['out'];
  if (kb == null || out == null) {
    stderr.writeln('Servono --kb e --out');
    stderr.writeln(_usage);
    exit(64);
  }
  final kbDir = _kbDirOrExit(kb);
  final result = buildBundle(kbDir, kbCommit: options['kb-commit']);
  if (result.errors.isNotEmpty) {
    for (final e in result.errors) {
      stderr.writeln(e);
    }
    stderr.writeln('${result.errors.length} errori: pacchetto non scritto');
    exit(1);
  }
  final file = File(out);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(result.json));
  stdout.writeln(
    'Pacchetto scritto in $out (rulesVersion ${result.json['rulesVersion']})',
  );
}

void _generate(Map<String, String> options) {
  final profilePath = options['profile'];
  if (profilePath == null) {
    stderr.writeln('Serve --profile');
    stderr.writeln(_usage);
    exit(64);
  }
  final bundlePath = options['bundle'];
  final kbPath = options['kb'];
  if ((bundlePath == null) == (kbPath == null)) {
    stderr.writeln('Serve esattamente uno tra --bundle e --kb');
    stderr.writeln(_usage);
    exit(64);
  }
  final profileFile = File(profilePath);
  if (!profileFile.existsSync()) {
    stderr.writeln('Profilo non trovato: $profilePath');
    exit(1);
  }
  final Object? profileJson;
  try {
    profileJson = jsonDecode(profileFile.readAsStringSync());
  } on FormatException catch (e) {
    stderr.writeln('Profilo non leggibile: ${e.message}');
    exit(1);
  }
  if (profileJson is! Map<String, Object?>) {
    stderr.writeln('Il profilo deve essere un oggetto JSON');
    exit(1);
  }

  Map<String, Object?> bundleJson;
  if (bundlePath != null) {
    final bundleFile = File(bundlePath);
    if (!bundleFile.existsSync()) {
      stderr.writeln('Pacchetto non trovato: $bundlePath');
      exit(1);
    }
    final decoded = jsonDecode(bundleFile.readAsStringSync());
    if (decoded is! Map<String, Object?>) {
      stderr.writeln('Il pacchetto deve essere un oggetto JSON');
      exit(1);
    }
    bundleJson = decoded;
  } else {
    final built = buildBundle(_kbDirOrExit(kbPath!));
    if (built.errors.isNotEmpty) {
      for (final e in built.errors) {
        stderr.writeln(e);
      }
      exit(1);
    }
    bundleJson = built.json;
  }

  final KnowledgeBase kb;
  try {
    kb = KnowledgeBase.fromJson(bundleJson);
  } on KbFormatException catch (e) {
    stderr.writeln('Pacchetto non valido: ${e.message}');
    exit(1);
  }

  final result = generatePlan(profileJson, kb);
  switch (result) {
    case Generated(:final plan):
      stdout.writeln(const JsonEncoder.withIndent('  ').convert(plan));
    case InvalidProfile(:final errors):
      stderr.writeln('Profilo non valido:');
      for (final e in errors) {
        stderr.writeln('  $e');
      }
      exit(2);
    case NotCovered(:final reason, :final detail):
      stderr.writeln(
        'Profilo non coperto dalla KB (${reason.name}): $detail',
      );
      exit(2);
  }
}

void _eval(Map<String, String> options) {
  final kbDir = _kbDirOrExit(options['kb'] ?? '../kb');
  final cases = runEval(kbDir);
  var failed = 0;
  for (final c in cases) {
    if (c.passed) {
      stdout.writeln('${c.id} PASS');
    } else {
      failed++;
      stdout.writeln('${c.id} FAIL');
      for (final f in c.failures) {
        stdout.writeln('  - $f');
      }
    }
  }
  stdout.writeln('${cases.length - failed}/${cases.length} casi passati');
  if (failed > 0) exit(1);
}
