import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/category/data/category_model.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/transaction/data/models/transaction_model.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/data/models/wallet_model.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

void main() {
  group('WalletModel', () {
    final Wallet wallet = Wallet(
      id: 'w1',
      name: 'GCash',
      accountType: AccountType.eWallet,
      iconIdentifier: 'wallet',
      balance: const Money(123456),
      sortOrder: 3,
      isArchived: true,
      createdAt: DateTime(2026, 1, 1, 8),
      updatedAt: DateTime(2026, 1, 2, 9),
    );

    test('round-trips through a SQLite row', () {
      final Map<String, Object?> row = WalletModel.toRow(wallet);
      expect(row['balance_minor'], 123456);
      expect(row['is_archived'], 1);
      expect(WalletModel.fromRow(row), wallet);
    });
  });

  group('TransactionModel', () {
    TransactionRecord record({
      required DateTime occurredAt,
      required String localDate,
    }) =>
        TransactionRecord(
          id: 't1',
          amount: const Money(15000),
          type: TransactionType.transfer,
          sourceWalletId: 'w1',
          targetWalletId: 'w2',
          occurredAt: occurredAt,
          localDate: localDate,
          note: 'moved to savings',
          createdAt: DateTime(2026, 11, 1, 8),
          updatedAt: DateTime(2026, 11, 1, 8),
        );

    test('round-trips through a SQLite row', () {
      final TransactionRecord original = record(
        occurredAt: DateTime(2026, 11, 1, 7),
        localDate: '2026-11-01',
      );
      final Map<String, Object?> row = TransactionModel.toRow(original);

      expect(row['amount_minor'], 15000);
      expect(row['occurred_at_ms'], epochMillis(original.occurredAt));
      expect(row['local_date'], '2026-11-01');
      expect(TransactionModel.fromRow(row), original);
    });

    test('stores the local date, not the UTC date, near midnight', () {
      final DateTime lateNight = DateTime(2026, 11, 1, 23, 59, 59);
      expect(localDateOf(lateNight), '2026-11-01');

      final TransactionRecord original = record(
        occurredAt: lateNight,
        localDate: localDateOf(lateNight),
      );
      expect(TransactionModel.toRow(original)['local_date'], '2026-11-01');
    });
  });

  group('CategoryModel', () {
    test('maps a row to the domain entity', () {
      final Category category = CategoryModel.fromRow(<String, Object?>{
        'id': 'c1',
        'name': 'Food & Dining',
        'type': 'EXPENSE',
        'icon_identifier': 'restaurant',
        'color_hex': '#F44336',
        'is_system': 0,
        'is_archived': 0,
        'sort_order': 4,
      });

      expect(category.type, CategoryType.expense);
      expect(category.isSystem, isFalse);
      expect(category.isArchived, isFalse);
      expect(category.sortOrder, 4);
    });
  });

  group('date helpers', () {
    test('month boundaries are stable at year end', () {
      expect(monthStartOf(DateTime(2026, 12, 31)), '2026-12-01');
      expect(nextMonthStartOf(DateTime(2026, 12, 31)), '2027-01-01');
    });

    test('epoch millis round-trip to the same instant', () {
      final DateTime value = DateTime(2026, 11, 1, 7, 30, 15);
      expect(fromEpochMillis(epochMillis(value)), value);
    });
  });
}
