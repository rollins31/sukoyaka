import 'timestamped_entry.dart';

class FeedingEntry implements TimestampedEntry {
  FeedingEntry({
    required this.id,
    required this.time,
    required this.milkType,
    required this.amount,
    required this.amountUnit,
    required this.notes,
  });

  final int id;
  @override
  DateTime time;
  String milkType;
  double? amount;
  String amountUnit;
  String notes;

  factory FeedingEntry.fromJson(Map<String, dynamic> json) {
    return FeedingEntry(
      id: json['id'] as int,
      time: DateTime.parse(json['time'] as String),
      milkType: json['milkType'] as String? ?? 'Other',
      amount: json['amount'] == null ? null : (json['amount'] as num).toDouble(),
      amountUnit: json['amountUnit'] as String? ?? 'ml',
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'time': time.toIso8601String(),
      'milkType': milkType,
      'amount': amount,
      'amountUnit': amountUnit,
      'notes': notes,
    };
  }
}
