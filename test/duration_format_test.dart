import 'package:flutter_test/flutter_test.dart';
import 'package:sukoyaka/duration_format.dart';

void main() {
  group('formatInterval', () {
    test('formats hours and minutes together', () {
      expect(formatInterval(const Duration(hours: 2, minutes: 30)), '2h 30m');
    });

    test('formats a whole number of hours as plural "hours"', () {
      expect(formatInterval(const Duration(hours: 3)), '3 hours');
    });

    test('formats exactly one hour as singular "hour"', () {
      expect(formatInterval(const Duration(hours: 1)), '1 hour');
    });

    test('formats minutes under an hour as plural "minutes"', () {
      expect(formatInterval(const Duration(minutes: 45)), '45 minutes');
    });

    test('formats exactly one minute as singular "minute"', () {
      expect(formatInterval(const Duration(minutes: 1)), '1 minute');
    });

    test('formats a zero duration as "0 minutes"', () {
      expect(formatInterval(Duration.zero), '0 minutes');
    });
  });

  group('formatDuration', () {
    test('formats hours, minutes, and seconds together', () {
      expect(
        formatDuration(const Duration(hours: 1, minutes: 24, seconds: 30)),
        '1h 24m 30s',
      );
    });

    test('omits hours under an hour and zero-pads seconds', () {
      expect(formatDuration(const Duration(minutes: 8, seconds: 5)), '8m 05s');
    });

    test('formats a zero duration as "0m 00s"', () {
      expect(formatDuration(Duration.zero), '0m 00s');
    });

    test('rolls seconds over 60 into minutes and hours', () {
      expect(formatDuration(const Duration(seconds: 3661)), '1h 1m 01s');
    });
  });
}
