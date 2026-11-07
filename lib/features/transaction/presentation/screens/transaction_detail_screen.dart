import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_detail.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/delete_transaction.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/usecases/get_transaction_detail.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/add_transaction_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/widgets/transaction_type_ui.dart';
import 'package:multi_wallet_tracker/injection_container.dart';

class TransactionDetailScreen extends StatefulWidget {
  const TransactionDetailScreen({
    required this.transactionId,
    super.key,
    this.loader,
    this.deleteTransaction,
  });

  final String transactionId;

  /// Test seams. In the app these resolve from the service locator.
  final GetTransactionDetail? loader;
  final DeleteTransaction? deleteTransaction;

  @override
  State<TransactionDetailScreen> createState() =>
      _TransactionDetailScreenState();
}

class _TransactionDetailScreenState extends State<TransactionDetailScreen> {
  TransactionDetail? _detail;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _fetch();
  }

  Future<void> _fetch() async {
    try {
      final TransactionDetail detail =
          await (widget.loader ?? sl<GetTransactionDetail>())(
        widget.transactionId,
      );
      if (!mounted) {
        return;
      }
      setState(() {
        _detail = detail;
        _loading = false;
        _error = null;
      });
    } on Failure catch (failure) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = failure.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load the transaction';
        });
      }
    }
  }

  Future<void> _reload() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    await _fetch();
  }

  Future<void> _edit() async {
    final TransactionDetail? detail = _detail;
    if (detail == null) {
      return;
    }
    final bool? saved = await Navigator.of(context).push<bool>(
      MaterialPageRoute<bool>(
        builder: (BuildContext context) =>
            AddTransactionScreen(existing: detail),
      ),
    );
    if (saved == true && mounted) {
      await _reload();
    }
  }

  Future<void> _delete() async {
    final TransactionDetail? detail = _detail;
    if (detail == null) {
      return;
    }

    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Delete this transaction?'),
        content: const Text(
          'The wallet balances will be corrected automatically. '
          'This cannot be undone.',
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
    if (confirmed != true || !mounted) {
      return;
    }

    try {
      await (widget.deleteTransaction ?? sl<DeleteTransaction>())(
        detail.record.id,
      );
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } on Failure catch (failure) {
      if (mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(failure.message)));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final bool generated = _detail?.record.subscriptionId != null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Transaction'),
        actions: _detail == null || generated
            ? null
            : <Widget>[
                IconButton(
                  tooltip: 'Edit transaction',
                  onPressed: _edit,
                  icon: const Icon(Icons.edit_outlined),
                ),
                IconButton(
                  tooltip: 'Delete transaction',
                  onPressed: _delete,
                  icon: const Icon(Icons.delete_outline),
                ),
              ],
      ),
      body: _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    final TransactionDetail? detail = _detail;
    if (detail == null) {
      return _DetailFailure(
        message: _error ?? 'Transaction not found',
        onRetry: _reload,
      );
    }

    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final Color typeColor =
        transactionTypeColor(context, detail.record.type);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Card(
            elevation: 0,
            color: scheme.surfaceContainerLow,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                children: <Widget>[
                  Icon(
                    transactionTypeIcon(detail.record.type),
                    color: typeColor,
                    size: 28,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    transactionTypeLabel(detail.record.type),
                    style: theme.textTheme.labelLarge?.copyWith(
                      color: scheme.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    signedAmount(detail.record.amount, detail.record.type),
                    textAlign: TextAlign.center,
                    style: theme.textTheme.headlineMedium?.copyWith(
                      color: typeColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (detail.targetWallet != null) ...<Widget>[
                    const SizedBox(height: 8),
                    Text(
                      '${detail.sourceWallet.name} to '
                      '${detail.targetWallet!.name}',
                      textAlign: TextAlign.center,
                      style: theme.textTheme.bodyMedium?.copyWith(
                        color: scheme.onSurfaceVariant,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          if (detail.record.subscriptionId != null) ...<Widget>[
            const SizedBox(height: 16),
            Card(
              elevation: 0,
              color: scheme.secondaryContainer,
              child: ListTile(
                leading: Icon(
                  Icons.autorenew,
                  color: scheme.onSecondaryContainer,
                ),
                title: Text(
                  'Generated by a subscription',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    color: scheme.onSecondaryContainer,
                  ),
                ),
                subtitle: Text(
                  kSubscriptionChargeImmutableMessage,
                  style: TextStyle(color: scheme.onSecondaryContainer),
                ),
              ),
            ),
          ],
          const SizedBox(height: 24),
          _DetailRow(label: 'From wallet', value: detail.sourceWallet.name),
          if (detail.targetWallet != null)
            _DetailRow(
              label: 'To wallet',
              value: detail.targetWallet!.name,
            ),
          if (detail.category != null)
            _DetailRow(label: 'Category', value: detail.category!.name),
          if (detail.record.fee.isPositive)
            _DetailRow(
              label: 'Transfer fee',
              value: detail.record.fee.format(),
            ),
          _DetailRow(
            label: 'Date and time',
            value: DateFormat.yMMMMd()
                .add_jm()
                .format(detail.record.occurredAt),
          ),
          if (detail.record.note != null &&
              detail.record.note!.isNotEmpty)
            _DetailRow(label: 'Note', value: detail.record.note!),
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

class _DetailFailure extends StatelessWidget {
  const _DetailFailure({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

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
