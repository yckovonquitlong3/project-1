import 'dart:async';

/// Signals that AI settings changed so mounted screens can refresh.
class AiSettingsBus {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Future<void> dispose() => _controller.close();
}
