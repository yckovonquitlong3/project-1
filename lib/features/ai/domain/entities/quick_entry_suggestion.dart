import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';

/// Raw, untrusted suggestion returned by the model. It contains names, not
/// local ids; the use case maps them against active wallets/categories.
class QuickEntrySuggestion extends Equatable {
  const QuickEntrySuggestion({
    required this.amountText,
    required this.type,
    this.walletName,
    this.targetWalletName,
    this.categoryName,
    this.feeText,
    this.note,
  });

  final String amountText;
  final TransactionType type;
  final String? walletName;
  final String? targetWalletName;
  final String? categoryName;
  final String? feeText;
  final String? note;

  @override
  List<Object?> get props => <Object?>[
        amountText,
        type,
        walletName,
        targetWalletName,
        categoryName,
        feeText,
        note,
      ];
}
