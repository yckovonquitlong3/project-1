import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/notifications/local_notification_service.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/subscription/data/notifications/subscription_reminder_scheduler_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';

class FakeLocalNotificationService extends LocalNotificationService {
  final List<({int id, String title, String body, DateTime when, String payload})>
      scheduled = <({int id, String title, String body, DateTime when, String payload})>[];
  int cancelAllCount = 0;
  bool enabled = true;

  @override
  Future<void> cancelAllScheduled() async {
    cancelAllCount++;
  }

  @override
  Future<void> scheduleReminder({
    required int id,
    required String title,
    required String body,
    required DateTime when,
    required String payload,
  }) async {
    scheduled.add(
      (id: id, title: title, body: body, when: when, payload: payload),
    );
  }

  @override
  Future<bool> notificationsEnabled() async => enabled;

  @override
  Future<bool> requestPermission() async => enabled;
}

Subscription subscriptionFixture({
  String id = 'sub-1',
  String walletId = 'w1',
  DateTime? nextBillingAt,
  BillingCycle cycle = BillingCycle.monthly,
  int anchorDay = 3,
  int timeMinutes = 9 * 60,
  bool isActive = true,
}) {
  final DateTime created = DateTime(2026, 1, 1, 8);
  return Subscription(
    id: id,
    name: 'Claude Pro',
    amount: const Money(115000),
    walletId: walletId,
    categoryId: 'cat-exp-subscriptions',
    cycle: cycle,
    nextBillingAt: nextBillingAt ?? DateTime(2026, 11, 3, 9),
    billingAnchorDay: anchorDay,
    billingTimeMinutes: timeMinutes,
    isActive: isActive,
    createdAt: created,
    updatedAt: created,
  );
}

void main() {
  test('schedules the 24-hour and due reminders for future cycles', () async {
    final FakeLocalNotificationService notifications =
        FakeLocalNotificationService();
    final DateTime now = DateTime(2026, 11, 1, 8);
    final SubscriptionReminderSchedulerImpl scheduler =
        SubscriptionReminderSchedulerImpl(
      notifications: notifications,
      clock: () => now,
    );

    await scheduler.sync(
      subscriptions: <Subscription>[subscriptionFixture()],
      walletNames: <String, String>{'w1': 'GCash'},
    );

    expect(notifications.cancelAllCount, 1);
    expect(notifications.scheduled, isNotEmpty);
    expect(
      notifications.scheduled.every(
        (({int id, String title, String body, DateTime when, String payload})
                item) =>
            item.when.isAfter(now),
      ),
      isTrue,
    );
    expect(
      notifications.scheduled.every(
        (({int id, String title, String body, DateTime when, String payload})
                item) =>
            item.payload == 'subscription:sub-1',
      ),
      isTrue,
    );

    final ({int id, String title, String body, DateTime when, String payload})
        warning = notifications.scheduled.firstWhere(
      (({int id, String title, String body, DateTime when, String payload})
              item) =>
          item.when == DateTime(2026, 11, 2, 9),
    );
    final ({int id, String title, String body, DateTime when, String payload})
        due = notifications.scheduled.firstWhere(
      (({int id, String title, String body, DateTime when, String payload})
              item) =>
          item.when == DateTime(2026, 11, 3, 9),
    );

    expect(warning.title, 'Upcoming: Claude Pro');
    expect(warning.body, contains('GCash'));
    expect(due.title, 'Due today: Claude Pro');
    expect(due.body, contains('GCash'));
    expect(
      notifications.scheduled.map((item) => item.id).toSet().length,
      notifications.scheduled.length,
    );
  });

  test('archived subscriptions are not scheduled', () async {
    final FakeLocalNotificationService notifications =
        FakeLocalNotificationService();
    final SubscriptionReminderSchedulerImpl scheduler =
        SubscriptionReminderSchedulerImpl(
      notifications: notifications,
      clock: () => DateTime(2026, 11, 1, 8),
    );

    await scheduler.sync(
      subscriptions: <Subscription>[
        subscriptionFixture(isActive: false),
      ],
      walletNames: <String, String>{'w1': 'GCash'},
    );

    expect(notifications.scheduled, isEmpty);
  });

  test('permission methods delegate to the notification service', () async {
    final FakeLocalNotificationService notifications =
        FakeLocalNotificationService();
    final SubscriptionReminderSchedulerImpl scheduler =
        SubscriptionReminderSchedulerImpl(notifications: notifications);

    expect(await scheduler.notificationsEnabled(), isTrue);
    notifications.enabled = false;
    expect(await scheduler.requestPermission(), isFalse);
  });
}
