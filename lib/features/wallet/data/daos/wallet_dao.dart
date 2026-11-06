import 'package:multi_wallet_tracker/features/wallet/data/models/wallet_model.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:sqflite/sqflite.dart';

class WalletDao {
  const WalletDao();

  static const String table = 'wallets';

  Future<List<Wallet>> all(
    DatabaseExecutor db, {
    bool includeArchived = false,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: includeArchived ? null : 'is_archived = 0',
      orderBy: 'sort_order ASC, name ASC',
    );
    return rows.map(WalletModel.fromRow).toList(growable: false);
  }

  Future<Wallet?> byId(DatabaseExecutor db, String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return WalletModel.fromRow(rows.first);
  }

  Future<void> insert(DatabaseExecutor db, Wallet wallet) async {
    await db.insert(table, WalletModel.toRow(wallet));
  }

  Future<void> update(DatabaseExecutor db, Wallet wallet) async {
    await db.update(
      table,
      WalletModel.toRow(wallet),
      where: 'id = ?',
      whereArgs: <Object?>[wallet.id],
    );
  }

  Future<void> setArchived(
    DatabaseExecutor db,
    String id, {
    required bool archived,
    required int updatedAtMs,
  }) async {
    await db.update(
      table,
      <String, Object?>{
        'is_archived': archived ? 1 : 0,
        'updated_at_ms': updatedAtMs,
      },
      where: 'id = ?',
      whereArgs: <Object?>[id],
    );
  }

  Future<int> countTransactions(DatabaseExecutor db, String walletId) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM transactions '
      'WHERE source_wallet_id = ? OR target_wallet_id = ?',
      <Object?>[walletId, walletId],
    );
    return rows.first['c']! as int;
  }

  Future<int> countSubscriptions(
    DatabaseExecutor db,
    String walletId, {
    bool activeOnly = false,
  }) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COUNT(*) AS c FROM subscriptions WHERE wallet_id = ?'
      '${activeOnly ? ' AND is_active = 1' : ''}',
      <Object?>[walletId],
    );
    return rows.first['c']! as int;
  }

  Future<void> delete(DatabaseExecutor db, String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);
  }
}