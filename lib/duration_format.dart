/// Reminder interval as e.g. "2h 30m", "2 hours", or "45 minutes".
String formatInterval(Duration interval) {
  final hours = interval.inHours;
  final minutes = interval.inMinutes % 60;
  if (hours > 0 && minutes > 0) {
    return '${hours}h ${minutes}m';
  }
  if (hours > 0) {
    return '$hours hour${hours == 1 ? '' : 's'}';
  }
  return '$minutes minute${minutes == 1 ? '' : 's'}';
}

/// Compact duration for sleep sessions, e.g. "1h 24m 30s" or "8m 05s".
String formatDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes % 60;
  final seconds = duration.inSeconds % 60;
  final secondsStr = seconds.toString().padLeft(2, '0');
  if (hours > 0) {
    return '${hours}h ${minutes}m ${secondsStr}s';
  }
  return '${minutes}m ${secondsStr}s';
}
