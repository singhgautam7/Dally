// Small, dependency-free formatters shared across games and the shell. All
// numerals render in JetBrains Mono with tabular figures at the widget layer.

/// `83` → `01:23`, `3661` → `61:01`. Negative clamps to zero.
String formatClock(int totalSeconds) {
  final s = totalSeconds < 0 ? 0 : totalSeconds;
  final m = s ~/ 60;
  final r = s % 60;
  return '${m.toString().padLeft(2, '0')}:${r.toString().padLeft(2, '0')}';
}

/// `11264` → `11 264` (thin space grouping, matching the mockups).
String formatGrouped(num n) {
  final digits = n.round().abs().toString();
  final buf = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buf.write(' ');
    buf.write(digits[i]);
  }
  return '${n < 0 ? '-' : ''}$buf';
}

/// `5400` → `1h 30m`, `240` → `4m`, `0` → `—`. Used where a duration is a
/// summary rather than a clock.
String formatDurationShort(int seconds) {
  if (seconds <= 0) return '—';
  final h = seconds ~/ 3600;
  final m = (seconds % 3600) ~/ 60;
  if (h > 0) return m > 0 ? '${h}h ${m}m' : '${h}h';
  if (m > 0) return '${m}m';
  return '${seconds}s';
}

/// `2026-08-24` → `24 Aug`. Day headers on the Activity screen.
String formatDayLabel(DateTime day, {DateTime? now}) {
  final today = DateTime(
      (now ?? DateTime.now()).year, (now ?? DateTime.now()).month, (now ?? DateTime.now()).day);
  final d = DateTime(day.year, day.month, day.day);
  final diff = today.difference(d).inDays;
  if (diff == 0) return 'Today';
  if (diff == 1) return 'Yesterday';
  const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
  final base = '${d.day} ${months[d.month - 1]}';
  return d.year == today.year ? base : '$base ${d.year}';
}

/// `14:05` in 24-hour time — the clock column on a session row.
String formatTimeOfDay(DateTime t) {
  final l = t.toLocal();
  return '${l.hour.toString().padLeft(2, '0')}:${l.minute.toString().padLeft(2, '0')}';
}
