import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_chat.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/cubit/analytics_chat_cubit.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/cubit/analytics_chat_state.dart';
import 'package:multi_wallet_tracker/features/ai/presentation/screens/ai_settings_screen.dart';
import 'package:multi_wallet_tracker/injection_container.dart';

class AnalyticsChatScreen extends StatefulWidget {
  const AnalyticsChatScreen({super.key, this.cubit});

  final AnalyticsChatCubit? cubit;

  @override
  State<AnalyticsChatScreen> createState() => _AnalyticsChatScreenState();
}

class _AnalyticsChatScreenState extends State<AnalyticsChatScreen> {
  late final AnalyticsChatCubit _cubit;
  late final bool _ownsCubit;
  final TextEditingController _controller = TextEditingController();
  final ScrollController _scrollController = ScrollController();

  static const List<String> _suggestions = <String>[
    'How much did I spend on food last month?',
    'What are my wallet balances?',
    'Summarize this month\'s income and expenses.',
  ];

  @override
  void initState() {
    super.initState();
    _ownsCubit = widget.cubit == null;
    _cubit = widget.cubit ?? sl<AnalyticsChatCubit>();
    if (_ownsCubit) {
      _cubit.load();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    _scrollController.dispose();
    if (_ownsCubit) {
      _cubit.close();
    }
    super.dispose();
  }

  Future<void> _send(String text) async {
    final String question = text.trim();
    if (question.isEmpty) {
      return;
    }
    _controller.clear();
    final String? error = await _cubit.send(question);
    if (!mounted) {
      return;
    }
    if (error != null) {
      _controller.text = question;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(error)));
    } else {
      _scrollToBottom();
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollController.hasClients) {
        return;
      }
      _scrollController.animateTo(
        _scrollController.position.maxScrollExtent,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  Future<void> _openSettings() async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (BuildContext context) => const AiSettingsScreen(),
      ),
    );
    if (mounted) {
      await _cubit.load();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider<AnalyticsChatCubit>.value(
      value: _cubit,
      child: BlocBuilder<AnalyticsChatCubit, AnalyticsChatState>(
        builder: (BuildContext context, AnalyticsChatState state) {
          final bool hasMessages =
              state is AnalyticsChatReady && state.messages.isNotEmpty;
          return Scaffold(
            appBar: AppBar(
              title: const Text('Ask AI'),
              actions: <Widget>[
                if (hasMessages)
                  IconButton(
                    tooltip: 'Clear chat',
                    onPressed: () => context.read<AnalyticsChatCubit>().clear(),
                    icon: const Icon(Icons.delete_sweep_outlined),
                  ),
              ],
            ),
            body: switch (state) {
              AnalyticsChatInitial() || AnalyticsChatLoading() => const Center(
                  child: CircularProgressIndicator(),
                ),
              AnalyticsChatUnavailable(:final String message) => _Unavailable(
                  message: message,
                  onOpenSettings: _openSettings,
                ),
              AnalyticsChatFailure(:final String message) => _Failure(
                  message: message,
                  onRetry: () => context.read<AnalyticsChatCubit>().load(),
                ),
              AnalyticsChatReady() => _buildChat(context, state),
            },
          );
        },
      ),
    );
  }

  Widget _buildChat(BuildContext context, AnalyticsChatReady state) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SafeArea(
      top: false,
      child: Column(
        children: <Widget>[
          Expanded(
            child: state.messages.isEmpty
                ? _EmptyChat(
                    suggestions: _suggestions,
                    onQuestion: _send,
                  )
                : ListView.builder(
                    controller: _scrollController,
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
                    itemCount: state.messages.length,
                    itemBuilder: (BuildContext context, int index) {
                      return _Bubble(message: state.messages[index]);
                    },
                  ),
          ),
          if (state.sending)
            LinearProgressIndicator(
              minHeight: 2,
              backgroundColor: scheme.surfaceContainerHighest,
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
            child: Text(
              'AI can be wrong. Check the dashboard for the final numbers.',
              style: theme.textTheme.labelSmall
                  ?.copyWith(color: scheme.onSurfaceVariant),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 4, 8, 12),
            child: Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _controller,
                    enabled: !state.sending,
                    maxLength: 400,
                    textInputAction: TextInputAction.send,
                    onSubmitted: _send,
                    decoration: const InputDecoration(
                      hintText: 'Ask about your spending...',
                      counterText: '',
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton.filled(
                  tooltip: 'Send question',
                  onPressed: state.sending ? null : () => _send(_controller.text),
                  icon: const Icon(Icons.arrow_upward),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message});

  final AiChatMessage message;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;
    final bool user = message.role == AiChatRole.user;

    return Align(
      alignment: user ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.sizeOf(context).width * 0.82,
        ),
        decoration: BoxDecoration(
          color: user ? scheme.primary : scheme.surfaceContainerHighest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(user ? 18 : 4),
            bottomRight: Radius.circular(user ? 4 : 18),
          ),
        ),
        child: Text(
          message.content ?? '',
          style: theme.textTheme.bodyMedium?.copyWith(
            color: user ? scheme.onPrimary : scheme.onSurface,
          ),
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  const _EmptyChat({required this.suggestions, required this.onQuestion});

  final List<String> suggestions;
  final Future<void> Function(String question) onQuestion;

  @override
  Widget build(BuildContext context) {
    final ThemeData theme = Theme.of(context);
    final ColorScheme scheme = theme.colorScheme;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Icon(Icons.insights_outlined, size: 56, color: scheme.primary),
          const SizedBox(height: 16),
          Text(
            'Ask your ledger',
            textAlign: TextAlign.center,
            style: theme.textTheme.titleLarge
                ?.copyWith(fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Text(
            'Questions use aggregate totals only. Raw transactions and notes '
            'are not sent.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium
                ?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 24),
          for (final String suggestion in suggestions)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: OutlinedButton(
                onPressed: () => onQuestion(suggestion),
                child: Text(suggestion, textAlign: TextAlign.center),
              ),
            ),
        ],
      ),
    );
  }
}

class _Unavailable extends StatelessWidget {
  const _Unavailable({required this.message, required this.onOpenSettings});

  final String message;
  final Future<void> Function() onOpenSettings;

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
            Icon(Icons.auto_awesome, size: 48, color: scheme.primary),
            const SizedBox(height: 16),
            Text(
              message,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyLarge,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onOpenSettings,
              child: const Text('Open AI settings'),
            ),
          ],
        ),
      ),
    );
  }
}

class _Failure extends StatelessWidget {
  const _Failure({required this.message, required this.onRetry});

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
