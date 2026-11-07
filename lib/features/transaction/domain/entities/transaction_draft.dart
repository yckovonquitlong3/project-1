import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';

/// Pre-fill values for the transaction form. Never saved automatically.
class TransactionDraft extends Equatable {
  const TransactionDraft({
    this.type = TransactionType.expense,
    this.amount,
    this.sourceWalletId,
    this.categoryId,
    this.note,
  });

  final TransactionType type;
  final Money? amount;
  final String? sourceWalletId;
  final String? categoryId;
  final String? note;

  @override
  List<Object?> get props => <Object?>[
        type,
        amount,
        sourceWalletId,
        categoryId,
        note,
      ];
}
