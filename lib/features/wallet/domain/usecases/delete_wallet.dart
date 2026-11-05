import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

final class DeleteWallet {
  const DeleteWallet({required WalletRepository wallets}) : _walletRepo = wallets;

  final WalletRepository _walletRepo;

  Future<void> call(String id) async {
    final Wallet? wallet = await _walletRepo.byId(id);
    if (wallet == null) {
      throw const NotFoundFailure('Wallet not found');
    }
    if (await _walletRepo.hasTransactions(id)) {
      throw const ConflictFailure(
        'Archive this wallet instead: it still has transactions',
      );
    }
    await _walletRepo.hardDelete(id);
  }
}
