import 'package:flutter/material.dart';

import '../../widgets/module_placeholder.dart';

class FinanceScreen extends StatelessWidget {
  const FinanceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const ModulePlaceholder(
      icon: Icons.account_balance_wallet_outlined,
      title: 'Keuangan',
      description: 'Catat pemasukan, pengeluaran, dan pantau ringkasan saldo.',
      accent: Color(0xFF1F6FEB),
    );
  }
}