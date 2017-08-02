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
    var $map = <String, dynamic>{};
    void $writeNotNull(String key, dynamic value) {
      if (value != null) {
        $map[key] = value;
      }
    }

    $map['name'] = name;
    $writeNotNull('version', version);
    return $map;
  }
}
