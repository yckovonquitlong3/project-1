import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';

void main() {
  group('Money.parsePesos', () {
    test('parses whole pesos', () {
      expect(Money.parsePesos('1234').minorUnits, 123400);
    });

    test('parses two decimals', () {
      expect(Money.parsePesos('1234.50').minorUnits, 123450);
    });

    test('parses a single decimal as tens of centavos', () {
      expect(Money.parsePesos('1.5').minorUnits, 150);
    });

    test('parses thousands separators', () {
      expect(Money.parsePesos('1,234.56').minorUnits, 123456);
    });

    test('parses the smallest unit', () {
      expect(Money.parsePesos('0.01').minorUnits, 1);
    });

    test('rejects more than two decimals', () {
      expect(() => Money.parsePesos('12.345'), throwsFormatException);
    });

    test('rejects negative amounts', () {
      expect(() => Money.parsePesos('-5'), throwsFormatException);
    });

    test('rejects zero', () {
      expect(() => Money.parsePesos('0'), throwsFormatException);
      expect(() => Money.parsePesos('0.00'), throwsFormatException);
    });

    test('rejects empty input', () {
      expect(() => Money.parsePesos('   '), throwsFormatException);
    });

    test('rejects non numeric input', () {
      expect(() => Money.parsePesos('12a'), throwsFormatException);
    });
  });

  group('Money.parsePesosOrZero', () {
    test('treats blank as zero', () {
      expect(Money.parsePesosOrZero('').minorUnits, 0);
      expect(Money.parsePesosOrZero('   ').minorUnits, 0);
    });

    test('treats zero as zero', () {
      expect(Money.parsePesosOrZero('0').minorUnits, 0);
      expect(Money.parsePesosOrZero('0.00').minorUnits, 0);
    });

    test('parses a normal fee', () {
      expect(Money.parsePesosOrZero('15').minorUnits, 1500);
      expect(Money.parsePesosOrZero('15.50').minorUnits, 1550);
      expect(Money.parsePesosOrZero('1,234.56').minorUnits, 123456);
    });

    test('rejects negative and over-precise fees', () {
      expect(() => Money.parsePesosOrZero('-1'), throwsFormatException);
      expect(() => Money.parsePesosOrZero('1.234'), throwsFormatException);
    });
  });

  group('Money.format', () {
    test('formats with symbol, grouping and two decimals', () {
      expect(const Money(123450).format(), '${Money.currencySymbol}1,234.50');
    });

    test('keeps trailing zero centavos', () {
      expect(const Money(50000).format(), '${Money.currencySymbol}500.00');
    });

    test('formats sub peso values', () {
      expect(const Money(5).format(), '${Money.currencySymbol}0.05');
    });

    test('formats negative values', () {
      expect(const Money(-123450).format(), '-${Money.currencySymbol}1,234.50');
    });
  });

  group('Money arithmetic', () {
    test('adds and subtracts exactly', () {
      const Money a = Money(1000);
      const Money b = Money(1);
      expect((a - b).minorUnits, 999);
      expect((a + b).minorUnits, 1001);
    });

    test('equality and comparison', () {
      expect(const Money(100), const Money(100));
      expect(const Money(100).compareTo(const Money(200)), lessThan(0));
    });
  });
}