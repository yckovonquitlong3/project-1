import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/subscription/data/daos/subscription_dao.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/billing_schedule.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription_failure_reason.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/repositories/subscription_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/data/daos/transaction_dao.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class SubscriptionRepositoryImpl implements SubscriptionRepository {
  SubscriptionRepositoryImpl({
    required AppDatabase database,
    Uuid? uuid,
    DateTime Function()? clock,
    SubscriptionDao subscriptionDao = const SubscriptionDao(),
    TransactionDao transactionDao = const TransactionDao(),
  })  : _db = database,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now,
        _dao = subscriptionDao,
        _transactionWriter = transactionDao;

  final AppDatabase _db;
  final Uuid _uuid;
  final DateTime Function() _clock;
  final SubscriptionDao _dao;
  final TransactionDao _transactionWriter;

  @override
  Future<List<Subscription>> all({bool includeInactive = false}) async {
    final Database db = await _db.database;
    try {
      return await _dao.all(db, includeInactive: includeInactive);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load subscriptions', cause: error);
    }
  }

  @override
  Future<Subscription?> byId(String id) async {
    final Database db = await _db.database;
    try {
      return await _dao.byId(db, id);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load the subscription', cause: error);
    }
  }

  @override
  Future<List<Subscription>> due(DateTime now) async {
    final Database db = await _db.database;
    try {
      return await _dao.due(db, now);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load due subscriptions', cause: error);
    }
  }

  @override
  Future<Subscription> create({
    required String name,
    required Money amount,
    required String walletId,
    required String categoryId,
    required BillingCycle cycle,
    required DateTime nextBillingAt,
    bool autoDeduct = true,
  }) async {
    final DateTime now = _clock();
    final Subscription subscription = Subscription(
      id: _uuid.v4(),
      name: name,
      amount: amount,
      walletId: walletId,
      categoryId: categoryId,
      cycle: cycle,
      nextBillingAt: nextBillingAt,
      billingAnchorDay: billingAnchorDayOf(nextBillingAt),
      billingTimeMinutes: billingTimeMinutesOf(nextBillingAt),
      autoDeduct: autoDeduct,
      createdAt: now,
      updatedAt: now,
    );

    final Database db = await _db.database;
    try {
      await _dao.insert(db, subscription);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not create the subscription', cause: error);
    }
    return subscription;
  }

  @override
  Future<Subscription> update({
    required String id,
    required String name,
    required Money amount,
    required String walletId,
    required String categoryId,
    required BillingCycle cycle,
    required DateTime nextBillingAt,
    required bool autoDeduct,
  }) async {
    final Database db = await _db.database;
    final Subscription? existing = await byId(id);
    if (existing == null) {
      throw const NotFoundFailure('Subscription not found');
    }

    final Subscription updated = Subscription(
      id: existing.id,
      name: name,
      amount: amount,
      walletId: walletId,
      categoryId: categoryId,
      cycle: cycle,
      nextBillingAt: nextBillingAt,
      billingAnchorDay: billingAnchorDayOf(nextBillingAt),
      billingTimeMinutes: billingTimeMinutesOf(nextBillingAt),
      autoDeduct: autoDeduct,
      isActive: existing.isActive,
      isOverdue: existing.isOverdue,
      lastPaidAt: existing.lastPaidAt,
      lastFailureReason: existing.lastFailureReason,
      lastNotifiedAt: existing.lastNotifiedAt,
      createdAt: existing.createdAt,
      updatedAt: _clock(),
    );

    try {
      await _dao.update(db, updated);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not update the subscription', cause: error);
    }
    return updated;
  }

  @override
  Future<void> setActive(String id, {required bool active}) async {
    final Database db = await _db.database;
    if (await byId(id) == null) {
      throw const NotFoundFailure('Subscription not found');
    }
    try {
      await _dao.setActive(
        db,
        id,
        active: active,
        updatedAtMs: epochMillis(_clock()),
      );
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not update the subscription', cause: error);
    }
  }

  @override
  Future<void> delete(String id) async {
    if (await hasCharges(id)) {
      throw const ConflictFailure(
        'Archive this subscription instead: it has generated charges',
      );
    }
    final Database db = await _db.database;
    try {
      await _dao.delete(db, id);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not delete the subscription', cause: error);
    }
  }

  @override
  Future<bool> hasCharges(String id) async {
    final Database db = await _db.database;
    try {
      return await _dao.countCharges(db, id) > 0;
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not inspect the subscription', cause: error);
    }
  }

  @override
  Future<bool> hasChargeForPeriod(
    String subscriptionId,
    String billingPeriod,
  ) async {
    final Database db = await _db.database;
    try {
      return await _dao.countForPeriod(db, subscriptionId, billingPeriod) > 0;
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not inspect the subscription', cause: error);
    }
  }

  @override
  Future<bool> hasActiveForWallet(String walletId) async {
    final Database db = await _db.database;
    try {
      return await _dao.countActiveForWallet(db, walletId) > 0;
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not inspect wallet subscriptions',
          cause: error);
    }
  }

  @override
  Future<bool> hasActiveForCategory(String categoryId) async {
    final Database db = await _db.database;
    try {
      return await _dao.countActiveForCategory(db, categoryId) > 0;
    } on DatabaseException catch (error) {
      throw DatabaseFailure(
        'Could not inspect category subscriptions',
        cause: error,
      );
    }
  }

  @override
  Future<bool> recordCharge({
    required TransactionRecord transaction,
    required int nextBillingAtMs,
    required bool isOverdue,
    required DateTime paidAt,
  }) async {
    if (transaction.type != TransactionType.expense) {
      throw const ValidationFailure('A subscription charge must be an expense');
    }
    final String? subscriptionId = transaction.subscriptionId;
    final String? billingPeriod = transaction.billingPeriod;
    if (subscriptionId == null || billingPeriod == null) {
      throw const ValidationFailure(
        'A subscription charge needs a subscription and billing period',
      );
    }

    final Database db = await _db.database;
    try {
      return await db.transaction((Transaction txn) async {
        final int existing = await _dao.countForPeriod(
          txn,
          subscriptionId,
          billingPeriod,
        );
        if (existing > 0) {
          return false;
        }

        await _transactionWriter.insert(txn, transaction);
        await _transactionWriter.applyEffect(txn, transaction, 1);
        await _dao.updateAfterCharge(
          txn,
          id: subscriptionId,
          nextBillingAtMs: nextBillingAtMs,
          isOverdue: isOverdue,
          paidAtMs: epochMillis(paidAt),
          updatedAtMs: epochMillis(paidAt),
        );
        return true;
      });
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not record the subscription charge',
          cause: error);
    }
  }

  @override
  Future<void> markOverdue({
    required String id,
    required SubscriptionFailureReason reason,
    required DateTime at,
  }) async {
    final Database db = await _db.database;
    try {
      await _dao.markOverdue(
        db,
        id: id,
        reason: reason.dbValue,
        atMs: epochMillis(at),
      );
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not update the subscription', cause: error);
    }
  }
}
