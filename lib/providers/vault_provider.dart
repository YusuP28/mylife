import 'package:flutter/foundation.dart';

import '../models/vault_item.dart';
import '../services/database_service.dart';

class VaultProvider extends ChangeNotifier {
  VaultProvider({DatabaseService? service})
      : _service = service ?? DatabaseService.instance;

  final DatabaseService _service;

  List<VaultItem> _items = <VaultItem>[];
  bool _loading = false;
  String? _error;

  List<VaultItem> get items => List<VaultItem>.unmodifiable(_items);
  bool get loading => _loading;
  String? get error => _error;
  int get count => _items.length;

  Future<void> loadItems() async {
    _loading = true;
    _error = null;
    notifyListeners();

    try {
      _items = await _service.getVaultItems();
    } catch (e) {
      _error = 'Gagal memuat brankas: $e';
    } finally {
      _loading = false;
      notifyListeners();
    }
  }

  Future<void> addItem({
    required String title,
    required String username,
    required String password,
    required String url,
    required String notes,
  }) async {
    if (title.trim().isEmpty) {
      throw ArgumentError('Judul item brankas tidak boleh kosong');
    }

    final now = DateTime.now();
    await _service.insertVaultItem(
      VaultItem(
        title: title,
        username: username,
        password: password,
        url: url,
        notes: notes,
        createdAt: now,
        updatedAt: now,
      ),
    );
    await loadItems();
  }

  Future<void> updateItem(VaultItem item) async {
    if (item.title.trim().isEmpty) {
      throw ArgumentError('Judul item brankas tidak boleh kosong');
    }

    await _service.updateVaultItem(
      VaultItem(
        id: item.id,
        title: item.title,
        username: item.username,
        password: item.password,
        url: item.url,
        notes: item.notes,
        createdAt: item.createdAt,
        updatedAt: DateTime.now(),
      ),
    );
    await loadItems();
  }

  Future<void> deleteItem(int id) async {
    await _service.deleteVaultItem(id);
    await loadItems();
  }
}
