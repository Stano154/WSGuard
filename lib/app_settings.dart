import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/material.dart';

import 'blocker_api.dart';
import 'l10n.dart';

/// Nastavenia aplikácie: jazyk, téma a heslo. Ukladajú sa v natívnej časti,
/// aby ich videla aj obrazovka "zablokované".
class AppSettings extends ChangeNotifier {
  String _language = 'sk';
  ThemeMode _themeMode = ThemeMode.system;
  String? _passwordHash;
  String? _passwordSalt;

  String get language => _language;
  ThemeMode get themeMode => _themeMode;
  bool get hasPassword => _passwordHash != null;
  S get strings => S(_language);

  Future<void> load() async {
    final map = await BlockerApi.getSettings();
    _language = map['language'] == 'en' ? 'en' : 'sk';
    _themeMode = switch (map['theme']) {
      'light' => ThemeMode.light,
      'dark' => ThemeMode.dark,
      _ => ThemeMode.system,
    };
    _passwordHash = map['passwordHash'];
    _passwordSalt = map['passwordSalt'];
    notifyListeners();
  }

  Future<void> setLanguage(String lang) async {
    _language = lang;
    notifyListeners();
    await BlockerApi.setSetting('language', lang);
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    _themeMode = mode;
    notifyListeners();
    await BlockerApi.setSetting('theme', mode.name);
  }

  // ---- heslo (ukladá sa iba SHA-256 odtlačok so soľou, nie samotné heslo) ----

  static String _hash(String salt, String password) =>
      sha256.convert(utf8.encode('$salt:$password')).toString();

  bool verifyPassword(String password) =>
      _passwordHash != null && _hash(_passwordSalt ?? '', password) == _passwordHash;

  Future<void> setPassword(String password) async {
    final random = Random.secure();
    _passwordSalt = base64Url.encode(List.generate(16, (_) => random.nextInt(256)));
    _passwordHash = _hash(_passwordSalt!, password);
    notifyListeners();
    await BlockerApi.setSetting('passwordSalt', _passwordSalt);
    await BlockerApi.setSetting('passwordHash', _passwordHash);
  }

  Future<void> clearPassword() async {
    _passwordHash = null;
    _passwordSalt = null;
    notifyListeners();
    await BlockerApi.setSetting('passwordHash', null);
    await BlockerApi.setSetting('passwordSalt', null);
  }
}

/// Jediná inštancia nastavení pre celú aplikáciu.
final appSettings = AppSettings();
