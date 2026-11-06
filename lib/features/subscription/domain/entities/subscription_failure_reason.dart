enum SubscriptionFailureReason {
  insufficientBalance('INSUFFICIENT_BALANCE'),
  walletArchived('WALLET_ARCHIVED'),
  categoryArchived('CATEGORY_ARCHIVED'),
  manualPaymentRequired('MANUAL_PAYMENT_REQUIRED');

  const SubscriptionFailureReason(this.dbValue);

  final String dbValue;

  static SubscriptionFailureReason? fromDb(String? value) {
    if (value == null) {
      return null;
    }
    return SubscriptionFailureReason.values.firstWhere(
      (SubscriptionFailureReason reason) => reason.dbValue == value,
      orElse: () => throw ArgumentError('Unknown subscription failure: $value'),
    );
  }
}
