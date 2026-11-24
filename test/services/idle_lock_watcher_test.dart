import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/services/idle_lock_watcher.dart';

void main() {
  test('memicu onIdle setelah timeout terlewati', () {
    var now = DateTime(2026, 1, 1);
    var fired = 0;
    final watcher = IdleLockWatcher(
      timeout: const Duration(minutes: 5),
      onIdle: () => fired++,
      clock: () => now,
      tick: const Duration(hours: 1),
    );

    watcher.start();
    now = now.add(const Duration(minutes: 4));
    watcher.check();
    expect(fired, 0);
    expect(watcher.isRunning, isTrue);

    now = now.add(const Duration(minutes: 2));
    watcher.check();
    expect(fired, 1);
    expect(watcher.isRunning, isFalse);

    watcher.dispose();
  });

  test('aktivitas menunda idle', () {
    var now = DateTime(2026, 1, 1);
    var fired = 0;
    final watcher = IdleLockWatcher(
      timeout: const Duration(minutes: 5),
      onIdle: () => fired++,
      clock: () => now,
      tick: const Duration(hours: 1),
    );

    watcher.start();
    now = now.add(const Duration(minutes: 4));
    watcher.noteActivity();
    now = now.add(const Duration(minutes: 4));
    watcher.check();
    expect(fired, 0);

    now = now.add(const Duration(minutes: 2));
    watcher.check();
    expect(fired, 1);

    watcher.dispose();
  });

  test('check setelah stop tidak memicu apa pun', () {
    var now = DateTime(2026, 1, 1);
    var fired = 0;
    final watcher = IdleLockWatcher(
      timeout: const Duration(minutes: 1),
      onIdle: () => fired++,
      clock: () => now,
      tick: const Duration(hours: 1),
    );

    watcher.start();
    watcher.stop();
    now = now.add(const Duration(hours: 1));
    watcher.check();
    expect(fired, 0);

    watcher.noteActivity();
    watcher.check();
    expect(fired, 0);

    watcher.dispose();
  });

  test('start ulang memakai waktu aktivitas baru', () {
    var now = DateTime(2026, 1, 1);
    var fired = 0;
    final watcher = IdleLockWatcher(
      timeout: const Duration(minutes: 5),
      onIdle: () => fired++,
      clock: () => now,
      tick: const Duration(hours: 1),
    );

    watcher.start();
    now = now.add(const Duration(hours: 1));
    watcher.start();
    watcher.check();
    expect(fired, 0);

    now = now.add(const Duration(minutes: 6));
    watcher.check();
    expect(fired, 1);

    watcher.dispose();
  });
}
