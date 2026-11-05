import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/repositories/dashboard_repository.dart';

final class GetMonthSummary {
  GetMonthSummary({
    required DashboardRepository dashboard,
    DateTime Function()? clock,
  })  : _repo = dashboard,
        _clock = clock ?? DateTime.now;

  final DashboardRepository _repo;
  final DateTime Function() _clock;

  Future<MonthSummary> call({DateTime? month}) =>
      _repo.monthSummary(month ?? _clock());
}
