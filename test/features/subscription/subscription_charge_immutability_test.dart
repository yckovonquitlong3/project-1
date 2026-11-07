import 'package:flutter_test/flutter_test.dart';
import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/data/repositories/category_repository_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/data/repositories/subscription_repository_impl.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/usecases/run_due_subscriptions.dart';
import 'package:multi_wallet_tracker/features/transaction/data/repositories/transaction_repository_impl.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/delete_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/edit_transaction.dart';
import 'package:multi_wallet_tracker/features/wallet/data/repositories/wallet_repository_impl.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

import '../../helpers/subscription_test_helpers.dart';

void main() {
  late AppDatabase appDatabase;
  late LedgerBus ledgerBus;
  late WalletRepositoryImpl wallets;
  late TransactionRepositoryImpl transactions;
  late CategoryRepositoryImpl categories;
  late SubscriptionRepositoryImpl subscriptions;

  final DateTime repositoryNow = DateTime(2026, 9, 1, 8);
  final DateTime chargeNow = DateTime(2026, 11, 1, 9, 5);

  setUpAll(sqfliteFfiInit);

  setUp(() async {
    appDatabase = AppDatabase(
      dbFactory: databaseFactoryFfi,
      path: inMemoryDatabasePath,
    );
    ledgerBus = LedgerBus();
    wallets = WalletRepositoryImpl(database: appDatabase, ledgerBus: ledgerBus);
    transactions = TransactionRepositoryImpl(
      database: appDatabase,
      ledgerBus: ledgerBus,
    );
    categories = CategoryRepositoryImpl(database: appDatabase);
    subscriptions = SubscriptionRepositoryImpl(
      database: appDatabase,
      clock: () => repositoryNow,
    );
    await appDatabase.database;
  });

  tearDown(() async {
    await ledgerBus.dispose();
    await appDatabase.close();
  });

  Future<({Wallet wallet, Subscription subscription, TransactionRecord charge})>
      seedCharge() async {
    final Wallet wallet = await wallets.create(
      name: 'GCash',
      accountType: AccountType.eWallet,
      iconIdentifier: 'phone_android',
      openingBalance: const Money(200000),
    );
    final Subscription subscription = await subscriptions.create(
      name: 'Claude Pro',
      amount: const Money(115000),
      walletId: wallet.id,
      categoryId: 'cat-exp-subscriptions',
      cycle: BillingCycle.monthly,
      nextBillingAt: DateTime(2026, 11, 1, 9),
      autoDeduct: true,
    );
    await RunDueSubscriptions(
      subscriptions: subscriptions,
      wallets: wallets,
      categories: categories,
      notifier: FakeSubscriptionNotifier(),
      ledgerBus: ledgerBus,
      clock: () => chargeNow,
    ).runAutomatic();

    final List<TransactionRecord> charges = (await transactions.recent())
        .where((TransactionRecord record) => record.subscriptionId != null)
        .toList(growable: false);
    return (wallet: wallet, subscription: subscription, charge: charges.single);
  }

  Future<void> expectStateUnchanged({
    required Wallet wallet,
    required Subscription subscription,
    required TransactionRecord charge,
  }) async {
    expect((await wallets.byId(wallet.id))!.balance, const Money(85000));
    expect(await transactions.byId(charge.id), isNotNull);
    final Subscription stored = (await subscriptions.byId(subscription.id))!;
    expect(stored.nextBillingAt, DateTime(2026, 12, 1, 9));
    expect(stored.lastPaidAt, chargeNow);
    expect(await transactions.verifyBalances(), isEmpty);
  }

  test('deleting a subscription charge is rejected', () async {
    final ({Wallet wallet, Subscription subscription, TransactionRecord charge})
        seeded = await seedCharge();

    await expectLater(
      DeleteTransaction(transactions: transactions)(seeded.charge.id),
      throwsA(isA<ConflictFailure>()),
    );

    await expectStateUnchanged(
      wallet: seeded.wallet,
      subscription: seeded.subscription,
      charge: seeded.charge,
    );
  });

  test('editing a subscription charge is rejected', () async {
    final ({Wallet wallet, Subscription subscription, TransactionRecord charge})
        seeded = await seedCharge();

    await expectLater(
      EditTransaction(
        transactions: transactions,
        wallets: wallets,
        categories: categories,
      )(
        previous: seeded.charge,
        amount: const Money(1000),
        note: 'changed',
      ),
      throwsA(isA<ConflictFailure>()),
    );

    final TransactionRecord stored =
        (await transactions.byId(seeded.charge.id))!;
    expect(stored.amount, const Money(115000));
    expect(stored.subscriptionId, seeded.subscription.id);
    expect(stored.billingPeriod, '2026-11-01');
    await expectStateUnchanged(
      wallet: seeded.wallet,
      subscription: seeded.subscription,
      charge: seeded.charge,
    );
  });

  test('the repository also rejects direct edit and delete calls', () async {
    final ({Wallet wallet, Subscription subscription, TransactionRecord charge})
        seeded = await seedCharge();

    await expectLater(
      transactions.delete(seeded.charge),
      throwsA(isA<ConflictFailure>()),
    );
    await expectLater(
      transactions.edit(seeded.charge, seeded.charge),
      throwsA(isA<ConflictFailure>()),
    );

    await expectStateUnchanged(
      wallet: seeded.wallet,
      subscription: seeded.subscription,
      charge: seeded.charge,
    );
  });
}
