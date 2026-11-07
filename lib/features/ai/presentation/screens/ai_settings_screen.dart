import 'package:flutter/material.dart';
import 'package:multi_wallet_tracker/core/error/failure.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_provider.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/repositories/ai_settings_store.dart';
import 'package:multi_wallet_tracker/features/ai/domain/services/ai_client.dart';
import 'package:multi_wallet_tracker/injection_container.dart';

class AiSettingsScreen extends StatefulWidget {
  const AiSettingsScreen({super.key, this.store, this.client});

  final AiSettingsStore? store;
  final AiClient? client;

  @override
  State<AiSettingsScreen> createState() => _AiSettingsScreenState();
}

class _AiSettingsScreenState extends State<AiSettingsScreen> {
  late final AiSettingsStore _store;
  late final AiClient _client;
  final TextEditingController _modelController = TextEditingController();
  final TextEditingController _keyController = TextEditingController();

  AiMode _mode = AiMode.off;
  AiProviderPreset _provider = AiProviderPreset.openai;
  bool _hasKey = false;
  bool _hasConsent = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _showKey = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _store = widget.store ?? sl<AiSettingsStore>();
    _client = widget.client ?? sl<AiClient>();
    _load();
  }

  @override
  void dispose() {
    _modelController.dispose();
    _keyController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final AiSettings settings = await _store.load();
      final bool hasKey = await _store.hasApiKey();
      final bool hasConsent = await _store.hasConsent();
      if (!mounted) {
        return;
      }
      setState(() {
        _mode = settings.mode;
        _provider = settings.provider;
        _modelController.text = settings.model;
        _hasKey = hasKey;
        _hasConsent = hasConsent;
        _loading = false;
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
          _error = 'Could not load AI settings.';
        });
      }
    }
  }

  Future<bool> _ensureConsent() async {
    if (_hasConsent) {
      return true;
    }
    final bool? accepted = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Enable AI features?'),
        content: SingleChildScrollView(
          child: Text(
            'Quick entry sends the text you type to '
            '${_provider.label} using your own API key. The provider returns '
            'suggested fields, which you review before saving. There is no '
            'proxy or server run by this app.\n\n'
            'Do not type information you do not want processed by the '
            'provider. You can disable AI and delete the key at any time.',
          ),
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('I understand'),
          ),
        ],
      ),
    );
    if (accepted != true) {
      return false;
    }
    try {
      await _store.grantConsent();
      if (!mounted) {
        return false;
      }
      setState(() => _hasConsent = true);
      return true;
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _error = failure.message);
      }
      return false;
    }
  }

  Future<void> _selectMode(AiMode mode) async {
    if (mode == _mode) {
      return;
    }
    if (mode == AiMode.byok) {
      final bool consent = await _ensureConsent();
      if (!consent || !mounted) {
        return;
      }
    }
    setState(() {
      _mode = mode;
      _error = null;
      if (mode == AiMode.byok && _modelController.text.trim().isEmpty) {
        _modelController.text = _provider.defaultModel;
      }
    });
  }

  Future<void> _save() async {
    final String? warning = _mode == AiMode.byok ? _modelWarning : null;
    if (warning != null) {
      setState(() => _error = warning);
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });

    try {
      final String model = _modelController.text.trim().isEmpty
          ? _provider.defaultModel
          : _modelController.text.trim();

      if (_mode == AiMode.byok) {
        if (!_hasConsent) {
          final bool consent = await _ensureConsent();
          if (!consent) {
            if (mounted) {
              setState(() {
                _saving = false;
                _mode = AiMode.off;
              });
            }
            return;
          }
        }
        final String typedKey = _keyController.text.trim();
        if (typedKey.isEmpty && !_hasKey) {
          if (mounted) {
            setState(() {
              _saving = false;
              _error = 'Enter your provider API key.';
            });
          }
          return;
        }
        if (typedKey.isNotEmpty) {
          await _store.saveApiKey(typedKey);
        }
      }

      await _store.save(
        AiSettings(mode: _mode, provider: _provider, model: model),
      );
      final bool hasKey = await _store.hasApiKey();
      if (!mounted) {
        return;
      }
      setState(() {
        _saving = false;
        _hasKey = hasKey;
        _keyController.clear();
      });
      _message(_mode == AiMode.off
          ? 'AI is off.'
          : 'AI quick entry is ready.');
    } on Failure catch (failure) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = failure.message;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not save AI settings.';
        });
      }
    }
  }

  Future<void> _testConnection() async {
    final String? warning = _mode == AiMode.byok ? _modelWarning : null;
    if (warning != null) {
      setState(() => _error = warning);
      return;
    }
    final String typedKey = _keyController.text.trim();
    final String? key =
        typedKey.isNotEmpty ? typedKey : await _store.readApiKey();
    if (key == null || key.trim().isEmpty) {
      setState(() => _error = 'Enter or save an API key first.');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
    });
    try {
      await _client.testConnection(
        settings: AiSettings(
          mode: AiMode.byok,
          provider: _provider,
          model: _modelController.text.trim().isEmpty
              ? _provider.defaultModel
              : _modelController.text.trim(),
        ),
        apiKey: key,
      );
      if (mounted) {
        _message('Connection successful.');
      }
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _error = failure.message);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Connection test failed.');
      }
    } finally {
      if (mounted) {
        setState(() => _testing = false);
      }
    }
  }

  Future<void> _disconnect() async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('Disconnect AI?'),
        content: const Text(
          'This turns AI off, deletes the saved API key, and clears your '
          'consent. Quick entry will fall back to manual entry.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Disconnect'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) {
      return;
    }
    try {
      await _store.revokeConsent();
      if (!mounted) {
        return;
      }
      setState(() {
        _mode = AiMode.off;
        _hasKey = false;
        _hasConsent = false;
        _keyController.clear();
        _error = null;
      });
      _message('AI disconnected.');
    } on Failure catch (failure) {
      if (mounted) {
        setState(() => _error = failure.message);
      }
    }
  }

  void _message(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String? get _modelWarning {
    final String model = _modelController.text.trim();
    if (model.isEmpty) {
      return null;
    }
    final String lower = model.toLowerCase();
    if (lower.startsWith('sk-') || model.contains(' ')) {
      return 'Enter a model ID such as ${_provider.defaultModel}, not an API '
          'key or key name.';
    }
    if (_provider == AiProviderPreset.openai && lower.contains('deepseek')) {
      return 'This looks like a DeepSeek model. Choose DeepSeek as the '
          'provider.';
    }
    if (_provider == AiProviderPreset.deepseek && lower.startsWith('gpt')) {
      return 'This looks like an OpenAI model. Choose OpenAI as the provider.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('AI settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _buildBody(context),
    );
  }

  Widget _buildBody(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool busy = _saving || _testing;

    return ListView(
      padding: const EdgeInsets.all(16),
      children: <Widget>[
        Card(
          elevation: 0,
          color: scheme.surfaceContainerLow,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Text(
              'AI is optional. The app calls your chosen provider directly '
              'with your own key; there is no proxy. Your key stays on this '
              'device in encrypted storage.',
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ),
        const SizedBox(height: 16),
        SegmentedButton<AiMode>(
          segments: const <ButtonSegment<AiMode>>[
            ButtonSegment<AiMode>(value: AiMode.off, label: Text('Off')),
            ButtonSegment<AiMode>(value: AiMode.byok, label: Text('BYOK')),
          ],
          selected: <AiMode>{_mode},
          showSelectedIcon: false,
          onSelectionChanged: busy
              ? null
              : (Set<AiMode> selection) => _selectMode(selection.first),
        ),
        const SizedBox(height: 16),
        if (_mode == AiMode.byok) ...<Widget>[
          DropdownButtonFormField<AiProviderPreset>(
            key: ValueKey<AiProviderPreset>(_provider),
            initialValue: _provider,
            isExpanded: true,
            decoration: const InputDecoration(
              labelText: 'Provider',
              helperText: 'Choose the provider that issued your API key.',
            ),
            items: AiProviderPreset.values
                .map(
                  (AiProviderPreset provider) =>
                      DropdownMenuItem<AiProviderPreset>(
                    value: provider,
                    child: Text(provider.label),
                  ),
                )
                .toList(growable: false),
            onChanged: busy
                ? null
                : (AiProviderPreset? value) {
                    if (value != null) {
                      setState(() {
                        _provider = value;
                        _modelController.text = value.defaultModel;
                      });
                    }
                  },
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _modelController,
            enabled: !busy,
            onChanged: (_) => setState(() {}),
            decoration: InputDecoration(
              labelText: 'Model',
              helperText: 'Model ID, not your key name. Default: '
                  '${_provider.defaultModel}',
            ),
          ),
          if (_modelWarning != null)
            Padding(
              padding: const EdgeInsets.only(top: 6),
              child: Text(
                _modelWarning!,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: scheme.error,
                ),
              ),
            ),
          const SizedBox(height: 12),
          TextField(
            controller: _keyController,
            enabled: !busy,
            obscureText: !_showKey,
            autocorrect: false,
            enableSuggestions: false,
            decoration: InputDecoration(
              labelText: 'API key',
              hintText: _hasKey
                  ? 'Key saved — paste a new one to replace'
                  : 'Paste your provider API key',
              helperText:
                  'Paste the secret value only (no "Bearer"). Stored in Android secure storage; never written to the database or logs.',
              suffixIcon: IconButton(
                tooltip: _showKey ? 'Hide key' : 'Show key',
                onPressed: () => setState(() => _showKey = !_showKey),
                icon: Icon(
                  _showKey ? Icons.visibility_off : Icons.visibility,
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Card(
            elevation: 0,
            color: _hasConsent
                ? scheme.secondaryContainer
                : scheme.surfaceContainerLow,
            child: ListTile(
              leading: Icon(
                _hasConsent ? Icons.verified_user : Icons.privacy_tip_outlined,
                color: _hasConsent
                    ? scheme.onSecondaryContainer
                    : scheme.onSurfaceVariant,
              ),
              title: Text(
                _hasConsent ? 'Consent recorded' : 'Consent required',
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: _hasConsent
                      ? scheme.onSecondaryContainer
                      : scheme.onSurface,
                ),
              ),
              subtitle: Text(
                _hasConsent
                    ? 'You can disconnect at any time.'
                    : 'Accept the data notice before enabling AI.',
              ),
              trailing: _hasConsent
                  ? null
                  : TextButton(
                      onPressed: busy ? null : _ensureConsent,
                      child: const Text('Review'),
                    ),
            ),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: busy ? null : _save,
            child: _saving
                ? SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: scheme.onPrimary,
                    ),
                  )
                : const Text('Save settings'),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            onPressed: busy ? null : _testConnection,
            child: _testing
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Test connection'),
          ),
          if (_hasKey) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : _disconnect,
              child: const Text('Disconnect AI and delete key'),
            ),
          ],
        ] else ...<Widget>[
          FilledButton(
            onPressed: busy ? null : _save,
            child: const Text('Save settings'),
          ),
          if (_hasKey) ...<Widget>[
            const SizedBox(height: 8),
            TextButton(
              onPressed: busy ? null : _disconnect,
              child: const Text('Disconnect AI and delete key'),
            ),
          ],
        ],
        if (_error != null) ...<Widget>[
          const SizedBox(height: 16),
          Text(
            _error!,
            style: theme.textTheme.bodyMedium?.copyWith(color: scheme.error),
          ),
        ],
      ],
    );
  }
}
