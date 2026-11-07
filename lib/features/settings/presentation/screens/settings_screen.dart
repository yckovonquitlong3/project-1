import 'dart:async';

import 'package:flutter/material.dart';
import 'package:multi_wallet_tracker/core/notifications/app_settings_launcher.dart';
import 'package:multi_wallet_tracker/core/notifications/local_notification_service.dart';
import 'package:multi_wallet_tracker/features/ai/domain/ai_settings_bus.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_settings.dart';
import 'package:multi_wallet_tracker/features/ai/domain/repositories/ai_settings_store.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/screens/ai_settings_screen.dart';
import 'package:multi_wallet_tracker/injection_container.dart';

/// Central place for AI status, notifications, and privacy information.
class SettingsScreen extends StatefulWidget {
  const SettingsScreen({
    super.key,
    this.settingsStore,
    this.bus,
    this.notificationService,
    this.appSettingsLauncher,
  });

  final AiSettingsStore? settingsStore;
  final AiSettingsBus? bus;
  final LocalNotificationService? notificationService;
  final AppSettingsLauncher? appSettingsLauncher;

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late final AiSettingsStore _store;
  late final AiSettingsBus? _bus;
  late final LocalNotificationService? _notifications;
  late final AppSettingsLauncher _launcher;
  StreamSubscription<void>? _busSubscription;

  bool _loading = true;
  bool _aiReady = false;
  bool _aiConfigured = false;
  bool _notificationsAvailable = false;
  bool _notificationsEnabled = false;
  AiSettings _settings = const AiSettings();
  String? _error;

  @override
  void initState() {
    super.initState();
    _store = widget.settingsStore ?? sl<AiSettingsStore>();
    _bus = widget.bus ??
        (sl.isRegistered<AiSettingsBus>() ? sl<AiSettingsBus>() : null);
    _notifications = widget.notificationService ??
        (sl.isRegistered<LocalNotificationService>()
            ? sl<LocalNotificationService>()
            : null);
    _launcher = widget.appSettingsLauncher ?? const AppSettingsLauncher();
    _notificationsAvailable = _notifications != null;
    _busSubscription = _bus?.changes.listen((_) => _load());
    _load();
  }

  @override
  void dispose() {
    unawaited(_busSubscription?.cancel());
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final AiSettings settings = await _store.load();
      final bool hasKey = await _store.hasApiKey();
      final bool hasConsent = await _store.hasConsent();
      var notificationsEnabled = false;
      final LocalNotificationService? service = _notifications;
      if (service != null) {
        try {
          notificationsEnabled = await service.notificationsEnabled();
        } catch (_) {
          notificationsEnabled = false;
        }
      }
      if (!mounted) {
        return;
      }
      setState(() {
        _settings = settings;
        _aiConfigured = hasKey && hasConsent;
        _aiReady = settings.isEnabled && _aiConfigured;
        _notificationsEnabled = notificationsEnabled;
        _loading = false;
        _error = null;
      });
    } catch (_) {
      if (mounted) {
        setState(() {
          _loading = false;
          _error = 'Could not load settings.';
        });
      }
    }
  }

  Future<void> _openAiSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => AiSettingsScreen(
          store: _store,
          bus: _bus,
        ),
      ),
    );
    if (mounted) {
      await _load();
    }
  }

  Future<void> _requestNotifications() async {
    final LocalNotificationService? service = _notifications;
    if (service == null) {
      return;
    }
    bool enabled = false;
    try {
      enabled = await service.requestPermission();
    } catch (_) {
      enabled = false;
    }
    if (!mounted) {
      return;
    }
    setState(() => _notificationsEnabled = enabled);
    _message(
      enabled
          ? 'Subscription reminders are enabled.'
          : 'Notifications are still off. Enable them in system settings.',
    );
  }

  Future<void> _openSystemNotificationSettings() async {
    final bool opened = await _launcher.openNotificationSettings();
    if (!mounted) {
      return;
    }
    if (!opened) {
      _message('Could not open system settings on this device.');
      return;
    }
    await _load();
  }

  void _showAiPrivacy() {
    showDialog<void>(
      context: context,
      builder: (BuildContext dialogContext) => AlertDialog(
        title: const Text('What AI can see'),
        scrollable: true,
        content: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text(
              'Quick entry sends the words you type, plus wallet and category '
              'names, to your chosen provider. The provider returns suggested '
              'fields that you review before saving.',
            ),
            SizedBox(height: 12),
            Text('Analytics chat sends only aggregate totals:'),
            SizedBox(height: 6),
            Text('• wallet names and current balances'),
            Text('• monthly income, expense, fee, and net totals'),
            Text('• category expense totals for a date range'),
            SizedBox(height: 12),
            Text(
              'It never sends raw transactions, notes, transaction IDs, or '
              'database access. AI cannot change your ledger and there is no '
              'AI write tool.',
            ),
            SizedBox(height: 12),
            Text(
              'Your API key is stored only on this device in encrypted '
              'storage. The app has no proxy or server. You can disconnect and '
              'delete the key at any time from AI settings.',
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Close'),
          ),
        ],
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
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                children: <Widget>[
                  const _SectionTitle('AI'),
                  _AiCard(
                    ready: _aiReady,
                    configured: _aiConfigured,
                    settings: _settings,
                    onManage: _openAiSettings,
                    onPrivacy: _showAiPrivacy,
                  ),
                  if (_notificationsAvailable) ...<Widget>[
                    const _SectionTitle('Notifications'),
                    _NotificationCard(
                      enabled: _notificationsEnabled,
                      onEnable: _requestNotifications,
                      onOpenSystemSettings: _openSystemNotificationSettings,
                    ),
                  ],
                  const _SectionTitle('Data and privacy'),
                  const Card(
                    elevation: 0,
                    child: ListTile(
                      leading: Icon(Icons.phonelink_lock_outlined),
                      title: Text('Your data stays on this device'),
                      subtitle: Text(
                        'The ledger uses a local database. There is no sync '
                        'server, no proxy, and no analytics upload.',
                      ),
                    ),
                  ),
                  const _SectionTitle('About'),
                  const Card(
                    elevation: 0,
                    child: Column(
                      children: <Widget>[
                        ListTile(
                          leading: Icon(Icons.info_outline),
                          title: Text('Multi-Wallet Tracker'),
                          subtitle: Text('Version 1.5.0 · offline-first ledger'),
                        ),
                        Divider(height: 1),
                        ListTile(
                          leading: Icon(Icons.auto_awesome_outlined),
                          title: Text('AI is optional'),
                          subtitle: Text(
                            'Off by default. Bring your own provider key to '
                            'use quick entry or analytics chat.',
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (_error != null) ...<Widget>[
                    const SizedBox(height: 16),
                    Text(
                      _error!,
                      style: Theme.of(context)
                          .textTheme
                          .bodyMedium
                          ?.copyWith(color: Theme.of(context).colorScheme.error),
                    ),
                  ],
                ],
              ),
            ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 20, bottom: 8),
      child: Text(
        title,
        style: Theme.of(context)
            .textTheme
            .titleMedium
            ?.copyWith(fontWeight: FontWeight.w600),
      ),
    );
  }
}

class _AiCard extends StatelessWidget {
  const _AiCard({
    required this.ready,
    required this.configured,
    required this.settings,
    required this.onManage,
    required this.onPrivacy,
  });

  final bool ready;
  final bool configured;
  final AiSettings settings;
  final Future<void> Function() onManage;
  final VoidCallback onPrivacy;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final String status = ready
        ? 'Ready · ${settings.provider.label}'
        : configured
            ? 'Off · setup saved'
            : 'Off · no key saved';
    final String detail = ready
        ? 'Model: ${settings.model}. Quick entry and analytics chat are '
            'available.'
        : 'AI is optional. Add your own provider key to enable quick entry '
            'and analytics chat.';

    return Card(
      elevation: 0,
      child: Column(
        children: <Widget>[
          ListTile(
            leading: Icon(
              ready ? Icons.auto_awesome : Icons.auto_awesome_outlined,
              color: ready ? scheme.primary : scheme.onSurfaceVariant,
            ),
            title: const Text('AI features'),
            subtitle: Text('$status\n$detail'),
            isThreeLine: true,
            trailing: TextButton(
              onPressed: onManage,
              child: const Text('Manage'),
            ),
          ),
          Divider(height: 1, color: scheme.outlineVariant),
          ListTile(
            leading: const Icon(Icons.visibility_outlined),
            title: const Text('What AI can see'),
            subtitle: const Text(
              'Only the text you type and aggregate totals. No raw '
              'transactions or notes.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: onPrivacy,
          ),
        ],
      ),
    );
  }
}

class _NotificationCard extends StatelessWidget {
  const _NotificationCard({
    required this.enabled,
    required this.onEnable,
    required this.onOpenSystemSettings,
  });

  final bool enabled;
  final Future<void> Function() onEnable;
  final Future<void> Function() onOpenSystemSettings;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return Card(
      elevation: 0,
      child: Column(
        children: <Widget>[
          ListTile(
            leading: Icon(
              enabled
                  ? Icons.notifications_active_outlined
                  : Icons.notifications_off_outlined,
              color: enabled ? scheme.primary : scheme.onSurfaceVariant,
            ),
            title: const Text('Subscription reminders'),
            subtitle: Text(
              enabled
                  ? 'On. Reminders are scheduled on this device.'
                  : 'Off. Reminders cannot appear until notifications are '
                      'allowed.',
            ),
            trailing: enabled
                ? null
                : TextButton(
                    onPressed: onEnable,
                    child: const Text('Enable'),
                  ),
          ),
          if (!enabled) ...<Widget>[
            Divider(height: 1, color: scheme.outlineVariant),
            ListTile(
              leading: const Icon(Icons.settings_outlined),
              title: const Text('Open system notification settings'),
              trailing: const Icon(Icons.open_in_new),
              onTap: onOpenSystemSettings,
            ),
          ],
        ],
      ),
    );
  }
}
