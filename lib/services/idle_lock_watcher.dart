import 'dart:async';

import 'package:flutter/foundation.dart';

/// Pengunci otomatis berbasis idle.
///
/// `check()` membandingkan waktu sekarang dengan aktivitas terakhir, sehingga
/// bisa diuji dengan jam palsu tanpa menunggu timer sungguhan.
///
/// Catatan: aktivitas yang dihitung berasal dari pointer/scroll. Mengetik di
/// soft keyboard tidak menghasilkan pointer event, jadi tidak menunda lock.
class IdleLockWatcher {
  IdleLockWatcher({
    required this.timeout,
    required this.onIdle,
    DateTime Function()? clock,
    this.tick = const Duration(seconds: 30),
  }) : _clock = clock ?? DateTime.now;

  final Duration timeout;
  final Duration tick;
  final VoidCallback onIdle;
  final DateTime Function() _clock;

  Timer? _timer;
  DateTime? _lastActivity;

  bool get isRunning => _timer != null;

  void start() {
    _lastActivity = _clock();
    _timer?.cancel();
    _timer = Timer.periodic(tick, (_) => check());
  }

  void noteActivity() {
    if (_timer == null) return;
    _lastActivity = _clock();
  }

  void check() {
    final last = _lastActivity;
    if (_timer == null || last == null) return;
    if (_clock().difference(last) < timeout) return;

    stop();
    onIdle();
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _lastActivity = null;
  }

  void dispose() => stop();
}
