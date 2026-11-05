import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

final class CreateWallet {
  const CreateWallet({required WalletRepository wallets}) : _walletRepo = wallets;

  final WalletRepository _walletRepo;

  Future<Wallet> call({
    required String name,
    required AccountType accountType,
    required String iconIdentifier,
    Money openingBalance = Money.zero,
  }) {
    final String trimmed = name.trim();
    if (trimmed.isEmpty) {
      throw const ValidationFailure('Wallet name is required');
    }
    if (openingBalance.isNegative) {
      throw const ValidationFailure('Opening balance cannot be negative');
    }
    return _walletRepo.create(
      name: trimmed,
      accountType: accountType,
      iconIdentifier: iconIdentifier,
      openingBalance: openingBalance,
    );
  }
}
