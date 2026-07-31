/// Tolerant numeric readers for fundraising API payloads.
///
/// Prisma `BigInt` values must be serialized by the API as JSON strings.
/// These helpers accept both normal JSON numbers and numeric strings so the
/// mobile app remains compatible during and after that backend correction.
int? fundraisingInt(Object? value) {
  if (value == null) return null;
  if (value is int) return value;
  if (value is BigInt) return value.toInt();
  if (value is num) return value.toInt();

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  final integer = int.tryParse(raw);
  if (integer != null) return integer;
  final decimal = double.tryParse(raw);
  if (decimal == null || !decimal.isFinite) return null;
  return decimal == decimal.truncateToDouble() ? decimal.toInt() : null;
}

double? fundraisingDouble(Object? value) {
  if (value == null) return null;
  if (value is double) return value;
  if (value is num) return value.toDouble();

  final raw = value.toString().trim();
  if (raw.isEmpty) return null;
  return double.tryParse(raw);
}

/// Tolerant boolean reader for fundraising API payloads.
bool? fundraisingBool(Object? value) {
  if (value == null) return null;
  if (value is bool) return value;
  if (value is num) return value != 0;

  final raw = value.toString().trim().toLowerCase();
  if (raw.isEmpty) return null;
  if (const <String>{'true', '1', 'yes', 'y'}.contains(raw)) return true;
  if (const <String>{'false', '0', 'no', 'n'}.contains(raw)) return false;
  return null;
}
