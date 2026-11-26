import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/finance_provider.dart';
import 'providers/globals_provider.dart';
import 'providers/notes_provider.dart';
import 'providers/theme_provider.dart';
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
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<NotesProvider>(
          create: (_) => NotesProvider()..loadNotes(),
        ),
        ChangeNotifierProvider<FinanceProvider>(
          create: (_) => FinanceProvider()..loadTransactions(),
        ),
        ChangeNotifierProvider<VaultProvider>(
          create: (_) => VaultProvider(),
        ),
        ProxyProvider4<NotesProvider, FinanceProvider, VaultProvider, GlobalsProvider>(
          update: (_, notes, finance, vault, previous) =>
              (previous ?? GlobalsProvider(
                notesProvider: notes,
                financeProvider: finance,
                vaultProvider: vault,
              )),
        ),
        ChangeNotifierProvider<GlobalsProvider>(
          create: (_) => GlobalsProvider(
            notesProvider: _.read<NotesProvider>(),
            financeProvider: _.read<FinanceProvider>(),
            vaultProvider: _.read<VaultProvider>(),
          ),
        ),
        ChangeNotifierProvider<VaultLockProvider>(
          create: (_) => VaultLockProvider()..refreshStatus(),
        ),
        ChangeNotifierProvider<ThemeProvider>(
          create: (_) => ThemeProvider()..load(),
        ),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeModel, child) {
          return MaterialApp(
            title: 'Mylife',
            debugShowCheckedModeBanner: false,
            themeMode: themeModel.mode,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
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
          );
        },
      ),
    );
  }
}
