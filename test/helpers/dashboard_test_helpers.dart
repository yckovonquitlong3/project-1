import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_net_worth.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_recent_transactions.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/get_wallets.dart';

class MockDashboardRepository extends Mock implements DashboardRepository {}

DashboardCubit buildDashboardCubit({
  required DashboardRepository dashboard,
  required WalletRepository wallets,
  LedgerBus? ledgerBus,
  DateTime Function()? clock,
}) {
  return DashboardCubit(
    getNetWorth: GetNetWorth(dashboard: dashboard),
    getMonthSummary: GetMonthSummary(dashboard: dashboard),
    getCategoryBreakdown: GetCategoryBreakdown(dashboard: dashboard),
    getRecentTransactions: GetRecentTransactions(dashboard: dashboard),
    wallets: GetWallets(wallets: wallets),
    ledgerBus: ledgerBus ?? LedgerBus(),
    clock: clock ?? () => DateTime(2026, 11, 5),
  );
}

void stubDashboardLoad(
  MockDashboardRepository dashboard, {
  Money netWorth = Money.zero,
  MonthSummary? summary,
  List<CategoryBreakdown> breakdown = const <CategoryBreakdown>[],
  List<DashboardTransaction> recent = const <DashboardTransaction>[],
}) {
  when(() => dashboard.netWorth()).thenAnswer((_) async => netWorth);
  when(() => dashboard.monthSummary(DateTime(2026, 11)))
      .thenAnswer((_) async => summary ?? MonthSummary.empty);
  when(() => dashboard.categoryBreakdown(DateTime(2026, 11)))
      .thenAnswer((_) async => breakdown);
  when(() => dashboard.recentTransactions(limit: 20))
      .thenAnswer((_) async => recent);
}

MonthSummary monthSummaryFixture({
  int incomeMinor = 100000,
  int expenseMinor = 25000,
}) {
  return MonthSummary(
    income: Money(incomeMinor),
    expense: Money(expenseMinor),
  );
}

CategoryBreakdown breakdownFixture({
  String categoryId = 'cat-exp-food-dining',
  String name = 'Food & Dining',
  String colorHex = '#F44336',
  int totalMinor = 25000,
}) {
  return CategoryBreakdown(
    categoryId: categoryId,
    name: name,
    colorHex: colorHex,
    total: Money(totalMinor),
  );
}

DashboardTransaction dashboardTransactionFixture({
  String id = 'tx-1',
  TransactionType type = TransactionType.expense,
  int amountMinor = 15000,
  String sourceWalletName = 'GCash',
  String? targetWalletName,
  String? categoryName = 'Food & Dining',
  DateTime? occurredAt,
}) {
  return DashboardTransaction(
    id: id,
    type: type,
    amount: Money(amountMinor),
    sourceWalletName: sourceWalletName,
    targetWalletName: targetWalletName,
    categoryName: categoryName,
    occurredAt: occurredAt ?? DateTime(2026, 11, 5, 10),
  );
}
