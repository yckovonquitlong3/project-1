import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();
  final WalletCubit walletCubit = sl<WalletCubit>();
  unawaited(walletCubit.load());
  runApp(MultiWalletApp(walletCubit: walletCubit));
}
