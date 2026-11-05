/// Date helpers. All grouping in the app happens on a local calendar date
/// string so that a UTC timestamp near midnight cannot fall into the wrong
/// month or day.
String localDateOf(DateTime value) {
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  final String day = local.day.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-$month-$day';
}

/// First day of the month containing [value], as `YYYY-MM-DD`.
String monthStartOf(DateTime value) {
  final DateTime local = value.toLocal();
  final String month = local.month.toString().padLeft(2, '0');
  return '${local.year.toString().padLeft(4, '0')}-$month-01';
}

/// First day of the month after [value], as `YYYY-MM-DD`. Used as an exclusive
/// upper bound so `local_date >= start AND local_date < end` never needs
/// month-length arithmetic in SQL.
String nextMonthStartOf(DateTime value) {
  final DateTime local = value.toLocal();
  final int year = local.month == 12 ? local.year + 1 : local.year;
  final int month = local.month == 12 ? 1 : local.month + 1;
  return '${year.toString().padLeft(4, '0')}-${month.toString().padLeft(2, '0')}-01';
}

int epochMillis(DateTime value) => value.toUtc().millisecondsSinceEpoch;

DateTime fromEpochMillis(int value) => DateTime.fromMillisecondsSinceEpoch(
      value,
      isUtc: true,
    ).toLocal();