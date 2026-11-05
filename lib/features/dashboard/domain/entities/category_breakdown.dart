import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';

class CategoryBreakdown extends Equatable {
  const CategoryBreakdown({
    required this.categoryId,
    required this.name,
    required this.colorHex,
    required this.total,
  });

  final String categoryId;
  final String name;
  final String colorHex;
  final Money total;

  @override
  List<Object?> get props => <Object?>[categoryId, name, colorHex, total];
}