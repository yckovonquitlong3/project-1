import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';

/// Whether a wallet is referenced by any transaction.
///
/// The UI asks this before offering permanent deletion, because history must
/// never be cascade-deleted.
final class HasTransactions {
  const HasTransactions({required WalletRepository wallets})
      : _walletRepo = wallets;

  final WalletRepository _walletRepo;

  Future<bool> call(String walletId) => _walletRepo.hasTransactions(walletId);
}
