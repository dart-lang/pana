import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;
import 'package:pool/pool.dart';

final _clear = _isPosixTerminal ? '\x1b[2K\r' : '';
final _cyan = _isPosixTerminal ? '\u001b[36m' : '';
final _yellow = _isPosixTerminal ? '\u001b[33m' : '';
final _red = _isPosixTerminal ? '\u001b[31m' : '';
final _endColor = _isPosixTerminal ? '\u001b[0m' : '';
final _isPosixTerminal =
    !Platform.isWindows && stdioType(stdout) == StdioType.TERMINAL;

main() async {
  int cols;
  try {
    var result = Process.runSync('tput', ['cols']);
    cols = int.parse(result.stdout.trim());
  } catch (_) {
    // nevermind
  }

  var lastLine = true;
  int lastNumber;
  Logger.root.onRecord.listen((log) {
    var number = int.parse(log.loggerName, onError: (s) => null);

    if (number != null && log.error == null && log.level < Level.SEVERE) {
      if (number == lastNumber) {
        stderr.write(_clear);
      } else {
        stderr.writeln();
        lastNumber = number;
      }
      var message = [log.loggerName, log.level, log.message].join('\t');
      if (log.level >= Level.WARNING) {
        message = "$_red$message$_endColor";
      }

      if (cols != null && message.length > cols) {
        message = message.substring(0, cols);
      }

      stderr.write(message);
      lastLine = false;
      lastNumber = number;
    } else {
      if (!lastLine) {
        stderr.writeln();
        lastLine = true;
      }
      stderr.writeln([log.loggerName, log.level, log.message].join('\t'));
      if (log.error != null) {
        stderr.writeln(log.error);
      }
      if (log.stackTrace != null) {
        stderr.writeln(log.stackTrace);
      }
    }
  });

  // dockerName
  var dockerName = 'pkg_clean.${new DateTime.now().millisecondsSinceEpoch}';

  // docker build
  await _runProc('docker', [
    'build',
    '-t',
    dockerName,
    Directory.current.resolveSymbolicLinksSync()
  ]);

  var packages = new File('tool/pkg_sample.txt').readAsLinesSync();

  var pool = new Pool(Platform.numberOfProcessors ~/ 2);

  print("Hacking through ${packages.length} package(s).");
  var count = 0;
  await Future.wait(packages.map((pkg) async {
    var resource = await pool.request();

    var logger = new Logger((++count).toString());
    try {
      // do things here!
      var result = await _runProc('docker', ['run', '--rm', dockerName, pkg],
          logger: logger);
      await _writeResult(dockerName, pkg, result);
    } catch (e, stack) {
      logger.severe("Oops!", e, stack);
    } finally {
      resource.release();
    }
  }));
}

_writeResult(String dockerName, String pkg, String output) async {
  var dir = new Directory(dockerName);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }

  var file = new File(p.join(dockerName, '$pkg.json'));

  await file.writeAsString(output, mode: WRITE_ONLY, flush: true);
}

Stream<String> _split(Stream<List<int>> stream) => stream
    .transform(SYSTEM_ENCODING.decoder)
    .transform(const LineSplitter())
    .map((line) => line.trim());

Future<String> _runProc(String proc, List<String> args, {Logger logger}) async {
  logger ??= Logger.root;

  var stdoutLines = <String>[];
  var stderrLines = <String>[];

  var process = await Process.start(proc, args);

  var items = await Future.wait(<Future<Object>>[
    process.exitCode,
    _split(process.stdout).forEach((outLine) {
      stdoutLines.add(outLine);
      logger.info(outLine);
    }),
    _split(process.stderr).forEach((errLine) {
      stderrLines.add(errLine);
      logger.warning(errLine);
    })
  ]);

  var exitCode = items.first as int;
  if (exitCode != 0) {
    throw stderrLines.join('\n');
  }

  return stdoutLines.join('\n');
}
