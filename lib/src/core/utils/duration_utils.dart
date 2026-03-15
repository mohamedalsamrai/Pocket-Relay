String formatElapsedDuration(Duration duration) {
  final totalSeconds = duration.inSeconds;
  final hours = totalSeconds ~/ Duration.secondsPerHour;
  final minutes =
      (totalSeconds % Duration.secondsPerHour) ~/ Duration.secondsPerMinute;
  final seconds = totalSeconds % Duration.secondsPerMinute;

  String twoDigits(int value) => value.toString().padLeft(2, '0');

  if (hours > 0) {
    return '$hours:${twoDigits(minutes)}:${twoDigits(seconds)}';
  }

  return '$minutes:${twoDigits(seconds)}';
}
