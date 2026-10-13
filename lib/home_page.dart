import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'add_site_sheet.dart';
import 'blocked_list.dart';
import 'blocker_api.dart';
import 'known_services.dart';
import 'l10n.dart';
import 'list_edit_page.dart';
import 'lists_section.dart';
import 'settings_page.dart';
import 'timer_picker.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  BlockerState _state = const BlockerState();
  bool _loading = true;
  bool _busy = false;
  Timer? _poll;

  /// Nainštalované aplikácie (názov + ikona) – načítajú sa raz na pozadí.
  late Future<List<InstalledApp>> _installedApps = BlockerApi.getInstalledApps();
  Map<String, InstalledApp> _appInfo = const {};

  S get s => S.of(context);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
    _loadApps();
    // Počítadlo zablokovaní a odpočty časových blokovaní sa menia, preto stav obnovujeme.
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _refresh());
  }

  void _loadApps() {
    _installedApps.then((apps) {
      if (mounted) setState(() => _appInfo = {for (final a in apps) a.package: a});
    }).catchError((_) {});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _poll?.cancel();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Po návrate z nastavení (VPN / prístupnosť) načítame nový stav.
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final st = await BlockerApi.getState();
      if (mounted) setState(() => _state = st);
    } on PlatformException catch (_) {
      // necháme posledný známy stav
    } finally {
      if (mounted && _loading) setState(() => _loading = false);
    }
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await action();
    } on PlatformException catch (e) {
      if (e.code == 'locked') _toast(s.lockedToast);
    } finally {
      // Služba sa spúšťa asynchrónne, chvíľu počkáme na jej stav.
      await Future.delayed(const Duration(milliseconds: 400));
      await _refresh();
      if (mounted) setState(() => _busy = false);
    }
  }

  // ---------- ochrana ----------

  Future<void> _toggleProtection() async {
    if (_state.isProtected) {
      if (_state.isLocked) return _toast(s.lockedToast);
      await _run(() async {
        await BlockerApi.stopVpn();
        await BlockerApi.setAccessibility(false);
      });
      _toast(s.turnedOff);
      return;
    }
    await _ensureProtection();
  }

  /// Zapne všetko, čo je potrebné na blokovanie aktuálneho zoznamu.
  Future<void> _ensureProtection() async {
    if (!_state.vpnRunning) await _setVpn(true);
    final needsApps = _state.effectiveApps.isNotEmpty ||
        _state.apps.isNotEmpty ||
        _state.lists.any((l) => l.apps.isNotEmpty);
    if (needsApps && !_state.accessibilityActive) {
      await _setAccessibility(true);
    } else if (_state.accessibilityServiceOn && !_state.accessibilityEnabled) {
      await _run(() => BlockerApi.setAccessibility(true));
    }
  }

  Future<void> _setVpn(bool on) async {
    if (!BlockerApi.isSupported) return _toast(s.unsupported);
    if (!on && _state.isLocked) return _toast(s.lockedToast);
    await _run(() async {
      if (on) {
        final granted = await BlockerApi.startVpn();
        if (!granted) _toast(s.vpnDenied);
      } else {
        await BlockerApi.stopVpn();
      }
    });
  }

  Future<void> _setAccessibility(bool on) async {
    if (!BlockerApi.isSupported) return _toast(s.unsupported);
    if (!on && _state.isLocked) return _toast(s.lockedToast);
    if (on && !_state.accessibilityServiceOn) {
      final ok = await showDialog<bool>(
        context: context,
        builder: (context) => const _AccessibilityDialog(),
      );
      if (ok != true) return;
      await BlockerApi.setAccessibility(true);
      await BlockerApi.openAccessibilitySettings();
      return;
    }
    await _run(() => BlockerApi.setAccessibility(on));
  }

  // ---------- pridávanie a odoberanie ----------

  Future<void> _add([AddKind kind = AddKind.site]) async {
    // Aplikácie mohli pribudnúť, kým bola obrazovka otvorená.
    _installedApps = BlockerApi.getInstalledApps();
    _loadApps();
    final result = await showModalBottomSheet<AddResult>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      useSafeArea: true,
      builder: (_) => AddSheet(
        existingSites: _state.entries,
        existingApps: _state.apps,
        installedApps: _installedApps,
        initialKind: kind,
      ),
    );
    if (result == null || result.isEmpty || !mounted) return;

    if (result.sites.isNotEmpty) await _saveEntries([...result.sites, ..._state.entries]);
    if (result.apps.isNotEmpty) await _saveApps([...result.apps, ..._state.apps]);

    final parts = s.and([
      if (result.apps.isNotEmpty) s.apps(result.apps.length),
      if (result.sites.isNotEmpty) s.sites(result.sites.length),
    ]);

    if (result.apps.isNotEmpty && !_state.accessibilityActive) {
      // Bez služby prístupnosti by sa aplikácie neblokovali – rovno ponúkneme zapnutie.
      _toast(s.added(parts));
      await _setAccessibility(true);
    } else {
      _toast(_state.isProtected ? s.added(parts) : s.addedTurnOn(parts));
    }
  }

  Future<bool> _confirmTimed(DateTime until) => confirmTimedBlock(
        context,
        end: until,
        minutes: _state.unblockMinutes,
        perDay: _state.unblockPerDay,
      );

  String _siteName(String entry) => serviceForDomain(entry)?.name ?? entry;
  String _appName(String pkg) => _appInfo[pkg]?.label ?? pkg;

  Future<void> _removeSite(String entry) async {
    if (_state.siteStatus(entry).isTimedLock) return _toast(s.lockedToast);
    final before = _state.entries;
    final disabled = _state.disabledEntries;
    await _saveEntries(before.where((e) => e != entry).toList());
    _undo(s.removed(_siteName(entry)), () async {
      await _saveEntries(before);
      await _saveDisabled(entries: disabled);
    });
  }

  Future<void> _removeApp(String package) async {
    if (_state.appStatus(package).isTimedLock) return _toast(s.lockedToast);
    final before = _state.apps;
    final disabled = _state.disabledApps;
    await _saveApps(before.where((e) => e != package).toList());
    _undo(s.removed(_appName(package)), () async {
      await _saveApps(before);
      await _saveDisabled(apps: disabled);
    });
  }

  /// Vypínač pri trvalej položke – dočasne povolí / znova zablokuje bez odstránenia zo zoznamu.
  Future<void> _toggleSite(String entry, bool blocked) async {
    final set = {..._state.disabledEntries};
    blocked ? set.remove(entry) : set.add(entry);
    await _saveDisabled(entries: set);
    _toast(blocked ? s.resumed(_siteName(entry)) : s.paused(_siteName(entry)));
  }

  Future<void> _toggleApp(String package, bool blocked) async {
    final set = {..._state.disabledApps};
    blocked ? set.remove(package) : set.add(package);
    await _saveDisabled(apps: set);
    _toast(blocked ? s.resumed(_appName(package)) : s.paused(_appName(package)));
  }

  // ---------- časové blokovanie ----------

  /// "Zablokovať na čas" pri položke alebo zozname. Bežiace blokovanie sa dá iba predĺžiť.
  Future<void> _timer(String key, String name) async {
    final until = await showBlockForTimeSheet(context, name: name, currentEnd: _state.timerEnd(key));
    if (until == null || !mounted) return;
    if (!await _confirmTimed(until)) return;
    final st = await BlockerApi.setTimer(key, until);
    if (mounted) setState(() => _state = st);
    await BlockerApi.requestNotifications();
    _toast(s.timedStarted(name, until));
    await _ensureProtection();
  }

  /// "Odblokovať na N min" pri časovom blokovaní.
  Future<void> _unblock(String key, String name) async {
    final r = await BlockerApi.pause(key);
    if (mounted) setState(() => _state = r.state);
    _toast(r.ok ? s.unblocked(name, _state.unblockMinutes) : s.unblockLimit);
  }

  // ---------- zoznamy ----------

  Future<void> _openList([BlockList? list]) async {
    _installedApps = BlockerApi.getInstalledApps();
    _loadApps();
    final saved = await Navigator.of(context).push<BlockList>(MaterialPageRoute(
      builder: (_) => ListEditPage(
        initial: list,
        locked: list != null && _state.listStatus(list.id).isTimedLock,
        installedApps: _installedApps,
      ),
    ));
    if (saved == null) return;
    final lists = [
      for (final l in _state.lists) l.id == saved.id ? saved : l,
      if (!_state.lists.any((l) => l.id == saved.id)) saved,
    ];
    await _saveLists(lists);
    if (list == null) {
      _toast(_state.isProtected ? s.added(saved.name) : s.addedTurnOn(saved.name));
    }
    if (saved.apps.isNotEmpty && _state.isProtected && !_state.accessibilityActive) {
      await _setAccessibility(true);
    }
  }

  Future<void> _toggleList(BlockList list, bool blocked) async {
    final set = {..._state.disabledLists};
    blocked ? set.remove(list.id) : set.add(list.id);
    await _saveDisabled(lists: set);
    _toast(blocked ? s.resumed(list.name) : s.paused(list.name));
  }

  Future<void> _removeList(BlockList list) async {
    if (_state.listStatus(list.id).isTimedLock) return _toast(s.lockedToast);
    final before = _state.lists;
    await _saveLists(before.where((l) => l.id != list.id).toList());
    _undo(s.listDeleted(list.name), () => _saveLists(before));
  }

  // ---------- ukladanie ----------

  void _undo(String text, VoidCallback undo) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
        content: Text(text),
        action: SnackBarAction(label: s.undo, onPressed: undo),
      ));
  }

  Future<void> _saveEntries(List<String> entries) async {
    // Okamžite zobrazíme zmenu, natívna časť ju potom potvrdí.
    setState(() => _state = _state.copyWith(entries: entries));
    final st = await BlockerApi.setEntries(entries);
    if (mounted) setState(() => _state = st);
  }

  Future<void> _saveApps(List<String> apps) async {
    setState(() => _state = _state.copyWith(apps: apps));
    final st = await BlockerApi.setApps(apps);
    if (mounted) setState(() => _state = st);
  }

  Future<void> _saveLists(List<BlockList> lists) async {
    setState(() => _state = _state.copyWith(lists: lists));
    final st = await BlockerApi.setLists(lists);
    if (mounted) setState(() => _state = st);
  }

  Future<void> _saveDisabled({Set<String>? entries, Set<String>? apps, Set<String>? lists}) async {
    setState(() => _state = _state.copyWith(
        disabledEntries: entries, disabledApps: apps, disabledLists: lists));
    final st = await BlockerApi.setDisabled(entries: entries, apps: apps, lists: lists);
    if (mounted) setState(() => _state = st);
  }

  void _toast(String text) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(text)));
  }

  // ---------- UI ----------

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final lockedUntil = _state.lockedUntil;
    return Scaffold(
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _add,
        icon: const Icon(Icons.add_rounded),
        label: Text(s.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _refresh,
              child: CustomScrollView(
                slivers: [
                  // Logo vľavo, nastavenia vpravo – v jednom riadku.
                  SliverAppBar(
                    pinned: true,
                    toolbarHeight: 80,
                    titleSpacing: 16,
                    title: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.asset(
                            'assets/branding/wsguard_mark.png',
                            width: 44,
                            height: 44,
                            filterQuality: FilterQuality.medium,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Text('WSGuard',
                            style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800)),
                      ],
                    ),
                    actions: [
                      Padding(
                        padding: const EdgeInsets.only(right: 16),
                        child: IconButton.filledTonal(
                          tooltip: s.settings,
                          icon: const Icon(Icons.settings_rounded),
                          onPressed: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(builder: (_) => const SettingsPage()),
                            );
                            _refresh();
                          },
                        ),
                      ),
                    ],
                    backgroundColor: scheme.surface,
                  ),
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 120),
                    sliver: SliverList.list(children: [
                      if (!BlockerApi.isSupported) ...[
                        _InfoBanner(icon: Icons.info_outline_rounded, text: s.iosBanner),
                        const SizedBox(height: 16),
                      ],
                      _StatusCard(state: _state, busy: _busy, onToggle: _toggleProtection),
                      if (lockedUntil != null) ...[
                        const SizedBox(height: 12),
                        Notice(text: s.lockedBanner(lockedUntil), icon: Icons.lock_clock_rounded),
                      ],
                      const SizedBox(height: 28),
                      ListsSection(
                        state: _state,
                        onNew: () => _openList(),
                        onEdit: _openList,
                        onToggle: _toggleList,
                        onRemove: _removeList,
                        onTimer: _timer,
                        onUnblock: _unblock,
                      ),
                      const SizedBox(height: 28),
                      BlockedList(
                        state: _state,
                        appInfo: _appInfo,
                        onAdd: _add,
                        onRemoveSite: _removeSite,
                        onRemoveApp: _removeApp,
                        onToggleSite: _toggleSite,
                        onToggleApp: _toggleApp,
                        onTimer: _timer,
                        onUnblock: _unblock,
                        onEnableBrowsers: () => _setAccessibility(true),
                        onEnableProtection: _toggleProtection,
                      ),
                      const SizedBox(height: 28),
                      _SectionTitle(s.methods),
                      const SizedBox(height: 8),
                      _MethodTile(
                        icon: Icons.vpn_lock_rounded,
                        title: s.vpnTitle,
                        subtitle: s.vpnSubtitle,
                        value: _state.vpnRunning,
                        locked: _state.isLocked && _state.vpnRunning,
                        onChanged: _busy ? null : _setVpn,
                      ),
                      const SizedBox(height: 8),
                      _MethodTile(
                        icon: Icons.apps_rounded,
                        title: s.a11yTitle,
                        subtitle: s.a11ySubtitle,
                        value: _state.accessibilityActive,
                        locked: _state.isLocked && _state.accessibilityActive,
                        onChanged: _busy ? null : _setAccessibility,
                        warning: _state.accessibilityEnabled && !_state.accessibilityServiceOn
                            ? s.a11yNeedsSettings
                            : null,
                        onWarningTap: BlockerApi.openAccessibilitySettings,
                      ),
                    ]),
                  ),
                ],
              ),
            ),
    );
  }
}

// ======================= widgety =======================

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.state, required this.busy, required this.onToggle});

  final BlockerState state;
  final bool busy;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    final on = state.isProtected;
    final colors = on
        ? const [Color(0xFF6A4CF0), Color(0xFF3F2B96)]
        : const [Color(0xFF6E6A7C), Color(0xFF45424F)];
    final sites = state.effectiveSites.length;
    final apps = state.effectiveApps.length;
    final lockedUntil = state.lockedUntil;
    final lockedNow = on && lockedUntil != null;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOutCubic,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(28),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
        boxShadow: [
          BoxShadow(
            color: colors.first.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              AnimatedSwitcher(
                duration: const Duration(milliseconds: 300),
                transitionBuilder: (child, a) => ScaleTransition(scale: a, child: child),
                child: Container(
                  key: ValueKey(on),
                  width: 64,
                  height: 64,
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.18),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    on ? Icons.shield_rounded : Icons.shield_outlined,
                    color: Colors.white,
                    size: 34,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      on ? s.protectionOn : s.protectionOff,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      !on
                          ? s.offSubtitle
                          : apps + sites == 0
                              ? s.addSomething
                              : s.blocking(s.and([
                                  if (apps > 0) s.appsAcc(apps),
                                  if (sites > 0) s.sitesAcc(sites),
                                ])),
                      style: TextStyle(color: Colors.white.withValues(alpha: 0.85)),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _Stat(value: '$apps', label: s.wApps(apps)),
                const SizedBox(width: 10),
                _Stat(value: '$sites', label: s.wSites(sites)),
                const SizedBox(width: 10),
                _Stat(value: '${state.blockedCount}', label: s.wBlocks(state.blockedCount)),
              ],
            ),
          ),
          const SizedBox(height: 20),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton(
              onPressed: busy || lockedNow ? null : onToggle,
              style: FilledButton.styleFrom(
                backgroundColor: Colors.white,
                foregroundColor: colors.last,
                disabledBackgroundColor: Colors.white.withValues(alpha: 0.6),
                textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
              child: busy
                  ? SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(strokeWidth: 2.5, color: colors.last),
                    )
                  : lockedNow
                      ? Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.lock_clock_rounded, color: colors.last, size: 20),
                            const SizedBox(width: 8),
                            Text(s.lockedShort(lockedUntil),
                                style: TextStyle(color: colors.last)),
                          ],
                        )
                      : Text(on ? s.turnOff : s.turnOn),
            ),
          ),
        ],
      ),
    );
  }
}

class _Stat extends StatelessWidget {
  const _Stat({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.14),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(value,
                style: const TextStyle(
                    color: Colors.white, fontSize: 22, fontWeight: FontWeight.w700)),
            Text(label,
                style: TextStyle(color: Colors.white.withValues(alpha: 0.8), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  const _SectionTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(text,
          style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
    );
  }
}

class _MethodTile extends StatelessWidget {
  const _MethodTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.value,
    required this.onChanged,
    this.locked = false,
    this.warning,
    this.onWarningTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final bool value;

  /// Počas časového blokovania sa spôsob blokovania nedá vypnúť.
  final bool locked;
  final ValueChanged<bool>? onChanged;
  final String? warning;
  final VoidCallback? onWarningTap;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onChanged == null || locked ? null : () => onChanged!(!value),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 12, 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: value ? scheme.primaryContainer : scheme.surfaceContainerHighest,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(icon,
                        color: value ? scheme.onPrimaryContainer : scheme.onSurfaceVariant),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title,
                            style: Theme.of(context)
                                .textTheme
                                .titleSmall
                                ?.copyWith(fontWeight: FontWeight.w700)),
                        const SizedBox(height: 2),
                        Text(subtitle,
                            style: Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(color: scheme.onSurfaceVariant)),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  if (locked)
                    Padding(
                      padding: const EdgeInsets.only(top: 10, right: 6),
                      child: Icon(Icons.lock_clock_rounded, color: scheme.primary),
                    ),
                  Switch(value: value, onChanged: locked ? null : onChanged),
                ],
              ),
              if (warning != null) ...[
                const SizedBox(height: 12),
                InkWell(
                  onTap: onWarningTap,
                  borderRadius: BorderRadius.circular(12),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: scheme.tertiaryContainer,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.warning_amber_rounded,
                            size: 18, color: scheme.onTertiaryContainer),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(warning!,
                              style: TextStyle(
                                  color: scheme.onTertiaryContainer, fontSize: 13)),
                        ),
                        Icon(Icons.chevron_right_rounded, color: scheme.onTertiaryContainer),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoBanner extends StatelessWidget {
  const _InfoBanner({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: scheme.secondaryContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(icon, color: scheme.onSecondaryContainer),
          const SizedBox(width: 12),
          Expanded(child: Text(text, style: TextStyle(color: scheme.onSecondaryContainer))),
        ],
      ),
    );
  }
}

class _AccessibilityDialog extends StatelessWidget {
  const _AccessibilityDialog();

  @override
  Widget build(BuildContext context) {
    final s = S.of(context);
    return AlertDialog(
      icon: const Icon(Icons.accessibility_new_rounded),
      title: Text(s.a11yDialogTitle),
      content: SingleChildScrollView(child: Text(s.a11yDialogBody)),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(s.cancel),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(context, true),
          child: Text(s.openSettings),
        ),
      ],
    );
  }
}
