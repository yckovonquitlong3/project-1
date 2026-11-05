import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

sealed class WalletState extends Equatable {
  const WalletState();

  @override
  List<Object?> get props => const <Object?>[];
}

final class WalletInitial extends WalletState {
  const WalletInitial();
}

final class WalletLoading extends WalletState {
  const WalletLoading();
}

final class WalletLoaded extends WalletState {
  const WalletLoaded({required this.active, required this.archived});

  final List<Wallet> active;
  final List<Wallet> archived;

  bool get isEmpty => active.isEmpty && archived.isEmpty;

  @override
  List<Object?> get props => <Object?>[active, archived];
}

final class WalletFailure extends WalletState {
  const WalletFailure(this.message);

  final String message;

  @override
  List<Object?> get props => <Object?>[message];
}
