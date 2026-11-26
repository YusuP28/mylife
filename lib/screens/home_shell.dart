import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../providers/globals_provider.dart';
import '../providers/vault_lock_provider.dart';
import '../providers/vault_provider.dart';
import '../widgets/global_search_delegate.dart';
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
  int _index = 0;
  VaultLockProvider? _lock;
  bool _wasUnlocked = false;

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
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    final lock = context.read<VaultLockProvider>();
    if (identical(lock, _lock)) return;

    _lock?.removeListener(_onLockChanged);
    _lock = lock..addListener(_onLockChanged);
    _wasUnlocked = lock.isUnlocked;
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _lock?.removeListener(_onLockChanged);
    super.dispose();
  }

  /// Plaintext di memori dibuang saat status berubah terbuka → terkunci,
  /// termasuk saat lock dipicu timer idle di `VaultLockProvider`.
  void _onLockChanged() {
    if (!mounted) return;

    final unlocked = _lock?.isUnlocked ?? false;
    if (_wasUnlocked && !unlocked) {
      context.read<VaultProvider>().clearItems();
    }
    _wasUnlocked = unlocked;
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.paused && state != AppLifecycleState.hidden) {
      return;
    }

    final lock = _lock;
    if (lock != null && lock.isUnlocked) lock.lock();
  }

  @override
  Widget build(BuildContext context) {
    final globals = context.watch<GlobalsProvider>();

    return Scaffold(
      body: Column(
        children: [
          // Search Bar
          if (globals.hasActiveSearch)
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                decoration: InputDecoration(
                  hintText: 'Cari catatan, transaksi, atau vault...',
                  prefixIcon: const Icon(Icons.search),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onChanged: globals.setQuery,
              ),
            ),
          // Content Area
          Expanded(
            child: globals.hasActiveSearch
                ? const GlobalSearchDelegate()
                : IndexedStack(index: _index, children: _screens),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) {
          if (globals.hasActiveSearch) {
            globals.clearQuery();
          }
          setState(() => _index = value);
        },
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
    );
  }
}