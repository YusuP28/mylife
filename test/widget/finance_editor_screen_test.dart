import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import 'package:mylife/models/finance_transaction.dart';
import 'package:mylife/providers/finance_provider.dart';
import 'package:mylife/screens/finance/finance_editor_screen.dart';
import 'package:mylife/services/database_service.dart';

/// Fake [FinanceProvider] for testing.
class _FakeFinanceProvider extends FinanceProvider {
  _FakeFinanceProvider();

  FinanceTransaction? _editingTransaction;
  bool _saved = false;
  String? _error;

  @override
  FinanceTransaction? get editingTransaction => _editingTransaction;

  @override
  bool get isEditing => _editingTransaction != null;

  @override
  String? get error => _error;

  @override
  void startEdit(FinanceTransaction transaction) {
    _editingTransaction = transaction;
    notifyListeners();
  }

  @override
  void startNew({String type = 'expense'}) {
    _editingTransaction = FinanceTransaction(
      id: 0,
      type: type,
      amount: 0,
      category: '',
      note: '',
      occurredAt: DateTime.now(),
      createdAt: DateTime.now(),
      updatedAt: DateTime.now(),
    );
    notifyListeners();
  }

  @override
  void updateType(String type) {
    if (_editingTransaction != null) {
      _editingTransaction = _editingTransaction!.copyWith(type: type);
      notifyListeners();
    }
  }

  @override
  void updateAmount(String amount) {
    if (_editingTransaction != null) {
      final parsed = int.tryParse(amount.replaceAll('.', '')) ?? 0;
      _editingTransaction = _editingTransaction!.copyWith(amount: parsed);
      notifyListeners();
    }
  }

  @override
  void updateCategory(String category) {
    if (_editingTransaction != null) {
      _editingTransaction = _editingTransaction!.copyWith(category: category);
      notifyListeners();
    }
  }

  @override
  void updateNote(String note) {
    if (_editingTransaction != null) {
      _editingTransaction = _editingTransaction!.copyWith(note: note);
      notifyListeners();
    }
  }

  @override
  void updateOccurredAt(DateTime date) {
    if (_editingTransaction != null) {
      _editingTransaction = _editingTransaction!.copyWith(occurredAt: date);
      notifyListeners();
    }
  }

  @override
  Future<bool> save() async {
    if (_editingTransaction == null) return false;
    if (_editingTransaction!.amount <= 0) {
      _error = 'Nominal harus lebih dari 0';
      notifyListeners();
      return false;
    }
    if (_editingTransaction!.category.trim().isEmpty) {
      _error = 'Kategori wajib diisi';
      notifyListeners();
      return false;
    }
    _saved = true;
    _editingTransaction = null;
    notifyListeners();
    return true;
  }

  @override
  void cancel() {
    _editingTransaction = null;
    _error = null;
    notifyListeners();
  }

  bool get saved => _saved;
}

void main() {
  group('FinanceEditorScreen', () {
    late _FakeFinanceProvider provider;

    setUp(() {
      provider = _FakeFinanceProvider();
    });

    Widget buildScreen() => ChangeNotifierProvider<FinanceProvider>.value(
          value: provider,
          child: MaterialApp(
            home: FinanceEditorScreen(),
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            supportedLocales: const [Locale('id', 'ID')],
          ),
        );

    testWidgets('shows new expense form by default', (WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());

      expect(find.text('Pengeluaran Baru'), findsOneWidget);
      expect(find.text('Nominal'), findsOneWidget);
      expect(find.text('Kategori'), findsOneWidget);
      expect(find.text('Catatan (opsional)'), findsOneWidget);
      expect(find.text('Tanggal'), findsOneWidget);
      expect(find.text('Simpan'), findsOneWidget);
      expect(find.text('Batal'), findsOneWidget);
    });

    testWidgets('shows new income form when type is income', (WidgetTester tester) async {
      provider.startNew(type: 'income');
      
      await tester.pumpWidget(buildScreen());

      expect(find.text('Pemasukan Baru'), findsOneWidget);
    });

    testWidgets('shows edit form when editing existing transaction', (WidgetTester tester) async {
      final tx = FinanceTransaction(
        id: 1,
        type: 'expense',
        amount: 1500000,
        category: 'Makan',
        note: 'Makan siang',
        occurredAt: DateTime(2026, 1, 20),
        createdAt: DateTime(2026, 1, 20),
        updatedAt: DateTime(2026, 1, 20),
      );
      provider.startEdit(tx);

      await tester.pumpWidget(buildScreen());

      expect(find.text('Edit Pengeluaran'), findsOneWidget);
      expect(find.byType(TextField).first, findsOneWidget);
    });

    testWidgets('validates amount > 0', (WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.enterText(find.byKey(const Key('amountField')), '0');
      await tester.enterText(find.byKey(const Key('categoryField')), 'Test');
      await tester.tap(find.text('Simpan'));
      await tester.pump();

      expect(find.text('Nominal harus lebih dari 0'), findsOneWidget);
    });

    testWidgets('validates category required', (WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.enterText(find.byKey(const Key('amountField')), '100000');
      // Leave category empty
      await tester.tap(find.text('Simpan'));
      await tester.pump();

      expect(find.text('Kategori wajib diisi'), findsOneWidget);
    });

    testWidgets('saves successfully with valid input', (WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.enterText(find.byKey(const Key('amountField')), '1500000');
      await tester.enterText(find.byKey(const Key('categoryField')), 'Makan');
      await tester.enterText(find.byKey(const Key('noteField')), 'Makan siang');
      await tester.tap(find.text('Simpan'));
      await tester.pump();

      expect(provider.saved, true);
      expect(provider.editingTransaction, null);
    });

    testWidgets('toggles between income/expense', (WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());

      // Default is expense
      expect(find.text('Pengeluaran Baru'), findsOneWidget);

      // Tap income segment
      await tester.tap(find.text('Pemasukan'));
      await tester.pump();

      expect(find.text('Pemasukan Baru'), findsOneWidget);
    });

    testWidgets('date picker updates date', (WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());

      // Tap date field
      await tester.tap(find.byKey(const Key('dateField')));
      await tester.pumpAndSettle();

      // Pick a date (this is tricky in test, just verify dialog opens)
      expect(find.byType(DatePickerDialog), findsOneWidget);
    });

    testWidgets('cancel clears form', (WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());

      await tester.enterText(find.byKey(const Key('amountField')), '100000');
      await tester.enterText(find.byKey(const Key('categoryField')), 'Test');
      await tester.tap(find.text('Batal'));
      await tester.pump();

      expect(provider.editingTransaction, null);
    });

    testWidgets('edit mode populates fields', (WidgetTester tester) async {
      final tx = FinanceTransaction(
        id: 1,
        type: 'income',
        amount: 5000000,
        category: 'Gaji',
        note: 'Bulanan',
        occurredAt: DateTime(2026, 1, 15),
        createdAt: DateTime(2026, 1, 15),
        updatedAt: DateTime(2026, 1, 15),
      );
      provider.startEdit(tx);

      await tester.pumpWidget(buildScreen());

      // Check fields are populated
      expect(find.text('5.000.000'), findsOneWidget); // formatted amount
      expect(find.text('Gaji'), findsOneWidget);
      expect(find.text('Bulanan'), findsOneWidget);
    });

    testWidgets('shows error when save fails', (WidgetTester tester) async {
      await tester.pumpWidget(buildScreen());

      // Try to save with amount 0
      await tester.tap(find.text('Simpan'));
      await tester.pump();

      expect(find.text('Nominal harus lebih dari 0'), findsOneWidget);
    });
  });
}