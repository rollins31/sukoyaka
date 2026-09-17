import 'timestamped_entry.dart';

class GrowthEntry implements TimestampedEntry {
  GrowthEntry({
    required this.id,
    required this.time,
    required this.weight,
    required this.weightUnit,
    required this.height,
    required this.heightUnit,
    required this.notes,
  });

  final int id;
  @override
  DateTime time;
  double? weight;
  String weightUnit;
  double? height;
  String heightUnit;
  String notes;

  factory GrowthEntry.fromJson(Map<String, dynamic> json) {
    return GrowthEntry(
      id: json['id'] as int,
      time: DateTime.parse(json['time'] as String),
      weight: json['weight'] == null ? null : (json['weight'] as num).toDouble(),
      weightUnit: json['weightUnit'] as String? ?? 'kg',
      height: json['height'] == null ? null : (json['height'] as num).toDouble(),
      heightUnit: json['heightUnit'] as String? ?? 'cm',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time.toIso8601String(),
      'weight': weight,
      'weightUnit': weightUnit,
      'height': height,
      'heightUnit': heightUnit,
      'notes': notes,
    };
  }
}
