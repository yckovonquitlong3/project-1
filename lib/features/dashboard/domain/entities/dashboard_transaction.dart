import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';

class DashboardTransaction extends Equatable {
  const DashboardTransaction({
    required this.id,
    required this.type,
    required this.amount,
    required this.sourceWalletName,
    required this.occurredAt,
    this.targetWalletName,
    this.categoryName,
  });

  final String id;
  final TransactionType type;
  final Money amount;
  final String sourceWalletName;
  final String? targetWalletName;
  final String? categoryName;
  final DateTime occurredAt;

  @override
  List<Object?> get props => <Object?>[
        id,
        type,
        amount,
        sourceWalletName,
        targetWalletName,
        categoryName,
        occurredAt,
      ];
}