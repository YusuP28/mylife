import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path_provider/path_provider.dart';
import 'package:provider/provider.dart';

import '../../providers/finance_provider.dart';
import '../../providers/notes_provider.dart';
import '../../providers/theme_provider.dart';
import '../../providers/vault_provider.dart';
import '../../services/backup_service.dart';
import '../../services/database_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final notesProvider = context.watch<NotesProvider>();
    final financeProvider = context.watch<FinanceProvider>();
    final vaultProvider = context.watch<VaultProvider>();
    final themeProvider = context.watch<ThemeProvider>();
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
          _ThemeSelector(current: themeProvider.mode, onSelect: themeProvider.select),
          const Divider(),
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Tentang Mylife'),
            subtitle: const Text('v1.0.0 — Notes, Finance, Vault, Settings'),
            onTap: () => _showAboutDialog(context),
          ),
          const Divider(),
          _SecurityWarningCard(
            items: [
              'Isi brankas dienkripsi AES-256-GCM. Kunci diturunkan dari password dengan PBKDF2-HMAC-SHA256 (210.000 iterasi).',
              'Password tidak disimpan di perangkat dan tidak ada mekanisme pemulihan. Lupa password berarti item brankas tidak bisa dibuka selamanya.',
              'Buka cepat (keychain/keystore) hanya mengikat sesi ke perangkat. Kunci ini tidak menyimpan password dan tidak bisa menggantikan password yang lupa.',
              'Saat brankas terbuka, isinya ada sebagai teks biasa di memori. Vault otomatis terkunci ketika aplikasi masuk background.',
              'File vault_key.json hanya berisi salt dan verifier (bukan password). Jangan menghapusnya selama data brankas masih dibutuhkan.',
            ],
          ),
          // Bagian Baru: Backup & Restore
          const SizedBox(height: 24),
          const _BackupSection(),
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
                Text('• Vault — kredensial terenkripsi (AES-256-GCM)'),
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

class _SecurityWarningCard extends StatelessWidget {
  const _SecurityWarningCard({required this.items});

  final List<String> items;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    // Tingkatkan kontras: tema terang pakai teks gelap, tema gelap pakai teks terang
    final isDark = theme.brightness == Brightness.dark;
    final warningColor = isDark ? Colors.amber.shade100 : Colors.amber.shade900;
    final bgColor = isDark ? Colors.amber.shade900.withOpacity(0.25) : Colors.amber.shade50;
    final borderColor = isDark ? Colors.amber.shade600 : Colors.amber.shade400;

    return Container(
      color: bgColor,
      decoration: BoxDecoration(
        border: Border.all(color: borderColor, width: 1.5),
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
                    color: warningColor, size: 20),
                const SizedBox(width: 8),
                Text('Peringatan Keamanan',
                    style: theme.textTheme.titleSmall?.copyWith(
                        color: warningColor, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 12),
            for (var i = 0; i < items.length; i++) ...<Widget>[
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  const SizedBox(width: 4),
                  Icon(Icons.check_circle_outline,
                      color: warningColor, size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      items[i],
                      style: TextStyle(
                        color: warningColor,
                        height: 1.5,
                        fontSize: 13,
                      ),
                    ),
                  ),
                ],
              ),
              if (i < items.length - 1) const SizedBox(height: 10),
            ]
          ],
        ),
      ),
    );
  }
}

class _ThemeSelector extends StatelessWidget {
  const _ThemeSelector({required this.current, required this.onSelect});

  final ThemeMode current;
  final void Function(ThemeChoice) onSelect;

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<ThemeProvider>();
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text('Tema',
            style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600)),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: provider.choices.map((choice) {
            final selected = choice.toMode == current;
            return FilterChip(
              selected: selected,
              onSelected: (_) => onSelect(choice),
              label: Text(choice.label),
              selectedColor: theme.colorScheme.primaryContainer,
              checkmarkColor: theme.colorScheme.onPrimaryContainer,
            );
          }).toList(),
        ),
      ],
    );
  }
}

/// Widget untuk backup dan restore data secara offline.
class _BackupSection extends StatefulWidget {
  const _BackupSection();

  @override
  State<_BackupSection> createState() => _BackupSectionState();
}

class _BackupSectionState extends State<_BackupSection> {
  bool _isBusy = false;
  String? _status;

  Future<void> _doBackup() async {
    setState(() {
      _isBusy = true;
      _status = null;
    });

    try {
      final db = DatabaseService.instance;
      final backup = BackupService(await db.database);
      final path = await backup.backup();
      if (!mounted) return;
      setState(() => _status = 'Backup berhasil: $path');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Backup berhasil disimpan ke:\n$path')),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal membuat backup: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<void> _doRestore() async {
    setState(() {
      _isBusy = true;
      _status = null;
    });

    try {
      final file = await pickRestoreFile();
      if (file == null) {
        setState(() => _status = 'Batalkan oleh pengguna');
        return;
      }

      final db = DatabaseService.instance;
      final backup = BackupService(await db.database);
      await backup.restore(file.path);

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Restore berhasil! Silakan buka kembali aplikasi.')),
      );

      // Reset data di semua provider
      if (mounted) {
        // Handle provider reset if needed
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _status = 'Gagal: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Gagal melakukan restore: $e')),
      );
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  Future<File?> pickRestoreFile() async {
    // Karena kita tidak bisa gunakan intent picker tanpa permission tambahan,
    // kita langsung gunakan file backup yang sudah ada di aplikasi.
    final backup = BackupService(await DatabaseService.instance.database);
    final hasBackup = await backup.hasBackup();
    if (!hasBackup) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Tidak ada file backup yang ditemukan')),
      );
      return null;
    }
    final file = await backup._getBackupFile();
    return file.exists() ? file : null;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      elevation: 2,
      child: Container(
        decoration: BoxDecoration(
          border: Border.all(color: theme.colorScheme.outlineVariant),
          borderRadius: BorderRadius.circular(12),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Backup & Restore',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Salin data secara offline ke file JSON. '
              'Backup disimpan di folder dokumen aplikasi.',
              style: theme.textTheme.bodySmall?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _isBusy ? null : _doBackup,
                    icon: const Icon(Icons.backup),
                    label: _isBusy
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Colors.white,
                            ),
                          )
                        : const Text('Backup'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _isBusy ? null : _doRestore,
                    icon: const Icon(Icons.restore),
                    label: const Text('Restore'),
                  ),
                ),
              ],
            ),
            if (_status != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                _status!,
                style: TextStyle(
                  color: _status!.startsWith('Gagal')
                      ? theme.colorScheme.error
                      : theme.colorScheme.onSurface,
                  fontSize: 12,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
