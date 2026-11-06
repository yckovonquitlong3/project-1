import 'subscription_notification.dart';

/// Phase 2 uses a fake; Phase 3 implements this with local notifications.
abstract interface class SubscriptionNotifier {
  Future<void> notify(SubscriptionNotification notification);
}
