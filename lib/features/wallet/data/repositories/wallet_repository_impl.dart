import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/database/seed.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/transaction/data/daos/transaction_dao.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/wallet/data/daos/wallet_dao.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:sqflite/sqflite.dart';
import 'package:uuid/uuid.dart';

class WalletRepositoryImpl implements WalletRepository {
  WalletRepositoryImpl({
    required AppDatabase database,
    required LedgerBus ledgerBus,
    Uuid? uuid,
    WalletDao walletDao = const WalletDao(),
    TransactionDao transactionDao = const TransactionDao(),
  })  : _db = database,
        _bus = ledgerBus,
        _uuid = uuid ?? const Uuid(),
        _wallets = walletDao,
        _transactions = transactionDao;

  final AppDatabase _db;
  final LedgerBus _bus;
  final Uuid _uuid;
  final WalletDao _wallets;
  final TransactionDao _transactions;

  @override
  Future<List<Wallet>> all({bool includeArchived = false}) async {
    final Database db = await _db.database;
    try {
      return await _wallets.all(db, includeArchived: includeArchived);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load wallets', cause: error);
    }
  }

  @override
  Future<Wallet?> byId(String id) async {
    final Database db = await _db.database;
    try {
      return await _wallets.byId(db, id);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load the wallet', cause: error);
    }
  }

  @override
  Future<Wallet> create({
    required String name,
    required AccountType accountType,
    required String iconIdentifier,
    required Money openingBalance,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationFailure('Wallet name is required');
    }
    if (openingBalance.isNegative) {
      throw const ValidationFailure('Opening balance cannot be negative');
    }

    final Database db = await _db.database;
    final DateTime now = DateTime.now();
    final String walletId = _uuid.v4();
    final Wallet wallet = Wallet(
      id: walletId,
      name: trimmedName,
      accountType: accountType,
      iconIdentifier: iconIdentifier,
      balance: Money.zero,
      createdAt: now,
      updatedAt: now,
    );

    try {
      await db.transaction((Transaction txn) async {
        await _wallets.insert(txn, wallet);
        if (openingBalance.isPositive) {
          final TransactionRecord opening = TransactionRecord(
            id: _uuid.v4(),
            amount: openingBalance,
            type: TransactionType.income,
            sourceWalletId: walletId,
            categoryId: kOpeningBalanceCategoryId,
            occurredAt: now,
            localDate: localDateOf(now),
            note: 'Opening balance',
            createdAt: now,
            updatedAt: now,
          );
          await _transactions.insert(txn, opening);
          await _transactions.applyEffect(txn, opening, 1);
        }
      });
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not create the wallet', cause: error);
    }

    _bus.notify();
    final Wallet? created = await byId(walletId);
    if (created == null) {
      throw const NotFoundFailure('Wallet disappeared after creation');
    }
    return created;
  }

  @override
  Future<Wallet> update({
    required String id,
    required String name,
    required AccountType accountType,
    required String iconIdentifier,
  }) async {
    final String trimmedName = name.trim();
    if (trimmedName.isEmpty) {
      throw const ValidationFailure('Wallet name is required');
    }

    final Database db = await _db.database;
    final Wallet? existing = await _wallets.byId(db, id);
    if (existing == null) {
      throw const NotFoundFailure('Wallet not found');
    }

    final Wallet updated = existing.copyWith(
      name: trimmedName,
      accountType: accountType,
      iconIdentifier: iconIdentifier,
      updatedAt: DateTime.now(),
    );

    try {
      await _wallets.update(db, updated);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not update the wallet', cause: error);
    }

    _bus.notify();
    return updated;
  }

  @override
  Future<void> archive(String id) => _setArchived(id, archived: true);

  @override
  Future<void> restore(String id) => _setArchived(id, archived: false);

  Future<void> _setArchived(String id, {required bool archived}) async {
    final Database db = await _db.database;
    try {
      if (archived &&
          await _wallets.countSubscriptions(db, id, activeOnly: true) > 0) {
        throw const ConflictFailure(
          'Archive or move its active subscriptions first',
        );
      }
      await _wallets.setArchived(
        db,
        id,
        archived: archived,
        updatedAtMs: epochMillis(DateTime.now()),
      );
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not update the wallet', cause: error);
    }
    _bus.notify();
  }

  @override
  Future<bool> hasTransactions(String id) async {
    final Database db = await _db.database;
    try {
      return await _wallets.countTransactions(db, id) > 0;
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not inspect the wallet', cause: error);
    }
  }

  @override
  Future<void> hardDelete(String id) async {
    if (await hasTransactions(id)) {
      throw const ConflictFailure(
        'Archive this wallet instead: it still has transactions',
      );
    }
    final Database db = await _db.database;
    try {
      if (await _wallets.countSubscriptions(db, id) > 0) {
        throw const ConflictFailure(
          'Remove or archive its subscriptions first',
        );
      }
      await _wallets.delete(db, id);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not delete the wallet', cause: error);
    }
    _bus.notify();
  }
}