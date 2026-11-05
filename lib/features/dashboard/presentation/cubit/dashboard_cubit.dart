import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_net_worth.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/usecases/get_recent_transactions.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/get_wallets.dart';

import 'dashboard_state.dart';

/// Loads every dashboard section concurrently and refreshes on ledger writes.
class DashboardCubit extends Cubit<DashboardState> {
  DashboardCubit({
    required GetNetWorth getNetWorth,
    required GetMonthSummary getMonthSummary,
    required GetCategoryBreakdown getCategoryBreakdown,
    required GetRecentTransactions getRecentTransactions,
    required GetWallets wallets,
    required LedgerBus ledgerBus,
    DateTime Function()? clock,
  })  : _netWorth = getNetWorth,
        _monthSummary = getMonthSummary,
        _breakdown = getCategoryBreakdown,
        _recent = getRecentTransactions,
        _walletList = wallets,
        _clock = clock ?? DateTime.now,
        super(const DashboardInitial()) {
    _subscription = ledgerBus.changes.listen((_) {
      if (!isClosed) {
        unawaited(load());
      }
    });
  }

  final GetNetWorth _netWorth;
  final GetMonthSummary _monthSummary;
  final GetCategoryBreakdown _breakdown;
  final GetRecentTransactions _recent;
  final GetWallets _walletList;
  final DateTime Function() _clock;
  late final StreamSubscription<void> _subscription;

  Future<void> load() async {
    if (isClosed) {
      return;
    }
    emit(const DashboardLoading());

    final DateTime now = _clock();
    final DateTime month = DateTime(now.year, now.month);

    try {
      // Start every query before awaiting any of them.
      final Future<Money> netWorthFuture = _netWorth();
      final Future<MonthSummary> summaryFuture =
          _monthSummary(month: month);
      final Future<List<CategoryBreakdown>> breakdownFuture =
          _breakdown(month: month);
      final Future<List<DashboardTransaction>> recentFuture =
          _recent(limit: 20);
      final Future<({List<Wallet> active, List<Wallet> archived})>
          walletsFuture = _walletList();

      final Money netWorth = await netWorthFuture;
      final MonthSummary summary = await summaryFuture;
      final List<CategoryBreakdown> breakdown = await breakdownFuture;
      final List<DashboardTransaction> recent = await recentFuture;
      final ({List<Wallet> active, List<Wallet> archived}) walletResult =
          await walletsFuture;

      if (isClosed) {
        return;
      }

      final List<Wallet> sorted = List<Wallet>.of(walletResult.active)
        ..sort((Wallet a, Wallet b) => b.balance.compareTo(a.balance));

      emit(
        DashboardLoaded(
          month: month,
          netWorth: netWorth,
          summary: summary,
          breakdown: breakdown,
          recent: recent,
          wallets: sorted.take(5).toList(growable: false),
          walletCount: walletResult.active.length,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed) {
        return;
      }
      emit(DashboardFailure(failure.message));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(const DashboardFailure('Could not load the dashboard'));
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
