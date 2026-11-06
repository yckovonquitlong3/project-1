import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/database/migrations.dart';
import 'package:multi_wallet_tracker/core/database/seed.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('a v1 database upgrades to v2 without losing data', () async {
    final Directory directory =
        Directory.systemTemp.createTempSync('wallet_migration_');
    final String path = p.join(directory.path, 'v1.db');
    final DateTime now = DateTime(2026, 11, 6, 10);
    final int nowMs = epochMillis(now);

    final Database v1 = await databaseFactoryFfi.openDatabase(
      path,
      options: OpenDatabaseOptions(
        version: 1,
        onConfigure: (Database db) async {
          await db.execute('PRAGMA foreign_keys = ON');
        },
        onCreate: (Database db, int version) async {
          await createSchemaV1(db);
          await seedCategories(db);
        },
      ),
    );

    await v1.insert('wallets', <String, Object?>{
      'id': 'w1',
      'name': 'Legacy wallet',
      'account_type': 'CASH',
      'icon_identifier': 'payments',
      'balance_minor': 15000,
      'sort_order': 0,
      'is_archived': 0,
      'created_at_ms': nowMs,
      'updated_at_ms': nowMs,
    });
    await v1.insert('transactions', <String, Object?>{
      'id': 'legacy-tx',
      'amount_minor': 15000,
      'transaction_type': 'EXPENSE',
      'source_wallet_id': 'w1',
      'category_id': 'cat-exp-food-dining',
      'occurred_at_ms': nowMs,
      'local_date': '2026-11-06',
      'note': 'legacy lunch',
      'created_at_ms': nowMs,
      'updated_at_ms': nowMs,
    });
    await v1.close();

    final AppDatabase appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: path,
    );
    addTearDown(() async {
      await appDatabase.close();
      try {
        directory.deleteSync(recursive: true);
      } catch (_) {
        // Best-effort cleanup on Windows.
      }
    });

    final Database db = await appDatabase.database;

    final List<Map<String, Object?>> versionRows =
        await db.rawQuery('PRAGMA user_version');
    expect(versionRows.first.values.first, kSchemaVersion);

    final List<Map<String, Object?>> walletRows = await db.query('wallets');
    expect(walletRows.length, 1);
    expect(walletRows.first['name'], 'Legacy wallet');
    expect(walletRows.first['balance_minor'], 15000);

    final List<Map<String, Object?>> transactionRows =
        await db.query('transactions');
    expect(transactionRows.length, 1);
    expect(transactionRows.first['id'], 'legacy-tx');
    expect(transactionRows.first['amount_minor'], 15000);
    expect(transactionRows.first['fee_minor'], 0);
    expect(transactionRows.first['subscription_id'], isNull);
    expect(transactionRows.first['billing_period'], isNull);

    final List<Map<String, Object?>> subscriptionTable = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'table' "
      "AND name = 'subscriptions'",
    );
    expect(subscriptionTable.length, 1);

    final List<Map<String, Object?>> indexRows = await db.rawQuery(
      "SELECT name FROM sqlite_master WHERE type = 'index' "
      "AND name LIKE 'idx_%'",
    );
    expect(indexRows.length, 9);
  });
}
