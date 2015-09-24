library panastrong.summary;

import 'analyzer_output.dart';

class Summary {
  final String packageName;
  final DateTime packageDownloadTime;
  final Map<String, dynamic> packageDetails;
  final Map<String, List<AnalyzerOutput>> results;

  Summary(this.packageName, this.packageDetails, this.packageDownloadTime,
      this.results);
  Iterable<AnalyzerOutput> get allOutputs => results.values.expand((a) => a);

  Set<String> get resultTypes =>
      allOutputs.fold(new Set<String>(), (Set theSet, AnalyzerOutput item) {
        theSet.add(item.type);
        return theSet;
      });

  int issuesForType(String type) =>
      allOutputs.where((AnalyzerOutput output) => output.type == type).length;

  Map<String, int> get issueSummary =>
      new Map.fromIterable(resultTypes, value: issuesForType);

  Map<String, dynamic> toJson() => <String, dynamic>{
        'packageName': packageName,
        'packageDownloadTime': packageDownloadTime.toIso8601String(),
        'packageDetails': packageDetails,
        'results': results
      };
}
