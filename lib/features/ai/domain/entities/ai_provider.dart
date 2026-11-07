enum AiProviderPreset {
  openai(
    'openai',
    'OpenAI',
    'https://api.openai.com/v1/chat/completions',
    'gpt-4o-mini',
  ),
  deepseek(
    'deepseek',
    'DeepSeek',
    'https://api.deepseek.com/chat/completions',
    'deepseek-chat',
  );

  const AiProviderPreset(
    this.dbValue,
    this.label,
    this.endpoint,
    this.defaultModel,
  );

  final String dbValue;
  final String label;
  final String endpoint;
  final String defaultModel;

  static AiProviderPreset fromDb(String? value) {
    return AiProviderPreset.values.firstWhere(
      (AiProviderPreset provider) => provider.dbValue == value,
      orElse: () => AiProviderPreset.openai,
    );
  }
}
