import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';

abstract final class SubscriptionModel {
  static Subscription fromRow(Map<String, Object?> row) {
    return Subscription(
      id: row['id']! as String,
      name: row['name']! as String,
      amount: Money(row['amount_minor']! as int),
      walletId: row['wallet_id']! as String,
      categoryId: row['category_id']! as String,
      cycle: BillingCycle.fromDb(row['billing_cycle']! as String),
      nextBillingAt: fromEpochMillis(row['next_billing_at_ms']! as int),
      billingAnchorDay: row['billing_anchor_day']! as int,
      billingTimeMinutes: row['billing_time_minutes']! as int,
      autoDeduct: (row['auto_deduct']! as int) == 1,
      isActive: (row['is_active']! as int) == 1,
      isOverdue: (row['is_overdue']! as int) == 1,
      lastPaidAt: row['last_paid_at_ms'] == null
          ? null
          : fromEpochMillis(row['last_paid_at_ms']! as int),
      lastFailureReason: SubscriptionFailureReason.fromDb(
        row['last_failure_reason'] as String?,
      ),
      lastNotifiedAt: row['last_notified_at_ms'] == null
          ? null
          : fromEpochMillis(row['last_notified_at_ms']! as int),
      createdAt: fromEpochMillis(row['created_at_ms']! as int),
      updatedAt: fromEpochMillis(row['updated_at_ms']! as int),
    );
  }

  static Map<String, Object?> toRow(Subscription subscription) {
    return <String, Object?>{
      'id': subscription.id,
      'name': subscription.name,
      'amount_minor': subscription.amount.minorUnits,
      'wallet_id': subscription.walletId,
      'category_id': subscription.categoryId,
      'billing_cycle': subscription.cycle.dbValue,
      'next_billing_at_ms': epochMillis(subscription.nextBillingAt),
      'billing_anchor_day': subscription.billingAnchorDay,
      'billing_time_minutes': subscription.billingTimeMinutes,
      'auto_deduct': subscription.autoDeduct ? 1 : 0,
      'is_active': subscription.isActive ? 1 : 0,
      'is_overdue': subscription.isOverdue ? 1 : 0,
      'last_paid_at_ms': subscription.lastPaidAt == null
          ? null
          : epochMillis(subscription.lastPaidAt!),
      'last_failure_reason': subscription.lastFailureReason?.dbValue,
      'last_notified_at_ms': subscription.lastNotifiedAt == null
          ? null
          : epochMillis(subscription.lastNotifiedAt!),
      'created_at_ms': epochMillis(subscription.createdAt),
      'updated_at_ms': epochMillis(subscription.updatedAt),
    };
  }
}
