import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';

/// Pre-fill values for the transaction form. Never saved automatically.
class TransactionDraft extends Equatable {
  const TransactionDraft({
    this.type = TransactionType.expense,
    this.amount,
    this.sourceWalletId,
    this.targetWalletId,
    this.categoryId,
    this.fee = Money.zero,
    this.note,
  });

  final TransactionType type;
  final Money? amount;
  final String? sourceWalletId;
  final String? targetWalletId;
  final String? categoryId;
  final Money fee;
  final String? note;

  @override
  List<Object?> get props => <Object?>[
        type,
        amount,
        sourceWalletId,
        targetWalletId,
        categoryId,
        fee,
        note,
      ];
}
