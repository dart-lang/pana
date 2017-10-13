// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.license;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

LicenseFile _$LicenseFileFromJson(Map<String, dynamic> json) =>
    new LicenseFile(json['path'] as String, json['name'] as String,
        version: json['version'] as String);

abstract class _$LicenseFileSerializerMixin {
  String get path;
  String get name;
  String get version;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
      'path': path,
      'name': name,
    };

    void writeNotNull(String key, dynamic value) {
      if (value != null) {
        val[key] = value;
      }
    }

    writeNotNull('version', version);
    return val;
  }
}
