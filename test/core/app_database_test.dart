import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/database/migrations.dart';
import 'package:multi_wallet_tracker/core/database/seed.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late AppDatabase appDatabase;
  late Database db;

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    db = await appDatabase.database;
  });

  tearDown(() async {
    await appDatabase.close();
  });

  test('creates the three tables', () async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name IN ('wallets','categories','transactions') ORDER BY name",
    );
    expect(
      rows.map((Map<String, Object?> row) => row['name']).toList(),
      <String>['categories', 'transactions', 'wallets'],
    );
  });

  test('creates every index', () async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name LIKE 'idx_%' ORDER BY name",
    );
    expect(rows.length, 9);
  });

  test('creates the subscriptions table', () async {
    final List<Map<String, Object?>> rows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'subscriptions'",
    );
    expect(rows.length, 1);
  });

  test('adds the v2 transaction columns', () async {
    final List<Map<String, Object?>> rows =
        await db.rawQuery('PRAGMA table_info(transactions)');
    final List<String> names = rows
        .map((Map<String, Object?> row) => row['name']! as String)
        .toList();
    expect(names, containsAll(<String>[
      'fee_minor',
      'subscription_id',
      'billing_period',
    ]));
  });

  test('rejects a fee on an expense', () async {
    await db.insert('wallets', <String, Object?>{
      'id': 'w1',
      'name': 'Cash',
      'account_type': 'CASH',
      'icon_identifier': 'payments',
      'created_at_ms': 0,
      'updated_at_ms': 0,
    });

    await expectLater(
      db.insert('transactions', <String, Object?>{
        'id': 'fee-expense',
        'amount_minor': 100,
        'fee_minor': 5,
        'transaction_type': 'EXPENSE',
        'source_wallet_id': 'w1',
        'category_id': kOpeningBalanceCategoryId,
        'occurred_at_ms': 0,
        'local_date': '2026-11-01',
        'created_at_ms': 0,
        'updated_at_ms': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects a negative transfer fee', () async {
    await db.insert('wallets', <String, Object?>{
      'id': 'w1',
      'name': 'Cash',
      'account_type': 'CASH',
      'icon_identifier': 'payments',
      'created_at_ms': 0,
      'updated_at_ms': 0,
    });
    await db.insert('wallets', <String, Object?>{
      'id': 'w2',
      'name': 'Bank',
      'account_type': 'BANK',
      'icon_identifier': 'account_balance',
      'created_at_ms': 0,
      'updated_at_ms': 0,
    });

    await expectLater(
      db.insert('transactions', <String, Object?>{
        'id': 'negative-fee',
        'amount_minor': 100,
        'fee_minor': -1,
        'transaction_type': 'TRANSFER',
        'source_wallet_id': 'w1',
        'target_wallet_id': 'w2',
        'occurred_at_ms': 0,
        'local_date': '2026-11-01',
        'created_at_ms': 0,
        'updated_at_ms': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('enables foreign keys on this connection', () async {
    final List<Map<String, Object?>> rows = await db.rawQuery('PRAGMA foreign_keys');
    expect(rows.first.values.first, 1);
  });

  test('sets the schema version', () async {
    final List<Map<String, Object?>> rows = await db.rawQuery('PRAGMA user_version');
    expect(rows.first.values.first, kSchemaVersion);
  });

  test('seeds every default category exactly once', () async {
    final List<Map<String, Object?>> rows = await db.query('categories');
    expect(rows.length, kSeedCategories.length);

    await seedCategories(db);

    final List<Map<String, Object?>> again = await db.query('categories');
    expect(again.length, kSeedCategories.length);
  });

  test('every seeded category id is unique', () {
    final Set<String> ids =
        kSeedCategories.map((SeedCategory c) => c.id).toSet();
    expect(ids.length, kSeedCategories.length);
  });

  test('rejects a transaction referencing a missing wallet', () async {
    await expectLater(
      db.insert('transactions', <String, Object?>{
        'id': 'tx1',
        'amount_minor': 100,
        'transaction_type': 'EXPENSE',
        'source_wallet_id': 'missing',
        'category_id': kOpeningBalanceCategoryId,
        'occurred_at_ms': 0,
        'local_date': '2026-11-01',
        'created_at_ms': 0,
        'updated_at_ms': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects an unknown account type', () async {
    await expectLater(
      db.insert('wallets', <String, Object?>{
        'id': 'w1',
        'name': 'Cash',
        'account_type': 'CRYPTO',
        'icon_identifier': 'payments',
        'created_at_ms': 0,
        'updated_at_ms': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects a transfer without a target wallet', () async {
    await db.insert('wallets', <String, Object?>{
      'id': 'w1',
      'name': 'Cash',
      'account_type': 'CASH',
      'icon_identifier': 'payments',
      'created_at_ms': 0,
      'updated_at_ms': 0,
    });

    await expectLater(
      db.insert('transactions', <String, Object?>{
        'id': 'tx2',
        'amount_minor': 100,
        'transaction_type': 'TRANSFER',
        'source_wallet_id': 'w1',
        'occurred_at_ms': 0,
        'local_date': '2026-11-01',
        'created_at_ms': 0,
        'updated_at_ms': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });

  test('rejects a transfer from a wallet to itself', () async {
    await db.insert('wallets', <String, Object?>{
      'id': 'w1',
      'name': 'Cash',
      'account_type': 'CASH',
      'icon_identifier': 'payments',
      'created_at_ms': 0,
      'updated_at_ms': 0,
    });

    await expectLater(
      db.insert('transactions', <String, Object?>{
        'id': 'tx3',
        'amount_minor': 100,
        'transaction_type': 'TRANSFER',
        'source_wallet_id': 'w1',
        'target_wallet_id': 'w1',
        'occurred_at_ms': 0,
        'local_date': '2026-11-01',
        'created_at_ms': 0,
        'updated_at_ms': 0,
      }),
      throwsA(isA<DatabaseException>()),
    );
  });
}