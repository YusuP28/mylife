import 'package:flutter/material.dart';

/// Layar buat/buka kunci Vault. Ditampilkan saat vault terkunci.
class VaultLockScreen extends StatefulWidget {
  const VaultLockScreen({
    super.key,
    required this.hasPassword,
    required this.hasQuickUnlock,
    required this.busy,
    required this.error,
    required this.onCreate,
    required this.onUnlock,
    required this.onUnlockWithDevice,
  });

  final bool hasPassword;

  /// `true` bila kunci perangkat tersimpan (buka cepat 4C-A).
  final bool hasQuickUnlock;
  final bool busy;
  final String? error;
  final Future<bool> Function(String password) onCreate;
  final Future<bool> Function(String password) onUnlock;
  final Future<bool> Function() onUnlockWithDevice;

  @override
  State<VaultLockScreen> createState() => _VaultLockScreenState();
}

class _VaultLockScreenState extends State<VaultLockScreen> {
  static const int minPasswordLength = 8;

  final TextEditingController _passwordCtrl = TextEditingController();
  final TextEditingController _confirmCtrl = TextEditingController();
  bool _showPassword = false;
  String? _localError;

  bool get _isCreating => !widget.hasPassword;

  @override
  void dispose() {
    _passwordCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (widget.busy) return;

    final password = _passwordCtrl.text;
    if (password.length < minPasswordLength) {
      setState(() {
        _localError = 'Password minimal $minPasswordLength karakter';
      });
      return;
    }
    if (_isCreating && _confirmCtrl.text != password) {
      setState(() => _localError = 'Konfirmasi password tidak sama');
      return;
    }

    setState(() => _localError = null);
    final ok = _isCreating
        ? await widget.onCreate(password)
        : await widget.onUnlock(password);

    if (!ok && mounted) {
      _passwordCtrl.clear();
      _confirmCtrl.clear();
    }
  }

  Future<void> _unlockWithDevice() async {
    if (widget.busy) return;
    setState(() => _localError = null);
    await widget.onUnlockWithDevice();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final message = _localError ?? widget.error;

    return Scaffold(
      appBar: AppBar(title: const Text('Vault')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: <Widget>[
            const SizedBox(height: 24),
            Icon(
              _isCreating ? Icons.lock_outline : Icons.lock,
              size: 64,
              color: theme.colorScheme.primary,
            ),
            const SizedBox(height: 16),
            Text(
              _isCreating ? 'Buat password brankas' : 'Buka brankas',
              textAlign: TextAlign.center,
              style: theme.textTheme.titleLarge
                  ?.copyWith(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),
            Text(
              _isCreating
                  ? 'Password ini menurunkan kunci enkripsi AES-256 untuk semua '
                      'item brankas, termasuk data lama yang masih plaintext.'
                  : 'Masukkan password brankas untuk membuka kunci enkripsi.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _passwordCtrl,
              obscureText: !_showPassword,
              enabled: !widget.busy,
              autofocus: true,
              textInputAction:
                  _isCreating ? TextInputAction.next : TextInputAction.done,
              onSubmitted: (_) {
                if (!_isCreating) _submit();
              },
              decoration: InputDecoration(
                labelText: 'Password',
                border: const OutlineInputBorder(),
                suffixIcon: IconButton(
                  onPressed: () {
                    setState(() => _showPassword = !_showPassword);
                  },
                  icon: Icon(
                    _showPassword ? Icons.visibility_off : Icons.visibility,
                  ),
                ),
              ),
            ),
            if (_isCreating) ...<Widget>[
              const SizedBox(height: 16),
              TextField(
                controller: _confirmCtrl,
                obscureText: !_showPassword,
                enabled: !widget.busy,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _submit(),
                decoration: const InputDecoration(
                  labelText: 'Ulangi password',
                  border: OutlineInputBorder(),
                ),
              ),
            ],
            if (message != null) ...<Widget>[
              const SizedBox(height: 12),
              Text(
                message,
                style: TextStyle(color: theme.colorScheme.error),
              ),
            ],
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: widget.busy ? null : _submit,
              icon: widget.busy
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Icon(_isCreating ? Icons.lock : Icons.lock_open),
              label: Text(
                widget.busy
                    ? 'Memproses...'
                    : _isCreating
                        ? 'Buat & enkripsi'
                        : 'Buka',
              ),
            ),
            if (!_isCreating && widget.hasQuickUnlock) ...<Widget>[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: widget.busy ? null : _unlockWithDevice,
                icon: const Icon(Icons.fingerprint),
                label: const Text('Buka cepat'),
              ),
            ],
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: theme.colorScheme.surfaceContainerHighest,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Password tidak disimpan di perangkat. Lupa password berarti '
                'data brankas tidak bisa dibuka lagi.',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: theme.colorScheme.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
