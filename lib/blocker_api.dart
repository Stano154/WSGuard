import 'dart:io';

import 'package:flutter/services.dart';

/// Stav blokovania, ako ho hlási natívna časť aplikácie.
class BlockerState {
  const BlockerState({
    this.entries = const [],
    this.apps = const [],
    this.disabledEntries = const {},
    this.disabledApps = const {},
    this.vpnRunning = false,
    this.accessibilityEnabled = false,
    this.accessibilityServiceOn = false,
    this.blockedCount = 0,
  });

  /// Zablokované stránky ("domena.sk" alebo "domena.sk/cesta").
  final List<String> entries;

  /// Zablokované aplikácie (názvy balíkov, napr. com.instagram.android).
  final List<String> apps;

  /// Položky, ktoré sú v zozname, ale dočasne sa neblokujú (vypínač pri položke).
  final Set<String> disabledEntries;
  final Set<String> disabledApps;
  final bool vpnRunning;

  /// Používateľ zapol režim "Prehliadače a aplikácie" v aplikácii.
  final bool accessibilityEnabled;

  /// Služba prístupnosti je povolená v systémových nastaveniach.
  final bool accessibilityServiceOn;
  final int blockedCount;

  bool get accessibilityActive => accessibilityEnabled && accessibilityServiceOn;
  bool get isProtected => vpnRunning || accessibilityActive;
  int get totalCount => entries.length + apps.length;
  int get activeSites => entries.where((e) => !disabledEntries.contains(e)).length;
  int get activeApps => apps.where((a) => !disabledApps.contains(a)).length;

  factory BlockerState.fromMap(Map<dynamic, dynamic> map) => BlockerState(
        entries: List<String>.from(map['entries'] as List? ?? const []),
        apps: List<String>.from(map['apps'] as List? ?? const []),
        disabledEntries: Set<String>.from(map['disabledEntries'] as List? ?? const []),
        disabledApps: Set<String>.from(map['disabledApps'] as List? ?? const []),
        vpnRunning: map['vpnRunning'] == true,
        accessibilityEnabled: map['accessibilityEnabled'] == true,
        accessibilityServiceOn: map['accessibilityServiceOn'] == true,
        blockedCount: (map['blockedCount'] as int?) ?? 0,
      );

  BlockerState copyWith({
    List<String>? entries,
    List<String>? apps,
    Set<String>? disabledEntries,
    Set<String>? disabledApps,
  }) =>
      BlockerState(
        entries: entries ?? this.entries,
        apps: apps ?? this.apps,
        disabledEntries: disabledEntries ?? this.disabledEntries,
        disabledApps: disabledApps ?? this.disabledApps,
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

/// Most medzi Flutter UI a natívnymi službami (zatiaľ len Android).
class BlockerApi {
  static const _channel = MethodChannel('sk.webostudio.web_blocker/blocker');

  static bool get isSupported => Platform.isAndroid;

  // Na nepodporovaných platformách držíme zoznam iba v pamäti.
  static BlockerState _fallback = const BlockerState();

  static Future<BlockerState> getState() async {
    if (!isSupported) return _fallback;
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getState');
    return BlockerState.fromMap(map ?? const {});
  }

  static Future<BlockerState> setEntries(List<String> entries) async {
    if (!isSupported) return _fallback = _fallback.copyWith(entries: entries);
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setEntries',
      {'entries': entries},
    );
    return BlockerState.fromMap(map ?? const {});
  }

  static Future<BlockerState> setApps(List<String> apps) async {
    if (!isSupported) return _fallback = _fallback.copyWith(apps: apps);
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('setApps', {'apps': apps});
    return BlockerState.fromMap(map ?? const {});
  }

  static Future<BlockerState> setDisabled(Set<String> entries, Set<String> apps) async {
    if (!isSupported) {
      return _fallback = _fallback.copyWith(disabledEntries: entries, disabledApps: apps);
    }
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>(
      'setDisabled',
      {'entries': entries.toList(), 'apps': apps.toList()},
    );
    return BlockerState.fromMap(map ?? const {});
  }

  // Na nepodporovaných platformách nastavenia iba v pamäti.
  static final Map<String, String> _fallbackSettings = {};

  static Future<Map<String, String>> getSettings() async {
    if (!isSupported) return Map.of(_fallbackSettings);
    final map = await _channel.invokeMethod<Map<dynamic, dynamic>>('getSettings') ?? const {};
    return map.map((k, v) => MapEntry(k as String, v as String));
  }

  static Future<void> setSetting(String key, String? value) async {
    if (!isSupported) {
      value == null ? _fallbackSettings.remove(key) : _fallbackSettings[key] = value;
      return;
    }
    await _channel.invokeMethod('setSetting', {'key': key, 'value': value});
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

  static Future<void> stopVpn() async {
    if (!isSupported) return;
    await _channel.invokeMethod('stopVpn');
  }

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
