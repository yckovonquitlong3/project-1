import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/ledger/ledger_bus.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/archive_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/create_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/delete_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/get_wallets.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/has_transactions.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/restore_wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/update_wallet.dart';

import 'wallet_state.dart';

/// Drives the wallet list.
///
/// Reads emit [WalletLoading] then either [WalletLoaded] or [WalletFailure].
/// Writes return an error message (null means success) so a failed save can be
/// shown in the form without replacing the list with an error screen.
class WalletCubit extends Cubit<WalletState> {
  WalletCubit({
    required GetWallets getWallets,
    required CreateWallet createWallet,
    required UpdateWallet updateWallet,
    required ArchiveWallet archiveWallet,
    required RestoreWallet restoreWallet,
    required DeleteWallet deleteWallet,
    required HasTransactions hasTransactions,
    required LedgerBus ledgerBus,
  })  : _loadWallets = getWallets,
        _create = createWallet,
        _update = updateWallet,
        _archive = archiveWallet,
        _restore = restoreWallet,
        _delete = deleteWallet,
        _walletHasTransactions = hasTransactions,
        super(const WalletInitial()) {
    _subscription = ledgerBus.changes.listen((_) {
      if (!_writing && !isClosed) {
        unawaited(load());
      }
    });
  }

  final GetWallets _loadWallets;
  final CreateWallet _create;
  final UpdateWallet _update;
  final ArchiveWallet _archive;
  final RestoreWallet _restore;
  final DeleteWallet _delete;
  final HasTransactions _walletHasTransactions;

  late final StreamSubscription<void> _subscription;
  bool _writing = false;

  Future<void> load() async {
    if (isClosed) {
      return;
    }
    emit(const WalletLoading());
    try {
      final ({List<Wallet> active, List<Wallet> archived}) result =
          await _loadWallets();
      if (isClosed) {
        return;
      }
      emit(
        WalletLoaded(
          active: result.active,
          archived: result.archived,
        ),
      );
    } on Failure catch (failure) {
      if (isClosed) {
        return;
      }
      emit(WalletFailure(failure.message));
    } catch (_) {
      if (isClosed) {
        return;
      }
      emit(const WalletFailure('Could not load your wallets'));
    }
  }

  Future<String?> create({
    required String name,
    required AccountType accountType,
    required String iconIdentifier,
    required Money openingBalance,
  }) {
    return _write(() async {
      await _create(
        name: name,
        accountType: accountType,
        iconIdentifier: iconIdentifier,
        openingBalance: openingBalance,
      );
    });
  }

  Future<String?> update({
    required String id,
    required String name,
    required AccountType accountType,
    required String iconIdentifier,
  }) {
    return _write(() async {
      await _update(
        id: id,
        name: name,
        accountType: accountType,
        iconIdentifier: iconIdentifier,
      );
    });
  }

  Future<String?> archive(String id) {
    return _write(() => _archive(id));
  }

  Future<String?> restore(String id) {
    return _write(() => _restore(id));
  }

  Future<String?> delete(String id) {
    return _write(() => _delete(id));
  }

  /// Conservative on failure: if we cannot prove the wallet is unused, the UI
  /// must not offer permanent deletion.
  Future<bool> hasTransactions(String id) async {
    try {
      return await _walletHasTransactions(id);
    } on Failure {
      return true;
    } catch (_) {
      return true;
    }
  }

  Future<String?> _write(Future<void> Function() action) async {
    _writing = true;
    try {
      await action();
      await load();
      return null;
    } on Failure catch (failure) {
      return failure.message;
    } catch (_) {
      return 'Something went wrong. Please try again.';
    } finally {
      _writing = false;
    }
  }

  @override
  Future<void> close() async {
    await _subscription.cancel();
    await super.close();
  }
}
