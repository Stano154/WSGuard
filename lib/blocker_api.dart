import 'dart:io';

import 'package:flutter/services.dart';

String siteKey(String entry) => 'site:$entry';
String appKey(String package) => 'app:$package';
String listKey(String id) => 'list:$id';

/// Stav jedného pravidla (stránky, aplikácie alebo zoznamu).
enum RuleStatus {
  /// Blokuje sa natrvalo (dá sa vypnúť vypínačom).
  permanent,

  /// Blokuje sa časovo – do konca sa nedá vypnúť ani odstrániť.
  timed,

  /// Časové blokovanie je dočasne odblokované (napr. na 15 min).
  paused,

  /// Neblokuje sa (vypnuté vypínačom alebo časové blokovanie skončilo).
  allowed,
}

extension RuleStatusX on RuleStatus {
  bool get blocking => this == RuleStatus.permanent || this == RuleStatus.timed;
  bool get isTimedLock => this == RuleStatus.timed || this == RuleStatus.paused;
}

/// Používateľom vytvorená skupina stránok a aplikácií, ktorá sa blokuje naraz.
class BlockList {
  const BlockList({
    required this.id,
    required this.name,
    this.emoji = '📋',
    this.sites = const [],
    this.apps = const [],
  });

  final String id;
  final String name;
  final String emoji;
  final List<String> sites;
  final List<String> apps;

  int get itemCount => sites.length + apps.length;

  factory BlockList.fromMap(Map<dynamic, dynamic> m) => BlockList(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        emoji: (m['emoji'] as String?) ?? '📋',
        sites: List<String>.from(m['sites'] as List? ?? const []),
        apps: List<String>.from(m['apps'] as List? ?? const []),
      );

  Map<String, Object> toMap() =>
      {'id': id, 'name': name, 'emoji': emoji, 'sites': sites, 'apps': apps};

  BlockList copyWith({String? name, String? emoji, List<String>? sites, List<String>? apps}) =>
      BlockList(
        id: id,
        name: name ?? this.name,
        emoji: emoji ?? this.emoji,
        sites: sites ?? this.sites,
        apps: apps ?? this.apps,
      );
}

/// Stav blokovania, ako ho hlási natívna časť aplikácie.
class BlockerState {
  const BlockerState({
    this.entries = const [],
    this.apps = const [],
    this.lists = const [],
    this.disabledEntries = const {},
    this.disabledApps = const {},
    this.disabledLists = const {},
    this.timers = const {},
    this.pauses = const {},
    this.pauseUsed = const {},
    this.cancelUntil = const {},
    this.unblockMinutes = 15,
    this.unblockPerDay = 3,
    this.uninstallProtection = false,
    this.vpnRunning = false,
    this.accessibilityEnabled = false,
    this.accessibilityServiceOn = false,
    this.blockedCount = 0,
  });

  /// Zablokované stránky ("domena.sk" alebo "domena.sk/cesta").
  final List<String> entries;

  /// Zablokované aplikácie (názvy balíkov, napr. com.instagram.android).
  final List<String> apps;
  final List<BlockList> lists;

  /// Trvalé položky vypnuté vypínačom (alebo po skončení časového blokovania).
  final Set<String> disabledEntries;
  final Set<String> disabledApps;
  final Set<String> disabledLists;

  /// Konce časových blokovaní a dočasných odblokovaní (kľúč -> ms od epochy).
  final Map<String, int> timers;
  final Map<String, int> pauses;

  /// Do kedy sa dá práve spustené časové blokovanie ešte zrušiť (10 min od spustenia).
  final Map<String, int> cancelUntil;

  /// Koľkokrát sa dnes pravidlo dočasne odblokovalo.
  final Map<String, int> pauseUsed;
  final int unblockMinutes;

  /// Koľkokrát za deň sa dá dočasne odblokovať (0 = nikdy).
  final int unblockPerDay;
  final bool uninstallProtection;
  final bool vpnRunning;

  /// Používateľ zapol režim "Aplikácie a prehliadače" v aplikácii.
  final bool accessibilityEnabled;

  /// Služba prístupnosti je povolená v systémových nastaveniach.
  final bool accessibilityServiceOn;
  final int blockedCount;

  bool get accessibilityActive => accessibilityEnabled && accessibilityServiceOn;
  bool get isProtected => vpnRunning || accessibilityActive;
  int get totalCount => entries.length + apps.length;

  static int get _now => DateTime.now().millisecondsSinceEpoch;

  RuleStatus status(String key, {required bool disabled}) {
    final now = _now;
    final until = timers[key];
    if (until != null) {
      if (until <= now) return RuleStatus.allowed;
      return (pauses[key] ?? 0) > now ? RuleStatus.paused : RuleStatus.timed;
    }
    return disabled ? RuleStatus.allowed : RuleStatus.permanent;
  }

  RuleStatus siteStatus(String e) => status(siteKey(e), disabled: disabledEntries.contains(e));
  RuleStatus appStatus(String p) => status(appKey(p), disabled: disabledApps.contains(p));
  RuleStatus listStatus(String id) => status(listKey(id), disabled: disabledLists.contains(id));

  DateTime? timerEnd(String key) {
    final t = timers[key];
    return t == null || t <= _now ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  DateTime? cancelEnd(String key) {
    final t = cancelUntil[key];
    return t == null || t <= _now ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  DateTime? pauseEnd(String key) {
    final t = pauses[key];
    return t == null || t <= _now ? null : DateTime.fromMillisecondsSinceEpoch(t);
  }

  /// Koľko dočasných odblokovaní ešte dnes zostáva (null = bez limitu).
  int unblocksLeft(String key) => (unblockPerDay - (pauseUsed[key] ?? 0)).clamp(0, 999);

  /// Je dočasné odblokovanie povolené? (v nastaveniach nie je "Nikdy")
  bool get unblockAllowed => unblockPerDay > 0;

  /// Do kedy je zamknutá ochrana – kým beží akékoľvek časové blokovanie.
  DateTime? get lockedUntil {
    final now = _now;
    final ends = timers.values.where((t) => t > now);
    if (ends.isEmpty) return null;
    return DateTime.fromMillisecondsSinceEpoch(ends.reduce((a, b) => a > b ? a : b));
  }

  bool get isLocked => lockedUntil != null;

  /// Stránky a aplikácie, ktoré sa práve naozaj blokujú (jednotlivo aj zo zoznamov).
  Set<String> get effectiveSites => {
        ...entries.where((e) => siteStatus(e).blocking),
        for (final l in lists)
          if (listStatus(l.id).blocking) ...l.sites,
      };

  Set<String> get effectiveApps => {
        ...apps.where((a) => appStatus(a).blocking),
        for (final l in lists)
          if (listStatus(l.id).blocking) ...l.apps,
      };

  static Map<String, int> _intMap(Object? raw) => {
        for (final e in ((raw as Map?) ?? const {}).entries)
          e.key as String: (e.value as num).toInt(),
      };

  factory BlockerState.fromMap(Map<dynamic, dynamic> map) => BlockerState(
        entries: List<String>.from(map['entries'] as List? ?? const []),
        apps: List<String>.from(map['apps'] as List? ?? const []),
        lists: [
          for (final m in (map['lists'] as List? ?? const []).cast<Map<dynamic, dynamic>>())
            BlockList.fromMap(m),
        ],
        disabledEntries: Set<String>.from(map['disabledEntries'] as List? ?? const []),
        disabledApps: Set<String>.from(map['disabledApps'] as List? ?? const []),
        disabledLists: Set<String>.from(map['disabledLists'] as List? ?? const []),
        timers: _intMap(map['timers']),
        pauses: _intMap(map['pauses']),
        cancelUntil: _intMap(map['cancelUntil']),
        pauseUsed: _intMap(map['pauseUsed']),
        unblockMinutes: (map['unblockMinutes'] as int?) ?? 15,
        unblockPerDay: (map['unblockPerDay'] as int?) ?? 3,
        uninstallProtection: map['uninstallProtection'] == true,
        vpnRunning: map['vpnRunning'] == true,
        accessibilityEnabled: map['accessibilityEnabled'] == true,
        accessibilityServiceOn: map['accessibilityServiceOn'] == true,
        blockedCount: (map['blockedCount'] as int?) ?? 0,
      );

  BlockerState copyWith({
    List<String>? entries,
    List<String>? apps,
    List<BlockList>? lists,
    Set<String>? disabledEntries,
    Set<String>? disabledApps,
    Set<String>? disabledLists,
    Map<String, int>? timers,
  }) =>
      BlockerState(
        entries: entries ?? this.entries,
        apps: apps ?? this.apps,
        lists: lists ?? this.lists,
        disabledEntries: disabledEntries ?? this.disabledEntries,
        disabledApps: disabledApps ?? this.disabledApps,
        disabledLists: disabledLists ?? this.disabledLists,
        timers: timers ?? this.timers,
        pauses: pauses,
        cancelUntil: cancelUntil,
        pauseUsed: pauseUsed,
        unblockMinutes: unblockMinutes,
        unblockPerDay: unblockPerDay,
        uninstallProtection: uninstallProtection,
        vpnRunning: vpnRunning,
        accessibilityEnabled: accessibilityEnabled,
        accessibilityServiceOn: accessibilityServiceOn,
        blockedCount: blockedCount,
      );
}

/// Nainštalovaná aplikácia, ktorú možno zablokovať.
class InstalledApp {
  const InstalledApp({required this.package, required this.label, this.icon});

  final String package;
  final String label;
  final Uint8List? icon;
}

/// Výsledok dočasného odblokovania.
class PauseResult {
  const PauseResult(this.ok, this.reason, this.state);

  final bool ok;

  /// "limit" = dnešný limit vyčerpaný.
  final String? reason;
  final BlockerState state;
}

/// Most medzi Flutter UI a natívnymi službami (zatiaľ len Android).
class BlockerApi {
  static const _channel = MethodChannel('sk.webostudio.web_blocker/blocker');

  static bool get isSupported => Platform.isAndroid;

  // Na nepodporovaných platformách držíme zoznam iba v pamäti.
  static BlockerState _fallback = const BlockerState();

  static Future<BlockerState> _call(String method, [Map<String, Object?>? args]) async {
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(method, args);
    return BlockerState.fromMap(map ?? const {});
  }

  static Future<BlockerState> getState() async {
    if (!isSupported) return _fallback;
    return _call('getState');
  }

  static Future<BlockerState> setEntries(List<String> entries) async {
    if (!isSupported) return _fallback = _fallback.copyWith(entries: entries);
    return _call('setEntries', {'entries': entries});
  }

  static Future<BlockerState> setApps(List<String> apps) async {
    if (!isSupported) return _fallback = _fallback.copyWith(apps: apps);
    return _call('setApps', {'apps': apps});
  }

  static Future<BlockerState> setLists(List<BlockList> lists) async {
    if (!isSupported) return _fallback = _fallback.copyWith(lists: lists);
    return _call('setLists', {'lists': [for (final l in lists) l.toMap()]});
  }

  static Future<BlockerState> setDisabled({
    Set<String>? entries,
    Set<String>? apps,
    Set<String>? lists,
  }) async {
    if (!isSupported) {
      return _fallback = _fallback.copyWith(
          disabledEntries: entries, disabledApps: apps, disabledLists: lists);
    }
    return _call('setDisabled', {
      if (entries != null) 'entries': entries.toList(),
      if (apps != null) 'apps': apps.toList(),
      if (lists != null) 'lists': lists.toList(),
    });
  }

  /// Časové blokovanie do [until]. Bežiace blokovanie sa dá iba predĺžiť.
  static Future<BlockerState> setTimer(String key, DateTime until) async {
    if (!isSupported) {
      return _fallback = _fallback.copyWith(
          timers: {..._fallback.timers, key: until.millisecondsSinceEpoch});
    }
    return _call('setTimer', {'key': key, 'until': until.millisecondsSinceEpoch});
  }

  /// Dočasné odblokovanie časového pravidla (dĺžka a limit podľa nastavení).
  /// Zruší časové blokovanie do 10 minút od spustenia. ok=false, ak je už neskoro.
  static Future<PauseResult> cancelTimer(String key) async {
    if (!isSupported) return PauseResult(false, 'unsupported', _fallback);
    final m =
        await _channel.invokeMethod<Map<dynamic, dynamic>>('cancelTimer', {'key': key}) ?? const {};
    return PauseResult(m['ok'] == true, m['ok'] == true ? null : 'tooLate',
        BlockerState.fromMap(m['state'] as Map? ?? const {}));
  }

  static Future<PauseResult> pause(String key) async {
    if (!isSupported) return PauseResult(false, 'unsupported', _fallback);
    final m = await _channel.invokeMethod<Map<dynamic, dynamic>>('pause', {'key': key}) ?? const {};
    return PauseResult(m['ok'] == true, m['reason'] as String?,
        BlockerState.fromMap(m['state'] as Map? ?? const {}));
  }

  /// Zapne/vypne ochranu proti odinštalovaniu. Vráti výsledný stav.
  /// Vyhodí PlatformException('locked'), ak beží časové blokovanie.
  static Future<bool> setUninstallProtection(bool enabled) async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('setUninstallProtection', {'enabled': enabled}) ?? false;
  }


  // Na nepodporovaných platformách nastavenia iba v pamäti.
  static final Map<String, String> _fallbackSettings = {};

  static Future<Map<String, String>> getSettings() async {
    if (!isSupported) return Map.of(_fallbackSettings);
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSettings') ?? const {};
    return map.map((k, v) => MapEntry(k as String, v as String));
  }

  /// Vráti `false`, ak sa nastavenie teraz meniť nedá (počas časového blokovania).
  static Future<bool> setSetting(String key, String? value) async {
    if (!isSupported) {
      value == null ? _fallbackSettings.remove(key) : _fallbackSettings[key] = value;
      return true;
    }
    return await _channel.invokeMethod<bool>('setSetting', {'key': key, 'value': value}) ?? true;
  }

  static Future<List<InstalledApp>> getInstalledApps() async {
    if (!isSupported) return const [];
    final list = await _channel.invokeMethod<List<dynamic>>('getInstalledApps') ?? const [];
    return [
      for (final m in list.cast<Map<dynamic, dynamic>>())
        InstalledApp(
          package: m['package'] as String,
          label: m['label'] as String,
          icon: m['icon'] as Uint8List?,
        ),
    ];
  }

  /// Vráti `false`, ak používateľ nepovolil VPN.
  static Future<bool> startVpn() async {
    if (!isSupported) return false;
    return await _channel.invokeMethod<bool>('startVpn') ?? false;
  }

  /// Vyhodí PlatformException('locked'), ak beží časové blokovanie.
  static Future<void> stopVpn() async {
    if (!isSupported) return;
    await _channel.invokeMethod('stopVpn');
  }

  /// Vypnutie vyhodí PlatformException('locked'), ak beží časové blokovanie.
  static Future<void> setAccessibility(bool enabled) async {
    if (!isSupported) return;
    await _channel.invokeMethod('setAccessibility', {'enabled': enabled});
  }

  static Future<void> openAccessibilitySettings() async {
    if (!isSupported) return;
    await _channel.invokeMethod('openAccessibilitySettings');
  }
}

/// "https://www.Facebook.com/" -> "facebook.com", "youtube.com/shorts/" -> "youtube.com/shorts".
/// Vráti `null`, ak vstup nevyzerá ako webová adresa.
String? normalizeEntry(String raw) {
  var s = raw.trim().toLowerCase();
  final scheme = s.indexOf('://');
  if (scheme >= 0) s = s.substring(scheme + 3);
  s = s.split('?').first.split('#').first;
  if (s.startsWith('www.')) s = s.substring(4);
  while (s.endsWith('/')) {
    s = s.substring(0, s.length - 1);
  }
  final slash = s.indexOf('/');
  final host = (slash >= 0 ? s.substring(0, slash) : s).split(':').first;
  final path = slash >= 0 ? s.substring(slash) : '';
  final validHost = RegExp(r'^([a-z0-9-]+\.)+[a-z0-9-]{2,}$');
  if (!validHost.hasMatch(host)) return null;
  return host + path;
}

bool entryHasPath(String entry) => entry.contains('/');
