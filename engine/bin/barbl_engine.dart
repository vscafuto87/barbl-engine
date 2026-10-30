import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/src/bundle/bundle_builder.dart';

const _usage = '''
Uso:
  barbl_engine bundle --kb <cartella> --out <file> [--kb-commit <sha>]''';

Future<void> main(List<String> args) async {
  if (args.isEmpty || args.first != 'bundle') {
    stderr.writeln(_usage);
    exit(64);
  }
  final options = <String, String>{};
  final rest = args.sublist(1);
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
  final kb = options['kb'];
  final out = options['out'];
  if (kb == null || out == null) {
    stderr.writeln('Servono --kb e --out');
    stderr.writeln(_usage);
    exit(64);
  }
  final kbDir = Directory(kb);
  if (!kbDir.existsSync()) {
    stderr.writeln('Cartella della KB non trovata: $kb');
    exit(1);
  }
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
