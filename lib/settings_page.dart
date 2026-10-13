import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_settings.dart';
import 'blocked_list.dart';
import 'blocker_api.dart';
import 'l10n.dart';
import 'lock_screen.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  static const appVersion = '1.1.1';

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  static const _lengths = [5, 10, 15, 30, 60];
  static const _perDay = [0, 1, 2, 3, 5, 10];

  BlockerState _state = const BlockerState();
  bool _busy = false;

  S get s => S.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    final st = await BlockerApi.getState();
    if (mounted) setState(() => _state = st);
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- dočasné odblokovanie ----------

  Future<void> _setUnblock(String key, int value) async {
    final ok = await BlockerApi.setSetting(key, '$value');
    if (!ok) _toast(s.lockedToast);
    await _refresh();
  }

  // ---------- heslo ----------

  Future<void> _setPassword() async {
    final password = await showPasswordDialog(context, title: s.setPassword, create: true);
    if (password == null) return;
    await appSettings.setPassword(password);
    _toast(s.passwordSet);
  }

  Future<void> _removePassword() async {
    if (_state.uninstallProtection) return _toast(s.turnOffProtectionFirst);
    final ok = await showPasswordDialog(context, title: s.removePasswordTitle, create: false);
    if (ok == null) return;
    await appSettings.clearPassword();
    _toast(s.passwordRemoved);
  }

  Future<void> _changePassword() async {
    final current = await showPasswordDialog(context, title: s.changePassword, create: false);
    if (current == null || !mounted) return;
    final password = await showPasswordDialog(context, title: s.newPassword, create: true);
    if (password == null) return;
    await appSettings.setPassword(password);
    _toast(s.passwordChanged);
  }

  // ---------- ochrana proti odinštalovaniu ----------

  Future<void> _setUninstallProtection(bool on) async {
    if (_busy) return;
    if (on && !appSettings.hasPassword) {
      _toast(s.needsPassword);
      return _setPassword();
    }
    if (!on) {
      if (_state.isLocked) return _toast(s.lockedToast);
      final ok = await showPasswordDialog(context, title: s.uninstallProtection, create: false);
      if (ok == null) return;
    }
    setState(() => _busy = true);
    try {
      final result = await BlockerApi.setUninstallProtection(on);
      if (on) {
        _toast(result ? s.protectionOnToast : s.protectionNotActivated);
      } else {
        _toast(s.protectionOffToast);
      }
    } on PlatformException catch (e) {
      if (e.code == 'locked') _toast(s.lockedToast);
    } finally {
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  void _showUninstallGuide() {
    showDialog<void>(
      context: context,
      builder: (context) {
        final s = S.of(context);
        final theme = Theme.of(context);
        Widget section(String title, String body, {bool mono = false}) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 6),
                  SelectableText(
                    body,
                    style: mono ? const TextStyle(fontFamily: 'monospace', fontSize: 12) : null,
                  ),
                ],
              ),
            );
        return AlertDialog(
          icon: const Icon(Icons.info_outline_rounded),
          title: Text(s.uninstallGuideTitle),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                section(s.uninstallGuideNormalTitle, s.uninstallGuideNormal),
                section(s.uninstallGuideForgotTitle, s.uninstallGuideForgot),
                section(s.uninstallGuidePcTitle, s.uninstallGuidePc, mono: true),
              ],
            ),
          ),
          actions: [
            FilledButton(onPressed: () => Navigator.pop(context), child: Text(s.close)),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final locked = _state.isLocked;

    return ListenableBuilder(
      listenable: appSettings,
      builder: (context, _) => Scaffold(
        appBar: AppBar(title: Text(s.settings)),
        body: ListView(
          padding: EdgeInsets.fromLTRB(16, 8, 16, MediaQuery.viewPaddingOf(context).bottom + 32),
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
            _Section(title: s.tempUnblock, children: [
              Text(s.tempUnblockHint,
                  style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
              if (locked) ...[
                const SizedBox(height: 10),
                Notice(text: s.lockedBanner(_state.lockedUntil!), icon: Icons.lock_clock_rounded),
              ],
              const SizedBox(height: 16),
              _Label(icon: Icons.timer_outlined, text: s.unblockLength),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final m in _lengths)
                    ChoiceChip(
                      label: Text('$m min'),
                      selected: _state.unblockMinutes == m,
                      showCheckmark: false,
                      onSelected: locked ? null : (_) => _setUnblock('unblockMinutes', m),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _Label(icon: Icons.repeat_rounded, text: s.unblockPerDayLabel),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final n in _perDay)
                    ChoiceChip(
                      label: Text(n == 0 ? s.never : '$n×'),
                      selected: _state.unblockPerDay == n,
                      showCheckmark: false,
                      onSelected: locked ? null : (_) => _setUnblock('unblockPerDay', n),
                    ),
                ],
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
                onChanged: (on) => on ? _setPassword() : _removePassword(),
              ),
              if (appSettings.hasPassword)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.password_rounded),
                  title: Text(s.changePassword),
                  trailing: const Icon(Icons.chevron_right_rounded),
                  onTap: _changePassword,
                ),
              const Divider(height: 24),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Icon(Icons.shield_rounded, color: scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(s.uninstallProtection,
                                  style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 16)),
                            ),
                            IconButton(
                              tooltip: s.uninstallGuideTitle,
                              visualDensity: VisualDensity.compact,
                              icon: Icon(Icons.info_outline_rounded, size: 20, color: scheme.primary),
                              onPressed: _showUninstallGuide,
                            ),
                          ],
                        ),
                        Text(s.uninstallProtectionHint,
                            style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                        if (_state.uninstallProtection && !_state.accessibilityActive) ...[
                          const SizedBox(height: 8),
                          Text(s.needsA11y,
                              style: TextStyle(color: scheme.tertiary, fontSize: 13)),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Switch(
                      value: _state.uninstallProtection,
                      onChanged: _busy ? null : _setUninstallProtection,
                    ),
                  ),
                ],
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
                        Text('${s.version} ${SettingsPage.appVersion}',
                            style: TextStyle(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(s.aboutBody, style: TextStyle(color: scheme.onSurfaceVariant)),
            ]),
          ],
        ),
      ),
    );
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
          Expanded(child: Text(text, style: const TextStyle(fontWeight: FontWeight.w600))),
        ],
      ),
    );
  }
}
