import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/vault_lock_provider.dart';
import '../providers/vault_provider.dart';
import '../services/idle_lock_watcher.dart';
import 'finance/finance_screen.dart';
import 'notes/notes_screen.dart';
import 'settings/settings_screen.dart';
import 'vault/vault_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> with WidgetsBindingObserver {
  static const Duration _idleTimeout = Duration(minutes: 5);

  int _index = 0;
  IdleLockWatcher? _idle;
  VaultLockProvider? _lock;

  static const List<Widget> _screens = <Widget>[
    NotesScreen(),
    FinanceScreen(),
    VaultScreen(),
    SettingsScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _idle = IdleLockWatcher(timeout: _idleTimeout, onIdle: _lockVault);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lock = context.read<VaultLockProvider>();
    if (!identical(lock, _lock)) {
      _lock?.removeListener(_syncIdleWatcher);
      _lock = lock..addListener(_syncIdleWatcher);
    }
    _syncIdleWatcher();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lock?.removeListener(_syncIdleWatcher);
    _idle?.dispose();
    super.dispose();
  }

  /// Timer idle hanya hidup selama vault terbuka.
  void _syncIdleWatcher() {
    final idle = _idle;
    if (idle == null) return;

    if (_lock?.isUnlocked ?? false) {
      if (!idle.isRunning) idle.start();
    } else {
      idle.stop();
    }
  }

  void _lockVault() {
    if (!mounted) return;

    final lock = _lock;
    if (lock == null || !lock.isUnlocked) return;

    _idle?.stop();
    lock.lock();
    context.read<VaultProvider>().clearItems();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused && state != AppLifecycleState.hidden) {
      return;
    }
    _lockVault();
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) => _idle?.noteActivity(),
      onPointerMove: (_) => _idle?.noteActivity(),
      onPointerSignal: (_) => _idle?.noteActivity(),
      child: Scaffold(
        body: IndexedStack(index: _index, children: _screens),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (value) => setState(() => _index = value),
          destinations: const <NavigationDestination>[
            NavigationDestination(
              icon: Icon(Icons.sticky_note_2_outlined),
              selectedIcon: Icon(Icons.sticky_note_2),
              label: 'Catatan',
            ),
            NavigationDestination(
              icon: Icon(Icons.account_balance_wallet_outlined),
              selectedIcon: Icon(Icons.account_balance_wallet),
              label: 'Keuangan',
            ),
            NavigationDestination(
              icon: Icon(Icons.lock_outline),
              selectedIcon: Icon(Icons.lock),
              label: 'Vault',
            ),
            NavigationDestination(
              icon: Icon(Icons.settings_outlined),
              selectedIcon: Icon(Icons.settings),
              label: 'Pengaturan',
            ),
          ],
        ),
      ),
    );
  }
}