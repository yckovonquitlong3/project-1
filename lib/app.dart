import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';
import 'features/wallet/presentation/screens/wallet_list_screen.dart';

class MultiWalletApp extends StatelessWidget {
  const MultiWalletApp({required this.walletCubit, super.key});

  final WalletCubit walletCubit;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Wallet Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: WalletListScreen(cubit: walletCubit),
    );
  }
}
