// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.analyzer_output;

// **************************************************************************
// Generator: JsonSerializableGenerator
// Target: class AnalyzerOutput
// **************************************************************************

AnalyzerOutput _$AnalyzerOutputFromJson(Map json) => new AnalyzerOutput(
    json['type'] as String,
    json['error'] as String,
    json['file'] as String,
    json['line'] as int,
    json['col'] as int);

abstract class _$AnalyzerOutputSerializerMixin {
  String get type;
  String get error;
  String get file;
  int get line;
  int get col;
  Map<String, dynamic> toJson() => <String, dynamic>{
        'type': type,
        'error': error,
        'file': file,
        'line': line,
        'col': col
      };
}
