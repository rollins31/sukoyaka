class SleepEntry {
  SleepEntry({
    required this.id,
    required this.start,
    this.end,
    this.notes = '',
  });

  final int id;
  DateTime start;

  /// `null` while the baby is still sleeping (session in progress).
  DateTime? end;
  String notes;

  bool get isInProgress => end == null;

  /// Elapsed time for a finished session, or `null` if still in progress.
  Duration? get duration => end?.difference(start);

  factory SleepEntry.fromJson(Map<String, dynamic> json) {
    return SleepEntry(
      id: json['id'] as int,
      start: DateTime.parse(json['start'] as String),
      end: json['end'] == null ? null : DateTime.parse(json['end'] as String),
      notes: json['notes'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'start': start.toIso8601String(),
      'end': end?.toIso8601String(),
      'notes': notes,
    };
  }
}
