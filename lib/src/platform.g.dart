// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.platform;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

DartPlatform _$DartPlatformFromJson(Map<String, dynamic> json) =>
    new DartPlatform(
        json['worksEverywhere'] as bool,
        (json['restrictedTo'] as List)?.map((e) => e as String)?.toList(),
        json['reason'] as String);

abstract class _$DartPlatformSerializerMixin {
  bool get worksEverywhere;
  List<String> get restrictedTo;
  String get reason;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'worksEverywhere': worksEverywhere,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('restrictedTo', restrictedTo);
    writeNotNull('reason', reason);
    return val;
  }
}
