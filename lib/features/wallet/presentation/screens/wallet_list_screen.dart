import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_cubit.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_state.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/widgets/wallet_card.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/widgets/wallet_form_sheet.dart';

class WalletListScreen extends StatelessWidget {
  const WalletListScreen({required this.cubit, super.key});

  final WalletCubit cubit;

  @override
  Widget build(BuildContext context) {
    return BlocProvider<WalletCubit>.value(
      value: cubit,
      child: const _WalletListView(),
    );
  }
}

class _WalletListView extends StatelessWidget {
  const _WalletListView();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Wallets')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openWalletForm(context),
        icon: const Icon(Icons.add),
        label: const Text('Add wallet'),
      ),
      body: BlocBuilder<WalletCubit, WalletState>(
        builder: (BuildContext context, WalletState state) {
          return switch (state) {
            WalletInitial() || WalletLoading() => const Center(
                child: CircularProgressIndicator(),
              ),
            WalletFailure(:final String message) => _FailureView(
                message: message,
                onRetry: () => context.read<WalletCubit>().load(),
              ),
            WalletLoaded(
              :final List<Wallet> active,
              :final List<Wallet> archived,
            ) =>
              _LoadedView(active: active, archived: archived),
          };
        },
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({required this.active, required this.archived});

  final List<Wallet> active;
  final List<Wallet> archived;

  @override
  Widget build(BuildContext context) {
    if (active.isEmpty && archived.isEmpty) {
      return _EmptyWallets(onAdd: () => _openWalletForm(context));
    }

    final Money total = <Wallet>[...active, ...archived].fold(
      Money.zero,
      (Money sum, Wallet wallet) => sum + wallet.balance,
    );
    final TextTheme textTheme = Theme.of(context).textTheme;

    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          sliver: SliverToBoxAdapter(
            child: _BalanceSummary(
              total: total,
              walletCount: active.length + archived.length,
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          sliver: SliverList.builder(
            itemCount: active.length,
            itemBuilder: (BuildContext context, int index) =>
                _cardFor(context, active[index]),
          ),
        ),
        if (active.isEmpty)
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'No active wallets. Restore one below or add a new wallet.',
                style: textTheme.bodyMedium,
              ),
            ),
          ),
        if (archived.isNotEmpty) ...<Widget>[
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 8),
            sliver: SliverToBoxAdapter(
              child: Text(
                'Archived',
                style: textTheme.titleSmall
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
            ),
          ),
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            sliver: SliverList.builder(
              itemCount: archived.length,
              itemBuilder: (BuildContext context, int index) =>
                  _cardFor(context, archived[index]),
            ),
          ),
        ],
        const SliverToBoxAdapter(child: SizedBox(height: 96)),
      ],
    );
  }

  Widget _cardFor(BuildContext context, Wallet wallet) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: WalletCard(
        wallet: wallet,
        onEdit: () => _openWalletForm(context, wallet: wallet),
        onArchive: () => _archiveWallet(context, wallet),
        onRestore: () => _restoreWallet(context, wallet),
        onDelete: () => _deleteWallet(context, wallet),
      ),
    );
  }
}

class _BalanceSummary extends StatelessWidget {
  const _BalanceSummary({required this.total, required this.walletCount});

  final Money total;
  final int walletCount;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      color: scheme.primaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Total balance',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              total.format(),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
                fontFeatures: const <FontFeature>[
                  FontFeature.tabularFigures(),
                ],
              ),
            ),
            const SizedBox(height: 4),
            Text(
              'Across $walletCount ${walletCount == 1 ? 'wallet' : 'wallets'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: scheme.onPrimaryContainer.withValues(alpha: 0.8),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyWallets extends StatelessWidget {
  const _EmptyWallets({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Center(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(
              Icons.account_balance_wallet_outlined,
              size: 56,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No wallets yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Add your first wallet to start tracking your money.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add wallet'),
            ),
          ],
        ),
      ),
    );
  }
}

class _FailureView extends StatelessWidget {
  const _FailureView({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton.tonal(
              onPressed: onRetry,
              child: const Text('Try again'),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _openWalletForm(BuildContext context, {Wallet? wallet}) async {
  final WalletCubit cubit = context.read<WalletCubit>();
  await showModalBottomSheet<bool>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    showDragHandle: true,
    builder: (BuildContext sheetContext) =>
        WalletFormSheet(cubit: cubit, wallet: wallet),
  );
}

Future<bool> _confirm(
  BuildContext context, {
  required String title,
  required String message,
  required String action,
}) async {
  final bool? result = await showDialog<bool>(
    context: context,
    builder: (BuildContext dialogContext) {
      return AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: Text(action),
          ),
        ],
      );
    },
  );
  return result ?? false;
}

void _showMessage(BuildContext context, String message) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

Future<void> _archiveWallet(BuildContext context, Wallet wallet) async {
  final WalletCubit cubit = context.read<WalletCubit>();
  final bool confirmed = await _confirm(
    context,
    title: 'Archive ${wallet.name}?',
    message: 'It will be hidden from pickers, but its transactions are kept.',
    action: 'Archive',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final String? error = await cubit.archive(wallet.id);
  if (context.mounted && error != null) {
    _showMessage(context, error);
  }
}

Future<void> _restoreWallet(BuildContext context, Wallet wallet) async {
  final WalletCubit cubit = context.read<WalletCubit>();
  final String? error = await cubit.restore(wallet.id);
  if (context.mounted && error != null) {
    _showMessage(context, error);
  }
}

Future<void> _deleteWallet(BuildContext context, Wallet wallet) async {
  final WalletCubit cubit = context.read<WalletCubit>();

  final bool hasHistory = await cubit.hasTransactions(wallet.id);
  if (!context.mounted) {
    return;
  }
  if (hasHistory) {
    _showMessage(context, 'This wallet has transactions. Archive it instead.');
    return;
  }

  final bool confirmed = await _confirm(
    context,
    title: 'Delete ${wallet.name}?',
    message: 'This permanently removes the wallet. This cannot be undone.',
    action: 'Delete',
  );
  if (!confirmed || !context.mounted) {
    return;
  }
  final String? error = await cubit.delete(wallet.id);
  if (context.mounted && error != null) {
    _showMessage(context, error);
  }
}
