import 'package:flutter/material.dart';

import '../../widgets/module_placeholder.dart';

class NotesScreen extends StatelessWidget {
  const NotesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      icon: Icons.sticky_note_2_outlined,
      title: 'Catatan',
      description: 'Tulis, kelompokkan, dan cari catatan pentingmu di satu tempat.',
      accent: Color(0xFF2E7D6B),
    );
  }
}