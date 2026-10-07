import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'l10n.dart';

/// Ak je nastavené heslo, pred obsahom aplikácie zobrazí zamykaciu obrazovku.
/// Aplikácia sa znova zamkne, keď bola na pozadí dlhšie ako [relockAfter].
class LockGate extends StatefulWidget {
  const LockGate({super.key, required this.child});

  final Widget child;
  static const relockAfter = Duration(seconds: 30);

  @override
  State<LockGate> createState() => _LockGateState();
}

class _LockGateState extends State<LockGate> with WidgetsBindingObserver {
  late bool _locked = appSettings.hasPassword;
  DateTime? _backgroundSince;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _backgroundSince = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final since = _backgroundSince;
      _backgroundSince = null;
      // Krátky odchod (napr. povolenie VPN alebo nastavenia prístupnosti) aplikáciu nezamkne.
      if (since != null &&
          appSettings.hasPassword &&
          DateTime.now().difference(since) > LockGate.relockAfter) {
        setState(() => _locked = true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_locked && appSettings.hasPassword) {
      return LockScreen(onUnlocked: () => setState(() => _locked = false));
    }
    return widget.child;
  }
}

class LockScreen extends StatefulWidget {
  const LockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<LockScreen> createState() => _LockScreenState();
}

class _LockScreenState extends State<LockScreen> {
  final _controller = TextEditingController();
  bool _obscure = true;
  String? _error;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _submit() {
    if (appSettings.verifyPassword(_controller.text)) {
      widget.onUnlocked();
    } else {
      setState(() => _error = S.of(context).wrongPassword);
      _controller.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(24),
                    child: Image.asset('assets/branding/wsguard_mark.png', width: 96, height: 96),
                  ),
                  const SizedBox(height: 24),
                  Text(s.lockedTitle,
                      textAlign: TextAlign.center,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 8),
                  Text(s.lockedHint,
                      textAlign: TextAlign.center,
                      style: TextStyle(color: theme.colorScheme.onSurfaceVariant)),
                  const SizedBox(height: 28),
                  TextField(
                    controller: _controller,
                    autofocus: true,
                    obscureText: _obscure,
                    textInputAction: TextInputAction.done,
                    // onEditingComplete (namiesto onSubmitted) nechá klávesnicu otvorenú,
                    // takže po nesprávnom hesle sa dá hneď písať znova.
                    onEditingComplete: _submit,
                    onChanged: (_) {
                      if (_error != null) setState(() => _error = null);
                    },
                    decoration: InputDecoration(
                      hintText: s.password,
                      errorText: _error,
                      prefixIcon: const Icon(Icons.lock_rounded),
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_rounded : Icons.visibility_off_rounded),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton(onPressed: _submit, child: Text(s.unlock)),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Dialóg na zadanie hesla.
/// [create] = nové heslo (zadať 2×), inak overenie súčasného hesla.
/// Vráti zadané (a overené) heslo alebo `null`, ak používateľ zrušil.
Future<String?> showPasswordDialog(BuildContext context,
    {required String title, required bool create}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _PasswordDialog(title: title, create: create),
  );
}

class _PasswordDialog extends StatefulWidget {
  const _PasswordDialog({required this.title, required this.create});

  final String title;
  final bool create;

  @override
  State<_PasswordDialog> createState() => _PasswordDialogState();
}

class _PasswordDialogState extends State<_PasswordDialog> {
  final _first = TextEditingController();
  final _second = TextEditingController();
  String? _error;

  @override
  void dispose() {
    _first.dispose();
    _second.dispose();
    super.dispose();
  }

  void _submit() {
    final s = S.of(context);
    if (widget.create) {
      if (_first.text.length < 4) return setState(() => _error = s.passwordTooShort);
      if (_first.text != _second.text) return setState(() => _error = s.passwordsDontMatch);
    } else if (!appSettings.verifyPassword(_first.text)) {
      return setState(() => _error = s.wrongPassword);
    }
    Navigator.pop(context, _first.text);
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      icon: const Icon(Icons.lock_rounded),
      title: Text(widget.title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _first,
            autofocus: true,
            obscureText: true,
            textInputAction: widget.create ? TextInputAction.next : TextInputAction.done,
            onSubmitted: widget.create ? null : (_) => _submit(),
            decoration: InputDecoration(
              hintText: widget.create ? s.newPassword : s.currentPassword,
              errorText: widget.create ? null : _error,
            ),
          ),
          if (widget.create) ...[
            const SizedBox(height: 12),
            TextField(
              controller: _second,
              obscureText: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _submit(),
              decoration: InputDecoration(hintText: s.repeatPassword, errorText: _error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: Text(s.cancel)),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.create ? s.save : s.confirm),
        ),
      ],
    );
  }
}
