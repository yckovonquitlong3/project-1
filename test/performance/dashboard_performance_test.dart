import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/dashboard/data/repositories/dashboard_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

/// Seeds 10,000 rows in one batch and checks the dashboard query budget from
/// SPEC section 9 (every list/aggregate query under 50 ms).
///
/// This measures SQL shape and query plans on the host VM. The on-device check
/// is a separate manual step.
void main() {
  setUpAll(sqfliteFfiInit);

  test(
    'dashboard queries stay under 50 ms with 10,000 transactions',
    () async {
      final AppDatabase appDatabase = AppDatabase(
        dbFactory: databaseFactoryFfi,
        path: inMemoryDatabasePath,
      );
      final LedgerBus ledgerBus = LedgerBus();
      addTearDown(() async {
        await ledgerBus.dispose();
        await appDatabase.close();
      });

      final Database db = await appDatabase.database;
      final List<String> walletIds = <String>['perf-1', 'perf-2', 'perf-3'];
      final DateTime created = DateTime(2026, 11, 15, 12);
      final int createdMs = epochMillis(created);

      for (final String id in walletIds) {
        await db.insert('wallets', <String, Object?>{
          'id': id,
          'name': 'Wallet $id',
          'account_type': 'CASH',
          'icon_identifier': 'payments',
          'balance_minor': 0,
          'sort_order': 0,
          'is_archived': 0,
          'created_at_ms': createdMs,
          'updated_at_ms': createdMs,
        });
      }

      final Map<String, int> deltas = <String, int>{
        for (final String id in walletIds) id: 0,
      };
      const List<String> expenseCategories = <String>[
        'cat-exp-groceries',
        'cat-exp-transportation',
        'cat-exp-utilities',
        'cat-exp-food-dining',
      ];
      const List<String> incomeCategories = <String>[
        'cat-inc-salary',
        'cat-inc-allowance',
      ];

      final Stopwatch seedWatch = Stopwatch()..start();
      await db.transaction((Transaction txn) async {
        final Batch batch = txn.batch();
        for (var index = 0; index < 10000; index++) {
          final int kind = index % 3;
          final int amount = (index % 500 + 1) * 100;
          final String source = walletIds[index % walletIds.length];
          String? target;
          String? category;
          final String type;

          if (kind == 0) {
            type = 'EXPENSE';
            category = expenseCategories[index % expenseCategories.length];
            deltas[source] = (deltas[source] ?? 0) - amount;
          } else if (kind == 1) {
            type = 'INCOME';
            category = incomeCategories[index % incomeCategories.length];
            deltas[source] = (deltas[source] ?? 0) + amount;
          } else {
            type = 'TRANSFER';
            target = walletIds[(index + 1) % walletIds.length];
            deltas[source] = (deltas[source] ?? 0) - amount;
            deltas[target] = (deltas[target] ?? 0) + amount;
          }

          final DateTime occurred =
              DateTime(2026, 1 + (index % 12), 1 + (index % 27), 10);
          batch.insert('transactions', <String, Object?>{
            'id': 'perf-tx-$index',
            'amount_minor': amount,
            'transaction_type': type,
            'source_wallet_id': source,
            'target_wallet_id': target,
            'category_id': category,
            'occurred_at_ms': epochMillis(occurred),
            'local_date': localDateOf(occurred),
            'note': null,
            'created_at_ms': createdMs,
            'updated_at_ms': createdMs,
          });
        }
        for (final String id in walletIds) {
          batch.update(
            'wallets',
            <String, Object?>{
              'balance_minor': deltas[id],
              'updated_at_ms': createdMs,
            },
            where: 'id = ?',
            whereArgs: <Object?>[id],
          );
        }
        await batch.commit(noResult: true);
      });
      seedWatch.stop();
      debugPrint(
        'Seeded 10,000 transactions in ${seedWatch.elapsedMilliseconds} ms',
      );

      final DashboardRepositoryImpl dashboard =
          DashboardRepositoryImpl(database: appDatabase);
      final WalletRepositoryImpl wallets = WalletRepositoryImpl(
        database: appDatabase,
        ledgerBus: ledgerBus,
      );

      // Warm the query cache and the SQLite statement cache.
      await dashboard.netWorth();
      await dashboard.monthSummary(DateTime(2026, 11));
      await dashboard.categoryBreakdown(DateTime(2026, 11));
      await dashboard.recentTransactions(limit: 20);
      await wallets.all(includeArchived: true);

      Future<int> averageMicros(Future<void> Function() query) async {
        const int runs = 5;
        var total = 0;
        for (var run = 0; run < runs; run++) {
          final Stopwatch watch = Stopwatch()..start();
          await query();
          watch.stop();
          total += watch.elapsedMicroseconds;
        }
        return total ~/ runs;
      }

      final Map<String, int> results = <String, int>{
        'net worth': await averageMicros(() async {
          await dashboard.netWorth();
        }),
        'month totals': await averageMicros(() async {
          await dashboard.monthSummary(DateTime(2026, 11));
        }),
        'category breakdown': await averageMicros(() async {
          await dashboard.categoryBreakdown(DateTime(2026, 11));
        }),
        'recent transactions': await averageMicros(() async {
          await dashboard.recentTransactions(limit: 20);
        }),
        'wallet list': await averageMicros(() async {
          await wallets.all(includeArchived: true);
        }),
      };

      for (final MapEntry<String, int> entry in results.entries) {
        debugPrint('${entry.key}: ${entry.value / 1000} ms');
        expect(
          entry.value,
          lessThan(50000),
          reason: '${entry.key} exceeded the 50 ms budget',
        );
      }
    },
    timeout: const Timeout(Duration(minutes: 2)),
  );
}
