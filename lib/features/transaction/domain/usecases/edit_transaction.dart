import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/repositories/category_repository.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

import 'ledger_validation.dart';

/// Edits a transaction without changing its type.
///
/// Wallets and category default to the stored values, so the UI can send only
/// what the user touched. The repository reverses the old effect and applies
/// the new one in a single database transaction.
final class EditTransaction {
  EditTransaction({
    required TransactionRepository transactions,
    required WalletRepository wallets,
    required CategoryRepository categories,
    DateTime Function()? clock,
  })  : _transactionRepo = transactions,
        _walletRepo = wallets,
        _categoryRepo = categories,
        _clock = clock ?? DateTime.now;

  final TransactionRepository _transactionRepo;
  final WalletRepository _walletRepo;
  final CategoryRepository _categoryRepo;
  final DateTime Function() _clock;

  Future<TransactionRecord> call({
    required TransactionRecord previous,
    required Money amount,
    Money? fee,
    String? sourceWalletId,
    String? targetWalletId,
    String? categoryId,
    DateTime? occurredAt,
    String? note,
  }) async {
    if (previous.subscriptionId != null) {
      throw const ConflictFailure(kSubscriptionChargeImmutableMessage);
    }
    requirePositiveAmount(amount);
    final Money effectiveFee = previous.type == TransactionType.transfer
        ? (fee ?? previous.fee)
        : Money.zero;
    if (previous.type == TransactionType.transfer) {
      requireValidFee(effectiveFee);
    }

    final String source = sourceWalletId ?? previous.sourceWalletId;
    String? target;
    String? category;

    switch (previous.type) {
      case TransactionType.expense:
        category = categoryId ?? previous.categoryId;
        if (category == null) {
          throw const ValidationFailure('Choose a category');
        }
        // An unchanged wallet/category may have been archived since the
        // transaction was written; history must stay editable. Only a *new*
        // reference has to be active.
        if (source != previous.sourceWalletId) {
          await requireActiveWallet(_walletRepo, source);
        }
        if (category != previous.categoryId) {
          await requireActiveCategory(
            _categoryRepo,
            category,
            CategoryType.expense,
          );
        }
      case TransactionType.income:
        category = categoryId ?? previous.categoryId;
        if (category == null) {
          throw const ValidationFailure('Choose a category');
        }
        if (source != previous.sourceWalletId) {
          await requireActiveWallet(_walletRepo, source);
        }
        if (category != previous.categoryId) {
          await requireActiveCategory(
            _categoryRepo,
            category,
            CategoryType.income,
          );
        }
      case TransactionType.transfer:
        target = targetWalletId ?? previous.targetWalletId;
        if (target == null) {
          throw const ValidationFailure('Choose a destination wallet');
        }
        if (target == source) {
          throw const ValidationFailure('Choose two different wallets');
        }
        if (source != previous.sourceWalletId) {
          await requireActiveWallet(_walletRepo, source);
        }
        if (target != previous.targetWalletId) {
          await requireActiveWallet(_walletRepo, target);
        }
    }

    final DateTime when = occurredAt ?? previous.occurredAt;
    final DateTime now = _clock();
    final String? mergedNote = note ?? previous.note;

    return _transactionRepo.edit(
      previous,
      TransactionRecord(
        id: previous.id,
        amount: amount,
        fee: effectiveFee,
        type: previous.type,
        sourceWalletId: source,
        targetWalletId: target,
        categoryId: category,
        occurredAt: when,
        localDate: localDateOf(when),
        note: mergedNote == null || mergedNote.trim().isEmpty
            ? null
            : mergedNote.trim(),
        createdAt: previous.createdAt,
        updatedAt: now,
      ),
    );
  }
}
