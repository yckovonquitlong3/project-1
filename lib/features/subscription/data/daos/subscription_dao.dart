import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/subscription/data/models/subscription_model.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:sqflite/sqflite.dart';

class SubscriptionDao {
  const SubscriptionDao();

  static const String table = 'subscriptions';

  Future<List<Subscription>> all(
    DatabaseExecutor db, {
    bool includeInactive = false,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: includeInactive ? null : 'is_active = 1',
      orderBy: 'next_billing_at_ms ASC, name ASC',
    );
    return rows.map(SubscriptionModel.fromRow).toList(growable: false);
  }

  Future<Subscription?> byId(DatabaseExecutor db, String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return SubscriptionModel.fromRow(rows.first);
  }

  Future<List<Subscription>> due(
    DatabaseExecutor db,
    DateTime now,
  ) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'is_active = 1 AND next_billing_at_ms <= ?',
      whereArgs: <Object?>[epochMillis(now)],
      orderBy: 'next_billing_at_ms ASC, name ASC',
    );
    return rows.map(SubscriptionModel.fromRow).toList(growable: false);
  }

  Future<void> insert(DatabaseExecutor db, Subscription subscription) async {
    await db.insert(table, SubscriptionModel.toRow(subscription));
  }

  Future<void> update(DatabaseExecutor db, Subscription subscription) async {
    await db.update(
      table,
      SubscriptionModel.toRow(subscription),
      where: 'id = ?',
      whereArgs: <Object?>[subscription.id],
    );
  }

  Future<void> setActive(
    DatabaseExecutor db,
    String id, {
    required bool active,
    required int updatedAtMs,
  }) async {
    await db.update(
      table,
      <String, Object?>{
        'is_active': active ? 1 : 0,
        'updated_at_ms': updatedAtMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> delete(DatabaseExecutor db, String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<int> countCharges(DatabaseExecutor db, String id) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions WHERE subscription_id = ?',
      <Object?>[id],
    );
    return rows.first['c']! as int;
  }

  Future<int> countForPeriod(
    DatabaseExecutor db,
    String subscriptionId,
    String billingPeriod,
  ) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions '
      'WHERE subscription_id = ? AND billing_period = ?',
      <Object?>[subscriptionId, billingPeriod],
    );
    return rows.first['c']! as int;
  }

  Future<int> countActiveForWallet(
    DatabaseExecutor db,
    String walletId,
  ) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM subscriptions '
      'WHERE wallet_id = ? AND is_active = 1',
      <Object?>[walletId],
    );
    return rows.first['c']! as int;
  }

  Future<int> countActiveForCategory(
    DatabaseExecutor db,
    String categoryId,
  ) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM subscriptions '
      'WHERE category_id = ? AND is_active = 1',
      <Object?>[categoryId],
    );
    return rows.first['c']! as int;
  }

  Future<void> updateAfterCharge(
    DatabaseExecutor db, {
    required String id,
    required int nextBillingAtMs,
    required bool isOverdue,
    required int paidAtMs,
    required int updatedAtMs,
  }) async {
    await db.update(
      table,
      <String, Object?>{
        'next_billing_at_ms': nextBillingAtMs,
        'is_overdue': isOverdue ? 1 : 0,
        'last_paid_at_ms': paidAtMs,
        'last_failure_reason': null,
        'last_notified_at_ms': null,
        'updated_at_ms': updatedAtMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<void> markOverdue(
    DatabaseExecutor db, {
    required String id,
    required String reason,
    required int atMs,
  }) async {
    await db.update(
      table,
      <String, Object?>{
        'is_overdue': 1,
        'last_failure_reason': reason,
        'last_notified_at_ms': atMs,
        'updated_at_ms': atMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }
}
