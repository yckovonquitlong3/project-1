import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:uuid/uuid.dart';

import 'ledger_validation.dart';

/// Shared implementation for the manual expense and income forms.
///
/// It validates input, builds the ledger row, and delegates the atomic write to
/// [TransactionRepository]. Balance arithmetic stays in the database layer.
abstract class EntryUseCase {
  EntryUseCase({
    required TransactionRepository transactions,
    required WalletRepository wallets,
    required CategoryRepository categories,
    required TransactionType type,
    required CategoryType categoryType,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _transactionRepo = transactions,
        _walletRepo = wallets,
        _categoryRepo = categories,
        _entryType = type,
        _entryCategoryType = categoryType,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final TransactionRepository _transactionRepo;
  final WalletRepository _walletRepo;
  final CategoryRepository _categoryRepo;
  final TransactionType _entryType;
  final CategoryType _entryCategoryType;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Future<TransactionRecord> call({
    required Money amount,
    required String walletId,
    required String categoryId,
    DateTime? occurredAt,
    String? note,
  }) async {
    requirePositiveAmount(amount);
    await requireActiveWallet(_walletRepo, walletId);
    await requireActiveCategory(_categoryRepo, categoryId, _entryCategoryType);

    final DateTime when = occurredAt ?? _clock();
    final DateTime now = _clock();

    return _transactionRepo.record(
      TransactionRecord(
        id: _uuid.v4(),
        amount: amount,
        type: _entryType,
        sourceWalletId: walletId,
        categoryId: categoryId,
        occurredAt: when,
        localDate: localDateOf(when),
        note: _normalizeNote(note),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }

  String? _normalizeNote(String? note) {
    if (note == null || note.trim().isEmpty) {
      return null;
    }
    return note.trim();
  }
}
