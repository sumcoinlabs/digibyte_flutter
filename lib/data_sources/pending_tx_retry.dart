import 'dart:async';

/// Tracks transactions discovered from Electrum UTXOs whose full
/// transaction data may not yet be available from the server.
class PendingTxRetry {
  PendingTxRetry({
    required this.request,
    required this.canRequest,
    this.onExhausted,
    this.responseTimeout = const Duration(seconds: 5),
    List<Duration> retryDelays = const [
      Duration(seconds: 2),
      Duration(seconds: 4),
      Duration(seconds: 6),
      Duration(seconds: 10),
      Duration(seconds: 16),
    ],
  }) : retryDelays = List.unmodifiable(retryDelays);

  final void Function(String txId) request;
  final bool Function() canRequest;
  final void Function(String txId)? onExhausted;
  final Duration responseTimeout;
  final List<Duration> retryDelays;

  final Map<String, _PendingTx> _pending = {};
  bool _disposed = false;
  bool _paused = false;

  int get pendingCount => _pending.length;

  void track(String txId) {
    if (_disposed || txId.isEmpty || _pending.containsKey(txId)) {
      return;
    }
    final pending = _PendingTx(txId);
    _pending[txId] = pending;
    _send(pending);
  }

  void _send(_PendingTx pending) {
    if (_disposed ||
        _paused ||
        !identical(_pending[pending.txId], pending)) {
      return;
    }

    pending.timer?.cancel();
    pending.timer = null;

    if (!canRequest()) {
      // Resume automatically when the transport is usable again.
      pending.timer = Timer(
        const Duration(seconds: 2),
        () => _send(pending),
      );
      return;
    }

    pending.awaitingResponse = true;
    pending.timer = Timer(responseTimeout, () {
      pending.awaitingResponse = false;
      _scheduleRetry(pending);
    });

    try {
      request(pending.txId);
    } catch (_) {
      pending.timer?.cancel();
      pending.awaitingResponse = false;
      _scheduleRetry(pending);
    }
  }

  void unavailable(String txId) {
    final pending = _pending[txId];
    if (pending == null || !pending.awaitingResponse) {
      return;
    }
    pending.timer?.cancel();
    pending.awaitingResponse = false;
    _scheduleRetry(pending);
  }

  void _scheduleRetry(_PendingTx pending) {
    if (_disposed ||
        _paused ||
        !identical(_pending[pending.txId], pending)) {
      return;
    }

    if (pending.retries >= retryDelays.length) {
      _pending.remove(pending.txId);
      pending.timer = null;
      onExhausted?.call(pending.txId);
      return;
    }

    final delay = retryDelays[pending.retries];
    pending.retries++;

    pending.timer = Timer(delay, () => _send(pending));
  }

  void succeeded(String txId) {
    _pending.remove(txId)?.timer?.cancel();
  }

  void pause() {
    _paused = true;
    for (final pending in _pending.values) {
      pending.timer?.cancel();
      pending.timer = null;
      pending.awaitingResponse = false;
    }
  }

  void resume() {
    if (_disposed) return;
    _paused = false;
    for (final pending in _pending.values.toList()) {
      _send(pending);
    }
  }

  void clear() {
    for (final pending in _pending.values) {
      pending.timer?.cancel();
    }
    _pending.clear();
  }

  void dispose() {
    _disposed = true;
    clear();
  }
}

class _PendingTx {
  _PendingTx(this.txId);

  final String txId;
  int retries = 0;
  bool awaitingResponse = false;
  Timer? timer;
}
