import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'providers/notes_provider.dart';
import 'screens/home_shell.dart';
import 'theme/app_theme.dart';

void main() {
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
