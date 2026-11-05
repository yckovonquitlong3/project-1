enum AccountType {
  cash('CASH', 'Cash'),
  eWallet('E_WALLET', 'E-Wallet'),
  bank('BANK', 'Bank'),
  other('OTHER', 'Other');

  const AccountType(this.dbValue, this.label);

  final String dbValue;
  final String label;

  static AccountType fromDb(String value) => AccountType.values.firstWhere(
        (AccountType type) => type.dbValue == value,
        orElse: () => throw ArgumentError('Unknown account type: $value'),
      );
}