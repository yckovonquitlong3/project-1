import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notification.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notifier.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_reminder_scheduler.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';

class FakeSubscriptionNotifier implements SubscriptionNotifier {
  final List<SubscriptionNotification> events = <SubscriptionNotification>[];

  bool throwOnNotify = false;

  @override
  Future<void> notify(SubscriptionNotification notification) async {
    if (throwOnNotify) {
      throw StateError('notification failure');
    }
    events.add(notification);
  }
}

class FakeSubscriptionReminderScheduler
    implements SubscriptionReminderScheduler {
  bool enabled = true;
  int syncCount = 0;
  List<Subscription> lastSubscriptions = <Subscription>[];
  Map<String, String> lastWalletNames = <String, String>{};

  @override
  Future<void> sync({
    required List<Subscription> subscriptions,
    required Map<String, String> walletNames,
  }) async {
    syncCount++;
    lastSubscriptions = subscriptions;
    lastWalletNames = walletNames;
  }

  @override
  Future<void> cancelAll() async {}

  @override
  Future<bool> requestPermission() async => enabled;

  @override
  Future<bool> notificationsEnabled() async => enabled;
}
