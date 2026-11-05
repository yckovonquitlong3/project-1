import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

final class RestoreWallet {
  const RestoreWallet({required WalletRepository wallets}) : _walletRepo = wallets;

  final WalletRepository _walletRepo;

  Future<void> call(String id) async {
    final Wallet? wallet = await _walletRepo.byId(id);
    if (wallet == null) {
      throw const NotFoundFailure('Wallet not found');
    }
    if (!wallet.isArchived) {
      return;
    }
    await _walletRepo.restore(id);
  }
}
