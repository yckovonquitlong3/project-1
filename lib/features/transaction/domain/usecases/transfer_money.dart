import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/core/utils/date_utils.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/repositories/transaction_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:uuid/uuid.dart';

import 'ledger_validation.dart';

final class TransferMoney {
  TransferMoney({
    required TransactionRepository transactions,
    required WalletRepository wallets,
    Uuid? uuid,
    DateTime Function()? clock,
  })  : _transactionRepo = transactions,
        _walletRepo = wallets,
        _uuid = uuid ?? const Uuid(),
        _clock = clock ?? DateTime.now;

  final TransactionRepository _transactionRepo;
  final WalletRepository _walletRepo;
  final Uuid _uuid;
  final DateTime Function() _clock;

  Future<TransactionRecord> call({
    required Money amount,
    required String sourceWalletId,
    required String targetWalletId,
    DateTime? occurredAt,
    String? note,
  }) async {
    requirePositiveAmount(amount);
    if (sourceWalletId == targetWalletId) {
      throw const ValidationFailure('Choose two different wallets');
    }
    await requireActiveWallet(_walletRepo, sourceWalletId);
    await requireActiveWallet(_walletRepo, targetWalletId);

    final DateTime when = occurredAt ?? _clock();
    final DateTime now = _clock();

    return _transactionRepo.record(
      TransactionRecord(
        id: _uuid.v4(),
        amount: amount,
        type: TransactionType.transfer,
        sourceWalletId: sourceWalletId,
        targetWalletId: targetWalletId,
        occurredAt: when,
        localDate: localDateOf(when),
        note: note == null || note.trim().isEmpty ? null : note.trim(),
        createdAt: now,
        updatedAt: now,
      ),
    );
  }
}
