import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/widgets/subscription_form_sheet.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/widgets/subscription_ui.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

class SubscriptionDetailScreen extends StatelessWidget {
  const SubscriptionDetailScreen({
    required this.subscription,
    required this.walletName,
    required this.categoryName,
    required this.cubit,
    required this.activeWallets,
    required this.expenseCategories,
    super.key,
  });

  final Subscription subscription;
  final String walletName;
  final String categoryName;
  final SubscriptionCubit cubit;
  final List<Wallet> activeWallets;
  final List<Category> expenseCategories;

  Future<void> _edit(BuildContext context) async {
    final bool? saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => SubscriptionFormSheet(
        cubit: cubit,
        activeWallets: activeWallets,
        expenseCategories: expenseCategories,
        existing: subscription,
      ),
    );
    if (saved == true && context.mounted) {
      Navigator.of(context).pop();
    }
  }

  Future<void> _markPaid(BuildContext context) async {
    final String? error = await cubit.markPaid(subscription.id);
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      _message(context, error);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _catchUpAll(BuildContext context) async {
    final String? error = await cubit.catchUpAll();
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      _message(context, error);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _toggleActive(BuildContext context) async {
    final String? error = await cubit.setActive(
      subscription.id,
      active: !subscription.isActive,
    );
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      _message(context, error);
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _delete(BuildContext context) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: Text('Delete ${subscription.name}?'),
        content: const Text(
          'This removes the subscription rule. Past charges stay in the '
          'ledger. This cannot be undone.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) {
      return;
    }
    final String? error = await cubit.delete(subscription.id);
    if (!context.mounted) {
      return;
    }
    if (error != null) {
      _message(context, error);
      return;
    }
    Navigator.of(context).pop();
  }

  void _message(BuildContext context, String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool overdue = subscription.isOverdue;
    final bool active = subscription.isActive;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Subscription'),
        actions: <Widget>[
          if (active)
            IconButton(
              tooltip: 'Edit subscription',
              onPressed: () => _edit(context),
              icon: const Icon(Icons.edit_outlined),
            ),
          PopupMenuButton<String>(
            tooltip: 'Subscription actions',
            onSelected: (String value) {
              switch (value) {
                case 'archive':
                  _toggleActive(context);
                case 'restore':
                  _toggleActive(context);
                case 'delete':
                  _delete(context);
              }
            },
            itemBuilder: (BuildContext context) =>
                <PopupMenuEntry<String>>[
              PopupMenuItem<String>(
                value: active ? 'archive' : 'restore',
                child: Text(active ? 'Archive' : 'Restore'),
              ),
              PopupMenuItem<String>(
                value: 'delete',
                child: Text(
                  'Delete',
                  style: TextStyle(color: scheme.error),
                ),
              ),
            ],
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          Card(
            elevation: 0,
            color: overdue ? scheme.errorContainer : scheme.primaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                children: <Widget>[
                  Icon(
                    subscriptionIcon(subscription.cycle),
                    size: 30,
                    color: overdue
                        ? scheme.onErrorContainer
                        : scheme.onPrimaryContainer,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    subscription.name,
                    textAlign: TextAlign.center,
                    style: theme.textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: overdue
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    subscription.amount.format(),
                    style: theme.textTheme.headlineMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: overdue
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    billingCycleLabel(subscription.cycle),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: overdue
                          ? scheme.onErrorContainer
                          : scheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (overdue) ...<Widget>[
            const SizedBox(height: 12),
            Card(
              elevation: 0,
              color: scheme.errorContainer,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      'Action needed',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                        color: scheme.onErrorContainer,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      failureReasonText(subscription.lastFailureReason),
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onErrorContainer,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
          const SizedBox(height: 16),
          _DetailRow(label: 'Wallet', value: walletName),
          _DetailRow(label: 'Category', value: categoryName),
          _DetailRow(
            label: 'Next billing',
            value: DateFormat.yMMMd()
                .add_jm()
                .format(subscription.nextBillingAt),
          ),
          _DetailRow(
            label: 'Auto-deduct',
            value: subscription.autoDeduct ? 'On' : 'Off',
          ),
          _DetailRow(
            label: 'Status',
            value: !active
                ? 'Archived'
                : overdue
                    ? 'Overdue'
                    : 'Active',
          ),
          if (subscription.lastPaidAt != null)
            _DetailRow(
              label: 'Last paid',
              value: DateFormat.yMMMd()
                  .add_jm()
                  .format(subscription.lastPaidAt!),
            ),
          const SizedBox(height: 24),
          if (active && overdue) ...<Widget>[
            FilledButton(
              onPressed: () => _markPaid(context),
              child: const Text('Mark as Paid'),
            ),
            const SizedBox(height: 8),
            FilledButton.tonal(
              onPressed: () => _catchUpAll(context),
              child: const Text('Catch up all'),
            ),
          ],
          if (!active) ...<Widget>[
            FilledButton.tonal(
              onPressed: () => _toggleActive(context),
              child: const Text('Restore subscription'),
            ),
          ],
        ],
      ),
    );
  }
}

class _DetailRow extends StatelessWidget {
  const _DetailRow({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          Expanded(
            child: Text(value, style: theme.textTheme.bodyLarge),
          ),
        ],
      ),
    );
  }
}
