import 'package:flutter/material.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'providers/notes_provider.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('id_ID');
  runApp(const MylifeApp());
}

class MylifeApp extends StatelessWidget {
  const MylifeApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider<NotesProvider>(
      create: (_) => NotesProvider()..loadNotes(),
      child: MaterialApp(
        title: 'Mylife',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light,
        home: const HomeShell(),
      ),
    );
  }
}
