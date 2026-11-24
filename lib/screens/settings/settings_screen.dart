import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/note.dart';
import '../../models/vault_item.dart';
import '../../providers/finance_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/vault_provider.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final vaultProvider = context.watch<VaultProvider>();
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Pengaturan')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: <Widget>[
          _SummaryCard(
            title: 'Catatan',
            count: notesProvider.notes.length,
            color: Colors.blue,
            icon: Icons.sticky_note_2_outlined,
          ),
          _SummaryCard(
            title: 'Keuangan',
            subtitle: 'Pemasukan: ${NumberFormat.currency(locale: 'id_ID', symbol: 'Rp', decimalDigits: 0).format(financeProvider.totalIncome)}',
            count: financeProvider.transactions.length,
            color: Colors.green,
            icon: Icons.account_balance_wallet_outlined,
          ),
          _SummaryCard(
            title: 'Vault',
            count: vaultProvider.count,
            color: Colors.purple,
            icon: Icons.vpn_key_outlined,
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Mylife'),
            subtitle: const Text('v1.0.0 — Notes, Finance, Vault, Settings'),
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(),
          _DataManagementSection(
            notesCount: notesProvider.notes.length,
            financeCount: financeProvider.transactions.length,
            vaultCount: vaultProvider.count,
            onResetNotes: () => _showResetDialog(
              context: context,
              title: 'Reset Catatan',
              description: 'Hapus SEMUA catatan (${notesProvider.notes.length} buah) dari perangkat. Tindakan tidak bisa dibatalkan.',
              onConfirm: () => _resetNotes(context),
            ),
            onResetFinance: () => _showResetDialog(
              context: context,
              title: 'Reset Keuangan',
              description:
                  'Hapus SEMUA transaksi (${financeProvider.transactions.length} buah) dari perangkat. Saldo akan kembali ke nol. Tindakan tidak bisa dibatalkan.',
              onConfirm: () => _resetFinance(context),
            ),
            onResetVault: () => _showResetDialog(
              context: context,
              title: 'Reset Vault',
              description:
                  'Hapus SEMUA item brankas (${vaultProvider.count} buah) dari perangkat. Password Anda hilang selamanya. Tindakan tidak bisa dibatalkan.',
              onConfirm: () => _resetVault(context),
            ),
          ),
          const Divider(),
          _SecurityWarningCard(
            items: [
              'Data sensitif (password, kredensial) disimpan sebagai teks biasa di SQLite lokal.',
              'Enkripsi penuh belum tersedia. Jangan simpan data penting sebelum Tahap 4.',
              'Backup eksternal harus mengakses file database yang sama.',
            ],
          ),
        ],
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Tentang Mylife'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Text('Mylife v1.0.0', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            const Text('Aplikasi pencatatan keuangan dan brankas.'),
            const SizedBox(height: 8),
            const Text('Fitur utama:'),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: const <Widget>[
                Text('• Catatan — dengan penanda format ringan'),
                Text('• Keuangan — transaksi, saldo, laporan'),
                Text('• Vault — penyimpanan kredensial (plaintext)'),
                Text('• Pengaturan — status data & info aplikasi'),
              ],
            ),
          ],
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Tutup'),
          ),
        ],
      ),
    );
  }

  Future<void> _showResetDialog({
    required BuildContext context,
    required String title,
    required String description,
    required VoidCallback onConfirm,
  }) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(title),
        content: Text(description),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Reset'),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      onConfirm();
    }
  }

  Future<void> _resetNotes(BuildContext context) async {
    await context.read<NotesProvider>().clearAllNotes();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua catatan telah dihapus')),
    );
  }

  Future<void> _resetFinance(BuildContext context) async {
    await context.read<FinanceProvider>().clearAllTransactions();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua transaksi telah dihapus')),
    );
  }

  Future<void> _resetVault(BuildContext context) async {
    await context.read<VaultProvider>().clearAllItems();
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Semua item brankas telah dihapus')),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.title,
    this.subtitle,
    required this.count,
    required this.color,
    required this.icon,
  });

  final String title;
  final String? subtitle;
  final int count;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title,
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
        subtitle: subtitle != null ? Text(subtitle!) : null,
        trailing: Chip(
          label: Text('$count item'),
          backgroundColor: color.withOpacity(0.1),
        ),
      ),
    );
  }
}

class _DataManagementSection extends StatelessWidget {
  const _DataManagementSection({
    required this.notesCount,
    required this.financeCount,
    required this.vaultCount,
    required this.onResetNotes,
    required this.onResetFinance,
    required this.onResetVault,
  });

  final int notesCount;
  final int financeCount;
  final int vaultCount;
  final VoidCallback onResetNotes;
  final VoidCallback onResetFinance;
  final VoidCallback onResetVault;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Manajemen Data',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        _ResetButton(
          icon: Icons.description,
          label: 'Catatan',
          count: notesCount,
          color: Colors.blue,
          onPressed: onResetNotes,
        ),
        const SizedBox(height: 8),
        _ResetButton(
          icon: Icons.account_balance_wallet,
          label: 'Keuangan',
          count: financeCount,
          color: Colors.green,
          onPressed: onResetFinance,
        ),
        const SizedBox(height: 8),
        _ResetButton(
          icon: Icons.vpn_key,
          label: 'Vault',
          count: vaultCount,
          color: Colors.purple,
          onPressed: onResetVault,
        ),
      ],
    );
  }
}

class _ResetButton extends StatelessWidget {
  const _ResetButton({
    required this.icon,
    required this.label,
    required this.count,
    required this.color,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final int count;
  final Color color;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return OutlinedButton.icon(
      onPressed: onPressed,
      icon: Icon(icon, color: color),
      label: Text('$label ($count)'),
    );
  }
}

class _SecurityWarningCard extends StatelessWidget {
  const _SecurityWarningCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      color: Colors.amber.shade50,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber.shade300),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.warning_amber_outlined,
                    color: Colors.amber.shade700, size: 20),
                const SizedBox(width: 8),
                Text('Peringatan Keamanan',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: Colors.amber.shade800, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < items.length; i++) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_outline,
                      color: Colors.amber.shade700, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items[i],
                      style:
                          TextStyle(color: Colors.amber.shade800, height: 1.4),
                    ),
                  ),
                ],
              ),
              if (i < items.length - 1) const SizedBox(height: 8),
            ]
          ],
        ),
      ),
    );
  }
}