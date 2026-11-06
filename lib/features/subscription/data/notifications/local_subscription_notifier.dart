import 'package:multi_wallet_tracker/core/notifications/local_notification_service.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notification.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notifier.dart';

class LocalSubscriptionNotifier implements SubscriptionNotifier {
  LocalSubscriptionNotifier({required LocalNotificationService notifications})
      : _notificationService = notifications;

  final LocalNotificationService _notificationService;

  @override
  Future<void> notify(SubscriptionNotification notification) async {
    final String payload =
        '${LocalNotificationService.payloadPrefix}${notification.subscription.id}';
    final int id = _stableId(
      '${notification.subscription.id}:${notification.runtimeType}:'
      '${DateTime.now().microsecondsSinceEpoch}',
    );

    final String title;
    final String body;
    switch (notification) {
      case SubscriptionPaidNotification():
        title = 'Subscription paid';
        body = '${notification.subscription.name}: '
            '${notification.amount.format()} from ${notification.walletName}';
      case SubscriptionInsufficientNotification():
        title = 'Deduction failed';
        body = '${notification.subscription.name}: needs '
            '${notification.amount.format()}, ${notification.walletName} has '
            '${notification.balance.format()}';
      case SubscriptionManualPaymentNotification():
        title = 'Payment due';
        body = '${notification.subscription.name}: '
            '${notification.subscription.amount.format()} from '
            '${notification.walletName}';
      case SubscriptionArchivedReferenceNotification():
        title = 'Subscription paused';
        body = '${notification.subscription.name}: '
            '${_reasonText(notification.reason)}';
    }

    await _notificationService.showNotification(
      id: id,
      title: title,
      body: body,
      payload: payload,
    );
  }

  String _reasonText(SubscriptionFailureReason reason) => switch (reason) {
        SubscriptionFailureReason.walletArchived => 'its wallet is archived',
        SubscriptionFailureReason.categoryArchived =>
          'its category is archived',
        SubscriptionFailureReason.insufficientBalance =>
          'the wallet balance is too low',
        SubscriptionFailureReason.manualPaymentRequired =>
          'manual payment is required',
      };

  int _stableId(String key) {
    var hash = 0x811c9dc5;
    for (final int code in key.codeUnits) {
      hash ^= code;
      hash = (hash * 0x01000193) & 0x7fffffff;
    }
    return hash == 0 ? 1 : hash;
  }
}
