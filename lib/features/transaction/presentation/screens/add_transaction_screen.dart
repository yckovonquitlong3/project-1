import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/category/domain/usecases/get_categories.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_detail.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_draft.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_type.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_cubit.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/cubit/transaction_state.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/usecases/get_wallets.dart';
import 'package:multi_wallet_tracker/injection_container.dart';

/// One form for expense, income, and transfer, in create or edit mode.
///
/// The transaction type is fixed when editing; changing an expense into an
/// income would be a different ledger operation, not an edit.
class AddTransactionScreen extends StatefulWidget {
  const AddTransactionScreen({
    super.key,
    this.existing,
    this.draft,
    this.cubit,
    this.activeWallets,
    this.categories,
  }) : assert(existing == null || draft == null);

  final TransactionDetail? existing;
  final TransactionDraft? draft;
  final TransactionCubit? cubit;

  /// Test seams. In the app these load from the use cases.
  final List<Wallet>? activeWallets;
  final List<Category>? categories;

  @override
  State<AddTransactionScreen> createState() => _AddTransactionScreenState();
}

class _AddTransactionScreenState extends State<AddTransactionScreen> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TransactionCubit _cubit;
  late final bool _ownsCubit;
  late final TextEditingController _amountController;
  late final TextEditingController _feeController;
  late final TextEditingController _noteController;
  late TransactionType _type;
  late DateTime _occurredAt;
  String? _sourceWalletId;
  String? _targetWalletId;
  String? _categoryId;
  List<Wallet> _wallets = const <Wallet>[];
  List<Category> _categories = const <Category>[];
  bool _loading = true;
  String? _loadError;

  bool get _isEditing => widget.existing != null;
  bool get _hasDraft => widget.draft != null;

  @override
  void initState() {
    super.initState();
    final TransactionDetail? detail = widget.existing;
    final TransactionDraft? draft = widget.draft;
    _type = detail?.record.type ?? draft?.type ?? TransactionType.expense;
    _occurredAt = detail?.record.occurredAt ?? DateTime.now();
    _amountController = TextEditingController(
      text: detail != null
          ? _amountText(detail.record.amount)
          : draft?.amount == null
              ? ''
              : _amountText(draft!.amount!),
    );
    _feeController = TextEditingController(
      text: detail != null
          ? (detail.record.fee.isZero
              ? ''
              : _amountText(detail.record.fee))
          : draft?.type == TransactionType.transfer &&
                  draft!.fee.isPositive
              ? _amountText(draft.fee)
              : '',
    );
    _noteController = TextEditingController(
      text: detail?.record.note ?? draft?.note ?? '',
    );
    _sourceWalletId =
        detail?.record.sourceWalletId ?? draft?.sourceWalletId;
    _targetWalletId =
        detail?.record.targetWalletId ?? draft?.targetWalletId;
    _categoryId = detail?.record.categoryId ?? draft?.categoryId;
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? sl<TransactionCubit>();
    unawaited(_loadReference());
  }

  @override
  void dispose() {
    _amountController.dispose();
    _feeController.dispose();
    _noteController.dispose();
    if (_ownsCubit) {
      unawaited(_cubit.close());
    }
    super.dispose();
  }

  String _amountText(Money money) {
    final int pesos = money.minorUnits ~/ 100;
    final int cents = money.minorUnits % 100;
    return '$pesos.${cents.toString().padLeft(2, '0')}';
  }

  Future<void> _loadReference() async {
    try {
      List<Wallet> wallets;
      List<Category> categories;

      if (widget.activeWallets != null && widget.categories != null) {
        wallets = List<Wallet>.of(widget.activeWallets!);
        categories = List<Category>.of(widget.categories!);
      } else {
        final result = await sl<GetWallets>()();
        wallets = List<Wallet>.of(result.active);
        final List<Category> expense =
            await sl<GetCategories>()(CategoryType.expense);
        final List<Category> income =
            await sl<GetCategories>()(CategoryType.income);
        categories = <Category>[...expense, ...income];
      }

      // Keep the current references selectable even if they were archived
      // after the transaction was written.
      final TransactionDetail? detail = widget.existing;
      if (detail != null) {
        if (!wallets.any((Wallet wallet) => wallet.id == detail.sourceWallet.id)) {
          wallets.add(detail.sourceWallet);
        }
        final Wallet? target = detail.targetWallet;
        if (target != null &&
            !wallets.any((Wallet wallet) => wallet.id == target.id)) {
          wallets.add(target);
        }
        final Category? category = detail.category;
        if (category != null &&
            !categories.any((Category item) => item.id == category.id)) {
          categories.add(category);
        }
      }

      if (!mounted) {
        return;
      }
      setState(() {
        _wallets = wallets;
        _categories = categories;
        _loading = false;
        _applyDefaults();
      });
    } on Failure catch (failure) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = failure.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _loadError = 'Could not load the transaction form';
        });
      }
    }
  }

  List<Category> _categoriesFor(TransactionType type) {
    final CategoryType expected = type == TransactionType.income
        ? CategoryType.income
        : CategoryType.expense;
    return _categories
        .where((Category category) => category.type == expected)
        .toList(growable: false);
  }

  void _applyDefaults() {
    if (_hasDraft) {
      // The AI supplied what it could; leave missing fields for the user.
      return;
    }
    if (_sourceWalletId == null && _wallets.isNotEmpty) {
      _sourceWalletId = _wallets.first.id;
    }

    if (_type == TransactionType.transfer) {
      _categoryId = null;
      if (_targetWalletId == null || _targetWalletId == _sourceWalletId) {
        final List<Wallet> others = _wallets
            .where((Wallet wallet) => wallet.id != _sourceWalletId)
            .toList(growable: false);
        _targetWalletId = others.isEmpty ? null : others.first.id;
      }
      return;
    }

    _targetWalletId = null;
    final List<Category> options = _categoriesFor(_type);
    if (_categoryId == null ||
        !options.any((Category category) => category.id == _categoryId)) {
      _categoryId = options.isEmpty ? null : options.first.id;
    }
  }

  void _changeType(TransactionType type) {
    if (_isEditing) {
      return;
    }
    setState(() {
      _type = type;
      _categoryId = null;
      if (type != TransactionType.transfer) {
        _targetWalletId = null;
        _feeController.clear();
      }
      _applyDefaults();
    });
  }

  String? _validateAmount(String? value) {
    try {
      Money.parsePesos(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  String? _validateFee(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      Money.parsePesosOrZero(text);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  String? _feeWarning() {
    if (_type != TransactionType.transfer) {
      return null;
    }
    try {
      final Money amount = Money.parsePesos(_amountController.text);
      final Money fee = Money.parsePesosOrZero(_feeController.text);
      if (fee.compareTo(amount) > 0) {
        return 'Fee is larger than the transfer amount.';
      }
    } on FormatException {
      return null;
    }
    return null;
  }

  String? _validateWallet(String? value) =>
      value == null ? 'Choose a wallet' : null;

  String? _validateTarget(String? value) {
    if (value == null) {
      return 'Choose a destination wallet';
    }
    if (value == _sourceWalletId) {
      return 'Choose two different wallets';
    }
    return null;
  }

  String? _validateCategory(String? value) =>
      value == null ? 'Choose a category' : null;

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_occurredAt),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _occurredAt = DateTime(
        date.year,
        date.month,
        date.day,
        time.hour,
        time.minute,
      );
    });
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }

    final Money amount;
    try {
      amount = Money.parsePesos(_amountController.text);
    } on FormatException {
      return;
    }
    final Money fee = _type == TransactionType.transfer
        ? Money.parsePesosOrZero(_feeController.text)
        : Money.zero;

    final TransactionDetail? detail = widget.existing;
    if (detail == null) {
      switch (_type) {
        case TransactionType.expense:
          await _cubit.addExpense(
            amount: amount,
            walletId: _sourceWalletId!,
            categoryId: _categoryId!,
            occurredAt: _occurredAt,
            note: _noteController.text,
          );
        case TransactionType.income:
          await _cubit.addIncome(
            amount: amount,
            walletId: _sourceWalletId!,
            categoryId: _categoryId!,
            occurredAt: _occurredAt,
            note: _noteController.text,
          );
        case TransactionType.transfer:
          await _cubit.addTransfer(
            amount: amount,
            sourceWalletId: _sourceWalletId!,
            targetWalletId: _targetWalletId!,
            fee: fee,
            occurredAt: _occurredAt,
            note: _noteController.text,
          );
      }
      return;
    }

    await _cubit.edit(
      previous: detail.record,
      amount: amount,
      fee: fee,
      sourceWalletId: _sourceWalletId,
      targetWalletId: _targetWalletId,
      categoryId: _categoryId,
      occurredAt: _occurredAt,
      note: _noteController.text,
    );
  }

  void _handleState(BuildContext context, TransactionState state) {
    if (state is TransactionSaved || state is TransactionDeleted) {
      Navigator.of(context).pop(true);
    } else if (state is TransactionFailure) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(state.message)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<TransactionCubit>.value(
      value: _cubit,
      child: BlocConsumer<TransactionCubit, TransactionState>(
        listener: _handleState,
        builder: (BuildContext context, TransactionState state) {
          return Scaffold(
            appBar: AppBar(
              title: Text(_isEditing ? 'Edit transaction' : 'Add transaction'),
            ),
            body: _loading
                ? const Center(child: CircularProgressIndicator())
                : _loadError != null
                    ? _LoadFailure(message: _loadError!, onRetry: _loadReference)
                    : _buildForm(context, saving: state is TransactionSaving),
          );
        },
      ),
    );
  }

  Widget _buildForm(BuildContext context, {required bool saving}) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final List<Category> categoryOptions = _categoriesFor(_type);
    final String? feeWarning = _feeWarning();

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: SegmentedButton<TransactionType>(
                segments: const <ButtonSegment<TransactionType>>[
                  ButtonSegment<TransactionType>(
                    value: TransactionType.expense,
                    label: Text('Expense'),
                  ),
                  ButtonSegment<TransactionType>(
                    value: TransactionType.income,
                    label: Text('Income'),
                  ),
                  ButtonSegment<TransactionType>(
                    value: TransactionType.transfer,
                    label: Text('Transfer'),
                  ),
                ],
                selected: <TransactionType>{_type},
                showSelectedIcon: false,
                onSelectionChanged: _isEditing
                    ? null
                    : (Set<TransactionType> selection) =>
                        _changeType(selection.first),
              ),
            ),
            if (_hasDraft) ...<Widget>[
              const SizedBox(height: 12),
              Card(
                elevation: 0,
                color: scheme.secondaryContainer,
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.auto_awesome,
                        size: 20,
                        color: scheme.onSecondaryContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Review the AI suggestion. Nothing is saved until '
                          'you tap Add transaction.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: scheme.onSecondaryContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            const SizedBox(height: 20),
            TextFormField(
              controller: _amountController,
              autofocus: !_isEditing,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              textInputAction: TextInputAction.next,
              style: theme.textTheme.headlineSmall
                  ?.copyWith(fontWeight: FontWeight.w600),
              decoration: const InputDecoration(
                labelText: 'Amount',
                hintText: '0.00',
                prefixText: '${Money.currencySymbol} ',
              ),
              validator: _validateAmount,
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            if (_wallets.isEmpty)
              Card(
                elevation: 0,
                color: scheme.errorContainer,
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: <Widget>[
                      Icon(
                        Icons.info_outline,
                        color: scheme.onErrorContainer,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Add a wallet first. Every transaction needs one.',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: scheme.onErrorContainer,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else ...<Widget>[
              DropdownButtonFormField<String>(
                key: ValueKey<String>(
                  'source-${_sourceWalletId ?? 'none'}-${_wallets.length}',
                ),
                initialValue: _sourceWalletId,
                isExpanded: true,
                decoration: InputDecoration(
                  labelText: _type == TransactionType.transfer
                      ? 'From wallet'
                      : 'Wallet',
                ),
                items: _wallets
                    .map(
                      (Wallet wallet) => DropdownMenuItem<String>(
                        value: wallet.id,
                        child: Text(
                          wallet.name,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    )
                    .toList(growable: false),
                validator: _validateWallet,
                onChanged: (String? value) {
                  setState(() {
                    _sourceWalletId = value;
                    if (_type == TransactionType.transfer &&
                        _targetWalletId == value) {
                      _targetWalletId = null;
                    }
                  });
                },
              ),
              if (_type == TransactionType.transfer) ...<Widget>[
                const SizedBox(height: 16),
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'target-${_targetWalletId ?? 'none'}-${_wallets.length}',
                  ),
                  initialValue: _targetWalletId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'To wallet'),
                  items: _wallets
                      .map(
                        (Wallet wallet) => DropdownMenuItem<String>(
                          value: wallet.id,
                          child: Text(
                            wallet.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  validator: _validateTarget,
                  onChanged: (String? value) =>
                      setState(() => _targetWalletId = value),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _feeController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(
                    labelText: 'Transfer fee (optional)',
                    hintText: '0.00',
                    prefixText: '${Money.currencySymbol} ',
                    helperText: 'Leave blank for no fee.',
                  ),
                  validator: _validateFee,
                  onChanged: (_) => setState(() {}),
                ),
                if (feeWarning != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      feeWarning,
                      style: theme.textTheme.bodySmall
                          ?.copyWith(color: scheme.error),
                    ),
                  ),
              ],
            ],
            if (_type != TransactionType.transfer) ...<Widget>[
              const SizedBox(height: 16),
              if (categoryOptions.isEmpty)
                Text(
                  'No categories available.',
                  style: theme.textTheme.bodyMedium
                      ?.copyWith(color: scheme.error),
                )
              else
                DropdownButtonFormField<String>(
                  key: ValueKey<String>(
                    'category-${_categoryId ?? 'none'}-${_type.name}-'
                    '${categoryOptions.length}',
                  ),
                  initialValue: _categoryId,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Category'),
                  items: categoryOptions
                      .map(
                        (Category category) => DropdownMenuItem<String>(
                          value: category.id,
                          child: Text(
                            category.name,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(growable: false),
                  validator: _validateCategory,
                  onChanged: (String? value) =>
                      setState(() => _categoryId = value),
                ),
            ],
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDateTime,
              borderRadius: BorderRadius.circular(16),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Date and time',
                ),
                child: Row(
                  children: <Widget>[
                    Icon(
                      Icons.event_outlined,
                      size: 20,
                      color: scheme.onSurfaceVariant,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        DateFormat.yMMMd().add_jm().format(_occurredAt),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _noteController,
              maxLines: 2,
              maxLength: 200,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Note (optional)',
                counterText: '',
                alignLabelWithHint: true,
              ),
            ),
            const SizedBox(height: 24),
            FilledButton(
              onPressed: saving || _wallets.isEmpty ? null : _save,
              child: saving
                  ? SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: scheme.onPrimary,
                      ),
                    )
                  : Text(
                      _isEditing ? 'Save changes' : 'Add transaction',
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _LoadFailure extends StatelessWidget {
  const _LoadFailure({required this.message, required this.onRetry});

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
