import 'package:flutter/material.dart';

import '../../widgets/module_placeholder.dart';

class VaultScreen extends StatelessWidget {
  const VaultScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      icon: Icons.lock_outline,
      title: 'Vault',
      description: 'Simpan berkas dan data sensitif dengan aman.',
      accent: Color(0xFF8B5CF6),
    );
  }
}