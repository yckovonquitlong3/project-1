import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

sealed class DashboardState extends Equatable {
  const DashboardState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class DashboardInitial extends DashboardState {
  const DashboardInitial();
}

final class DashboardLoading extends DashboardState {
  const DashboardLoading();
}

final class DashboardLoaded extends DashboardState {
  const DashboardLoaded({
    required this.month,
    required this.netWorth,
    required this.summary,
    required this.breakdown,
    required this.recent,
    required this.wallets,
    required this.walletCount,
  });

  final DateTime month;
  final Money netWorth;
  final MonthSummary summary;
  final List<CategoryBreakdown> breakdown;
  final List<DashboardTransaction> recent;
  final List<Wallet> wallets;
  final int walletCount;

  bool get isEmpty => walletCount == 0 && recent.isEmpty;

  @override
  List<Object?> get props => <Object?>[
        month,
        netWorth,
        summary,
        breakdown,
        recent,
        wallets,
        walletCount,
      ];
}

final class DashboardFailure extends DashboardState {
  const DashboardFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
