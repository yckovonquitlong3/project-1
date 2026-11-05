import 'package:flutter/material.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';

String transactionTypeLabel(TransactionType type) => switch (type) {
      TransactionType.expense => 'Expense',
      TransactionType.income => 'Income',
      TransactionType.transfer => 'Transfer',
    };

IconData transactionTypeIcon(TransactionType type) => switch (type) {
      TransactionType.expense => Icons.arrow_upward,
      TransactionType.income => Icons.arrow_downward,
      TransactionType.transfer => Icons.swap_horiz,
    };

Color transactionTypeColor(BuildContext context, TransactionType type) {
  final ColorScheme scheme = Theme.of(context).colorScheme;
  return switch (type) {
    TransactionType.expense => scheme.error,
    TransactionType.income => scheme.primary,
    TransactionType.transfer => scheme.onSurfaceVariant,
  };
}

/// Expense and income are signed; a transfer only moves money.
String signedAmount(Money amount, TransactionType type) => switch (type) {
      TransactionType.expense => '-${amount.format()}',
      TransactionType.income => '+${amount.format()}',
      TransactionType.transfer => amount.format(),
    };
