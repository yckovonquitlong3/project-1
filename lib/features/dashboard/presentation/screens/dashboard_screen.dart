import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/category_breakdown.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/dashboard_transaction.dart';
import 'package:multi_wallet_tracker/features/dashboard/domain/entities/month_summary.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_cubit.dart';
import 'package:multi_wallet_tracker/features/dashboard/presentation/cubit/dashboard_state.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/add_transaction_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/transaction_detail_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/widgets/transaction_type_ui.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

class DashboardScreen extends StatelessWidget {
  const DashboardScreen({
    required this.cubit,
    super.key,
    this.onOpenWallets,
    this.onOpenActivity,
    this.quickEntry,
  });

  final DashboardCubit cubit;
  final VoidCallback? onOpenWallets;
  final VoidCallback? onOpenActivity;
  final Widget? quickEntry;

  Future<void> _addTransaction(BuildContext context) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const AddTransactionScreen(),
      ),
    );
    if (context.mounted) {
      unawaited(context.read<DashboardCubit>().load());
    }
  }

  Future<void> _openTransaction(BuildContext context, String id) async {
    await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            TransactionDetailScreen(transactionId: id),
      ),
    );
    if (context.mounted) {
      unawaited(context.read<DashboardCubit>().load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<DashboardCubit>.value(
      value: cubit,
      child: Scaffold(
        appBar: AppBar(title: const Text('Dashboard')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () => _addTransaction(context),
          icon: const Icon(Icons.add),
          label: const Text('Add transaction'),
        ),
        body: BlocBuilder<DashboardCubit, DashboardState>(
          builder: (BuildContext context, DashboardState state) {
            return switch (state) {
              DashboardInitial() || DashboardLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              DashboardFailure(:final String message) => _DashboardFailure(
                  message: message,
                  onRetry: () => context.read<DashboardCubit>().load(),
                ),
              DashboardLoaded() => _DashboardBody(
                  state: state,
                  onRefresh: () => context.read<DashboardCubit>().load(),
                  onAddWallet: onOpenWallets,
                  onOpenWallets: onOpenWallets,
                  onOpenActivity: onOpenActivity,
                  onTransactionTap: (String id) =>
                      _openTransaction(context, id),
                  quickEntry: quickEntry,
                ),
            };
          },
        ),
      ),
    );
  }
}

class _DashboardBody extends StatelessWidget {
  const _DashboardBody({
    required this.state,
    required this.onRefresh,
    required this.onAddWallet,
    required this.onOpenWallets,
    required this.onOpenActivity,
    required this.onTransactionTap,
    this.quickEntry,
  });

  final DashboardLoaded state;
  final Future<void> Function() onRefresh;
  final VoidCallback? onAddWallet;
  final VoidCallback? onOpenWallets;
  final VoidCallback? onOpenActivity;
  final ValueChanged<String> onTransactionTap;
  final Widget? quickEntry;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(32),
          child: _DashboardEmpty(onAddWallet: onAddWallet),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: onRefresh,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
        children: <Widget>[
          _NetWorthCard(
            netWorth: state.netWorth,
            month: state.month,
            walletCount: state.walletCount,
          ),
          const SizedBox(height: 16),
          _MonthCard(state: state),
          if (quickEntry != null) ...<Widget>[
            const SizedBox(height: 16),
            quickEntry!,
          ],
          if (state.wallets.isNotEmpty) ...<Widget>[
            _SectionHeader(
              title: 'Wallets',
              actionLabel: 'See all',
              onAction: onOpenWallets,
            ),
            _WalletCarousel(
              wallets: state.wallets,
              onTap: onOpenWallets,
            ),
          ],
          if (state.breakdown.isNotEmpty) ...<Widget>[
            const _SectionHeader(title: 'Spending by category'),
            _BreakdownCard(breakdown: state.breakdown),
          ],
          if (state.recent.isNotEmpty) ...<Widget>[
            _SectionHeader(
              title: 'Recent activity',
              actionLabel: 'See all',
              onAction: onOpenActivity,
            ),
            _RecentCard(
              items: state.recent.take(10).toList(growable: false),
              onTap: onTransactionTap,
            ),
          ],
        ],
      ),
    );
  }
}

class _NetWorthCard extends StatelessWidget {
  const _NetWorthCard({
    required this.netWorth,
    required this.month,
    required this.walletCount,
  });

  final Money netWorth;
  final DateTime month;
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
              'Net worth',
              style: theme.textTheme.labelLarge
                  ?.copyWith(color: scheme.onPrimaryContainer),
            ),
            const SizedBox(height: 6),
            Text(
              netWorth.format(),
              style: theme.textTheme.headlineMedium?.copyWith(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              '${DateFormat.yMMMM().format(month)} · $walletCount '
              '${walletCount == 1 ? 'wallet' : 'wallets'}',
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

class _MonthCard extends StatelessWidget {
  const _MonthCard({required this.state});

  final DashboardLoaded state;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final MonthSummary summary = state.summary;

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Text(
                  'This month',
                  style: theme.textTheme.titleMedium
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                Text(
                  DateFormat.yMMMM().format(state.month),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Expanded(
                  child: _SummaryTile(
                    label: 'Income',
                    amount: summary.income,
                    icon: Icons.arrow_downward,
                    color: scheme.primary,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _SummaryTile(
                    label: 'Expense',
                    amount: summary.expense,
                    icon: Icons.arrow_upward,
                    color: scheme.error,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: <Widget>[
                Text(
                  'Net',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
                const Spacer(),
                Text(
                  summary.net.format(),
                  style: theme.textTheme.titleSmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: summary.net.isNegative
                        ? scheme.error
                        : scheme.onSurface,
                  ),
                ),
              ],
            ),
            if (summary.fees.isPositive) ...<Widget>[
              const SizedBox(height: 6),
              Text(
                'Includes ${summary.fees.format()} in transfer fees',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _SummaryTile extends StatelessWidget {
  const _SummaryTile({
    required this.label,
    required this.amount,
    required this.icon,
    required this.color,
  });

  final String label;
  final Money amount;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 4),
              Text(
                label,
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            amount.format(),
            style: theme.textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({
    required this.title,
    this.actionLabel,
    this.onAction,
  });

  final String title;
  final String? actionLabel;
  final VoidCallback? onAction;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 24, bottom: 8),
      child: Row(
        children: <Widget>[
          Expanded(
            child: Text(
              title,
              style: Theme.of(context).textTheme.titleMedium
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
          ),
          if (actionLabel != null && onAction != null)
            TextButton(
              onPressed: onAction,
              child: Text(actionLabel!),
            ),
        ],
      ),
    );
  }
}

class _WalletCarousel extends StatelessWidget {
  const _WalletCarousel({required this.wallets, required this.onTap});

  final List<Wallet> wallets;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SizedBox(
      height: 96,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: wallets.length,
        separatorBuilder: (BuildContext context, int index) =>
            const SizedBox(width: 8),
        itemBuilder: (BuildContext context, int index) {
          final Wallet wallet = wallets[index];
          return SizedBox(
            width: 160,
            child: Card(
              elevation: 0,
              color: scheme.surfaceContainerLow,
              clipBehavior: Clip.antiAlias,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: InkWell(
                onTap: onTap,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text(
                        wallet.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleSmall
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        wallet.balance.format(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: theme.textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _BreakdownCard extends StatelessWidget {
  const _BreakdownCard({required this.breakdown});

  final List<CategoryBreakdown> breakdown;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final int total = breakdown.fold(
      0,
      (int sum, CategoryBreakdown item) => sum + item.total.minorUnits,
    );

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        child: Column(
          children: <Widget>[
            for (final CategoryBreakdown item in breakdown)
              _BreakdownRow(
                item: item,
                fraction: total == 0 ? 0 : item.total.minorUnits / total,
                color: _categoryColor(context, item.colorHex),
                style: theme.textTheme,
              ),
          ],
        ),
      ),
    );
  }
}

class _BreakdownRow extends StatelessWidget {
  const _BreakdownRow({
    required this.item,
    required this.fraction,
    required this.color,
    required this.style,
  });

  final CategoryBreakdown item;
  final double fraction;
  final Color color;
  final TextTheme style;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Column(
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                width: 10,
                height: 10,
                decoration: BoxDecoration(
                  color: color,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: style.bodyMedium,
                ),
              ),
              Text(
                item.total.format(),
                style: style.bodyMedium
                    ?.copyWith(fontWeight: FontWeight.w600),
              ),
              SizedBox(
                width: 44,
                child: Text(
                  '${(fraction * 100).round()}%',
                  textAlign: TextAlign.end,
                  style: style.bodySmall
                      ?.copyWith(color: scheme.onSurfaceVariant),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          LinearProgressIndicator(
            value: fraction,
            minHeight: 6,
            color: color,
            backgroundColor: color.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(999),
          ),
        ],
      ),
    );
  }
}

class _RecentCard extends StatelessWidget {
  const _RecentCard({required this.items, required this.onTap});

  final List<DashboardTransaction> items;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Column(
        children: <Widget>[
          for (int index = 0; index < items.length; index++) ...<Widget>[
            if (index > 0)
              Divider(height: 1, color: scheme.outlineVariant),
            _RecentTile(
              item: items[index],
              onTap: () => onTap(items[index].id),
            ),
          ],
        ],
      ),
    );
  }
}

class _RecentTile extends StatelessWidget {
  const _RecentTile({required this.item, required this.onTap});

  final DashboardTransaction item;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = transactionTypeColor(context, item.type);
    final String title = item.categoryName ?? transactionTypeLabel(item.type);
    final String date = DateFormat.MMMd().format(item.occurredAt);
    final String walletText = item.type.isTransfer
        ? '${item.sourceWalletName} to ${item.targetWalletName ?? ''}'
        : item.sourceWalletName;
    final String feeText =
        item.fee.isPositive ? ' · fee ${item.fee.format()}' : '';

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      leading: CircleAvatar(
        radius: 18,
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(transactionTypeIcon(item.type), size: 18),
      ),
      title: Text(
        title,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: theme.textTheme.bodyLarge,
      ),
      subtitle: Text(
        '$walletText$feeText · $date',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        signedAmount(item.amount, item.type),
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _DashboardEmpty extends StatelessWidget {
  const _DashboardEmpty({required this.onAddWallet});

  final VoidCallback? onAddWallet;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Icon(Icons.insights_outlined, size: 56, color: scheme.primary),
        const SizedBox(height: 16),
        Text(
          'Set up your ledger',
          style: theme.textTheme.titleLarge
              ?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 8),
        Text(
          'Add your first wallet, then record expenses, income, and transfers. '
          'Your totals will appear here.',
          textAlign: TextAlign.center,
          style: theme.textTheme.bodyMedium
              ?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (onAddWallet != null) ...<Widget>[
          const SizedBox(height: 24),
          FilledButton.icon(
            onPressed: onAddWallet,
            icon: const Icon(Icons.account_balance_wallet_outlined),
            label: const Text('Add a wallet'),
          ),
        ],
      ],
    );
  }
}

class _DashboardFailure extends StatelessWidget {
  const _DashboardFailure({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.error_outline, size: 48, color: scheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
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

Color _categoryColor(BuildContext context, String hex) {
  final String value = hex.startsWith('#') ? hex.substring(1) : hex;
  final int? parsed = int.tryParse(value, radix: 16);
  if (parsed == null) {
    return Theme.of(context).colorScheme.outline;
  }
  return Color(value.length <= 6 ? 0xFF000000 | parsed : parsed);
}
