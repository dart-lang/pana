import 'dart:io';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as path;

Future<void> main(List<String> arguments) async {
  // parse command-line arguments
  final argResults = ArgParser().parse(arguments);
  final paths = argResults.rest;

  if (paths.length != 1) {
    _exitFatal('Please specify a exactly one directory for analysis.', 1);
  }

  final packageLocation = paths.first;
  if (!await FileSystemEntity.isDirectory(paths.first)) {
    _exitFatal('Please specify a directory for analysis.', 1);
  }

  // initialise analyser
  final context = ContextBuilder().createContext(
    contextRoot: ContextLocator().locateRoots(
      // use canonicalize to ensure we get an absolute path
      includedPaths: [path.canonicalize(packageLocation)],
    ).first,
  );

  for (final filePath in context.contextRoot.analyzedFiles()) {
    final session = context.currentSession;
    final someResolvedLibrary = await session.getResolvedLibrary(filePath);

    // match [packageLocation]/lib/*.dart
    if (!(path.isWithin(path.join(packageLocation, 'lib'), filePath) &&
        path.extension(filePath) == '.dart')) {
      continue;
    }

    // ensure that resolving has been successful
    if (someResolvedLibrary is! ResolvedLibraryResult) {
      stderr.writeln('$filePath is not a library');
      continue;
    }

    _traverseLibrary(someResolvedLibrary.element);
  }
}

void _traverseLibrary(LibraryElement libraryElement) {
  print(libraryElement.identifier);
  // TODO
}

void _exitFatal(String errorMessage, int exitCode) {
  stderr.writeln(errorMessage);
  exit(exitCode);
}
