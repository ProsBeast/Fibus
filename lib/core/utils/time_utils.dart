import 'package:intl/intl.dart';

/// Time and date utilities with Indian Standard Time (IST, UTC+5:30) conversion,
/// relative time formatting, countdown generation, and schedule parsing.
abstract final class TimeUtils {
  /// Indian Standard Time offset from UTC (+05:30).
  static const Duration istOffset = Duration(hours: 5, minutes: 30);

  /// Converts a [DateTime] to Indian Standard Time (IST).
  static DateTime toIst(DateTime dateTime) {
    final utc = dateTime.isUtc ? dateTime : dateTime.toUtc();
    return utc.add(istOffset);
  }

  /// Current DateTime in Indian Standard Time (IST).
  static DateTime nowIst() {
    return toIst(DateTime.now());
  }

  /// Formats a [DateTime] in IST as a clock time string (e.g. "08:30 AM" or "14:30").
  static String formatClockTime(
    DateTime dateTime, {
    bool is24Hour = false,
    bool includeSeconds = false,
  }) {
    final ist = toIst(dateTime);
    if (is24Hour) {
      final pattern = includeSeconds ? 'HH:mm:ss' : 'HH:mm';
      return DateFormat(pattern).format(ist);
    } else {
      final pattern = includeSeconds ? 'hh:mm:ss a' : 'hh:mm a';
      return DateFormat(pattern).format(ist);
    }
  }

  /// Formats a [DateTime] into a friendly relative description (e.g. "just now", "3 min ago").
  static String formatRelativeTime(DateTime dateTime) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (difference.isNegative) {
      // Future time
      final futureDiff = dateTime.difference(now);
      if (futureDiff.inSeconds < 45) return 'in a few seconds';
      if (futureDiff.inMinutes < 60) {
        final m = futureDiff.inMinutes;
        return 'in $m ${m == 1 ? 'min' : 'mins'}';
      }
      if (futureDiff.inHours < 24) {
        final h = futureDiff.inHours;
        return 'in $h ${h == 1 ? 'hour' : 'hours'}';
      }
      return DateFormat('MMM d, h:mm a').format(toIst(dateTime));
    }

    if (difference.inSeconds < 15) {
      return 'just now';
    }
    if (difference.inSeconds < 60) {
      return '${difference.inSeconds}s ago';
    }
    if (difference.inMinutes < 60) {
      final mins = difference.inMinutes;
      return '$mins ${mins == 1 ? 'min' : 'mins'} ago';
    }
    if (difference.inHours < 24) {
      final hours = difference.inHours;
      return '$hours ${hours == 1 ? 'hr' : 'hrs'} ago';
    }
    if (difference.inDays == 1) {
      return 'yesterday';
    }
    if (difference.inDays < 7) {
      return '${difference.inDays} days ago';
    }

    return DateFormat('MMM d, yyyy').format(toIst(dateTime));
  }

  /// Formats a duration in seconds into a countdown clock string (e.g. "5:23", "0:45", "1:15:30").
  static String formatCountdown(int totalSeconds) {
    if (totalSeconds <= 0) return '0:00';

    final int hours = totalSeconds ~/ 3600;
    final int minutes = (totalSeconds % 3600) ~/ 60;
    final int seconds = totalSeconds % 60;

    final secondsStr = seconds.toString().padLeft(2, '0');

    if (hours > 0) {
      final minutesStr = minutes.toString().padLeft(2, '0');
      return '$hours:$minutesStr:$secondsStr';
    }

    return '$minutes:$secondsStr';
  }

  /// Formats ETA in seconds into a friendly human-readable label (e.g. "Arriving now", "4 mins", "1 hr 12 mins").
  static String formatEtaLabel(int etaSeconds) {
    if (etaSeconds <= 30) {
      return 'Arriving now';
    }
    if (etaSeconds < 60) {
      return '< 1 min';
    }

    final int minutes = (etaSeconds / 60).round();
    if (minutes < 60) {
      return '$minutes ${minutes == 1 ? 'min' : 'mins'}';
    }

    final int hours = minutes ~/ 60;
    final int remainingMins = minutes % 60;
    if (remainingMins == 0) {
      return '$hours ${hours == 1 ? 'hr' : 'hrs'}';
    }

    return '$hours hr $remainingMins min';
  }

  /// Parses a time string (e.g., "08:30", "14:45", "8:15 AM", "8:15 PM") into hour and minute.
  static ({int hour, int minute}) parseTimeString(String timeStr) {
    final clean = timeStr.trim().toUpperCase();

    // Check for 12-hour AM/PM format
    final isPm = clean.contains('PM');
    final isAm = clean.contains('AM');

    final numbersOnly = clean.replaceAll(RegExp(r'[^0-9:]'), '');
    final parts = numbersOnly.split(':');

    if (parts.length >= 2) {
      int hour = int.tryParse(parts[0]) ?? 0;
      final int minute = int.tryParse(parts[1]) ?? 0;

      if (isPm && hour < 12) {
        hour += 12;
      } else if (isAm && hour == 12) {
        hour = 0;
      }

      return (hour: hour, minute: minute);
    }

    return (hour: 0, minute: 0);
  }

  /// Combines today's date in IST with a schedule time string (HH:mm) into a full [DateTime].
  static DateTime scheduledTimeToDateTimeToday(String timeStr) {
    final parsed = parseTimeString(timeStr);
    final now = nowIst();
    return DateTime(now.year, now.month, now.day, parsed.hour, parsed.minute);
  }

  /// Calculates remaining seconds from now (IST) until a scheduled time string.
  ///
  /// If the time has already passed today, returns 0.
  static int secondsUntilScheduledTime(String timeStr) {
    final target = scheduledTimeToDateTimeToday(timeStr);
    final now = nowIst();
    final diff = target.difference(now).inSeconds;
    return diff > 0 ? diff : 0;
  }
}
