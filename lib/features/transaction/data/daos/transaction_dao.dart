import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/transaction/data/models/transaction_model.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:sqflite/sqflite.dart';

/// All ledger SQL lives here.
///
/// [applyEffect] is the single place where a wallet balance changes. Create,
/// edit, delete, and transfer all route through it, so the arithmetic cannot
/// drift between code paths.
class TransactionDao {
  const TransactionDao();

  static const String table = 'transactions';

  Future<void> insert(DatabaseExecutor db, TransactionRecord record) async {
    await db.insert(table, TransactionModel.toRow(record));
  }

  Future<void> update(DatabaseExecutor db, TransactionRecord record) async {
    await db.update(
      table,
      TransactionModel.toRow(record),
      where: 'id = ?',
      whereArgs: <Object?>[record.id],
    );
  }

  Future<void> deleteById(DatabaseExecutor db, String id) async {
    await db.delete(table, where: 'id = ?', whereArgs: <Object?>[id]);
  }

  Future<TransactionRecord?> byId(DatabaseExecutor db, String id) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'id = ?',
      whereArgs: <Object?>[id],
      limit: 1,
    );
    if (rows.isEmpty) {
      return null;
    }
    return TransactionModel.fromRow(rows.first);
  }

  Future<List<TransactionRecord>> recent(
    DatabaseExecutor db, {
    int limit = 20,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      orderBy: 'occurred_at_ms DESC, created_at_ms DESC',
      limit: limit,
    );
    return rows.map(TransactionModel.fromRow).toList(growable: false);
  }

  Future<List<TransactionRecord>> forWallet(
    DatabaseExecutor db,
    String walletId, {
    int limit = 50,
  }) async {
    final List<Map<String, Object?>> rows = await db.query(
      table,
      where: 'source_wallet_id = ? OR target_wallet_id = ?',
      whereArgs: <Object?>[walletId, walletId],
      orderBy: 'occurred_at_ms DESC, created_at_ms DESC',
      limit: limit,
    );
    return rows.map(TransactionModel.fromRow).toList(growable: false);
  }

  /// Applies the balance effect of [record]. `sign` is `1` to apply and `-1`
  /// to reverse. Must be called inside a database transaction.
  Future<void> applyEffect(
    DatabaseExecutor db,
    TransactionRecord record,
    int sign,
  ) async {
    final int amount = record.amount.minorUnits * sign;
    switch (record.type) {
      case TransactionType.expense:
        await _addToBalance(db, record.sourceWalletId, -amount);
      case TransactionType.income:
        await _addToBalance(db, record.sourceWalletId, amount);
      case TransactionType.transfer:
        await _addToBalance(db, record.sourceWalletId, -amount);
        await _addToBalance(db, record.targetWalletId!, amount);
    }
  }

  Future<void> _addToBalance(
    DatabaseExecutor db,
    String walletId,
    int deltaMinor,
  ) async {
    final int updated = await db.rawUpdate(
      'UPDATE wallets SET balance_minor = balance_minor + ?, updated_at_ms = ? '
      'WHERE id = ?',
      <Object?>[deltaMinor, epochMillis(DateTime.now()), walletId],
    );
    if (updated != 1) {
      throw NotFoundFailure('Wallet $walletId does not exist');
    }
  }

  /// Wallet ids whose stored balance does not match the sum of their
  /// transaction deltas.
  Future<List<String>> mismatchedWallets(DatabaseExecutor db) async {
    final List<Map<String, Object?>> rows = await db.rawQuery('''
SELECT w.id AS id
FROM wallets w
LEFT JOIN transactions t
  ON t.source_wallet_id = w.id OR t.target_wallet_id = w.id
GROUP BY w.id, w.balance_minor
HAVING w.balance_minor <> COALESCE(SUM(
  CASE
    WHEN t.transaction_type = 'INCOME'   AND t.source_wallet_id = w.id THEN  t.amount_minor
    WHEN t.transaction_type = 'EXPENSE'  AND t.source_wallet_id = w.id THEN -t.amount_minor
    WHEN t.transaction_type = 'TRANSFER' AND t.source_wallet_id = w.id THEN -t.amount_minor
    WHEN t.transaction_type = 'TRANSFER' AND t.target_wallet_id = w.id THEN  t.amount_minor
    ELSE 0
  END
), 0)
''');
    return rows
        .map((Map<String, Object?> row) => row['id']! as String)
        .toList(growable: false);
  }
}