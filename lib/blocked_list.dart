import 'package:flutter/material.dart';

import 'add_site_sheet.dart';
import 'blocker_api.dart';
import 'known_services.dart';
import 'l10n.dart';

enum _Filter { all, apps, sites }

/// Sekcia "Čo blokujem" – prehľad zablokovaných aplikácií a stránok.
class BlockedList extends StatefulWidget {
  const BlockedList({
    super.key,
    required this.state,
    required this.appInfo,
    required this.onAdd,
    required this.onRemoveSite,
    required this.onRemoveApp,
    required this.onToggleSite,
    required this.onToggleApp,
    required this.onEnableBrowsers,
    required this.onEnableProtection,
  });

  final BlockerState state;
  final Map<String, InstalledApp> appInfo;
  final void Function([AddKind kind]) onAdd;
  final ValueChanged<String> onRemoveSite;
  final ValueChanged<String> onRemoveApp;
  final void Function(String entry, bool blocked) onToggleSite;
  final void Function(String package, bool blocked) onToggleApp;
  final VoidCallback onEnableBrowsers;
  final VoidCallback onEnableProtection;

  @override
  State<BlockedList> createState() => _BlockedListState();
}

class _BlockedListState extends State<BlockedList> {
  _Filter _filter = _Filter.all;

  BlockerState get st => widget.state;

  bool _siteActive(String entry) =>
      entryHasPath(entry) ? st.accessibilityActive : st.vpnRunning || st.accessibilityActive;

  _Status _siteStatus(String entry) {
    if (st.disabledEntries.contains(entry)) return _Status.allowed;
    return st.isProtected && _siteActive(entry) ? _Status.blocked : _Status.inactive;
  }

  _Status _appStatus(String pkg) {
    if (st.disabledApps.contains(pkg)) return _Status.allowed;
    return st.accessibilityActive ? _Status.blocked : _Status.inactive;
  }

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final theme = Theme.of(context);
    final showApps = _filter != _Filter.sites && st.apps.isNotEmpty;
    final showSites = _filter != _Filter.apps && st.entries.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Text(s.whatIBlock,
              style: theme.textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        if (st.totalCount == 0)
          _Empty(onAdd: widget.onAdd)
        else ...[
          _FilterBar(
            filter: _filter,
            labels: {
              _Filter.all: s.filterAll,
              _Filter.apps: s.filterApps,
              _Filter.sites: s.filterSites,
            },
            counts: {
              _Filter.all: st.totalCount,
              _Filter.apps: st.apps.length,
              _Filter.sites: st.entries.length,
            },
            onChanged: (f) => setState(() => _filter = f),
          ),
          const SizedBox(height: 12),
          ..._warning(s),
          if (showApps) ...[
            _GroupHeader(icon: Icons.apps_rounded, text: s.groupApps, count: st.apps.length),
            for (final pkg in st.apps)
              _ItemCard(
                key: ValueKey('app-$pkg'),
                leading: AppIcon(app: widget.appInfo[pkg], size: 48),
                title: widget.appInfo[pkg]?.label ?? pkg,
                subtitle: widget.appInfo[pkg] == null ? s.appMissing : s.app,
                status: _appStatus(pkg),
                onToggle: (v) => widget.onToggleApp(pkg, v),
                onRemove: () => widget.onRemoveApp(pkg),
              ),
          ],
          if (showSites) ...[
            if (showApps) const SizedBox(height: 8),
            _GroupHeader(icon: Icons.language_rounded, text: s.groupSites, count: st.entries.length),
            for (final entry in st.entries)
              _ItemCard(
                key: ValueKey('site-$entry'),
                leading: _SiteAvatar(entry: entry),
                title: serviceForDomain(entry)?.name ?? entry,
                subtitle: serviceForDomain(entry) != null
                    ? entry
                    : entryHasPath(entry)
                        ? s.pathOnly
                        : s.wholeSite,
                status: _siteStatus(entry),
                onToggle: (v) => widget.onToggleSite(entry, v),
                onRemove: () => widget.onRemoveSite(entry),
              ),
          ],
          if (_filter == _Filter.apps && st.apps.isEmpty)
            _FilterEmpty(text: s.noApps, action: s.addApp, onTap: () => widget.onAdd(AddKind.app)),
          if (_filter == _Filter.sites && st.entries.isEmpty)
            _FilterEmpty(text: s.noSites, action: s.addSite, onTap: () => widget.onAdd(AddKind.site)),
        ],
      ],
    );
  }

  /// Vysvetlí, prečo sa niečo neblokuje, a ponúkne opravu jedným klepnutím.
  List<Widget> _warning(S s) {
    if (!st.isProtected) {
      return [
        _Notice(text: s.noticeOff, action: s.turnOnShort, onTap: widget.onEnableProtection),
        const SizedBox(height: 12),
      ];
    }
    final inactiveApps = st.apps.where((p) => _appStatus(p) == _Status.inactive).length;
    final inactiveSites = st.entries.where((e) => _siteStatus(e) == _Status.inactive).length;
    if (inactiveApps + inactiveSites == 0) return const [];
    final what = s.and([
      if (inactiveApps > 0) s.apps(inactiveApps),
      if (inactiveSites > 0) s.sites(inactiveSites),
    ]);
    return [
      _Notice(
        text: s.noticeInactive(what, many: inactiveApps + inactiveSites > 1),
        action: s.turnOnShort,
        onTap: widget.onEnableBrowsers,
      ),
      const SizedBox(height: 12),
    ];
  }
}

enum _Status { blocked, inactive, allowed }

// ----------------------------------------------------------------------------

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.filter,
    required this.labels,
    required this.counts,
    required this.onChanged,
  });

  final _Filter filter;
  final Map<_Filter, String> labels;
  final Map<_Filter, int> counts;
  final ValueChanged<_Filter> onChanged;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          for (final f in _Filter.values)
            Expanded(
              child: GestureDetector(
                onTap: () => onChanged(f),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: f == filter ? scheme.surface : Colors.transparent,
                    borderRadius: BorderRadius.circular(12),
                    boxShadow: f == filter
                        ? [BoxShadow(color: Colors.black.withValues(alpha: 0.08), blurRadius: 6)]
                        : null,
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Flexible(
                        child: Text(
                          labels[f]!,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontWeight: f == filter ? FontWeight.w700 : FontWeight.w500,
                            color: f == filter ? scheme.onSurface : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                      const SizedBox(width: 6),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 1),
                        decoration: BoxDecoration(
                          color: f == filter ? scheme.primary : scheme.outlineVariant,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          '${counts[f]}',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: f == filter ? scheme.onPrimary : scheme.onSurfaceVariant,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _GroupHeader extends StatelessWidget {
  const _GroupHeader({required this.icon, required this.text, required this.count});

  final IconData icon;
  final String text;
  final int count;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
      child: Row(
        children: [
          Icon(icon, size: 18, color: scheme.primary),
          const SizedBox(width: 8),
          Text(text,
              style: TextStyle(
                  color: scheme.primary, fontWeight: FontWeight.w700, letterSpacing: 0.2)),
          const SizedBox(width: 6),
          Text('· $count', style: TextStyle(color: scheme.onSurfaceVariant)),
        ],
      ),
    );
  }
}

class _ItemCard extends StatelessWidget {
  const _ItemCard({
    super.key,
    required this.leading,
    required this.title,
    required this.subtitle,
    required this.status,
    required this.onToggle,
    required this.onRemove,
  });

  final Widget leading;
  final String title;
  final String subtitle;
  final _Status status;
  final ValueChanged<bool> onToggle;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final allowed = status == _Status.allowed;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Dismissible(
        key: ValueKey('dismiss-$key'),
        direction: DismissDirection.endToStart,
        onDismissed: (_) => onRemove(),
        background: Container(
          alignment: Alignment.centerRight,
          padding: const EdgeInsets.only(right: 24),
          decoration: BoxDecoration(
            color: scheme.errorContainer,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              Text(s.remove,
                  style: TextStyle(color: scheme.onErrorContainer, fontWeight: FontWeight.w600)),
              const SizedBox(width: 8),
              Icon(Icons.delete_outline_rounded, color: scheme.onErrorContainer),
            ],
          ),
        ),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 250),
          padding: const EdgeInsets.fromLTRB(12, 12, 0, 12),
          decoration: BoxDecoration(
            color: allowed ? scheme.surfaceContainerLowest : scheme.surfaceContainerLow,
            borderRadius: BorderRadius.circular(20),
            border: allowed ? Border.all(color: scheme.outlineVariant) : null,
          ),
          child: Row(
            children: [
              AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: allowed ? 0.4 : 1,
                child: ClipRRect(borderRadius: BorderRadius.circular(14), child: leading),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 16,
                          color: allowed ? scheme.onSurfaceVariant : scheme.onSurface,
                        )),
                    const SizedBox(height: 2),
                    Text(subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: scheme.onSurfaceVariant, fontSize: 13)),
                    const SizedBox(height: 6),
                    _StatusPill(status: status),
                  ],
                ),
              ),
              Tooltip(
                message: s.toggleTooltip,
                child: Switch(value: !allowed, onChanged: onToggle),
              ),
              IconButton(
                tooltip: s.remove,
                visualDensity: VisualDensity.compact,
                icon: Icon(Icons.delete_outline_rounded, color: scheme.onSurfaceVariant),
                onPressed: onRemove,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});

  final _Status status;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    final dark = Theme.of(context).brightness == Brightness.dark;
    final (color, icon, text) = switch (status) {
      _Status.blocked => (
          dark ? const Color(0xFF6DD58C) : const Color(0xFF1B7F3B),
          Icons.lock_rounded,
          s.statusBlocked,
        ),
      _Status.inactive => (
          dark ? const Color(0xFFFFB95C) : const Color(0xFFB25E00),
          Icons.pause_circle_outline_rounded,
          s.statusInactive,
        ),
      _Status.allowed => (scheme.onSurfaceVariant, Icons.lock_open_rounded, s.statusAllowed),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 13, color: color),
          const SizedBox(width: 4),
          Text(text, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}

class _SiteAvatar extends StatelessWidget {
  const _SiteAvatar({required this.entry});

  final String entry;

  static const _palette = [
    Color(0xFF5B3FD9),
    Color(0xFF0091FF),
    Color(0xFF12A594),
    Color(0xFFF76808),
    Color(0xFFD6409F),
    Color(0xFF3E63DD),
  ];

  @override
  Widget build(BuildContext context) {
    final service = serviceForDomain(entry);
    final color = service?.color ??
        _palette[entry.codeUnits.fold<int>(0, (a, b) => a + b) % _palette.length];
    final onColor = service?.onColor ?? Colors.white;
    return Container(
      width: 48,
      height: 48,
      color: color,
      alignment: Alignment.center,
      child: service != null
          ? Text(service.name[0],
              style: TextStyle(color: onColor, fontSize: 22, fontWeight: FontWeight.w800))
          : Icon(Icons.language_rounded, color: onColor, size: 26),
    );
  }
}

class _Notice extends StatelessWidget {
  const _Notice({required this.text, required this.action, required this.onTap});

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(Icons.info_outline_rounded, color: scheme.onTertiaryContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13)),
          ),
          TextButton(onPressed: onTap, child: Text(action)),
        ],
      ),
    );
  }
}

class _FilterEmpty extends StatelessWidget {
  const _FilterEmpty({required this.text, required this.action, required this.onTap});

  final String text;
  final String action;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 20),
      child: Column(
        children: [
          Text(text, style: TextStyle(color: Theme.of(context).colorScheme.onSurfaceVariant)),
          const SizedBox(height: 8),
          FilledButton.tonalIcon(
            onPressed: onTap,
            icon: const Icon(Icons.add_rounded),
            label: Text(action),
          ),
        ],
      ),
    );
  }
}

class _Empty extends StatelessWidget {
  const _Empty({required this.onAdd});

  final void Function([AddKind kind]) onAdd;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
      decoration: BoxDecoration(
        color: scheme.surfaceContainerLow,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(color: scheme.primaryContainer, shape: BoxShape.circle),
            child: Icon(Icons.block_rounded, size: 36, color: scheme.onPrimaryContainer),
          ),
          const SizedBox(height: 16),
          Text(s.emptyTitle,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(s.emptyBody, textAlign: TextAlign.center, style: TextStyle(color: scheme.onSurfaceVariant)),
          const SizedBox(height: 16),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: () => onAdd(AddKind.app),
                icon: const Icon(Icons.apps_rounded),
                label: Text(s.emptyApp),
              ),
              FilledButton.tonalIcon(
                onPressed: () => onAdd(AddKind.site),
                icon: const Icon(Icons.language_rounded),
                label: Text(s.emptySite),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
