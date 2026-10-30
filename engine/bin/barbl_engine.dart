import 'dart:io';

import 'package:barbl_engine/src/bundle/cli.dart';

Future<void> main(List<String> args) async {
  final outcome = runCli(args);
  stdout.write(outcome.out);
  stderr.write(outcome.err);
  await stdout.flush();
  await stderr.flush();
  exit(outcome.code);
}
