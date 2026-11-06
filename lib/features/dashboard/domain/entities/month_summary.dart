import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';

class MonthSummary extends Equatable {
  const MonthSummary({
    required this.income,
    required this.expense,
    this.fees = Money.zero,
  });

  static const MonthSummary empty = MonthSummary(
    income: Money.zero,
    expense: Money.zero,
  );

  final Money income;

  /// All outflow except transfers, including transfer fees.
  final Money expense;

  /// The transfer-fee portion of [expense].
  final Money fees;

  Money get net => income - expense;

  @override
  List<Object?> get props => <Object?>[income, expense, fees];
}
