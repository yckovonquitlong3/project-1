import 'package:intl/intl.dart';

/// An amount of money stored as integer minor units (centavos).
///
/// Never use `double` for money: repeated addition of binary fractions drifts.
/// Every value in the ledger is a whole number of centavos.
class Money implements Comparable<Money> {
  const Money(this.minorUnits);

  static const Money zero = Money(0);

  /// Accepts `1,234.50`, `1234.5`, `1234`, `0.01`.
  /// Rejects empty input, negatives, zero, and more than two decimals.
  static final RegExp _validInput = RegExp(r'^\d{1,12}(\.\d{1,2})?$');

  static const String currencySymbol = '\u20B1';

  final int minorUnits;

  static Money parsePesos(String input) {
    final String normalized = input.trim().replaceAll(',', '');
    if (normalized.isEmpty) {
      throw const FormatException('Enter an amount');
    }
    if (!_validInput.hasMatch(normalized)) {
      throw const FormatException('Enter a valid amount (up to 2 decimals)');
    }
    final List<String> parts = normalized.split('.');
    final int pesos = int.parse(parts[0]);
    final int cents = parts.length == 1
        ? 0
        : int.parse(parts[1].padRight(2, '0'));
    final int value = pesos * 100 + cents;
    if (value <= 0) {
      throw const FormatException('Amount must be greater than zero');
    }
    return Money(value);
  }

  Money operator +(Money other) => Money(minorUnits + other.minorUnits);

  Money operator -(Money other) => Money(minorUnits - other.minorUnits);

  bool get isZero => minorUnits == 0;

  bool get isNegative => minorUnits < 0;

  bool get isPositive => minorUnits > 0;

  int get pesos => minorUnits ~/ 100;

  int get centavos => minorUnits.abs() % 100;

  /// `123450` -> `P1,234.50`
  String format() {
    final String sign = minorUnits < 0 ? '-' : '';
    final String pesosText =
        NumberFormat.decimalPattern('en_US').format(minorUnits.abs() ~/ 100);
    final String centsText = (minorUnits.abs() % 100).toString().padLeft(2, '0');
    return '$sign$currencySymbol$pesosText.$centsText';
  }

  @override
  int compareTo(Money other) => minorUnits.compareTo(other.minorUnits);

  @override
  bool operator ==(Object other) =>
      other is Money && other.minorUnits == minorUnits;

  @override
  int get hashCode => minorUnits.hashCode;

  @override
  String toString() => 'Money($minorUnits)';
}