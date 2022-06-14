import 'dart:io';

import 'package:analyzer/dart/analysis/results.dart';
import 'package:analyzer/dart/element/element.dart';
import 'package:path/path.dart' as path;

import 'common.dart';

Future<void> generateSummary(
  PackageAnalysisContext packageAnalysisContext,
  String packageLocation,
) async {
  var collection = packageAnalysisContext.analysisContextCollection;

  for (var context in collection.contexts) {
    for (var filePath in context.contextRoot.analyzedFiles()) {
      final session = context.currentSession;
      final library = await session.getResolvedLibrary(filePath);

      // match [packageLocation]/lib/*.dart
      // but exclude [packageLocation]/lib/src/*.dart
      if (!(path.isWithin(path.join(packageLocation, 'lib'), filePath) &&
          !path.isWithin(path.join(packageLocation, 'lib', 'src'), filePath) &&
          path.extension(filePath) == '.dart')) {
        continue;
      }

      // this file is just part of another library
      if (library is NotLibraryButPartResult) {
        continue;
      }

      // ensure that resolving has been successful
      if (library is! ResolvedLibraryResult) {
        stderr.writeln('analysis of $filePath as a library failed');
        continue;
      }

      _traverseLibrary(library.element);
    }
  }
}

void _traverseLibrary(LibraryElement libraryElement) {
  print(libraryElement.identifier);
  // TODO
}
