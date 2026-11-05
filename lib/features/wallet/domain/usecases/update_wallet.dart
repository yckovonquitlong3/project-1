import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

final class UpdateWallet {
  const UpdateWallet({required WalletRepository wallets}) : _walletRepo = wallets;

  final WalletRepository _walletRepo;

  Future<Wallet> call({
    required String id,
    required String name,
    required AccountType accountType,
    required String iconIdentifier,
  }) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Wallet name is required');
    }
    return _walletRepo.update(
      id: id,
      name: trimmed,
      accountType: accountType,
      iconIdentifier: iconIdentifier,
    );
  }
}
