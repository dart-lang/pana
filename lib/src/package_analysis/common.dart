import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';

class PackageAnalysisError implements Exception {
  final String message;

  const PackageAnalysisError(this.message);

  @override
  String toString() => 'PackageAnalysisError: $message';
}

abstract class PackageAnalysisContext {
  AnalysisContextCollection get analysisContextCollection;

  AnalysisContext contextFor(String path) =>
      analysisContextCollection.contextFor(path);

  /// Log [message] as warning that something unexpected happened.
  void error(String message);
}
