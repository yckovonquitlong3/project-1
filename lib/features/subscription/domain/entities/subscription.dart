import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';

import 'billing_cycle.dart';
import 'subscription_failure_reason.dart';

class Subscription extends Equatable {
  const Subscription({
    required this.id,
    required this.name,
    required this.amount,
    required this.walletId,
    required this.categoryId,
    required this.cycle,
    required this.nextBillingAt,
    required this.billingAnchorDay,
    required this.billingTimeMinutes,
    required this.createdAt,
    required this.updatedAt,
    this.autoDeduct = true,
    this.isActive = true,
    this.isOverdue = false,
    this.lastPaidAt,
    this.lastFailureReason,
    this.lastNotifiedAt,
  });

  final String id;
  final String name;
  final Money amount;
  final String walletId;
  final String categoryId;
  final BillingCycle cycle;
  final DateTime nextBillingAt;

  /// Original billing day (1–31), preserved across short months.
  final int billingAnchorDay;

  /// Local billing time as minutes after midnight (0–1439).
  final int billingTimeMinutes;

  final bool autoDeduct;
  final bool isActive;
  final bool isOverdue;
  final DateTime? lastPaidAt;
  final SubscriptionFailureReason? lastFailureReason;
  final DateTime? lastNotifiedAt;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool isDueAt(DateTime now) => isActive && !nextBillingAt.isAfter(now);

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        amount,
        walletId,
        categoryId,
        cycle,
        nextBillingAt,
        billingAnchorDay,
        billingTimeMinutes,
        autoDeduct,
        isActive,
        isOverdue,
        lastPaidAt,
        lastFailureReason,
        lastNotifiedAt,
        createdAt,
        updatedAt,
      ];
}
