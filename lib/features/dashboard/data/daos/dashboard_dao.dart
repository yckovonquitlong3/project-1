import 'package:sqflite/sqflite.dart';

/// Read-only aggregate queries for the dashboard.
class DashboardDao {
  const DashboardDao();

  Future<int> netWorthMinor(DatabaseExecutor db) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      'SELECT COALESCE(SUM(balance_minor), 0) AS total FROM wallets',
    );
    return rows.first['total']! as int;
  }

  /// Totals for the half-open range `[start, end)` on `local_date`.
  Future<({int income, int expense})> monthTotals(
    DatabaseExecutor db,
    String start,
    String end,
  ) async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      '''
SELECT
  COALESCE(SUM(CASE WHEN transaction_type = 'INCOME'  THEN amount_minor ELSE 0 END), 0) AS income,
  COALESCE(SUM(CASE WHEN transaction_type = 'EXPENSE' THEN amount_minor ELSE 0 END), 0) AS expense
FROM transactions
WHERE local_date >= ? AND local_date < ?
''',
      <Object?>[start, end],
    );
    final Map<String, Object?> row = rows.first;
    return (
      income: row['income']! as int,
      expense: row['expense']! as int,
    );
  }

  Future<List<Map<String, Object?>>> categoryBreakdown(
    DatabaseExecutor db,
    String start,
    String end,
  ) {
    return db.rawQuery(
      '''
SELECT c.id AS category_id, c.name AS name, c.color_hex AS color_hex,
       SUM(t.amount_minor) AS total
FROM transactions t
JOIN categories c ON c.id = t.category_id
WHERE t.transaction_type = 'EXPENSE'
  AND t.local_date >= ? AND t.local_date < ?
GROUP BY c.id, c.name, c.color_hex
ORDER BY total DESC, c.name ASC
''',
      <Object?>[start, end],
    );
  }

  Future<List<Map<String, Object?>>> recent(
    DatabaseExecutor db, {
    int limit = 20,
  }) {
    return db.rawQuery(
      '''
SELECT t.id AS id, t.transaction_type AS transaction_type,
       t.amount_minor AS amount_minor, t.occurred_at_ms AS occurred_at_ms,
       sw.name AS source_wallet_name,
       tw.name AS target_wallet_name,
       c.name  AS category_name
FROM transactions t
JOIN wallets sw ON sw.id = t.source_wallet_id
LEFT JOIN wallets tw ON tw.id = t.target_wallet_id
LEFT JOIN categories c ON c.id = t.category_id
ORDER BY t.occurred_at_ms DESC, t.created_at_ms DESC
LIMIT ?
''',
      <Object?>[limit],
    );
  }
}