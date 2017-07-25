// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.analyzer_output;

// **************************************************************************
// Generator: JsonSerializableGenerator
// Target: class AnalyzerOutput
// **************************************************************************

AnalyzerOutput _$AnalyzerOutputFromJson(Map<String, dynamic> json) =>
    new AnalyzerOutput(json['type'] as String, json['error'] as String,
        json['file'] as String, json['line'] as int, json['col'] as int);

abstract class _$AnalyzerOutputSerializerMixin {
  String get type;
  String get file;
  int get line;
  int get col;
  String get error;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'file': file,
        'line': line,
        'col': col,
        'error': error
      };
}
