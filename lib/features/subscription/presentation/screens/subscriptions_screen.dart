import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/cubit/subscription_state.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/screens/subscription_detail_screen.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/widgets/subscription_form_sheet.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/widgets/subscription_ui.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/injection_container.dart';

class SubscriptionsScreen extends StatefulWidget {
  const SubscriptionsScreen({super.key, this.cubit});

  final SubscriptionCubit? cubit;

  @override
  State<SubscriptionsScreen> createState() => _SubscriptionsScreenState();
}

class _SubscriptionsScreenState extends State<SubscriptionsScreen> {
  late final SubscriptionCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? sl<SubscriptionCubit>();
    if (_ownsCubit) {
      unawaited(_cubit.load());
    }
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      unawaited(_cubit.close());
    }
    super.dispose();
  }

  Future<void> _openForm(
    SubscriptionLoaded state, {
    Subscription? existing,
  }) async {
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      builder: (BuildContext context) => SubscriptionFormSheet(
        cubit: _cubit,
        activeWallets: state.activeWallets,
        expenseCategories: state.expenseCategories,
        existing: existing,
      ),
    );
  }

  Future<void> _openDetail(
    Subscription subscription,
    Map<String, String> walletNames,
    Map<String, String> categoryNames,
    List<Wallet> activeWallets,
    List<Category> expenseCategories,
  ) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => SubscriptionDetailScreen(
          subscription: subscription,
          walletName:
              walletNames[subscription.walletId] ?? 'Unknown wallet',
          categoryName:
              categoryNames[subscription.categoryId] ?? 'Unknown category',
          cubit: _cubit,
          activeWallets: activeWallets,
          expenseCategories: expenseCategories,
        ),
      ),
    );
  }

  Future<void> _requestNotifications() async {
    final bool granted = await _cubit.requestNotificationPermission();
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            granted
                ? 'Notifications enabled.'
                : 'Notifications are still disabled in system settings.',
          ),
        ),
      );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<SubscriptionCubit>.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(title: const Text('Subscriptions')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: () {
            final SubscriptionState state = _cubit.state;
            if (state is SubscriptionLoaded) {
              _openForm(state);
            }
          },
          icon: const Icon(Icons.add),
          label: const Text('Add subscription'),
        ),
        body: BlocBuilder<SubscriptionCubit, SubscriptionState>(
          builder: (BuildContext context, SubscriptionState state) {
            return switch (state) {
              SubscriptionInitial() || SubscriptionLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              SubscriptionFailure(:final String message) => _FailureView(
                  message: message,
                  onRetry: () => context.read<SubscriptionCubit>().load(),
                ),
              SubscriptionLoaded() => _LoadedView(
                  state: state,
                  onAdd: () => _openForm(state),
                  onOpen: (Subscription subscription) => _openDetail(
                    subscription,
                    state.walletNames,
                    state.categoryNames,
                    state.activeWallets,
                    state.expenseCategories,
                  ),
                  onRequestNotifications: _requestNotifications,
                ),
            };
          },
        ),
      ),
    );
  }
}

class _LoadedView extends StatelessWidget {
  const _LoadedView({
    required this.state,
    required this.onAdd,
    required this.onOpen,
    required this.onRequestNotifications,
  });

  final SubscriptionLoaded state;
  final VoidCallback onAdd;
  final ValueChanged<Subscription> onOpen;
  final Future<void> Function() onRequestNotifications;

  @override
  Widget build(BuildContext context) {
    if (state.isEmpty) {
      return _EmptySubscriptions(onAdd: onAdd);
    }

    final ThemeData theme = Theme.of(context);
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      children: <Widget>[
        if (!state.notificationsEnabled) ...<Widget>[
          _PermissionBanner(onEnable: onRequestNotifications),
          const SizedBox(height: 8),
        ],
        if (state.active.isNotEmpty) ...<Widget>[
          _SectionTitle(title: 'Active', count: state.active.length),
          for (final Subscription subscription in state.active)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SubscriptionCard(
                subscription: subscription,
                walletName:
                    state.walletNames[subscription.walletId] ?? 'Wallet',
                onTap: () => onOpen(subscription),
              ),
            ),
        ],
        if (state.archived.isNotEmpty) ...<Widget>[
          const SizedBox(height: 12),
          _SectionTitle(title: 'Archived', count: state.archived.length),
          for (final Subscription subscription in state.archived)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _SubscriptionCard(
                subscription: subscription,
                walletName:
                    state.walletNames[subscription.walletId] ?? 'Wallet',
                onTap: () => onOpen(subscription),
              ),
            ),
        ],
        if (state.active.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Text(
              'No active subscriptions. Restore one below or add a new one.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
      ],
    );
  }
}

class _SubscriptionCard extends StatelessWidget {
  const _SubscriptionCard({
    required this.subscription,
    required this.walletName,
    required this.onTap,
  });

  final Subscription subscription;
  final String walletName;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool overdue = subscription.isOverdue;

    return Card(
      margin: EdgeInsets.zero,
      elevation: 0,
      color: scheme.surfaceContainerLow,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  CircleAvatar(
                    radius: 22,
                    backgroundColor:
                        overdue ? scheme.errorContainer : scheme.primaryContainer,
                    foregroundColor:
                        overdue ? scheme.onErrorContainer : scheme.onPrimaryContainer,
                    child: Icon(
                      subscriptionIcon(subscription.cycle),
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          subscription.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${billingCycleLabel(subscription.cycle)} · '
                          '$walletName',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    subscription.amount.format(),
                    style: theme.textTheme.titleMedium
                        ?.copyWith(fontWeight: FontWeight.w600),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Icon(
                    Icons.event_outlined,
                    size: 16,
                    color: scheme.onSurfaceVariant,
                  ),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      overdue
                          ? 'Due ${DateFormat.yMMMd().add_jm().format(subscription.nextBillingAt)}'
                          : 'Next ${DateFormat.yMMMd().add_jm().format(subscription.nextBillingAt)}',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.onSurfaceVariant),
                    ),
                  ),
                  if (overdue)
                    _Badge(
                      label: 'Overdue',
                      background: scheme.errorContainer,
                      foreground: scheme.onErrorContainer,
                    )
                  else if (!subscription.isActive)
                    _Badge(
                      label: 'Archived',
                      background: scheme.secondaryContainer,
                      foreground: scheme.onSecondaryContainer,
                    ),
                ],
              ),
              if (overdue) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  failureReasonText(subscription.lastFailureReason),
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: scheme.error),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _Badge extends StatelessWidget {
  const _Badge({
    required this.label,
    required this.background,
    required this.foreground,
  });

  final String label;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelSmall?.copyWith(
              color: foreground,
              fontWeight: FontWeight.w600,
            ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle({required this.title, required this.count});

  final String title;
  final int count;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 8, bottom: 8),
      child: Row(
        children: <Widget>[
          Text(
            title,
            style: Theme.of(context).textTheme.titleMedium
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(width: 8),
          Text(
            '$count',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
          ),
        ],
      ),
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.onEnable});

  final Future<void> Function() onEnable;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.secondaryContainer,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ListTile(
        leading: Icon(
          Icons.notifications_off_outlined,
          color: scheme.onSecondaryContainer,
        ),
        title: Text(
          'Notifications are off',
          style: TextStyle(
            color: scheme.onSecondaryContainer,
            fontWeight: FontWeight.w600,
          ),
        ),
        subtitle: Text(
          'Enable them to receive the 24-hour and billing-day reminders.',
          style: TextStyle(color: scheme.onSecondaryContainer),
        ),
        trailing: TextButton(
          onPressed: onEnable,
          child: const Text('Enable'),
        ),
      ),
    );
  }
}

class _EmptySubscriptions extends StatelessWidget {
  const _EmptySubscriptions({required this.onAdd});

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
            Icon(Icons.autorenew, size: 56, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              'No subscriptions yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Track recurring expenses and get a reminder before each '
              'billing date.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add subscription'),
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
