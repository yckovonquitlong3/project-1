import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/category/domain/entities/category.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/billing_cycle.dart';
import 'package:multi_wallet_tracker/features/subscription/domain/entities/subscription.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/cubit/subscription_cubit.dart';
import 'package:multi_wallet_tracker/features/subscription/presentation/widgets/subscription_ui.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';

class SubscriptionFormSheet extends StatefulWidget {
  const SubscriptionFormSheet({
    required this.cubit,
    required this.activeWallets,
    required this.expenseCategories,
    this.existing,
    super.key,
  });

  final SubscriptionCubit cubit;
  final List<Wallet> activeWallets;
  final List<Category> expenseCategories;
  final Subscription? existing;

  @override
  State<SubscriptionFormSheet> createState() => _SubscriptionFormSheetState();
}

class _SubscriptionFormSheetState extends State<SubscriptionFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _amountController;
  late String? _walletId;
  late String? _categoryId;
  late BillingCycle _cycle;
  late DateTime _nextBillingAt;
  late bool _autoDeduct;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final Subscription? existing = widget.existing;
    _nameController = TextEditingController(text: existing?.name ?? '');
    _amountController = TextEditingController(
      text: existing == null ? '' : _amountText(existing.amount),
    );
    _walletId = existing?.walletId ??
        (widget.activeWallets.isEmpty ? null : widget.activeWallets.first.id);
    _categoryId = existing?.categoryId ??
        (widget.expenseCategories.isEmpty
            ? null
            : widget.expenseCategories.first.id);
    _cycle = existing?.cycle ?? BillingCycle.monthly;
    _nextBillingAt = existing?.nextBillingAt ?? _defaultBillingDate();
    _autoDeduct = existing?.autoDeduct ?? true;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    super.dispose();
  }

  DateTime _defaultBillingDate() {
    final DateTime now = DateTime.now();
    return DateTime(now.year, now.month + 1, now.day, 9);
  }

  String _amountText(Money money) {
    final int pesos = money.minorUnits ~/ 100;
    final int cents = money.minorUnits % 100;
    return '$pesos.${cents.toString().padLeft(2, '0')}';
  }

  String? _validateName(String? value) =>
      value == null || value.trim().isEmpty
          ? 'Subscription name is required'
          : null;

  String? _validateAmount(String? value) {
    try {
      Money.parsePesos(value ?? '');
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  String? _validateWallet(String? value) =>
      value == null ? 'Choose a wallet' : null;

  String? _validateCategory(String? value) =>
      value == null ? 'Choose a category' : null;

  Future<void> _pickDateTime() async {
    final DateTime? date = await showDatePicker(
      context: context,
      initialDate: _nextBillingAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (date == null || !mounted) {
      return;
    }
    final TimeOfDay? time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(_nextBillingAt),
    );
    if (time == null || !mounted) {
      return;
    }
    setState(() {
      _nextBillingAt = DateTime(
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
    if (_walletId == null || _categoryId == null) {
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });

    final String? error;
    if (_isEditing) {
      error = await widget.cubit.update(
        id: widget.existing!.id,
        name: _nameController.text,
        amount: amount,
        walletId: _walletId!,
        categoryId: _categoryId!,
        cycle: _cycle,
        nextBillingAt: _nextBillingAt,
        autoDeduct: _autoDeduct,
      );
    } else {
      error = await widget.cubit.create(
        name: _nameController.text,
        amount: amount,
        walletId: _walletId!,
        categoryId: _categoryId!,
        cycle: _cycle,
        nextBillingAt: _nextBillingAt,
        autoDeduct: _autoDeduct,
      );
    }

    if (!mounted) {
      return;
    }
    if (error != null) {
      setState(() {
        _saving = false;
        _error = error;
      });
      return;
    }
    Navigator.of(context).pop(true);
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool canSave = !_saving &&
        widget.activeWallets.isNotEmpty &&
        widget.expenseCategories.isNotEmpty;

    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: <Widget>[
                Row(
                  children: <Widget>[
                    Expanded(
                      child: Text(
                        _isEditing ? 'Edit subscription' : 'New subscription',
                        style: theme.textTheme.titleLarge
                            ?.copyWith(fontWeight: FontWeight.w600),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Close',
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(false),
                      icon: const Icon(Icons.close),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _nameController,
                  autofocus: !_isEditing,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 60,
                  decoration: const InputDecoration(
                    labelText: 'Subscription name',
                    hintText: 'e.g. Claude Pro',
                    counterText: '',
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _amountController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  textInputAction: TextInputAction.next,
                  decoration: const InputDecoration(
                    labelText: 'Amount',
                    hintText: '0.00',
                    prefixText: '${Money.currencySymbol} ',
                  ),
                  validator: _validateAmount,
                ),
                const SizedBox(height: 12),
                if (widget.activeWallets.isEmpty)
                  const _MissingData(
                    message: 'Add an active wallet before creating a '
                        'subscription.',
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'sub-wallet-${_walletId ?? 'none'}-'
                      '${widget.activeWallets.length}',
                    ),
                    initialValue: _walletId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Wallet'),
                    items: widget.activeWallets
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
                    onChanged: (String? value) =>
                        setState(() => _walletId = value),
                  ),
                const SizedBox(height: 12),
                if (widget.expenseCategories.isEmpty)
                  const _MissingData(
                    message: 'No expense categories are available.',
                  )
                else
                  DropdownButtonFormField<String>(
                    key: ValueKey<String?>(
                      'sub-category-${_categoryId ?? 'none'}-'
                      '${widget.expenseCategories.length}',
                    ),
                    initialValue: _categoryId,
                    isExpanded: true,
                    decoration: const InputDecoration(labelText: 'Category'),
                    items: widget.expenseCategories
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
                const SizedBox(height: 12),
                DropdownButtonFormField<BillingCycle>(
                  key: ValueKey<BillingCycle>(_cycle),
                  initialValue: _cycle,
                  isExpanded: true,
                  decoration: const InputDecoration(labelText: 'Billing cycle'),
                  items: BillingCycle.values
                      .map(
                        (BillingCycle cycle) =>
                            DropdownMenuItem<BillingCycle>(
                          value: cycle,
                          child: Text(billingCycleLabel(cycle)),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (BillingCycle? value) {
                    if (value != null) {
                      setState(() => _cycle = value);
                    }
                  },
                ),
                const SizedBox(height: 16),
                InkWell(
                  onTap: _pickDateTime,
                  borderRadius: BorderRadius.circular(16),
                  child: InputDecorator(
                    decoration: const InputDecoration(
                      labelText: 'Next billing date and time',
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
                            DateFormat.yMMMd()
                                .add_jm()
                                .format(_nextBillingAt),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: const Text('Auto-deduct'),
                  subtitle: const Text(
                    'Charge it automatically when the app next opens.',
                  ),
                  value: _autoDeduct,
                  onChanged: _saving
                      ? null
                      : (bool value) => setState(() => _autoDeduct = value),
                ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 8),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 16),
                FilledButton(
                  onPressed: canSave ? _save : null,
                  child: _saving
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Text(
                          _isEditing ? 'Save changes' : 'Add subscription',
                        ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _MissingData extends StatelessWidget {
  const _MissingData({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    final ColorScheme scheme = Theme.of(context).colorScheme;
    return Card(
      elevation: 0,
      color: scheme.errorContainer,
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: scheme.onErrorContainer,
              ),
        ),
      ),
    );
  }
}
