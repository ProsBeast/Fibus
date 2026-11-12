/// Timetable calendar helpers. Pure functions, no Flutter or Firebase.
library;

/// Parses `HH:mm` into hour and minute, or null when malformed.
({int hour, int minute})? parseHhMm(String hhmm) {
  final parts = hhmm.split(':');
  if (parts.length < 2) return null;
  final h = int.tryParse(parts[0].trim());
  final m = int.tryParse(parts[1].trim());
  if (h == null || m == null || h < 0 || h > 23 || m < 0 || m > 59) return null;
  return (hour: h, minute: m);
}

/// Timetable `HH:mm` as the 12-hour form used across the apps: `7:59 am`.
/// Returns the input unchanged when it cannot be parsed.
String formatTimetable(String hhmm) {
  final t = parseHhMm(hhmm);
  if (t == null) return hhmm;
  final h = t.hour % 12 == 0 ? 12 : t.hour % 12;
  return '$h:${t.minute.toString().padLeft(2, '0')} ${t.hour < 12 ? 'am' : 'pm'}';
}

/// The next time the bus is scheduled at a stop, at or after [now].
///
/// [serviceDays] are ISO weekdays (Mon = 1 … Sun = 7); empty means every day.
/// Today's run still counts until [grace] after its scheduled time, because
/// buses run late; after that, or when [skipToday] is set (the bus was seen
/// passing the stop), the next service day is returned.
///
/// Returns null only when [hhmm] cannot be parsed.
DateTime? nextServiceArrival({
  required String hhmm,
  required List<int> serviceDays,
  required DateTime now,
  Duration grace = const Duration(minutes: 30),
  bool skipToday = false,
}) {
  final time = parseHhMm(hhmm);
  if (time == null) return null;
  final days = serviceDays.where((d) => d >= 1 && d <= 7).toSet();

  for (var offset = 0; offset <= 7; offset++) {
    final day = DateTime(now.year, now.month, now.day + offset);
    if (days.isNotEmpty && !days.contains(day.weekday)) continue;
    final arrival = DateTime(
      day.year,
      day.month,
      day.day,
      time.hour,
      time.minute,
    );
    if (offset == 0) {
      if (skipToday || now.isAfter(arrival.add(grace))) continue;
    }
    return arrival;
  }
  return null;
}

/// `yyyy-MM-dd` for the local calendar day of [t].
String serviceDateKey(DateTime t) =>
    '${t.year.toString().padLeft(4, '0')}-'
    '${t.month.toString().padLeft(2, '0')}-'
    '${t.day.toString().padLeft(2, '0')}';

/// Empty for today, `tomorrow`, otherwise the weekday name. For phrases
/// such as "Leave tomorrow by" and "Alerts for Monday".
String relativeDayLabel(DateTime when, DateTime now) {
  final a = DateTime(when.year, when.month, when.day);
  final b = DateTime(now.year, now.month, now.day);
  final diff = a.difference(b).inHours / 24;
  final days = diff.round();
  if (days <= 0) return '';
  if (days == 1) return 'tomorrow';
  const names = [
    'Monday',
    'Tuesday',
    'Wednesday',
    'Thursday',
    'Friday',
    'Saturday',
    'Sunday',
  ];
  return names[when.weekday - 1];
}
