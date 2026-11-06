import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/billing_schedule.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notification.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/notifications/subscription_notifier.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:uuid/uuid.dart';

enum SubscriptionRunMode { automatic, catchUpAll, manual }

class SubscriptionRunResult {
  const SubscriptionRunResult({
    this.paid = 0,
    this.failed = 0,
    this.skipped = 0,
    this.busy = false,
  });

  final int paid;
  final int failed;
  final int skipped;
  final bool busy;

  bool get didWork => paid > 0;
}

enum _CycleOutcome { paid, insufficient, walletArchived, categoryArchived, duplicate, failed }

class _CycleResult {
  const _CycleResult(this.outcome, [this.updated]);

  final _CycleOutcome outcome;
  final Subscription? updated;
}

/// Processes due subscriptions in the foreground only.
///
/// There is no background database write: this is invoked on app start/resume
/// and when the Subscriptions screen opens. The notification is a side effect
/// after the database transaction commits.
class RunDueSubscriptions {
  RunDueSubscriptions({
    required SubscriptionRepository subscriptions,
    required WalletRepository wallets,
    required CategoryRepository categories,
    required SubscriptionNotifier notifier,
    required LedgerBus ledgerBus,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _subscriptionRepo = subscriptions,
        _walletRepo = wallets,
        _categoryRepo = categories,
        _notificationSink = notifier,
        _bus = ledgerBus,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final SubscriptionRepository _subscriptionRepo;
  final WalletRepository _walletRepo;
  final CategoryRepository _categoryRepo;
  final SubscriptionNotifier _notificationSink;
  final LedgerBus _bus;
  final Uuid _uuid;
  final DateTime Function() _clock;

  bool _running = false;

  Future<SubscriptionRunResult> runAutomatic() =>
      _run(mode: SubscriptionRunMode.automatic);

  Future<SubscriptionRunResult> catchUpAll() =>
      _run(mode: SubscriptionRunMode.catchUpAll);

  Future<SubscriptionRunResult> markPaid(String id) async {
    if (_running) {
      return const SubscriptionRunResult(busy: true);
    }
    _running = true;
    try {
      final Subscription? subscription = await _subscriptionRepo.byId(id);
      if (subscription == null) {
        throw const NotFoundFailure('Subscription not found');
      }
      if (!subscription.isActive) {
        throw const ValidationFailure('This subscription is archived');
      }

      final DateTime now = _clock();
      if (!subscription.isDueAt(now)) {
        return const SubscriptionRunResult(skipped: 1);
      }

      final _CycleResult result = await _chargeOne(subscription, now);
      return switch (result.outcome) {
        _CycleOutcome.paid => const SubscriptionRunResult(paid: 1),
        _CycleOutcome.duplicate => const SubscriptionRunResult(skipped: 1),
        _ => const SubscriptionRunResult(failed: 1),
      };
    } finally {
      _running = false;
    }
  }

  Future<SubscriptionRunResult> _run({
    required SubscriptionRunMode mode,
  }) async {
    if (_running) {
      return const SubscriptionRunResult(busy: true);
    }
    _running = true;
    try {
      final DateTime now = _clock();
      final List<Subscription> due = await _subscriptionRepo.due(now);
      var paid = 0;
      var failed = 0;
      var skipped = 0;

      for (final Subscription subscription in due) {
        if (mode == SubscriptionRunMode.automatic &&
            !subscription.autoDeduct) {
          await _markOverdue(
            subscription,
            SubscriptionFailureReason.manualPaymentRequired,
            now,
          );
          skipped++;
          continue;
        }

        var current = subscription;
        var cycles = 0;
        final int maxCycles =
            mode == SubscriptionRunMode.catchUpAll ? 60 : 1;

        while (cycles < maxCycles && current.isDueAt(now)) {
          final _CycleResult result = await _chargeOne(current, now);
          cycles++;

          if (result.outcome == _CycleOutcome.paid) {
            paid++;
            current = result.updated!;
            continue;
          }

          if (result.outcome == _CycleOutcome.duplicate) {
            skipped++;
          } else {
            failed++;
          }
          break;
        }
      }

      return SubscriptionRunResult(
        paid: paid,
        failed: failed,
        skipped: skipped,
      );
    } finally {
      _running = false;
    }
  }

  Future<_CycleResult> _chargeOne(
    Subscription subscription,
    DateTime now,
  ) async {
    final Wallet? wallet = await _walletRepo.byId(subscription.walletId);
    final String walletName = wallet?.name ?? 'Unknown wallet';

    if (wallet == null || wallet.isArchived) {
      await _markOverdue(
        subscription,
        SubscriptionFailureReason.walletArchived,
        now,
        walletName: walletName,
      );
      return const _CycleResult(_CycleOutcome.walletArchived);
    }

    final category = await _categoryRepo.byId(subscription.categoryId);
    if (category == null || category.isArchived) {
      await _markOverdue(
        subscription,
        SubscriptionFailureReason.categoryArchived,
        now,
        walletName: walletName,
      );
      return const _CycleResult(_CycleOutcome.categoryArchived);
    }

    if (wallet.balance.minorUnits < subscription.amount.minorUnits) {
      await _markOverdue(
        subscription,
        SubscriptionFailureReason.insufficientBalance,
        now,
        walletName: walletName,
        balance: wallet.balance,
      );
      return const _CycleResult(_CycleOutcome.insufficient);
    }

    final DateTime nextBillingAt = nextBillingDate(
      current: subscription.nextBillingAt,
      cycle: subscription.cycle,
      anchorDay: subscription.billingAnchorDay,
      timeMinutes: subscription.billingTimeMinutes,
    );
    final bool isOverdue = !nextBillingAt.isAfter(now);
    final String billingPeriod = localDateOf(subscription.nextBillingAt);

    final TransactionRecord charge = TransactionRecord(
      id: _uuid.v4(),
      amount: subscription.amount,
      type: TransactionType.expense,
      sourceWalletId: subscription.walletId,
      categoryId: subscription.categoryId,
      occurredAt: subscription.nextBillingAt,
      localDate: billingPeriod,
      note: subscription.name,
      subscriptionId: subscription.id,
      billingPeriod: billingPeriod,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final bool recorded = await _subscriptionRepo.recordCharge(
        transaction: charge,
        nextBillingAtMs: epochMillis(nextBillingAt),
        isOverdue: isOverdue,
        paidAt: now,
      );
      if (!recorded) {
        return const _CycleResult(_CycleOutcome.duplicate);
      }

      await _safeNotify(
        SubscriptionPaidNotification(
          subscription,
          amount: subscription.amount,
          walletName: walletName,
        ),
      );
      _bus.notify();

      return _CycleResult(
        _CycleOutcome.paid,
        Subscription(
          id: subscription.id,
          name: subscription.name,
          amount: subscription.amount,
          walletId: subscription.walletId,
          categoryId: subscription.categoryId,
          cycle: subscription.cycle,
          nextBillingAt: nextBillingAt,
          billingAnchorDay: subscription.billingAnchorDay,
          billingTimeMinutes: subscription.billingTimeMinutes,
          autoDeduct: subscription.autoDeduct,
          isActive: subscription.isActive,
          isOverdue: isOverdue,
          lastPaidAt: now,
          createdAt: subscription.createdAt,
          updatedAt: now,
        ),
      );
    } on Failure {
      return const _CycleResult(_CycleOutcome.failed);
    }
  }

  Future<void> _markOverdue(
    Subscription subscription,
    SubscriptionFailureReason reason,
    DateTime now, {
    String? walletName,
    Money? balance,
  }) async {
    await _subscriptionRepo.markOverdue(
      id: subscription.id,
      reason: reason,
      at: now,
    );

    final String name = walletName ??
        (await _walletRepo.byId(subscription.walletId))?.name ??
        'Unknown wallet';

    final SubscriptionNotification notification;
    switch (reason) {
      case SubscriptionFailureReason.insufficientBalance:
        notification = SubscriptionInsufficientNotification(
          subscription,
          amount: subscription.amount,
          balance: balance ?? Money.zero,
          walletName: name,
        );
      case SubscriptionFailureReason.walletArchived:
      case SubscriptionFailureReason.categoryArchived:
        notification = SubscriptionArchivedReferenceNotification(
          subscription,
          reason: reason,
        );
      case SubscriptionFailureReason.manualPaymentRequired:
        notification = SubscriptionManualPaymentNotification(
          subscription,
          walletName: name,
        );
    }

    await _safeNotify(notification);
    _bus.notify();
  }

  Future<void> _safeNotify(SubscriptionNotification notification) async {
    try {
      await _notificationSink.notify(notification);
    } catch (_) {
      // Notifications are best-effort; the ledger write must not roll back.
    }
  }
}
