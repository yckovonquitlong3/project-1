import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'features/wallet/presentation/cubit/wallet_cubit.dart';
import 'injection_container.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initDependencies();

  final WalletCubit walletCubit = sl<WalletCubit>();
  final DashboardCubit dashboardCubit = sl<DashboardCubit>();
  unawaited(walletCubit.load());
  unawaited(dashboardCubit.load());

  runApp(
    MultiWalletApp(
      walletCubit: walletCubit,
      dashboardCubit: dashboardCubit,
    ),
  );
}
