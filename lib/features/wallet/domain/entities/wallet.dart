import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';

import 'account_type.dart';

class Wallet extends Equatable {
  const Wallet({
    required this.id,
    required this.name,
    required this.accountType,
    required this.iconIdentifier,
    required this.balance,
    required this.createdAt,
    required this.updatedAt,
    this.sortOrder = 0,
    this.isArchived = false,
  });

  final String id;
  final String name;
  final AccountType accountType;
  final String iconIdentifier;
  final Money balance;
  final int sortOrder;
  final bool isArchived;
  final DateTime createdAt;
  final DateTime updatedAt;

  Wallet copyWith({
    String? name,
    AccountType? accountType,
    String? iconIdentifier,
    Money? balance,
    int? sortOrder,
    bool? isArchived,
    DateTime? updatedAt,
  }) {
    return Wallet(
      id: id,
      name: name ?? this.name,
      accountType: accountType ?? this.accountType,
      iconIdentifier: iconIdentifier ?? this.iconIdentifier,
      balance: balance ?? this.balance,
      sortOrder: sortOrder ?? this.sortOrder,
      isArchived: isArchived ?? this.isArchived,
      createdAt: createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  List<Object?> get props => <Object?>[
        id,
        name,
        accountType,
        iconIdentifier,
        balance,
        sortOrder,
        isArchived,
        createdAt,
        updatedAt,
      ];
}