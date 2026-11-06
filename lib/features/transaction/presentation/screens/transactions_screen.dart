import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_record.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_list_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_list_state.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/add_transaction_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/transaction_detail_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/widgets/transaction_type_ui.dart';
import 'package:multi_wallet_tracker/injection_container.dart';

class TransactionsScreen extends StatefulWidget {
  const TransactionsScreen({super.key, this.cubit});

  final TransactionListCubit? cubit;

  @override
  State<TransactionsScreen> createState() => _TransactionsScreenState();
}

class _TransactionsScreenState extends State<TransactionsScreen> {
  late final TransactionListCubit _cubit;
  late final bool _ownsCubit;

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? sl<TransactionListCubit>();
    unawaited(_cubit.load());
  }

  @override
  void dispose() {
    if (_ownsCubit) {
      unawaited(_cubit.close());
    }
    super.dispose();
  }

  Future<void> _addTransaction() async {
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => const AddTransactionScreen(),
      ),
    );
    if (saved == true) {
      unawaited(_cubit.load());
    }
  }

  Future<void> _openTransaction(TransactionRecord record) async {
    final bool? changed = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) => TransactionDetailScreen(
          transactionId: record.id,
        ),
      ),
    );
    if (changed == true) {
      unawaited(_cubit.load());
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransactionListCubit>.value(
      value: _cubit,
      child: Scaffold(
        appBar: AppBar(title: const Text('Activity')),
        floatingActionButton: FloatingActionButton.extended(
          onPressed: _addTransaction,
          icon: const Icon(Icons.add),
          label: const Text('Add transaction'),
        ),
        body: BlocBuilder<TransactionListCubit, TransactionListState>(
          builder: (BuildContext context, TransactionListState state) {
            return switch (state) {
              TransactionListInitial() || TransactionListLoading() =>
                const Center(child: CircularProgressIndicator()),
              TransactionListFailure(:final String message) => _ActivityFailure(
                  message: message,
                  onRetry: () => context.read<TransactionListCubit>().load(),
                ),
              TransactionListLoaded(:final List<TransactionRecord> items) =>
                items.isEmpty
                    ? _EmptyActivity(onAdd: _addTransaction)
                    : _ActivityList(items: items, onTap: _openTransaction),
            };
          },
        ),
      ),
    );
  }
}

class _ActivityList extends StatelessWidget {
  const _ActivityList({required this.items, required this.onTap});

  final List<TransactionRecord> items;
  final Future<void> Function(TransactionRecord record) onTap;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 96),
      itemCount: items.length,
      separatorBuilder: (BuildContext context, int index) =>
          Divider(height: 1, color: scheme.outlineVariant),
      itemBuilder: (BuildContext context, int index) {
        final TransactionRecord record = items[index];
        return _ActivityTile(
          record: record,
          onTap: () => onTap(record),
        );
      },
    );
  }
}

class _ActivityTile extends StatelessWidget {
  const _ActivityTile({required this.record, required this.onTap});

  final TransactionRecord record;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final Color color = transactionTypeColor(context, record.type);
    final String typeLabel = transactionTypeLabel(record.type);
    final String date = DateFormat.yMMMd().add_jm().format(record.occurredAt);
    final String? note = record.note;
    final bool hasNote = note != null && note.isNotEmpty;
    final String details = record.fee.isPositive
        ? 'Fee ${record.fee.format()} · $date'
        : date;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
      leading: CircleAvatar(
        backgroundColor: color.withValues(alpha: 0.12),
        foregroundColor: color,
        child: Icon(transactionTypeIcon(record.type), size: 20),
      ),
      title: Text(
        hasNote ? note : typeLabel,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Text(
        hasNote ? '$typeLabel · $details' : details,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Text(
        signedAmount(record.amount, record.type),
        style: theme.textTheme.titleSmall?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
      ),
      onTap: onTap,
    );
  }
}

class _EmptyActivity extends StatelessWidget {
  const _EmptyActivity({required this.onAdd});

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
              Icons.receipt_long_outlined,
              size: 56,
              color: scheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              'No transactions yet',
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              'Record an expense, income, or transfer to see it here.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: onAdd,
              icon: const Icon(Icons.add),
              label: const Text('Add transaction'),
            ),
          ],
        ),
      ),
    );
  }
}

class _ActivityFailure extends StatelessWidget {
  const _ActivityFailure({required this.message, required this.onRetry});

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
