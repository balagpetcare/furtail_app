class FundraisingDeadlineOptions {
  const FundraisingDeadlineOptions._();

  static const List<int> allowedDurations = <int>[7, 15, 30, 90];

  static DateTime calculateDeadline({
    required DateTime now,
    required int durationDays,
  }) {
    if (!allowedDurations.contains(durationDays)) {
      throw ArgumentError.value(
        durationDays,
        'durationDays',
        'Unsupported fundraiser duration.',
      );
    }
    final localDate = DateTime(now.year, now.month, now.day);
    final targetDate = localDate.add(Duration(days: durationDays));
    return DateTime(targetDate.year, targetDate.month, targetDate.day, 23, 59);
  }

  static int? durationForDeadline({
    required DateTime now,
    required DateTime? deadline,
  }) {
    if (deadline == null) return null;
    final today = DateTime(now.year, now.month, now.day);
    final deadlineDay = DateTime(
      deadline.toLocal().year,
      deadline.toLocal().month,
      deadline.toLocal().day,
    );
    final days = deadlineDay.difference(today).inDays;
    return allowedDurations.contains(days) ? days : null;
  }
}
