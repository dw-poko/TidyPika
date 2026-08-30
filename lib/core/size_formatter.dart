const List<String> _units = ['B', 'KB', 'MB', 'GB', 'TB', 'PB'];

String formatSize(int bytes) {
  if (bytes <= 0) return '0 B';

  var size = bytes.toDouble();
  for (final unit in _units) {
    if (size < 1024) {
      return unit == 'B'
          ? '${size.toStringAsFixed(0)} B'
          : '${size.toStringAsFixed(1)} $unit';
    }
    size /= 1024;
  }

  return '${size.toStringAsFixed(1)} PB';
}

/// Groups digits in threes. Written out rather than pulled from `intl` to keep
/// the dependency list — and the shipped binary — small.
String formatCount(int value) {
  final digits = value.abs().toString();
  final buffer = StringBuffer();

  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) buffer.write(',');
    buffer.write(digits[i]);
  }

  return value < 0 ? '-$buffer' : buffer.toString();
}

/// Elapsed time split for display: whole minutes, and the seconds left over.
///
/// Under a minute the seconds keep their fraction, because the difference
/// between half a second and four is the whole of what a short scan has to
/// say. Past a minute the fraction stops meaning anything.
(int, double) elapsedParts(Duration elapsed) {
  final minutes = elapsed.inMinutes;

  return (minutes, elapsed.inMilliseconds / 1000 - minutes * 60);
}

/// A date as year-month-day.
///
/// The one order every language this app speaks reads the same way, and the
/// one that sorts. Nothing here needs the time of day.
String formatDate(DateTime value) {
  final month = value.month.toString().padLeft(2, '0');
  final day = value.day.toString().padLeft(2, '0');

  return '${value.year}-$month-$day';
}
