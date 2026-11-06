enum BillingCycle {
  weekly('WEEKLY'),
  monthly('MONTHLY'),
  yearly('YEARLY');

  const BillingCycle(this.dbValue);

  final String dbValue;

  static BillingCycle fromDb(String value) => BillingCycle.values.firstWhere(
        (BillingCycle cycle) => cycle.dbValue == value,
        orElse: () => throw ArgumentError('Unknown billing cycle: $value'),
      );
}
