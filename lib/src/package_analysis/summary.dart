import 'dart:io';

import 'package:analyzer/dart/analysis/context_builder.dart';
import 'package:analyzer/dart/analysis/context_locator.dart';
import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as path;

import './common.dart';

Future<void> generateSummary(String packageLocation) async {
  if (!await Directory(packageLocation).exists()) {
    exitFatal('Please specify a directory for analysis.', 1);
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
    // but exclude [packageLocation]/lib/src/*.dart
    if (!(path.isWithin(path.join(packageLocation, 'lib'), filePath) &&
        !path.isWithin(path.join(packageLocation, 'lib', 'src'), filePath) &&
        path.extension(filePath) == '.dart')) {
      continue;
    }

    // this file is just part of another library
    if (someResolvedLibrary is NotLibraryButPartResult) {
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
