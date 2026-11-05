import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';

import 'transaction_type.dart';

/// One row of the ledger. Named `TransactionRecord` to avoid colliding with
/// `sqflite`'s `Transaction` (which is a database handle).
class TransactionRecord extends Equatable {
  const TransactionRecord({
    required this.id,
    required this.amount,
    required this.type,
    required this.sourceWalletId,
    required this.occurredAt,
    required this.localDate,
    required this.createdAt,
    required this.updatedAt,
    this.targetWalletId,
    this.categoryId,
    this.note,
  });

  final String id;
  final Money amount;
  final TransactionType type;
  final String sourceWalletId;
  final String? targetWalletId;
  final String? categoryId;
  final DateTime occurredAt;

  /// Calendar date (`YYYY-MM-DD`) in the device's local time zone.
  final String localDate;

  final String? note;
  final DateTime createdAt;
  final DateTime updatedAt;

  bool get affectsTwoWallets => type.isTransfer;

  @override
  List<Object?> get props => <Object?>[
        id,
        amount,
        type,
        sourceWalletId,
        targetWalletId,
        categoryId,
        occurredAt,
        localDate,
        note,
        createdAt,
        updatedAt,
      ];
}