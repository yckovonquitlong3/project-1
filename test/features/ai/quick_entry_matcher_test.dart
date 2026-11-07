import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/features/ai/domain/quick_entry_matcher.dart';

void main() {
  const List<({String id, String name})> wallets = <({String id, String name})>[
    (id: 'w1', name: 'GCash'),
    (id: 'w2', name: 'Bank Account'),
    (id: 'w3', name: 'Maya'),
    (id: 'w4', name: 'Cash'),
  ];

  test('matches exact names case-insensitively', () {
    expect(matchLocalName('gcash', wallets), 'w1');
    expect(matchLocalName('  BANK ACCOUNT ', wallets), 'w2');
  });

  test('normalizes punctuation', () {
    expect(matchLocalName('g-cash', wallets), 'w1');
  });

  test('allows unique containment', () {
    expect(matchLocalName('Bank', wallets), 'w2');
  });

  test('leaves ambiguous names blank', () {
    expect(
      matchLocalName('Cash', <({String id, String name})>[
        (id: 'a', name: 'Cash'),
        (id: 'b', name: 'Cash'),
      ]),
      isNull,
    );
  });

  test('allows a unique fuzzy match', () {
    expect(matchLocalName('GCashh', wallets), 'w1');
  });

  test('returns null for null, empty, or unrelated names', () {
    expect(matchLocalName(null, wallets), isNull);
    expect(matchLocalName('  ', wallets), isNull);
    expect(matchLocalName('Completely different', wallets), isNull);
  });
}
