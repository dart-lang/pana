// GENERATED CODE - DO NOT MODIFY BY HAND

part of pana.health;

// **************************************************************************
// Generator: JsonSerializableGenerator
// **************************************************************************

Fitness _$FitnessFromJson(Map<String, dynamic> json) => new Fitness(
    (json['value'] as num)?.toDouble(), (json['total'] as num)?.toDouble());

abstract class _$FitnessSerializerMixin {
  double get value;
  double get total;
  Map<String, dynamic> toJson() =>
      <String, dynamic>{'value': value, 'total': total};
}
