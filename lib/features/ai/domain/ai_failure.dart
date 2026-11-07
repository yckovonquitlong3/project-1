import 'package:multi_wallet_tracker/core/error/failure.dart';

enum AiFailureKind {
  disabled,
  consentRequired,
  noKey,
  network,
  timeout,
  auth,
  rateLimit,
  invalidResponse,
  unknown,
}

final class AiFailure extends Failure {
  const AiFailure(
    super.message, {
    this.kind = AiFailureKind.unknown,
    super.cause,
  });

  final AiFailureKind kind;
}
