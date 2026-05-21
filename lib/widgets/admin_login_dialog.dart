import 'package:flutter/material.dart';
import '../screens/csv_link_screen.dart';
import '../services/security_service.dart';

// Fully self-contained — no async gaps between Navigator calls,
// no reliance on outer BuildContext after dialog closes.
void showAdminLogin(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _AdminLoginDialog(parentContext: context),
  );
}

class _AdminLoginDialog extends StatefulWidget {
  final BuildContext parentContext;
  const _AdminLoginDialog({required this.parentContext});

  @override
  State<_AdminLoginDialog> createState() => _AdminLoginDialogState();
}

class _AdminLoginDialogState extends State<_AdminLoginDialog> {
  final _controller = TextEditingController();
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final input = _controller.text.trim();
    if (input.isEmpty) return;

    setState(() { _loading = true; _error = null; });

    // Check recovery password first (synchronous)
    if (SecurityService.verifyRecoveryPassword(input)) {
      if (!mounted) return;
      Navigator.of(context).pop();
      showResetPasswordDialog(widget.parentContext);
      return;
    }

    // Check admin password (async)
    final valid = await SecurityService.verifyPassword(input);
    if (!mounted) return;

    setState(() => _loading = false);

    if (valid) {
      Navigator.of(context).pop();
      Navigator.push(
        widget.parentContext,
        MaterialPageRoute(builder: (_) => const CsvLinkScreen()),
      );
    } else {
      setState(() => _error = 'Incorrect password. Try again.');
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Admin Access'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _controller,
            obscureText: true,
            autofocus: true,
            onSubmitted: (_) => _submit(),
            decoration: InputDecoration(
              labelText: 'Password',
              prefixIcon: const Icon(Icons.lock_outline_rounded),
              errorText: _error,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _loading ? null : _submit,
          child: _loading
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Login'),
        ),
      ],
    );
  }
}

void showResetPasswordDialog(BuildContext context) {
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (_) => _ResetPasswordDialog(parentContext: context),
  );
}

class _ResetPasswordDialog extends StatefulWidget {
  final BuildContext parentContext;
  const _ResetPasswordDialog({required this.parentContext});

  @override
  State<_ResetPasswordDialog> createState() => _ResetPasswordDialogState();
}

class _ResetPasswordDialogState extends State<_ResetPasswordDialog> {
  final _controller = TextEditingController();
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final newPw = _controller.text.trim();
    if (newPw.isEmpty) return;

    setState(() => _saving = true);
    await SecurityService.changePassword(newPw);
    if (!mounted) return;

    Navigator.of(context).pop();
    ScaffoldMessenger.of(widget.parentContext).showSnackBar(
      const SnackBar(content: Text('Password changed successfully')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Reset Password'),
      content: TextField(
        controller: _controller,
        obscureText: true,
        autofocus: true,
        onSubmitted: (_) => _save(),
        decoration: const InputDecoration(
          labelText: 'New Password',
          prefixIcon: Icon(Icons.lock_reset_rounded),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(
                  width: 16, height: 16,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Save'),
        ),
      ],
    );
  }
}
