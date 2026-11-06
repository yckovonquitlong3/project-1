import 'dart:math' as math;

import 'entities/billing_cycle.dart';

/// Returns the next billing instant after [current], preserving the anchor
/// day and local time. Month-end dates clamp without losing the anchor:
/// Jan 31 -> Feb 28/29 -> Mar 31.
DateTime nextBillingDate({
  required DateTime current,
  required BillingCycle cycle,
  required int anchorDay,
  required int timeMinutes,
}) {
  final int hour = timeMinutes ~/ 60;
  final int minute = timeMinutes % 60;

  switch (cycle) {
    case BillingCycle.weekly:
      return DateTime(
        current.year,
        current.month,
        current.day + 7,
        hour,
        minute,
      );
    case BillingCycle.monthly:
      final int nextMonth = current.month == 12 ? 1 : current.month + 1;
      final int nextYear = current.month == 12 ? current.year + 1 : current.year;
      return DateTime(
        nextYear,
        nextMonth,
        math.min(anchorDay, daysInMonth(nextYear, nextMonth)),
        hour,
        minute,
      );
    case BillingCycle.yearly:
      final int nextYear = current.year + 1;
      return DateTime(
        nextYear,
        current.month,
        math.min(anchorDay, daysInMonth(nextYear, current.month)),
        hour,
        minute,
      );
  }
}

int daysInMonth(int year, int month) => DateTime(year, month + 1, 0).day;

int billingAnchorDayOf(DateTime value) => value.day;

int billingTimeMinutesOf(DateTime value) => value.hour * 60 + value.minute;
