import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/finance_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/vault_lock_provider.dart';
import 'providers/vault_provider.dart';
import 'screens/home_shell.dart';
import 'services/database_service.dart';
import 'services/vault_encryption_service.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');

  // Vault mulai terkunci: tidak ada operasi database yang menulis plaintext.
  DatabaseService.instance.vaultEncryption = const LockedEncryption();

  runApp(const MylifeApp());
}

class MylifeApp extends StatelessWidget {
  const MylifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotesProvider>(
      create: (_) => NotesProvider()..loadNotes(),
      child: ChangeNotifierProvider<FinanceProvider>(
        create: (_) => FinanceProvider()..loadTransactions(),
        child: ChangeNotifierProvider<VaultProvider>(
          create: (_) => VaultProvider(),
          child: ChangeNotifierProvider<VaultLockProvider>(
            create: (_) => VaultLockProvider()..refreshStatus(),
            child: MaterialApp(
              title: 'Mylife',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.light,
              home: const HomeShell(),
              builder: (context, child) {
                final lock = context.read<VaultLockProvider>();
                return Listener(
                  behavior: HitTestBehavior.translucent,
                  onPointerDown: (_) => lock.noteActivity(),
                  onPointerMove: (_) => lock.noteActivity(),
                  onPointerSignal: (_) => lock.noteActivity(),
                  child: child ?? const SizedBox.shrink(),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}
