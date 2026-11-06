import 'package:intl/intl.dart';
import 'package:multi_wallet_tracker/core/notifications/local_notification_service.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/billing_schedule.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_reminder_scheduler.dart';

class SubscriptionReminderSchedulerImpl
    implements SubscriptionReminderScheduler {
  SubscriptionReminderSchedulerImpl({
    required LocalNotificationService notifications,
    DateTime Function()? clock,
  })  : _notificationService = notifications,
        _clock = clock ?? DateTime.now;

  static const int _maxCycles = 52;
  static const int _maxAlarms = 200;

  final LocalNotificationService _notificationService;
  final DateTime Function() _clock;

  @override
  Future<void> sync({
    required List<Subscription> subscriptions,
    required Map<String, String> walletNames,
  }) async {
    await _notificationService.cancelAllScheduled();

    final DateTime now = _clock();
    final DateTime horizon = now.add(const Duration(days: 366));
    var total = 0;

    for (final Subscription subscription in subscriptions) {
      if (!subscription.isActive) {
        continue;
      }
      final String walletName =
          walletNames[subscription.walletId] ?? 'your wallet';
      var due = subscription.nextBillingAt;
      var index = 0;

      while (!due.isAfter(horizon) &&
          index < _maxCycles &&
          total < _maxAlarms) {
        final String date = DateFormat.yMMMd().add_jm().format(due);
        final String payload =
            '${LocalNotificationService.payloadPrefix}${subscription.id}';

        final DateTime warning = due.subtract(const Duration(hours: 24));
        if (warning.isAfter(now) && total < _maxAlarms) {
          await _notificationService.scheduleReminder(
            id: _id(subscription.id, index, 0),
            title: 'Upcoming: ${subscription.name}',
            body: '${subscription.amount.format()} from $walletName on $date',
            when: warning,
            payload: payload,
          );
          total++;
        }

        if (due.isAfter(now) && total < _maxAlarms) {
          await _notificationService.scheduleReminder(
            id: _id(subscription.id, index, 1),
            title: 'Due today: ${subscription.name}',
            body: '${subscription.amount.format()} from $walletName',
            when: due,
            payload: payload,
          );
          total++;
        }

        due = nextBillingDate(
          current: due,
          cycle: subscription.cycle,
          anchorDay: subscription.billingAnchorDay,
          timeMinutes: subscription.billingTimeMinutes,
        );
        index++;
      }
    }
  }

  @override
  Future<void> cancelAll() => _notificationService.cancelAllScheduled();

  @override
  Future<bool> requestPermission() => _notificationService.requestPermission();

  @override
  Future<bool> notificationsEnabled() => _notificationService.notificationsEnabled();

  int _id(String subscriptionId, int cycleIndex, int stage) {
    final String key = '$subscriptionId:$cycleIndex:$stage';
    var hash = 0x811c9dc5;
    for (final int code in key.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
