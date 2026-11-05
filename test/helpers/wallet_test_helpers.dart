import 'package:mocktail/mocktail.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/repositories/wallet_repository.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/archive_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/create_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/delete_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/get_wallets.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/has_transactions.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/restore_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/update_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_cubit.dart';

class MockWalletRepository extends Mock implements WalletRepository {}

Wallet walletFixture({
  String id = 'w1',
  String name = 'GCash',
  AccountType accountType = AccountType.eWallet,
  String iconIdentifier = 'phone_android',
  int balanceMinor = 100000,
  bool isArchived = false,
}) {
  final DateTime now = DateTime(2026, 11, 5, 10);
  return Wallet(
    id: id,
    name: name,
    accountType: accountType,
    iconIdentifier: iconIdentifier,
    balance: Money(balanceMinor),
    isArchived: isArchived,
    createdAt: now,
    updatedAt: now,
  );
}

/// Real use cases over a mocked repository, so the cubit is exercised through
/// the same validation path the app uses.
WalletCubit buildWalletCubit(
  WalletRepository wallets, {
  LedgerBus? ledgerBus,
}) {
  return WalletCubit(
    getWallets: GetWallets(wallets: wallets),
    createWallet: CreateWallet(wallets: wallets),
    updateWallet: UpdateWallet(wallets: wallets),
    archiveWallet: ArchiveWallet(wallets: wallets),
    restoreWallet: RestoreWallet(wallets: wallets),
    deleteWallet: DeleteWallet(wallets: wallets),
    hasTransactions: HasTransactions(wallets: wallets),
    ledgerBus: ledgerBus ?? LedgerBus(),
  );
}
