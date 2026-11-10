import 'dart:convert';
import 'dart:io';

import 'package:barbl_engine/src/bundle/cli.dart';

/// Tutto lo standard input come testo.
String _readStdin() {
  final bytes = <int>[];
  for (var b = stdin.readByteSync(); b != -1; b = stdin.readByteSync()) {
    bytes.add(b);
  }
  return utf8.decode(bytes, allowMalformed: true);
}

Future<void> main(List<String> args) async {
  final outcome = runCli(args, readStdin: _readStdin);
  stdout.write(outcome.out);
  stderr.write(outcome.err);
  await stdout.flush();
  await stderr.flush();
  exit(outcome.code);
}
