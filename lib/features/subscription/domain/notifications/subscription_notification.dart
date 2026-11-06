import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';

sealed class SubscriptionNotification {
  const SubscriptionNotification(this.subscription);

  final Subscription subscription;
}

final class SubscriptionPaidNotification extends SubscriptionNotification {
  const SubscriptionPaidNotification(
    super.subscription, {
    required this.amount,
    required this.walletName,
  });

  final Money amount;
  final String walletName;
}

final class SubscriptionInsufficientNotification
    extends SubscriptionNotification {
  const SubscriptionInsufficientNotification(
    super.subscription, {
    required this.amount,
    required this.balance,
    required this.walletName,
  });

  final Money amount;
  final Money balance;
  final String walletName;
}

final class SubscriptionManualPaymentNotification
    extends SubscriptionNotification {
  const SubscriptionManualPaymentNotification(
    super.subscription, {
    required this.walletName,
  });

  final String walletName;
}

final class SubscriptionArchivedReferenceNotification
    extends SubscriptionNotification {
  const SubscriptionArchivedReferenceNotification(
    super.subscription, {
    required this.reason,
  });

  final SubscriptionFailureReason reason;
}
