import 'package:analyzer/dart/analysis/analysis_context.dart';
import 'package:analyzer/dart/analysis/analysis_context_collection.dart';

abstract class PackageAnalysisContext {
  AnalysisContextCollection get analysisContextCollection;

  AnalysisContext contextFor(String path) =>
      analysisContextCollection.contextFor(path);

  /// Log [message] as warning that something unexpected happened.
  void warning(String message);
}
