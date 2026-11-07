import 'package:flutter/material.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/repositories/ai_settings_store.dart';
import 'package:multi_wallet_tracker/features/ai/domain/usecases/parse_quick_entry.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/screens/ai_settings_screen.dart';
import 'package:multi_wallet_tracker/features/transaction/domain/entities/transaction_draft.dart';
import 'package:multi_wallet_tracker/features/transaction/presentation/screens/add_transaction_screen.dart';
import 'package:multi_wallet_tracker/injection_container.dart';

class AiQuickEntryCard extends StatefulWidget {
  const AiQuickEntryCard({super.key, this.store, this.parseQuickEntry});

  final AiSettingsStore? store;
  final ParseQuickEntry? parseQuickEntry;

  @override
  State<AiQuickEntryCard> createState() => _AiQuickEntryCardState();
}

class _AiQuickEntryCardState extends State<AiQuickEntryCard> {
  late final AiSettingsStore _store;
  late final ParseQuickEntry _parse;
  final TextEditingController _controller = TextEditingController();

  bool _loading = true;
  bool _ready = false;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? sl<AiSettingsStore>();
    _parse = widget.parseQuickEntry ?? sl<ParseQuickEntry>();
    _refresh();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _refresh() async {
    try {
      final AiSettings settings = await _store.load();
      final bool hasKey = await _store.hasApiKey();
      final bool hasConsent = await _store.hasConsent();
      if (!mounted) {
        return;
      }
      setState(() {
        _ready = settings.isEnabled && hasKey && hasConsent;
        _loading = false;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _ready = false;
          _loading = false;
        });
      }
    }
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AiSettingsScreen(),
      ),
    );
    if (mounted) {
      await _refresh();
    }
  }

  Future<void> _submit() async {
    final String text = _controller.text.trim();
    if (text.isEmpty || _sending) {
      return;
    }
    setState(() => _sending = true);
    try {
      final TransactionDraft draft = await _parse(text);
      if (!mounted) {
        return;
      }
      _controller.clear();
      await Navigator.of(context).push<void>(
        MaterialPageRoute<void>(
          builder: (BuildContext context) =>
              AddTransactionScreen(draft: draft),
        ),
      );
    } on AiFailure catch (failure) {
      if (!mounted) {
        return;
      }
      _message(failure.message);
      await _openManualFallback(text);
    } catch (_) {
      if (!mounted) {
        return;
      }
      _message('AI could not process that. Opening manual entry.');
      await _openManualFallback(text);
    } finally {
      if (mounted) {
        setState(() => _sending = false);
      }
    }
  }

  Future<void> _openManualFallback(String text) async {
    if (!mounted) {
      return;
    }
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AddTransactionScreen(
          draft: TransactionDraft(note: text),
        ),
      ),
    );
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    if (_loading) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        child: const ListTile(
          leading: Icon(Icons.auto_awesome),
          title: Text('AI quick entry'),
          trailing: SizedBox.square(
            dimension: 18,
            child: CircularProgressIndicator(strokeWidth: 2),
          ),
        ),
      );
    }

    if (!_ready) {
      return Card(
        elevation: 0,
        color: scheme.surfaceContainerLow,
        child: ListTile(
          leading: Icon(Icons.auto_awesome, color: scheme.primary),
          title: const Text('AI quick entry'),
          subtitle: const Text(
            'Connect a provider to type a transaction in plain language.',
          ),
          trailing: TextButton(
            onPressed: _openSettings,
            child: const Text('Set up'),
          ),
        ),
      );
    }

    return Card(
      elevation: 0,
      color: scheme.surfaceContainerLow,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.auto_awesome, size: 18, color: scheme.primary),
                const SizedBox(width: 8),
                Text(
                  'AI quick entry',
                  style: theme.textTheme.labelLarge
                      ?.copyWith(fontWeight: FontWeight.w600),
                ),
                const Spacer(),
                IconButton(
                  tooltip: 'AI settings',
                  onPressed: _openSettings,
                  icon: const Icon(Icons.settings_outlined, size: 20),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !_sending,
                    maxLength: 400,
                    textInputAction: TextInputAction.send,
                    onSubmitted: (_) => _submit(),
                    decoration: const InputDecoration(
                      hintText: 'Spent 150 on iced coffee via GCash',
                      counterText: '',
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                _sending
                    ? const Padding(
                        padding: EdgeInsets.all(12),
                        child: SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    : IconButton(
                        tooltip: 'Parse with AI',
                        onPressed: _submit,
                        icon: const Icon(Icons.arrow_upward),
                      ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(left: 2, bottom: 2),
              child: Text(
                'The AI fills the form; you confirm before saving.',
                style: theme.textTheme.labelSmall
                    ?.copyWith(color: scheme.onSurfaceVariant),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
