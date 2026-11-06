import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';

abstract interface class SubscriptionReminderScheduler {
  /// Cancels previous scheduled reminders and schedules upcoming ones.
  Future<void> sync({
    required List<Subscription> subscriptions,
    required Map<String, String> walletNames,
  });

  Future<void> cancelAll();

  Future<bool> requestPermission();

  Future<bool> notificationsEnabled();
}
