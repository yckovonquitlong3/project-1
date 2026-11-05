import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';

final class GetRecentTransactions {
  const GetRecentTransactions({required DashboardRepository dashboard})
      : _repo = dashboard;

  final DashboardRepository _repo;

  Future<List<DashboardTransaction>> call({int limit = 20}) =>
      _repo.recentTransactions(limit: limit);
}
