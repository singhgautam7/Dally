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
