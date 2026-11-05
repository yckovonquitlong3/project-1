import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';

class MonthSummary extends Equatable {
  const MonthSummary({required this.income, required this.expense});

  static const MonthSummary empty = MonthSummary(
    income: Money.zero,
    expense: Money.zero,
  );

  final Money income;
  final Money expense;

  Money get net => income - expense;

  @override
  List<Object?> get props => <Object?>[income, expense];
}