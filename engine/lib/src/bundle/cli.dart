import 'dart:convert';
import 'dart:io';

import '../generate/generate_plan.dart';
import '../generate/result.dart';
import '../kb/kb_format_exception.dart';
import '../kb/knowledge_base.dart';
import 'bundle_builder.dart';
import 'eval_runner.dart';

/// Esito di un comando: codice di uscita e testo per stdout e stderr.
class CliOutcome {
  CliOutcome(this.code, this.out, this.err);

  final int code;
  final String out;
  final String err;
}

const String cliUsage = '''
Uso:
  barbl_engine bundle --kb <cartella> --out <file> [--kb-commit <sha>]
  barbl_engine generate --profile <file> [--bundle <file> | --kb <cartella>]
  barbl_engine eval [--kb <cartella>]''';

CliOutcome _fail(int code, String message) => CliOutcome(code, '', '$message\n');

CliOutcome _usageError(String message) =>
    CliOutcome(64, '', '$message\n$cliUsage\n');

/// Esegue un comando della riga di comando senza terminare il processo.
CliOutcome runCli(List<String> args) {
  if (args.isEmpty) return _usageError('Manca il comando');
  final options = <String, String>{};
  final rest = args.sublist(1);
  for (var i = 0; i < rest.length; i++) {
    final a = rest[i];
    if (a.startsWith('--') && i + 1 < rest.length) {
      options[a.substring(2)] = rest[i + 1];
      i++;
    } else {
      return _usageError('Argomento non valido: $a');
    }
  }
  switch (args.first) {
    case 'bundle':
      return _bundle(options);
    case 'generate':
      return _generate(options);
    case 'eval':
      return _eval(options);
    default:
      return _usageError('Comando sconosciuto: ${args.first}');
  }
}

CliOutcome _bundle(Map<String, String> options) {
  final kb = options['kb'];
  final out = options['out'];
  if (kb == null || out == null) return _usageError('Servono --kb e --out');
  final kbDir = Directory(kb);
  if (!kbDir.existsSync()) {
    return _fail(1, 'Cartella della KB non trovata: $kb');
  }
  final result = buildBundle(kbDir, kbCommit: options['kb-commit']);
  if (result.errors.isNotEmpty) {
    return _fail(
      1,
      '${result.errors.join('\n')}\n'
      '${result.errors.length} errori: pacchetto non scritto',
    );
  }
  final file = File(out);
  file.parent.createSync(recursive: true);
  file.writeAsStringSync(jsonEncode(result.json));
  return CliOutcome(
    0,
    'Pacchetto scritto in $out (rulesVersion ${result.json['rulesVersion']})\n',
    '',
  );
}

CliOutcome _generate(Map<String, String> options) {
  final profilePath = options['profile'];
  if (profilePath == null) return _usageError('Serve --profile');
  final bundlePath = options['bundle'];
  final kbPath = options['kb'];
  if ((bundlePath == null) == (kbPath == null)) {
    return _usageError('Serve esattamente uno tra --bundle e --kb');
  }
  final profileFile = File(profilePath);
  if (!profileFile.existsSync()) {
    return _fail(1, 'Profilo non trovato: $profilePath');
  }
  final Object? profileJson;
  try {
    profileJson = jsonDecode(profileFile.readAsStringSync());
  } on FormatException catch (e) {
    return _fail(1, 'Profilo non leggibile: ${e.message}');
  }
  if (profileJson is! Map<String, Object?>) {
    return _fail(1, 'Il profilo deve essere un oggetto JSON');
  }

  final Map<String, Object?> bundleJson;
  if (bundlePath != null) {
    final bundleFile = File(bundlePath);
    if (!bundleFile.existsSync()) {
      return _fail(1, 'Pacchetto non trovato: $bundlePath');
    }
    final Object? decoded;
    try {
      decoded = jsonDecode(bundleFile.readAsStringSync());
    } on FormatException catch (e) {
      return _fail(2, 'Pacchetto non leggibile: ${e.message}');
    }
    if (decoded is! Map<String, Object?>) {
      return _fail(2, 'Il pacchetto deve essere un oggetto JSON');
    }
    bundleJson = decoded;
  } else {
    final kbDir = Directory(kbPath!);
    if (!kbDir.existsSync()) {
      return _fail(1, 'Cartella della KB non trovata: $kbPath');
    }
    final built = buildBundle(kbDir);
    if (built.errors.isNotEmpty) return _fail(1, built.errors.join('\n'));
    bundleJson = built.json;
  }

  final KnowledgeBase kb;
  try {
    kb = KnowledgeBase.fromJson(bundleJson);
  } on KbFormatException catch (e) {
    return _fail(2, 'Pacchetto non valido: ${e.message}');
  } catch (e) {
    return _fail(2, 'Pacchetto non valido: $e');
  }

  final result = generatePlan(profileJson, kb);
  switch (result) {
    case Generated(:final plan):
      return CliOutcome(
        0,
        '${const JsonEncoder.withIndent('  ').convert(plan)}\n',
        '',
      );
    case InvalidProfile(:final errors):
      return _fail(2, 'Profilo non valido:\n  ${errors.join('\n  ')}');
    case NotCovered(:final reason, :final detail):
      return _fail(
        2,
        'Profilo non coperto dalla KB (${reason.name}): $detail',
      );
  }
}

CliOutcome _eval(Map<String, String> options) {
  final path = options['kb'] ?? '../kb';
  final kbDir = Directory(path);
  if (!kbDir.existsSync()) {
    return _fail(1, 'Cartella della KB non trovata: $path');
  }
  final cases = runEval(kbDir);
  final out = StringBuffer();
  var failed = 0;
  for (final c in cases) {
    if (c.passed) {
      out.writeln('${c.id} PASS');
    } else {
      failed++;
      out.writeln('${c.id} FAIL');
      for (final f in c.failures) {
        out.writeln('  - $f');
      }
    }
  }
  out.writeln('${cases.length - failed}/${cases.length} casi passati');
  return CliOutcome(failed > 0 ? 1 : 0, out.toString(), '');
}
