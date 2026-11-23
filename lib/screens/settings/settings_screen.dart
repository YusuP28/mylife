import 'package:flutter/material.dart';

import '../../widgets/module_placeholder.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      icon: Icons.settings_outlined,
      title: 'Pengaturan',
      description: 'Atur tema, backup, dan preferensi aplikasi.',
      accent: Color(0xFF6B7280),
    );
  }
}