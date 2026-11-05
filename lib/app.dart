import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';

class MultiWalletApp extends StatelessWidget {
  const MultiWalletApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Multi-Wallet Tracker',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      home: const _BootstrapPlaceholder(),
    );
  }
}

class _BootstrapPlaceholder extends StatelessWidget {
  const _BootstrapPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Multi-Wallet Tracker')),
      body: const Center(child: Text('Ledger setup in progress')),
    );
  }
}