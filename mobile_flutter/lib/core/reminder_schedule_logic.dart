import 'package:timezone/timezone.dart' as tz;

tz.TZDateTime nextLocalReminder(
  tz.TZDateTime now, {
  required int hour,
  required int minute,
}) {
  var next = tz.TZDateTime(
    tz.local,
    now.year,
    now.month,
    now.day,
    hour,
    minute,
  );
  if (!next.isAfter(now)) {
    next = tz.TZDateTime(
      tz.local,
      now.year,
      now.month,
      now.day + 1,
      hour,
      minute,
    );
  }
  return next;
}
