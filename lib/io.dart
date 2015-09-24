import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' show ByteStream;

import 'error_group.dart';
import 'logging.dart';

Stream<String> getLines(Stream<List<int>> bytes) =>
    const LineSplitter().bind(SYSTEM_ENCODING.decoder.bind(bytes));

/// Extracts a `.tar.gz` file from [stream] to [destination].
Future extractTarGz(Stream<List<int>> stream, String destination) async {
  log.fine("Extracting .tar.gz stream to $destination.");

  var args = ["--extract", "--gunzip", "--directory", destination];
  if (_noUnknownKeyword) {
    // BSD tar (the default on OS X) can insert strange headers to a tarfile
    // that GNU tar (the default on Linux) is unable to understand. This will
    // cause GNU tar to emit a number of harmless but scary-looking warnings
    // which are silenced by this flag.
    args.insert(0, "--warning=no-unknown-keyword");
  }

  var process = await startProcess("tar", args);

  // Ignore errors on process.std{out,err}. They'll be passed to
  // process.exitCode, and we don't want them being top-levelled by
  // std{out,err}Sink.
  store(process.stdout.handleError((_) {}), stdout, closeSink: false);
  store(process.stderr.handleError((_) {}), stderr, closeSink: false);
  var results =
      await Future.wait([store(stream, process.stdin), process.exitCode]);

  var exitCode = results[1];
  if (exitCode != 0) {
    throw new Exception("Failed to extract .tar.gz stream to $destination "
        "(exit code $exitCode).");
  }
  log.fine("Extracted .tar.gz stream to $destination. Exit code $exitCode.");
}

// TODO(nweiz): remove this when issue 7786 is fixed.
/// Pipes all data and errors from [stream] into [sink].
///
/// When [stream] is done, the returned [Future] is completed and [sink] is
/// closed if [closeSink] is true.
///
/// When an error occurs on [stream], that error is passed to [sink]. If
/// [cancelOnError] is true, [Future] will be completed successfully and no
/// more data or errors will be piped from [stream] to [sink]. If
/// [cancelOnError] and [closeSink] are both true, [sink] will then be
/// closed.
Future store(Stream stream, EventSink sink,
    {bool cancelOnError: true, bool closeSink: true}) {
  var completer = new Completer();
  stream.listen(sink.add, onError: (e, stackTrace) {
    sink.addError(e, stackTrace);
    if (cancelOnError) {
      completer.complete();
      if (closeSink) sink.close();
    }
  }, onDone: () {
    if (closeSink) sink.close();
    completer.complete();
  }, cancelOnError: cancelOnError);
  return completer.future;
}

/// Whether to include "--warning=no-unknown-keyword" when invoking tar.
///
/// This flag quiets warnings that come from opening OS X-generated tarballs on
/// Linux, but only GNU tar >= 1.26 supports it.
final bool _noUnknownKeyword = _computeNoUnknownKeyword();
bool _computeNoUnknownKeyword() {
  if (!Platform.isLinux) return false;
  var result = Process.runSync("tar", ["--version"]);
  if (result.exitCode != 0) {
    throw new ProcessException('tar', ['--version'],
        "Failed to run tar (exit code ${result.exitCode}):\n${result.stderr}");
  }

  var match =
      new RegExp(r"^tar \(GNU tar\) (\d+).(\d+)\n").firstMatch(result.stdout);
  if (match == null) return false;

  var major = int.parse(match[1]);
  var minor = int.parse(match[2]);
  return major >= 2 || (major == 1 && minor >= 23);
}

/// Spawns the process located at [executable], passing in [args].
///
/// Returns a [Future] that will complete with the [Process] once it's been
/// started.
///
/// The spawned process will inherit its parent's environment variables. If
/// [environment] is provided, that will be used to augment (not replace) the
/// the inherited variables.
Future<PubProcess> startProcess(String executable, List<String> args,
    {workingDir, Map<String, String> environment}) {
  return _doProcess(Process.start, executable, args, workingDir, environment)
      .then((ioProcess) {
    var process = new PubProcess(ioProcess);
    return process;
  });
}

/// A wrapper around [Process] that exposes `dart:async`-style APIs.
class PubProcess {
  /// The underlying `dart:io` [Process].
  final Process _process;

  /// The mutable field for [stdin].
  EventSink<List<int>> _stdin;

  /// The mutable field for [stdinClosed].
  Future _stdinClosed;

  /// The mutable field for [stdout].
  ByteStream _stdout;

  /// The mutable field for [stderr].
  ByteStream _stderr;

  /// The mutable field for [exitCode].
  Future<int> _exitCode;

  /// The sink used for passing data to the process's standard input stream.
  ///
  /// Errors on this stream are surfaced through [stdinClosed], [stdout],
  /// [stderr], and [exitCode], which are all members of an [ErrorGroup].
  EventSink<List<int>> get stdin => _stdin;

  // TODO(nweiz): write some more sophisticated Future machinery so that this
  // doesn't surface errors from the other streams/futures, but still passes its
  // unhandled errors to them. Right now it's impossible to recover from a stdin
  // error and continue interacting with the process.
  /// A [Future] that completes when [stdin] is closed, either by the user or by
  /// the process itself.
  ///
  /// This is in an [ErrorGroup] with [stdout], [stderr], and [exitCode], so any
  /// error in process will be passed to it, but won't reach the top-level error
  /// handler unless nothing has handled it.
  Future get stdinClosed => _stdinClosed;

  /// The process's standard output stream.
  ///
  /// This is in an [ErrorGroup] with [stdinClosed], [stderr], and [exitCode],
  /// so any error in process will be passed to it, but won't reach the
  /// top-level error handler unless nothing has handled it.
  ByteStream get stdout => _stdout;

  /// The process's standard error stream.
  ///
  /// This is in an [ErrorGroup] with [stdinClosed], [stdout], and [exitCode],
  /// so any error in process will be passed to it, but won't reach the
  /// top-level error handler unless nothing has handled it.
  ByteStream get stderr => _stderr;

  /// A [Future] that will complete to the process's exit code once the process
  /// has finished running.
  ///
  /// This is in an [ErrorGroup] with [stdinClosed], [stdout], and [stderr], so
  /// any error in process will be passed to it, but won't reach the top-level
  /// error handler unless nothing has handled it.
  Future<int> get exitCode => _exitCode;

  /// Creates a new [PubProcess] wrapping [process].
  PubProcess(Process process) : _process = process {
    var errorGroup = new ErrorGroup();

    var pair = consumerToSink(process.stdin);
    _stdin = pair.first;
    _stdinClosed = errorGroup.registerFuture(pair.last);

    _stdout = new ByteStream(errorGroup.registerStream(process.stdout));
    _stderr = new ByteStream(errorGroup.registerStream(process.stderr));

    var exitCodeCompleter = new Completer();
    _exitCode = errorGroup.registerFuture(exitCodeCompleter.future);
    _process.exitCode.then((code) => exitCodeCompleter.complete(code));
  }

  /// Sends [signal] to the underlying process.
  bool kill([ProcessSignal signal = ProcessSignal.SIGTERM]) =>
      _process.kill(signal);
}

/// Returns a [EventSink] that pipes all data to [consumer] and a [Future] that
/// will succeed when [EventSink] is closed or fail with any errors that occur
/// while writing.
Pair<EventSink, Future> consumerToSink(StreamConsumer consumer) {
  var controller = new StreamController(sync: true);
  var done = controller.stream.pipe(consumer);
  return new Pair<EventSink, Future>(controller.sink, done);
}

/// A pair of values.
class Pair<E, F> {
  E first;
  F last;

  Pair(this.first, this.last);

  String toString() => '($first, $last)';

  bool operator ==(other) {
    if (other is! Pair) return false;
    return other.first == first && other.last == last;
  }

  int get hashCode => first.hashCode ^ last.hashCode;
}

/// Calls [fn] with appropriately modified arguments.
///
/// [fn] should have the same signature as [Process.start], except that the
/// returned value may have any return type.
_doProcess(Function fn, String executable, List<String> args, String workingDir,
    Map<String, String> environment) {
  // TODO(rnystrom): Should dart:io just handle this?
  // Spawning a process on Windows will not look for the executable in the
  // system path. So, if executable looks like it needs that (i.e. it doesn't
  // have any path separators in it), then spawn it through a shell.
  if ((Platform.operatingSystem == "windows") &&
      (executable.indexOf('\\') == -1)) {
    args = flatten(["/c", executable, args]);
    executable = "cmd";
  }

  log.info(
      "$executable ${args.join(' ')} ${workingDir == null ? '.' : workingDir}");

  return fn(executable, args,
      workingDirectory: workingDir, environment: environment);
}

/// Flattens nested lists inside an iterable into a single list containing only
/// non-list elements.
List flatten(Iterable nested) {
  var result = [];
  helper(list) {
    for (var element in list) {
      if (element is List) {
        helper(element);
      } else {
        result.add(element);
      }
    }
  }
  helper(nested);
  return result;
}
