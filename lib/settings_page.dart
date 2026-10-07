import 'package:flutter/material.dart';

import 'app_settings.dart';
import 'l10n.dart';
import 'lock_screen.dart';

class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  static const appVersion = '1.0.0';

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(s.settings)),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
          children: [
            _Section(title: s.appearance, children: [
              _Label(icon: Icons.palette_outlined, text: s.theme),
              SegmentedButton<ThemeMode>(
                segments: [
                  ButtonSegment(
                      value: ThemeMode.light,
                      icon: const Icon(Icons.light_mode_rounded),
                      label: Text(s.themeLight)),
                  ButtonSegment(
                      value: ThemeMode.system,
                      icon: const Icon(Icons.brightness_auto_rounded),
                      label: Text(s.themeSystem)),
                  ButtonSegment(
                      value: ThemeMode.dark,
                      icon: const Icon(Icons.dark_mode_rounded),
                      label: Text(s.themeDark)),
                ],
                selected: {appSettings.themeMode},
                showSelectedIcon: false,
                onSelectionChanged: (v) => appSettings.setThemeMode(v.first),
              ),
              const SizedBox(height: 20),
              _Label(icon: Icons.translate_rounded, text: s.language),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'sk', label: Text('🇸🇰  Slovenčina')),
                  ButtonSegment(value: 'en', label: Text('🇬🇧  English')),
                ],
                selected: {appSettings.language},
                showSelectedIcon: false,
                onSelectionChanged: (v) => appSettings.setLanguage(v.first),
              ),
            ]),
            const SizedBox(height: 16),
            _Section(title: s.security, children: [
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                secondary: const Icon(Icons.lock_rounded),
                title: Text(s.lockApp, style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(s.lockAppHint),
                value: appSettings.hasPassword,
                onChanged: (on) => on ? _setPassword(context) : _removePassword(context),
              ),
              if (appSettings.hasPassword)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_rounded),
                  title: Text(s.changePassword),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: () => _changePassword(context),
                ),
            ]),
            const SizedBox(height: 16),
            _Section(title: s.about, children: [
              Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Image.asset('assets/branding/wsguard_mark.png', width: 56, height: 56),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('WSGuard',
                            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
                        Text('${s.version} $appVersion',
                            style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(s.aboutBody,
                  style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
            ]),
          ],
        ),
      ),
    );
  }

  Future<void> _setPassword(BuildContext context) async {
    final s = S.of(context);
    final password = await showPasswordDialog(context, title: s.setPassword, create: true);
    if (password == null) return;
    await appSettings.setPassword(password);
    if (context.mounted) _toast(context, s.passwordSet);
  }

  Future<void> _removePassword(BuildContext context) async {
    final s = S.of(context);
    final ok = await showPasswordDialog(context, title: s.removePasswordTitle, create: false);
    if (ok == null) return;
    await appSettings.clearPassword();
    if (context.mounted) _toast(context, s.passwordRemoved);
  }

  Future<void> _changePassword(BuildContext context) async {
    final s = S.of(context);
    final current = await showPasswordDialog(context, title: s.changePassword, create: false);
    if (current == null || !context.mounted) return;
    final password = await showPasswordDialog(context, title: s.newPassword, create: true);
    if (password == null) return;
    await appSettings.setPassword(password);
    if (context.mounted) _toast(context, s.passwordChanged);
  }

  void _toast(BuildContext context, String text) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }
}

class _Section extends StatelessWidget {
  const _Section({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title,
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          const SizedBox(height: 12),
          ...children,
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Theme.of(context).colorScheme.onSurfaceVariant),
          const SizedBox(width: 8),
          Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
        ],
      ),
    );
  }
}
