// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.license;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

License _$LicenseFromJson(Map<String, dynamic> json) =>
    new License(json['name'] as String, json['version'] as String);

abstract class _$LicenseSerializerMixin {
  String get name;
  String get version;
  Map<String, dynamic> toJson() {
    var val = <String, dynamic>{
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
