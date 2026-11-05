import 'package:flutter/material.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';

/// Icons the wallet form offers. Stored by identifier so the database stays
/// independent of Flutter's icon codepoints.
const Map<String, ({IconData icon, String label})> kWalletIconChoices =
    <String, ({IconData icon, String label})>{
  'payments': (icon: Icons.payments_outlined, label: 'Cash'),
  'wallet': (icon: Icons.account_balance_wallet_outlined, label: 'Wallet'),
  'phone_android': (icon: Icons.phone_android_outlined, label: 'E-wallet'),
  'savings': (icon: Icons.savings_outlined, label: 'Savings'),
  'credit_card': (icon: Icons.credit_card_outlined, label: 'Card'),
  'account_balance': (icon: Icons.account_balance_outlined, label: 'Bank'),
};

IconData iconForWallet(String identifier) =>
    kWalletIconChoices[identifier]?.icon ??
    Icons.account_balance_wallet_outlined;

IconData iconForAccountType(AccountType type) => switch (type) {
      AccountType.cash => Icons.payments_outlined,
      AccountType.eWallet => Icons.phone_android_outlined,
      AccountType.bank => Icons.account_balance_outlined,
      AccountType.other => Icons.account_balance_wallet_outlined,
    };
