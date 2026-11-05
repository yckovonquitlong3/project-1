import 'package:get_it/get_it.dart';

/// Global service locator.
///
/// Registration happens in [initDependencies]; widgets never resolve
/// dependencies directly, cubits receive them through their constructor.
final GetIt sl = GetIt.instance;

Future<void> initDependencies() async {
  // Phase 2+: database, DAOs, repositories, use cases, cubits.
}