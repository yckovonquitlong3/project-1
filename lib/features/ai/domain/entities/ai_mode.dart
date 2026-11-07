enum AiMode {
  off('off'),
  byok('byok');

  const AiMode(this.dbValue);

  final String dbValue;

  static AiMode fromDb(String? value) {
    if (value == null) {
      return AiMode.off;
    }
    return AiMode.values.firstWhere(
      (AiMode mode) => mode.dbValue == value,
      orElse: () => AiMode.off,
    );
  }
}
