import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

String formatFundraisingMoney(BuildContext context, int amount) {
  final locale = Localizations.localeOf(context).toLanguageTag();
  return '৳${NumberFormat.decimalPattern(locale).format(amount)}';
}

String formatFundraisingDate(BuildContext context, DateTime value) {
  return MaterialLocalizations.of(context).formatMediumDate(value.toLocal());
}

String fundraisingDeadlineText(BuildContext context, DateTime? deadline) {
  if (deadline == null) return 'No deadline';
  final today = DateUtils.dateOnly(DateTime.now());
  final due = DateUtils.dateOnly(deadline.toLocal());
  final days = due.difference(today).inDays;
  if (days < 0) return 'Ended ${formatFundraisingDate(context, due)}';
  if (days == 0) return 'Ends today';
  if (days == 1) return '1 day left';
  return '$days days left';
}
