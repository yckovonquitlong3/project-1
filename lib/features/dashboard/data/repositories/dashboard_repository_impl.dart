import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/dashboard/data/daos/dashboard_dao.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:sqflite/sqflite.dart';

class DashboardRepositoryImpl implements DashboardRepository {
  DashboardRepositoryImpl({
    required AppDatabase database,
    DashboardDao dashboardDao = const DashboardDao(),
  })  : _db = database,
        _dao = dashboardDao;

  final AppDatabase _db;
  final DashboardDao _dao;

  @override
  Future<Money> netWorth() async {
    final Database db = await _db.database;
    try {
      return Money(await _dao.netWorthMinor(db));
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load net worth', cause: error);
    }
  }

  @override
  Future<MonthSummary> monthSummary(DateTime month) async {
    final Database db = await _db.database;
    try {
      final ({int income, int expense}) totals = await _dao.monthTotals(
        db,
        monthStartOf(month),
        nextMonthStartOf(month),
      );
      return MonthSummary(
        income: Money(totals.income),
        expense: Money(totals.expense),
      );
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load the monthly summary', cause: error);
    }
  }

  @override
  Future<List<CategoryBreakdown>> categoryBreakdown(DateTime month) async {
    final Database db = await _db.database;
    try {
      final List<Map<String, Object?>> rows = await _dao.categoryBreakdown(
        db,
        monthStartOf(month),
        nextMonthStartOf(month),
      );
      return rows
          .map(
            (Map<String, Object?> row) => CategoryBreakdown(
              categoryId: row['category_id']! as String,
              name: row['name']! as String,
              colorHex: row['color_hex']! as String,
              total: Money(row['total']! as int),
            ),
          )
          .toList(growable: false);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load the breakdown', cause: error);
    }
  }

  @override
  Future<List<DashboardTransaction>> recentTransactions({int limit = 20}) async {
    final Database db = await _db.database;
    try {
      final List<Map<String, Object?>> rows =
          await _dao.recent(db, limit: limit);
      return rows
          .map(
            (Map<String, Object?> row) => DashboardTransaction(
              id: row['id']! as String,
              type: TransactionType.fromDb(
                row['transaction_type']! as String,
              ),
              amount: Money(row['amount_minor']! as int),
              sourceWalletName: row['source_wallet_name']! as String,
              targetWalletName: row['target_wallet_name'] as String?,
              categoryName: row['category_name'] as String?,
              occurredAt: fromEpochMillis(row['occurred_at_ms']! as int),
            ),
          )
          .toList(growable: false);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load recent transactions', cause: error);
    }
  }
}