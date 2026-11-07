import 'package:equatable/equatable.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_mode.dart';
import 'package:multi_wallet_tracker/features/ai/domain/entities/ai_provider.dart';

class AiSettings extends Equatable {
  const AiSettings({
    this.mode = AiMode.off,
    this.provider = AiProviderPreset.openai,
    this.model = 'gpt-4o-mini',
  });

  final AiMode mode;
  final AiProviderPreset provider;
  final String model;

  bool get isEnabled => mode == AiMode.byok;

  @override
  List<Object?> get props => <Object?>[mode, provider, model];
}
