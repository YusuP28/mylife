import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mylife/providers/vault_lock_provider.dart';
import 'package:mylife/screens/vault/vault_screen.dart';
import 'package:mylife/services/vault_key_manager.dart';
import 'package:provider/provider.dart';

class _EmptyKeyStore implements VaultKeyStore {
  @override
  Future<VaultKeyRecord?> read() async => null;

  @override
  Future<void> write(VaultKeyRecord record) async {}

  @override
  Future<void> delete() async {}
}

void main() {
  testWidgets('editor saat terkunci mematikan simpan dan menampilkan banner',
      (tester) async {
    final lock = VaultLockProvider(
      keyManager: VaultKeyManager(store: _EmptyKeyStore(), iterations: 1),
    );

    await tester.pumpWidget(
      ChangeNotifierProvider<VaultLockProvider>.value(
        value: lock,
        child: const MaterialApp(home: VaultEditorScreen()),
      ),
    );

    expect(find.text('Vault terkunci'), findsOneWidget);
    expect(find.text('Kembali ke brankas'), findsOneWidget);

    final save = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Simpan'),
    );
    expect(save.onPressed, isNull);

    final fields = tester.widgetList<TextField>(find.byType(TextField));
    expect(fields, isNotEmpty);
    expect(fields.every((field) => field.enabled != true), isTrue);
  });
}
