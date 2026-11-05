import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';

final class GetNetWorth {
  const GetNetWorth({required DashboardRepository dashboard})
      : _repo = dashboard;

  final DashboardRepository _repo;

  Future<Money> call() => _repo.netWorth();
}
