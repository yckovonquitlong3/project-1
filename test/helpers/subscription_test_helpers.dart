import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notification.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notifier.dart';

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
