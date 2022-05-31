import 'dart:io';

void exitFatal(String errorMessage, int exitCode) {
  stderr.writeln(errorMessage);
  exit(exitCode);
}
