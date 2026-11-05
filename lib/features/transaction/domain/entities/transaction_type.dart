enum TransactionType {
  expense('EXPENSE'),
  income('INCOME'),
  transfer('TRANSFER');

  const TransactionType(this.dbValue);

  final String dbValue;

  bool get isTransfer => this == TransactionType.transfer;

  static TransactionType fromDb(String value) =>
      TransactionType.values.firstWhere(
        (TransactionType type) => type.dbValue == value,
        orElse: () => throw ArgumentError('Unknown transaction type: $value'),
      );
}