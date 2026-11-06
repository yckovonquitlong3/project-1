import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';

abstract interface class SubscriptionRepository {
  Future<List<Subscription>> all({bool includeInactive = false});

  Future<Subscription?> byId(String id);

  /// Active subscriptions whose billing instant is at or before [now],
  /// oldest first.
  Future<List<Subscription>> due(DateTime now);

  Future<Subscription> create({
    required String name,
    required Money amount,
    required String walletId,
    required String categoryId,
    required BillingCycle cycle,
    required DateTime nextBillingAt,
    bool autoDeduct = true,
  });

  Future<Subscription> update({
    required String id,
    required String name,
    required Money amount,
    required String walletId,
    required String categoryId,
    required BillingCycle cycle,
    required DateTime nextBillingAt,
    required bool autoDeduct,
  });

  Future<void> setActive(String id, {required bool active});

  /// Throws [ConflictFailure] when the subscription has generated charges.
  Future<void> delete(String id);

  Future<bool> hasCharges(String id);

  Future<bool> hasChargeForPeriod(String subscriptionId, String billingPeriod);

  Future<bool> hasActiveForWallet(String walletId);

  Future<bool> hasActiveForCategory(String categoryId);

  /// Atomically inserts the expense, applies its balance effect, and advances
  /// the subscription. Returns false when this period was already charged.
  Future<bool> recordCharge({
    required TransactionRecord transaction,
    required int nextBillingAtMs,
    required bool isOverdue,
    required DateTime paidAt,
  });

  Future<void> markOverdue({
    required String id,
    required SubscriptionFailureReason reason,
    required DateTime at,
  });
}
