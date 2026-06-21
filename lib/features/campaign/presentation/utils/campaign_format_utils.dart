import 'package:intl/intl.dart';

String formatCampaignDate(DateTime? date) {
  if (date == null) return '—';
  return DateFormat('d MMM yyyy').format(date);
}

String formatCampaignDateTime(DateTime? date, String? start, String? end) {
  final d = formatCampaignDate(date);
  if (start == null) return d;
  if (end != null) return '$d · $start–$end';
  return '$d · $start';
}
