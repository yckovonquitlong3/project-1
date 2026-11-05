import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';

final class GetCategoryBreakdown {
  GetCategoryBreakdown({
    required DashboardRepository dashboard,
    DateTime Function()? clock,
  })  : _repo = dashboard,
        _clock = clock ?? DateTime.now;

  final DashboardRepository _repo;
  final DateTime Function() _clock;

  Future<List<CategoryBreakdown>> call({DateTime? month}) =>
      _repo.categoryBreakdown(month ?? _clock());
}
