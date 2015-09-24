library panastrong.analyzer_output;

class AnalyzerOutput {
  static final _regexp = new RegExp(
      r'^\[(\w+)\]' // matches the type of notification
      ' (.*?) ' // matches the error statement
      '\\((.*?), line (\\d+), col (\\d+)' // matches the file, line, and col
      ,
      multiLine: true);

  final String type;
  final String error;
  final String file;
  final int line;
  final int col;

  AnalyzerOutput(this.type, this.error, this.file, this.line, this.col);

  static AnalyzerOutput parseOrNull(String content) {
    var allMatches = _regexp.allMatches(content).toList();

    if (allMatches.isEmpty) {
      return null;
    }

    var match = allMatches.single;

    return new AnalyzerOutput(
        match[1], match[2], match[3], int.parse(match[4]), int.parse(match[5]));
  }

  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'file': file,
        'line': line,
        'col': col,
        'error': error,
      };
}
