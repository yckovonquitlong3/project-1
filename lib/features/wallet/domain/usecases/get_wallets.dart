import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

/// Loads the wallet list split into the two sections the screen renders.
final class GetWallets {
  const GetWallets({required WalletRepository wallets}) : _walletRepo = wallets;

  final WalletRepository _walletRepo;

  Future<({List<Wallet> active, List<Wallet> archived})> call() async {
    final List<Wallet> all = await _walletRepo.all(includeArchived: true);
    return (
      active: all
          .where((Wallet wallet) => !wallet.isArchived)
          .toList(growable: false),
      archived: all
          .where((Wallet wallet) => wallet.isArchived)
          .toList(growable: false),
    );
  }
}
