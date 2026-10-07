import 'package:flutter/material.dart';

import 'blocker_api.dart';
import 'known_services.dart';
import 'l10n.dart';

/// Čo sa má pridať do blokovania.
class AddResult {
  const AddResult({this.sites = const [], this.apps = const []});

  final List<String> sites;
  final List<String> apps;

  bool get isEmpty => sites.isEmpty && apps.isEmpty;
}

enum AddKind { site, app }

/// Spodný panel na pridanie stránky alebo aplikácie.
class AddSheet extends StatefulWidget {
  const AddSheet({
    super.key,
    required this.existingSites,
    required this.existingApps,
    required this.installedApps,
    this.initialKind = AddKind.site,
  });

  final List<String> existingSites;
  final List<String> existingApps;
  final Future<List<InstalledApp>> installedApps;
  final AddKind initialKind;

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  final _siteController = TextEditingController();
  final _searchController = TextEditingController();
  final _services = <KnownService>{};
  final _apps = <String>{};
  late AddKind _kind = widget.initialKind;
  List<InstalledApp> _installed = const [];
  String? _error;

  @override
  void initState() {
    super.initState();
    widget.installedApps.then((apps) {
      if (mounted) setState(() => _installed = apps);
    });
  }

  @override
  void dispose() {
    _siteController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  Set<String> get _installedPackages => {for (final a in _installed) a.package};

  /// Aplikácie, ktoré pribudnú vďaka rýchlemu výberu (iba nainštalované a ešte neblokované).
  Set<String> get _serviceApps => {
        for (final s in _services)
          for (final p in s.packages)
            if (_installedPackages.contains(p) && !widget.existingApps.contains(p)) p,
      };

  int get _count {
    final typed = _siteController.text.trim().isEmpty ? 0 : 1;
    return typed + _services.length + {..._apps, ..._serviceApps}.length;
  }

  void _submit() {
    final sites = <String>{for (final s in _services) s.domain};
    final text = _siteController.text.trim();
    if (text.isNotEmpty) {
      final entry = normalizeEntry(text);
      if (entry == null) {
        return _fail(S.of(context).invalidSite);
      }
      if (widget.existingSites.contains(entry)) {
        return _fail(S.of(context).alreadyListed(entry));
      }
      sites.add(entry);
    }
    final apps = {..._apps, ..._serviceApps};
    if (sites.isEmpty && apps.isEmpty) {
      setState(() => _error = _kind == AddKind.site
          ? S.of(context).pickSomething
          : null);
      if (_kind == AddKind.app) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(S.of(context).pickApp)),
        );
      }
      return;
    }
    Navigator.pop(context, AddResult(sites: sites.toList(), apps: apps.toList()));
  }

  void _fail(String message) => setState(() {
        _kind = AddKind.site;
        _error = message;
      });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final s = S.of(context);
    final keyboard = MediaQuery.viewInsetsOf(context).bottom;
    // Pod tlačidlom necháme miesto pre navigačný panel telefónu (Späť, Domov…).
    final bottomGap = keyboard > 0 ? 12.0 : MediaQuery.viewPaddingOf(context).bottom + 16;

    return Padding(
      padding: EdgeInsets.only(bottom: keyboard),
      child: FractionallySizedBox(
        heightFactor: 0.92,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(s.addTitle,
                      style: theme.textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                  const SizedBox(height: 16),
                  SizedBox(
                    width: double.infinity,
                    child: SegmentedButton<AddKind>(
                      segments: [
                        ButtonSegment(
                            value: AddKind.site,
                            icon: Icon(Icons.language_rounded),
                            label: Text(s.kindSite)),
                        ButtonSegment(
                            value: AddKind.app,
                            icon: Icon(Icons.apps_rounded),
                            label: Text(s.kindApp)),
                      ],
                      selected: {_kind},
                      onSelectionChanged: (s) => setState(() {
                        _kind = s.first;
                        FocusScope.of(context).unfocus();
                      }),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(child: _kind == AddKind.site ? _siteTab(theme) : _appTab(theme)),
            DecoratedBox(
              decoration: BoxDecoration(
                color: scheme.surfaceContainerLow,
                border: Border(top: BorderSide(color: scheme.outlineVariant.withValues(alpha: 0.5))),
              ),
              child: Padding(
                padding: EdgeInsets.fromLTRB(20, 12, 20, bottomGap),
                child: SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    onPressed: _submit,
                    icon: const Icon(Icons.block_rounded),
                    label: Text(
                      _count == 0 ? s.block : '${s.block} ($_count)',
                      style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _siteTab(ThemeData theme) {
    final scheme = theme.colorScheme;
    final available =
        knownServices.where((s) => !widget.existingSites.contains(s.domain)).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
      children: [
        TextField(
          controller: _siteController,
          keyboardType: TextInputType.url,
          autocorrect: false,
          textInputAction: TextInputAction.done,
          onChanged: (_) => setState(() => _error = null),
          onSubmitted: (_) => _submit(),
          decoration: InputDecoration(
            hintText: S.of(context).siteHint,
            prefixIcon: const Icon(Icons.language_rounded),
            errorText: _error,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          S.of(context).siteTip,
          style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
        ),
        if (available.isNotEmpty) ...[
          const SizedBox(height: 24),
          Text(S.of(context).popular,
              style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 4),
          Text(
            S.of(context).popularHint,
            style: theme.textTheme.bodySmall?.copyWith(color: scheme.onSurfaceVariant),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              for (final s in available)
                FilterChip(
                  avatar: CircleAvatar(
                    backgroundColor: s.color,
                    child: Text(s.name[0],
                        style: TextStyle(
                            color: s.onColor, fontSize: 12, fontWeight: FontWeight.w800)),
                  ),
                  label: Text(s.name),
                  selected: _services.contains(s),
                  showCheckmark: false,
                  onSelected: (on) => setState(() {
                    on ? _services.add(s) : _services.remove(s);
                    _error = null;
                  }),
                ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _appTab(ThemeData theme) {
    final scheme = theme.colorScheme;
    return FutureBuilder<List<InstalledApp>>(
      future: widget.installedApps,
      builder: (context, snapshot) {
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final query = _searchController.text.trim().toLowerCase();
        final apps = snapshot.data!
            .where((a) => query.isEmpty || a.label.toLowerCase().contains(query))
            .toList();

        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: TextField(
                controller: _searchController,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: S.of(context).searchApp,
                  prefixIcon: const Icon(Icons.search_rounded),
                ),
              ),
            ),
            Expanded(
              child: apps.isEmpty
                  ? Center(
                      child: Text(S.of(context).nothingFound,
                          style: TextStyle(color: scheme.onSurfaceVariant)))
                  : ListView.builder(
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 12),
                      itemCount: apps.length,
                      itemBuilder: (context, i) {
                        final app = apps[i];
                        final already = widget.existingApps.contains(app.package);
                        final checked = already || _apps.contains(app.package);
                        return ListTile(
                          enabled: !already,
                          shape:
                              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                          leading: AppIcon(app: app, size: 40),
                          title: Text(app.label, style: const TextStyle(fontWeight: FontWeight.w600)),
                          subtitle: already ? Text(S.of(context).alreadyBlocked) : null,
                          trailing: Checkbox(
                            value: checked,
                            onChanged: already
                                ? null
                                : (v) => setState(() =>
                                    v == true ? _apps.add(app.package) : _apps.remove(app.package)),
                          ),
                          onTap: already
                              ? null
                              : () => setState(() => _apps.contains(app.package)
                                  ? _apps.remove(app.package)
                                  : _apps.add(app.package)),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}

/// Ikona aplikácie (alebo náhradná, ak ju nepoznáme).
class AppIcon extends StatelessWidget {
  const AppIcon({super.key, required this.app, this.size = 44});

  final InstalledApp? app;
  final double size;

  @override
  Widget build(BuildContext context) {
    final icon = app?.icon;
    if (icon != null) {
      return Image.memory(icon, width: size, height: size, gaplessPlayback: true);
    }
    final scheme = Theme.of(context).colorScheme;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(size / 3.5),
      ),
      child: Icon(Icons.android_rounded, color: scheme.onSurfaceVariant, size: size * 0.55),
    );
  }
}
