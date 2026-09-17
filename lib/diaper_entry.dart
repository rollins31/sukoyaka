import 'timestamped_entry.dart';

class DiaperEntry implements TimestampedEntry {
  DiaperEntry({
    required this.id,
    required this.time,
    this.pee = false,
    this.poo = false,
    this.notes = '',
  });

  final int id;
  @override
  DateTime time;
  bool pee;
  bool poo;
  String notes;

  /// Short human-readable summary of what the diaper contained.
  String get contentsLabel {
    if (pee && poo) return 'Pee & poo';
    if (pee) return 'Pee';
    if (poo) return 'Poo';
    return 'Dry / changed';
  }

  factory DiaperEntry.fromJson(Map<String, dynamic> json) {
    return DiaperEntry(
      id: json['id'] as int,
      time: DateTime.parse(json['time'] as String),
      pee: json['pee'] as bool? ?? false,
      poo: json['poo'] as bool? ?? false,
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time.toIso8601String(),
      'pee': pee,
      'poo': poo,
      'notes': notes,
    };
  }
}
