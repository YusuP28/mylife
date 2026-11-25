import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/finance_transaction.dart';
import '../../providers/finance_provider.dart';
import 'finance_editor_screen.dart';

class FinanceScreen extends StatefulWidget {
  const FinanceScreen({super.key});

  @override
  State<FinanceScreen> createState() => _FinanceScreenState();
}

class _FinanceScreenState extends State<FinanceScreen> {
  late final TextEditingController _searchController;
  bool _showGrid = false;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    // Auto-load transaksi saat masuk ke layar
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        context.read<FinanceProvider>().loadTransactions();
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _resetFilters() {
    _searchController.clear();
    context.read<FinanceProvider>().resetFilters();
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<FinanceProvider>();
    final currency = NumberFormat.currency(
      locale: 'id_ID',
      symbol: 'Rp',
      decimalDigits: 0,
    );
    final filtered = provider.hasActiveFilter;
    final visible = provider.visibleSummary;
    final totalIncome = filtered ? visible.income : provider.totalIncome;
    final totalExpense = filtered ? visible.expense : provider.totalExpense;
    final balance = filtered
        ? (totalIncome - totalExpense).toDouble()
        : provider.balance;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Keuangan'),
        actions: <Widget>[
          IconButton(
            icon: Icon(_showGrid ? Icons.view_list : Icons.grid_view),
            tooltip: _showGrid ? 'Tampilan daftar' : 'Tampilan grid',
            onPressed: () => setState(() => _showGrid = !_showGrid),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _openEditor(),
        tooltip: 'Tambah transaksi',
        child: const Icon(Icons.add),
      ),
      body: Column(
        children: <Widget>[
          _SummaryCard(
            balance: balance,
            totalIncome: totalIncome,
            totalExpense: totalExpense,
            currency: currency,
            filtered: filtered,
            visibleCount: visible.count,
            totalCount: provider.transactions.length,
          ),
          if (provider.error != null)
            _ErrorState(
              error: provider.error!,
              onRetry: () => provider.loadTransactions(),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: TextField(
              controller: _searchController,
              onChanged: provider.setQuery,
              decoration: InputDecoration(
                hintText: 'Cari transaksi...',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _searchController.text.isEmpty
                    ? null
                    : IconButton(
                        icon: const Icon(Icons.close),
                        tooltip: 'Hapus pencarian',
                        onPressed: () {
                          _searchController.clear();
                          provider.setQuery('');
                        },
                      ),
                border: const OutlineInputBorder(),
                isDense: true,
              ),
            ),
          ),
          _FilterBar(
            typeFilter: provider.typeFilter,
            monthFilter: provider.monthFilter,
            categoryFilter: provider.categoryFilter,
            months: provider.months,
            categories: provider.categories,
            hasActiveFilter: provider.hasActiveFilter,
            onTypeChanged: provider.setTypeFilter,
            onMonthChanged: provider.setMonthFilter,
            onCategoryChanged: provider.setCategoryFilter,
            onReset: _resetFilters,
          ),
          Expanded(
            child: provider.loading
                ? const Center(child: CircularProgressIndicator())
                : provider.transactions.isEmpty
                ? _EmptyState(onAdd: () => _openEditor())
                : provider.visibleTransactions.isEmpty
                ? _NoResultsState(onReset: _resetFilters)
                : _showGrid
                ? _buildGridListView(provider.visibleTransactions, currency)
                : _TransactionList(
                    transactions: provider.visibleTransactions,
                    currency: currency,
                    onEdit: _openEditor,
                    onDelete: _confirmDelete,
                  ),
          ),
        ],
      ),
    );
  }

  Future<void> _openEditor([FinanceTransaction? transaction]) async {
    await Navigator.of(context).push<void>(
      MaterialPageRoute<void>(
        builder: (_) => FinanceEditorScreen(transaction: transaction),
      ),
    );
  }

  Future<void> _confirmDelete(FinanceTransaction tx) async {
    final id = tx.id;
    if (id == null) return;

    final provider = context.read<FinanceProvider>();
    final messenger = ScaffoldMessenger.of(context);

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Hapus transaksi'),
        content: Text(
          'Hapus transaksi '
          '"${tx.category.isEmpty ? 'Tanpa kategori' : tx.category}"?',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      await provider.deleteTransaction(id);
    } catch (e) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menghapus transaksi: $e')),
      );
    }
  }
}

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.balance,
    required this.totalIncome,
    required this.totalExpense,
    required this.currency,
    required this.filtered,
    required this.visibleCount,
    required this.totalCount,
  });

  final double balance;
  final int totalIncome;
  final int totalExpense;
  final NumberFormat currency;

  /// `true` bila angka mengikuti filter, bukan seluruh transaksi.
  final bool filtered;
  final int visibleCount;
  final int totalCount;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final incomeColor = Theme.of(context).colorScheme.primary;
    final expenseColor = Theme.of(context).colorScheme.error;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            theme.colorScheme.primary.withOpacity(0.1),
            theme.colorScheme.primary.withOpacity(0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      margin: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Text(
                filtered ? 'Ringkasan filter' : 'Ringkasan',
                style: theme.textTheme.titleMedium,
              ),
              const Spacer(),
              if (filtered)
                Text(
                  '$visibleCount dari $totalCount transaksi',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              _SummaryItem(
                label: filtered ? 'Selisih' : 'Saldo',
                value: currency.format(balance),
                color: balance >= 0 ? Colors.green[700] : Colors.red[700],
              ),
              _SummaryItem(
                label: 'Pemasukan',
                value: currency.format(totalIncome),
                color: incomeColor,
              ),
              _SummaryItem(
                label: 'Pengeluaran',
                value: '(- ' + currency.format(totalExpense) + ')',
                color: expenseColor,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _SummaryItem extends StatelessWidget {
  const _SummaryItem({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Text(
          label,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: Theme.of(context).colorScheme.onSurfaceVariant),
        ),
        const SizedBox(height: 4),
        Text(
          value,
          style: TextStyle(color: color, fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.typeFilter,
    required this.monthFilter,
    required this.categoryFilter,
    required this.months,
    required this.categories,
    required this.hasActiveFilter,
    required this.onTypeChanged,
    required this.onMonthChanged,
    required this.onCategoryChanged,
    required this.onReset,
  });

  final FinanceTransactionType? typeFilter;
  final DateTime? monthFilter;
  final String? categoryFilter;
  final List<DateTime> months;
  final List<String> categories;
  final bool hasActiveFilter;
  final ValueChanged<FinanceTransactionType?> onTypeChanged;
  final ValueChanged<DateTime?> onMonthChanged;
  final ValueChanged<String?> onCategoryChanged;
  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final monthLabel = monthFilter == null
        ? 'Semua bulan'
        : DateFormat('MMMM yyyy', 'id_ID').format(monthFilter!);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: Row(
        children: <Widget>[
            _FilterMenu(
              label: typeFilter == null
                  ? 'Semua tipe'
                  : typeFilter == FinanceTransactionType.income
                  ? 'Pemasukan'
                  : 'Pengeluaran',
              active: typeFilter != null,
              entries: const <PopupMenuEntry<String>>[
                PopupMenuItem<String>(value: '', child: Text('Semua tipe')),
                PopupMenuItem<String>(
                  value: 'income',
                  child: Text('Pemasukan'),
                ),
                PopupMenuItem<String>(
                  value: 'expense',
                  child: Text('Pengeluaran'),
                ),
              ],
              onSelected: (value) {
                if (value == 'income') {
                  onTypeChanged(FinanceTransactionType.income);
                } else if (value == 'expense') {
                  onTypeChanged(FinanceTransactionType.expense);
                } else {
                  onTypeChanged(null);
                }
              },
            ),
            const SizedBox(width: 8),
            _FilterMenu(
              label: monthLabel,
              active: monthFilter != null,
              entries: <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: '',
                  child: Text('Semua bulan'),
                ),
                for (final month in months)
                  PopupMenuItem<String>(
                    value: '${month.year}-${month.month}',
                    child: Text(DateFormat('MMMM yyyy', 'id_ID').format(month)),
                  ),
              ],
              onSelected: (value) {
                final parts = value.split('-');
                if (parts.length != 2) {
                  onMonthChanged(null);
                  return;
                }
                onMonthChanged(
                  DateTime(int.parse(parts[0]), int.parse(parts[1])),
                );
              },
            ),
            const SizedBox(width: 8),
            _FilterMenu(
              label: categoryFilter ?? 'Semua kategori',
              active: categoryFilter != null,
              entries: <PopupMenuEntry<String>>[
                const PopupMenuItem<String>(
                  value: '',
                  child: Text('Semua kategori'),
                ),
                for (final category in categories)
                  PopupMenuItem<String>(value: category, child: Text(category)),
              ],
              onSelected: onCategoryChanged,
            ),
            if (hasActiveFilter) ...<Widget>[
              const SizedBox(width: 8),
              TextButton.icon(
                onPressed: onReset,
                icon: const Icon(Icons.filter_alt_off, size: 18),
                label: const Text('Reset'),
              ),
            ],
          ],
        ),
      );
  }
}

class _FilterMenu extends StatelessWidget {
  const _FilterMenu({
    required this.label,
    required this.active,
    required this.entries,
    required this.onSelected,
  });

  final String label;
  final bool active;
  final List<PopupMenuEntry<String>> entries;
  final ValueChanged<String> onSelected;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final foreground = active
        ? theme.colorScheme.onPrimaryContainer
        : theme.colorScheme.onSurfaceVariant;

    return PopupMenuButton<String>(
      onSelected: onSelected,
      itemBuilder: (_) => entries,
      tooltip: label,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: active
              ? theme.colorScheme.primaryContainer
              : theme.colorScheme.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: active
                ? theme.colorScheme.primary
                : theme.colorScheme.outlineVariant,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Text(
              label,
              style: theme.textTheme.labelLarge?.copyWith(color: foreground),
            ),
            Icon(Icons.arrow_drop_down, size: 18, color: foreground),
          ],
        ),
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState({required this.onReset});

  final VoidCallback onReset;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.search_off,
            size: 56,
            color: theme.colorScheme.onSurfaceVariant,
          ),
          const SizedBox(height: 12),
          Text(
            'Tidak ada transaksi yang cocok',
            style: theme.textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          Text(
            'Coba kata kunci lain atau reset filter.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onReset,
            icon: const Icon(Icons.filter_alt_off),
            label: const Text('Reset filter'),
          ),
        ],
      ),
    );
  }
}

class _TransactionList extends StatelessWidget {
  const _TransactionList({
    required this.transactions,
    required this.currency,
    required this.onEdit,
    required this.onDelete,
  });

  final List<FinanceTransaction> transactions;
  final NumberFormat currency;
  final ValueChanged<FinanceTransaction> onEdit;
  final ValueChanged<FinanceTransaction> onDelete;

  @override
  Widget build(BuildContext context) {
    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
      itemCount: transactions.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        final tx = transactions[index];
        return _TransactionTile(
          tx: tx,
          currency: currency,
          onTap: () => onEdit(tx),
          onDelete: () => onDelete(tx),
        );
      },
    );
  }
}

/// Grid view 3 kolom untuk transaksi keuangan.
Widget _buildGridListView(
  List<FinanceTransaction> transactions,
  NumberFormat currency,
) {
  return GridView.builder(
    padding: const EdgeInsets.all(12),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      mainAxisSpacing: 8,
      crossAxisSpacing: 8,
    ),
    itemCount: transactions.length,
    itemBuilder: (context, index) {
      final tx = transactions[index];
      return _GridTransactionTile(tx: tx, currency: currency);
    },
  );
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.tx,
    required this.currency,
    required this.onTap,
    required this.onDelete,
  });

  final FinanceTransaction tx;
  final NumberFormat currency;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = tx.isIncome;
    final amountColor = isIncome ? Colors.green[700] : Colors.red[700];

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(
                    isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                    size: 18,
                    color: amountColor,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      tx.category.isEmpty ? 'Tanpa kategori' : tx.category,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  Text(
                    (isIncome ? '+ ' : '- ') + currency.format(tx.amount),
                    style: TextStyle(
                      color: amountColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  IconButton(
                    onPressed: onDelete,
                    tooltip: 'Hapus transaksi',
                    icon: Icon(
                      Icons.delete_outline,
                      color: theme.colorScheme.error,
                    ),
                  ),
                ],
              ),
              if (tx.note.isNotEmpty) ...<Widget>[
                const SizedBox(height: 6),
                Text(
                  tx.note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: 6),
              Text(
                DateFormat.yMMMd('id_ID').add_jm().format(tx.occurredAt),
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error, required this.onRetry});

  final String error;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      width: double.infinity,
      color: theme.colorScheme.errorContainer,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: <Widget>[
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 20),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              error,
              style: TextStyle(color: theme.colorScheme.onErrorContainer),
            ),
          ),
          TextButton(onPressed: onRetry, child: const Text('Refresh')),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Icon(
            Icons.account_balance_wallet_outlined,
            size: 64,
            color: theme.colorScheme.primary,
          ),
          const SizedBox(height: 16),
          Text('Belum ada transaksi', style: theme.textTheme.titleMedium),
          const SizedBox(height: 8),
          Text(
            'Tekan tombol + untuk menambah transaksi keuangan.',
            textAlign: TextAlign.center,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: theme.colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 16),
          FilledButton.icon(
            onPressed: onAdd,
            icon: const Icon(Icons.add),
            label: const Text('Tambah transaksi'),
          ),
        ],
      ),
    );
  }
}

/// Grid tile untuk transaksi keuangan (3 kolom).
class _GridTransactionTile extends StatelessWidget {
  const _GridTransactionTile({required this.tx, required this.currency});

  final FinanceTransaction tx;
  final NumberFormat currency;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isIncome = tx.isIncome;
    final amountColor = isIncome ? Colors.green[700] : Colors.red[700];

    return Material(
      color: theme.colorScheme.surface,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () {},
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(
                isIncome ? Icons.arrow_downward : Icons.arrow_upward,
                size: 20,
                color: amountColor,
              ),
              const SizedBox(height: 4),
              Text(
                tx.category.isEmpty ? 'Tanpa kategori' : tx.category,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                (isIncome ? '+ ' : '- ') + currency.format(tx.amount),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: amountColor,
                  fontWeight: FontWeight.w600,
                  fontSize: 12,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
