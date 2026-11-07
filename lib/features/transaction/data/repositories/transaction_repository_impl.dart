import 'package:multi_wallet_tracker/core/database/app_database.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/features/transaction/data/daos/transaction_dao.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:sqflite/sqflite.dart';

class TransactionRepositoryImpl implements TransactionRepository {
  TransactionRepositoryImpl({
    required AppDatabase database,
    required LedgerBus ledgerBus,
    TransactionDao transactionDao = const TransactionDao(),
  })  : _db = database,
        _bus = ledgerBus,
        _dao = transactionDao;

  final AppDatabase _db;
  final LedgerBus _bus;
  final TransactionDao _dao;

  @override
  Future<TransactionRecord> record(TransactionRecord record) async {
    final Database db = await _db.database;
    try {
      await db.transaction((Transaction txn) async {
        await _dao.insert(txn, record);
        await _dao.applyEffect(txn, record, 1);
      });
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not save the transaction', cause: error);
    }
    _bus.notify();
    return record;
  }

  @override
  Future<TransactionRecord> edit(
    TransactionRecord previous,
    TransactionRecord updated,
  ) async {
    if (previous.subscriptionId != null || updated.subscriptionId != null) {
      throw const ConflictFailure(kSubscriptionChargeImmutableMessage);
    }
    final Database db = await _db.database;
    try {
      await db.transaction((Transaction txn) async {
        await _dao.applyEffect(txn, previous, -1);
        await _dao.update(txn, updated);
        await _dao.applyEffect(txn, updated, 1);
      });
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not update the transaction', cause: error);
    }
    _bus.notify();
    return updated;
  }

  @override
  Future<void> delete(TransactionRecord record) async {
    if (record.subscriptionId != null) {
      throw const ConflictFailure(kSubscriptionChargeImmutableMessage);
    }
    final Database db = await _db.database;
    try {
      await db.transaction((Transaction txn) async {
        await _dao.applyEffect(txn, record, -1);
        await _dao.deleteById(txn, record.id);
      });
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not delete the transaction', cause: error);
    }
    _bus.notify();
  }

  @override
  Future<TransactionRecord?> byId(String id) async {
    final Database db = await _db.database;
    try {
      return await _dao.byId(db, id);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load the transaction', cause: error);
    }
  }

  @override
  Future<List<TransactionRecord>> recent({int limit = 20}) async {
    final Database db = await _db.database;
    try {
      return await _dao.recent(db, limit: limit);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load transactions', cause: error);
    }
  }

  @override
  Future<List<TransactionRecord>> forWallet(
    String walletId, {
    int limit = 50,
  }) async {
    final Database db = await _db.database;
    try {
      return await _dao.forWallet(db, walletId, limit: limit);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not load transactions', cause: error);
    }
  }

  @override
  Future<List<String>> verifyBalances() async {
    final Database db = await _db.database;
    try {
      return await _dao.mismatchedWallets(db);
    } on DatabaseException catch (error) {
      throw DatabaseFailure('Could not verify balances', cause: error);
    }
  }
}