import 'package:flutter/material.dart';

import 'add_site_sheet.dart';
import 'blocker_api.dart';
import 'known_services.dart';
import 'l10n.dart';
import 'rule_card.dart';

enum _Filter { all, apps, sites }

/// Sekcia "Čo blokujem" – jednotlivé aplikácie a stránky (mimo zoznamov).
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
    required this.onTimer,
    required this.onUnblock,
    required this.onCancelTimer,
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

  /// Zablokovať na čas: (kľúč pravidla, zobrazovaný názov).
  final void Function(String key, String name) onTimer;

  /// Dočasne odblokovať: (kľúč pravidla, zobrazovaný názov).
  final void Function(String key, String name) onUnblock;

  /// Zrušiť časové blokovanie do 10 min od spustenia: (kľúč, názov).
  final void Function(String key, String name) onCancelTimer;
  final VoidCallback onEnableBrowsers;
  final VoidCallback onEnableProtection;

  @override
  State<BlockedList> createState() => _BlockedListState();
}

class _BlockedListState extends State<BlockedList> {
  _Filter _filter = _Filter.all;

  BlockerState get st => widget.state;

  bool _siteMethod(String entry) =>
      entryHasPath(entry) ? st.accessibilityActive : st.vpnRunning || st.accessibilityActive;

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
            for (final pkg in st.apps) _appCard(s, pkg),
          ],
          if (showSites) ...[
            if (showApps) const SizedBox(height: 8),
            _GroupHeader(icon: Icons.language_rounded, text: s.groupSites, count: st.entries.length),
            for (final entry in st.entries) _siteCard(s, entry),
          ],
          if (_filter == _Filter.apps && st.apps.isEmpty)
            _FilterEmpty(text: s.noApps, action: s.addApp, onTap: () => widget.onAdd(AddKind.app)),
          if (_filter == _Filter.sites && st.entries.isEmpty)
            _FilterEmpty(text: s.noSites, action: s.addSite, onTap: () => widget.onAdd(AddKind.site)),
        ],
      ],
    );
  }

  Widget _appCard(S s, String pkg) {
    final key = appKey(pkg);
    final name = widget.appInfo[pkg]?.label ?? pkg;
    return RuleCard(
      key: ValueKey(key),
      leading: AppIcon(app: widget.appInfo[pkg], size: 48),
      title: name,
      subtitle: widget.appInfo[pkg] == null ? s.appMissing : s.app,
      status: st.appStatus(pkg),
      methodActive: st.accessibilityActive,
      timerEnd: st.timerEnd(key),
      pauseEnd: st.pauseEnd(key),
      cancelEnd: st.cancelEnd(key),
      onCancelTimer: () => widget.onCancelTimer(key, name),
      unblocksLeft: st.unblockAllowed ? st.unblocksLeft(key) : null,
      unblockMinutes: st.unblockMinutes,
      onToggle: (v) => widget.onToggleApp(pkg, v),
      onRemove: () => widget.onRemoveApp(pkg),
      onBlockForTime: () => widget.onTimer(key, name),
      onUnblock: () => widget.onUnblock(key, name),
    );
  }

  Widget _siteCard(S s, String entry) {
    final key = siteKey(entry);
    final service = serviceForDomain(entry);
    final name = service?.name ?? entry;
    return RuleCard(
      key: ValueKey(key),
      leading: SiteAvatar(entry: entry),
      title: name,
      subtitle: service != null
          ? entry
          : entryHasPath(entry)
              ? s.pathOnly
              : s.wholeSite,
      status: st.siteStatus(entry),
      methodActive: _siteMethod(entry),
      timerEnd: st.timerEnd(key),
      pauseEnd: st.pauseEnd(key),
      cancelEnd: st.cancelEnd(key),
      onCancelTimer: () => widget.onCancelTimer(key, name),
      unblocksLeft: st.unblockAllowed ? st.unblocksLeft(key) : null,
      unblockMinutes: st.unblockMinutes,
      onToggle: (v) => widget.onToggleSite(entry, v),
      onRemove: () => widget.onRemoveSite(entry),
      onBlockForTime: () => widget.onTimer(key, name),
      onUnblock: () => widget.onUnblock(key, name),
    );
  }

  /// Vysvetlí, prečo sa niečo neblokuje, a ponúkne opravu jedným klepnutím.
  List<Widget> _warning(S s) {
    if (!st.isProtected) {
      return [
        Notice(text: s.noticeOff, action: s.turnOnShort, onTap: widget.onEnableProtection),
        const SizedBox(height: 12),
      ];
    }
    final inactiveApps =
        st.apps.where((p) => st.appStatus(p).blocking && !st.accessibilityActive).length;
    final inactiveSites =
        st.entries.where((e) => st.siteStatus(e).blocking && !_siteMethod(e)).length;
    if (inactiveApps + inactiveSites == 0) return const [];
    final what = s.and([
      if (inactiveApps > 0) s.apps(inactiveApps),
      if (inactiveSites > 0) s.sites(inactiveSites),
    ]);
    return [
      Notice(
        text: s.noticeInactive(what, many: inactiveApps + inactiveSites > 1),
        action: s.turnOnShort,
        onTap: widget.onEnableBrowsers,
      ),
      const SizedBox(height: 12),
    ];
  }
}

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

/// Farebná ikona stránky (pri známych službách v ich farbe).
class SiteAvatar extends StatelessWidget {
  const SiteAvatar({super.key, required this.entry, this.size = 48});

  final String entry;
  final double size;

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
      width: size,
      height: size,
      color: color,
      alignment: Alignment.center,
      child: service != null
          ? Text(service.name[0],
              style: TextStyle(color: onColor, fontSize: size * 0.46, fontWeight: FontWeight.w800))
          : Icon(Icons.language_rounded, color: onColor, size: size * 0.54),
    );
  }
}

/// Upozornenie s jedným tlačidlom (napr. "Ochrana je vypnutá – Zapnúť").
class Notice extends StatelessWidget {
  const Notice({super.key, required this.text, this.action, this.onTap, this.icon});

  final String text;
  final String? action;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: EdgeInsets.fromLTRB(14, 8, action == null ? 14 : 8, 8),
      constraints: const BoxConstraints(minHeight: 48),
      decoration: BoxDecoration(
        color: scheme.tertiaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon ?? Icons.info_outline_rounded, color: scheme.onTertiaryContainer, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(text, style: TextStyle(color: scheme.onTertiaryContainer, fontSize: 13)),
          ),
          if (action != null) TextButton(onPressed: onTap, child: Text(action!)),
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
