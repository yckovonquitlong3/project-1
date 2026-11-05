import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

void main() {
  final DateTime createdAt = DateTime(2026, 1, 1, 8);
  final DateTime updatedAt = DateTime(2026, 1, 2, 9);

  Wallet wallet() => Wallet(
        id: 'w1',
        name: 'GCash',
        accountType: AccountType.eWallet,
        iconIdentifier: 'wallet',
        balance: const Money(100000),
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  group('Wallet', () {
    test('equality compares every field', () {
      expect(wallet(), wallet());
      expect(wallet() == wallet().copyWith(name: 'Maya'), isFalse);
      expect(wallet().hashCode, wallet().hashCode);
    });

    test('copyWith keeps identity and creation time', () {
      final Wallet changed = wallet().copyWith(
        name: 'Maya',
        accountType: AccountType.bank,
        balance: const Money(5),
        isArchived: true,
      );

      expect(changed.id, 'w1');
      expect(changed.createdAt, createdAt);
      expect(changed.updatedAt, updatedAt);
      expect(changed.name, 'Maya');
      expect(changed.accountType, AccountType.bank);
      expect(changed.balance, const Money(5));
      expect(changed.isArchived, isTrue);
    });

    test('copyWith without arguments is a copy', () {
      expect(wallet().copyWith(), wallet());
    });
  });

  group('AccountType', () {
    test('maps every value to and from its database string', () {
      for (final AccountType type in AccountType.values) {
        expect(AccountType.fromDb(type.dbValue), type);
      }
    });

    test('rejects an unknown database string', () {
      expect(() => AccountType.fromDb('CRYPTO'), throwsArgumentError);
    });
  });

  group('Category', () {
    const Category category = Category(
      id: 'c1',
      name: 'Food & Dining',
      type: CategoryType.expense,
      iconIdentifier: 'restaurant',
      colorHex: '#F44336',
      sortOrder: 4,
    );

    test('equality compares every field', () {
      expect(category, category);
      expect(
        category ==
            const Category(
              id: 'c1',
              name: 'Food & Dining',
              type: CategoryType.expense,
              iconIdentifier: 'restaurant',
              colorHex: '#FF0000',
              sortOrder: 4,
            ),
        isFalse,
      );
    });

    test('CategoryType maps both ways', () {
      for (final CategoryType type in CategoryType.values) {
        expect(CategoryType.fromDb(type.dbValue), type);
      }
      expect(() => CategoryType.fromDb('TRANSFER'), throwsArgumentError);
    });
  });

  group('TransactionRecord', () {
    TransactionRecord record() => TransactionRecord(
          id: 't1',
          amount: const Money(15000),
          type: TransactionType.expense,
          sourceWalletId: 'w1',
          categoryId: 'c1',
          occurredAt: DateTime(2026, 11, 1, 7),
          localDate: '2026-11-01',
          note: 'lunch',
          createdAt: createdAt,
          updatedAt: updatedAt,
        );

    test('equality compares every field including the note', () {
      expect(record(), record());
      expect(
        record() ==
            TransactionRecord(
              id: 't1',
              amount: const Money(15000),
              type: TransactionType.expense,
              sourceWalletId: 'w1',
              categoryId: 'c1',
              occurredAt: DateTime(2026, 11, 1, 7),
              localDate: '2026-11-01',
              note: 'dinner',
              createdAt: createdAt,
              updatedAt: updatedAt,
            ),
        isFalse,
      );
    });

    test('only transfers affect two wallets', () {
      expect(record().affectsTwoWallets, isFalse);
      final TransactionRecord transfer = TransactionRecord(
        id: 't2',
        amount: const Money(1000),
        type: TransactionType.transfer,
        sourceWalletId: 'w1',
        targetWalletId: 'w2',
        occurredAt: DateTime(2026, 11, 1, 7),
        localDate: '2026-11-01',
        createdAt: createdAt,
        updatedAt: updatedAt,
      );
      expect(transfer.affectsTwoWallets, isTrue);
    });

    test('TransactionType maps both ways', () {
      for (final TransactionType type in TransactionType.values) {
        expect(TransactionType.fromDb(type.dbValue), type);
      }
      expect(() => TransactionType.fromDb('REFUND'), throwsArgumentError);
    });
  });
}
