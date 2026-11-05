import 'package:flutter/material.dart';
import 'package:multi_wallet_tracker/core/money/money.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/account_type.dart';
import 'package:multi_wallet_tracker/features/wallet/domain/entities/wallet.dart';
import 'package:multi_wallet_tracker/features/wallet/presentation/cubit/wallet_cubit.dart';

import 'wallet_icons.dart';

/// Create/edit form. Editing never touches the balance: it is derived from the
/// ledger and can only change through transactions.
class WalletFormSheet extends StatefulWidget {
  const WalletFormSheet({required this.cubit, this.wallet, super.key});

  final WalletCubit cubit;
  final Wallet? wallet;

  @override
  State<WalletFormSheet> createState() => _WalletFormSheetState();
}

class _WalletFormSheetState extends State<WalletFormSheet> {
  final GlobalKey<FormState> _formKey = GlobalKey<FormState>();
  late final TextEditingController _nameController;
  late final TextEditingController _openingController;
  late AccountType _accountType;
  late String _iconIdentifier;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.wallet != null;

  @override
  void initState() {
    super.initState();
    final Wallet? wallet = widget.wallet;
    _nameController = TextEditingController(text: wallet?.name ?? '');
    _openingController = TextEditingController();
    _accountType = wallet?.accountType ?? AccountType.cash;
    _iconIdentifier = wallet?.iconIdentifier ?? kWalletIconChoices.keys.first;
  }

  @override
  void dispose() {
    _nameController.dispose();
    _openingController.dispose();
    super.dispose();
  }

  Money _parseOpening(String raw) {
    final String text = raw.trim();
    if (text.isEmpty || RegExp(r'^0+(\.0{1,2})?$').hasMatch(text)) {
      return Money.zero;
    }
    return Money.parsePesos(text);
  }

  String? _validateName(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Wallet name is required';
    }
    return null;
  }

  String? _validateOpening(String? value) {
    final String text = (value ?? '').trim();
    if (text.isEmpty) {
      return null;
    }
    try {
      _parseOpening(text);
      return null;
    } on FormatException catch (error) {
      return error.message;
    }
  }

  Future<void> _save() async {
    if (!(_formKey.currentState?.validate() ?? false)) {
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    final String? error;
    if (_isEditing) {
      error = await widget.cubit.update(
        id: widget.wallet!.id,
        name: _nameController.text,
        accountType: _accountType,
        iconIdentifier: _iconIdentifier,
      );
    } else {
      error = await widget.cubit.create(
        name: _nameController.text,
        accountType: _accountType,
        iconIdentifier: _iconIdentifier,
        openingBalance: _parseOpening(_openingController.text),
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
                        _isEditing ? 'Edit wallet' : 'New wallet',
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
                  maxLength: 40,
                  decoration: const InputDecoration(
                    labelText: 'Wallet name',
                    hintText: 'e.g. GCash',
                    counterText: '',
                  ),
                  validator: _validateName,
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<AccountType>(
                  initialValue: _accountType,
                  decoration: const InputDecoration(labelText: 'Account type'),
                  items: AccountType.values
                      .map(
                        (AccountType type) =>
                            DropdownMenuItem<AccountType>(
                          value: type,
                          child: Row(
                            children: <Widget>[
                              Icon(iconForAccountType(type), size: 20),
                              const SizedBox(width: 10),
                              Text(type.label),
                            ],
                          ),
                        ),
                      )
                      .toList(growable: false),
                  onChanged: (AccountType? value) {
                    if (value != null) {
                      setState(() => _accountType = value);
                    }
                  },
                ),
                const SizedBox(height: 20),
                Text('Icon', style: theme.textTheme.labelLarge),
                const SizedBox(height: 8),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: kWalletIconChoices.entries
                      .map(
                        (MapEntry<String, ({IconData icon, String label})>
                            entry) {
                          final bool selected = _iconIdentifier == entry.key;
                          return IconButton(
                            tooltip: entry.value.label,
                            isSelected: selected,
                            icon: Icon(entry.value.icon),
                            selectedIcon: Icon(entry.value.icon),
                            style: IconButton.styleFrom(
                              minimumSize: const Size(48, 48),
                              backgroundColor: selected
                                  ? scheme.primaryContainer
                                  : scheme.surfaceContainerHighest,
                              foregroundColor: selected
                                  ? scheme.onPrimaryContainer
                                  : scheme.onSurfaceVariant,
                            ),
                            onPressed: () =>
                                setState(() => _iconIdentifier = entry.key),
                          );
                        },
                      )
                      .toList(growable: false),
                ),
                const SizedBox(height: 20),
                if (_isEditing)
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: <Widget>[
                        Text(
                          'Current balance',
                          style: theme.textTheme.bodyMedium
                              ?.copyWith(color: scheme.onSurfaceVariant),
                        ),
                        Text(
                          widget.wallet!.balance.format(),
                          style: theme.textTheme.titleMedium
                              ?.copyWith(fontWeight: FontWeight.w600),
                        ),
                      ],
                    ),
                  )
                else
                  TextFormField(
                    controller: _openingController,
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    textInputAction: TextInputAction.done,
                    decoration: const InputDecoration(
                      labelText: 'Opening balance',
                      hintText: '0.00',
                      prefixText: '${Money.currencySymbol} ',
                      helperText: 'Optional. Leave blank for zero.',
                    ),
                    validator: _validateOpening,
                    onFieldSubmitted: (_) => _save(),
                  ),
                if (_error != null) ...<Widget>[
                  const SizedBox(height: 12),
                  Text(
                    _error!,
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(color: scheme.error),
                  ),
                ],
                const SizedBox(height: 24),
                FilledButton(
                  onPressed: _saving ? null : _save,
                  child: _saving
                      ? SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: scheme.onPrimary,
                          ),
                        )
                      : Text(_isEditing ? 'Save changes' : 'Add wallet'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
