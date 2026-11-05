import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';

abstract interface class DashboardRepository {
  /// Sum of every wallet balance, archived wallets included.
  Future<Money> netWorth();

  Future<MonthSummary> monthSummary(DateTime month);

  Future<List<CategoryBreakdown>> categoryBreakdown(DateTime month);

  Future<List<DashboardTransaction>> recentTransactions({int limit = 20});
}