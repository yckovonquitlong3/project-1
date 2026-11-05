import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

/// A transaction plus the entities its ids point at, ready to display or edit.
class TransactionDetail extends Equatable {
  const TransactionDetail({
    required this.record,
    required this.sourceWallet,
    this.targetWallet,
    this.category,
  });

  final TransactionRecord record;
  final Wallet sourceWallet;
  final Wallet? targetWallet;
  final Category? category;

  @override
  List<Object?> get props => <Object?>[
        record,
        sourceWallet,
        targetWallet,
        category,
      ];
}
