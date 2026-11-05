import 'dart:async';

/// Broadcast signal that the ledger changed.
///
/// Cubits subscribe instead of calling each other, so features stay decoupled.
class LedgerBus {
  final StreamController<void> _controller = StreamController<void>.broadcast();

  Stream<void> get changes => _controller.stream;

  void notify() {
    if (!_controller.isClosed) {
      _controller.add(null);
    }
  }

  Future<void> dispose() => _controller.close();
}