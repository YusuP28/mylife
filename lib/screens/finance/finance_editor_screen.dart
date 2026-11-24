import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../models/finance_transaction.dart';
import '../../providers/finance_provider.dart';

class FinanceEditorScreen extends StatefulWidget {
  const FinanceEditorScreen({super.key, this.transaction});

  /// null = tambah transaksi baru, non-null = edit transaksi.
  final FinanceTransaction? transaction;

  @override
  State<FinanceEditorScreen> createState() => _FinanceEditorScreenState();
}

class _FinanceEditorScreenState extends State<FinanceEditorScreen> {
  late final TextEditingController _amountController;
  late final TextEditingController _categoryController;
  late final TextEditingController _noteController;
  late FinanceTransactionType _type;
  late DateTime _occurredAt;
  bool _saving = false;

  bool get _isEditing => widget.transaction != null;

  @override
  void initState() {
    super.initState();
    final tx = widget.transaction;
    _type = tx?.type ?? FinanceTransactionType.expense;
    _occurredAt = tx?.occurredAt ?? DateTime.now();
    _amountController = TextEditingController(
      text: tx == null ? '' : tx.amount.toString(),
    );
    _categoryController = TextEditingController(text: tx?.category ?? '');
    _noteController = TextEditingController(text: tx?.note ?? '');
  }

  @override
  void dispose() {
    _amountController.dispose();
    _categoryController.dispose();
    _noteController.dispose();
    super.dispose();
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _occurredAt,
      firstDate: DateTime(2000),
      lastDate: DateTime(2100),
    );
    if (picked != null) {
      setState(() => _occurredAt = picked);
    }
  }

  Future<void> _save() async {
    final amount = int.tryParse(_amountController.text.trim()) ?? 0;
    final messenger = ScaffoldMessenger.of(context);

    if (amount <= 0) {
      messenger.showSnackBar(
        const SnackBar(content: Text('Nominal harus lebih dari 0')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      final provider = context.read<FinanceProvider>();
      final category = _categoryController.text.trim();
      final note = _noteController.text.trim();
      final existing = widget.transaction;

      if (existing == null) {
        await provider.addTransaction(
          type: _type,
          amount: amount,
          category: category,
          note: note,
          occurredAt: _occurredAt,
        );
      } else {
        await provider.updateTransaction(
          FinanceTransaction(
            id: existing.id,
            type: _type,
            amount: amount,
            category: category,
            note: note,
            occurredAt: _occurredAt,
            createdAt: existing.createdAt,
            updatedAt: DateTime.now(),
          ),
        );
      }

      if (!mounted) return;
      Navigator.of(context).pop();
    } catch (e) {
      if (!mounted) return;
      setState(() => _saving = false);
      messenger.showSnackBar(
        SnackBar(content: Text('Gagal menyimpan transaksi: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit transaksi' : 'Transaksi baru'),
        actions: <Widget>[
          IconButton(
            onPressed: _saving ? null : _save,
            tooltip: 'Simpan',
            icon: _saving
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.check),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: <Widget>[
            SegmentedButton<FinanceTransactionType>(
              segments: const <ButtonSegment<FinanceTransactionType>>[
                ButtonSegment<FinanceTransactionType>(
                  value: FinanceTransactionType.income,
                  label: Text('Pemasukan'),
                  icon: Icon(Icons.arrow_downward),
                ),
                ButtonSegment<FinanceTransactionType>(
                  value: FinanceTransactionType.expense,
                  label: Text('Pengeluaran'),
                  icon: Icon(Icons.arrow_upward),
                ),
              ],
              selected: <FinanceTransactionType>{_type},
              onSelectionChanged: (selection) {
                setState(() => _type = selection.first);
              },
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _amountController,
              keyboardType: TextInputType.number,
              inputFormatters: <TextInputFormatter>[
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: const InputDecoration(
                labelText: 'Nominal (Rp)',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _categoryController,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Kategori',
                hintText: 'Contoh: Makan, Transport, Gaji',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _noteController,
              minLines: 2,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Catatan (opsional)',
                alignLabelWithHint: true,
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            InkWell(
              onTap: _pickDate,
              borderRadius: BorderRadius.circular(4),
              child: InputDecorator(
                decoration: const InputDecoration(
                  labelText: 'Tanggal',
                  border: OutlineInputBorder(),
                  suffixIcon: Icon(Icons.calendar_today_outlined),
                ),
                child: Text(
                  DateFormat.yMMMd('id_ID').format(_occurredAt),
                  style: theme.textTheme.bodyLarge,
                ),
              ),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: _saving ? null : _save,
              icon: const Icon(Icons.save_outlined),
              label: Text(_saving ? 'Menyimpan...' : 'Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}
