import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/billing_schedule.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';

void main() {
  group('monthly billing', () {
    test('Jan 31 becomes Feb 28 in a non-leap year', () {
      final DateTime next = nextBillingDate(
        current: DateTime(2026, 1, 31, 9, 30),
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        timeMinutes: 9 * 60 + 30,
      );
      expect(next, DateTime(2026, 2, 28, 9, 30));
    });

    test('Feb 28 returns to Mar 31 using the anchor', () {
      final DateTime next = nextBillingDate(
        current: DateTime(2026, 2, 28, 9, 30),
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        timeMinutes: 9 * 60 + 30,
      );
      expect(next, DateTime(2026, 3, 31, 9, 30));
    });

    test('Jan 31 becomes Feb 29 in a leap year', () {
      final DateTime next = nextBillingDate(
        current: DateTime(2028, 1, 31, 9, 30),
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        timeMinutes: 9 * 60 + 30,
      );
      expect(next, DateTime(2028, 2, 29, 9, 30));
    });

    test('December rolls into January of the next year', () {
      final DateTime next = nextBillingDate(
        current: DateTime(2026, 12, 31, 9),
        cycle: BillingCycle.monthly,
        anchorDay: 31,
        timeMinutes: 9 * 60,
      );
      expect(next, DateTime(2027, 1, 31, 9));
    });
  });

  group('yearly billing', () {
    test('Feb 29 clamps to Feb 28 the next year', () {
      final DateTime next = nextBillingDate(
        current: DateTime(2028, 2, 29, 9),
        cycle: BillingCycle.yearly,
        anchorDay: 29,
        timeMinutes: 9 * 60,
      );
      expect(next, DateTime(2029, 2, 28, 9));
    });

    test('preserves month and time', () {
      final DateTime next = nextBillingDate(
        current: DateTime(2026, 7, 15, 18, 45),
        cycle: BillingCycle.yearly,
        anchorDay: 15,
        timeMinutes: 18 * 60 + 45,
      );
      expect(next, DateTime(2027, 7, 15, 18, 45));
    });
  });

  group('weekly billing', () {
    test('crosses a year boundary', () {
      final DateTime next = nextBillingDate(
        current: DateTime(2026, 12, 29, 8),
        cycle: BillingCycle.weekly,
        anchorDay: 29,
        timeMinutes: 8 * 60,
      );
      expect(next, DateTime(2027, 1, 5, 8));
    });
  });

  test('anchor and time helpers read a local DateTime', () {
    final DateTime value = DateTime(2026, 11, 6, 14, 25);
    expect(billingAnchorDayOf(value), 6);
    expect(billingTimeMinutesOf(value), 14 * 60 + 25);
  });
}
