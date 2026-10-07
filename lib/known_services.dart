import 'package:flutter/material.dart';

/// Známe služby – pekný názov, farba a balíky ich aplikácií.
class KnownService {
  const KnownService(this.name, this.domain, this.color, {this.packages = const []});

  final String name;
  final String domain;
  final Color color;

  /// Aplikácie tejto služby – pri rýchlom výbere sa zablokujú tiež (ak sú nainštalované).
  final List<String> packages;

  Color get onColor =>
      ThemeData.estimateBrightnessForColor(color) == Brightness.dark ? Colors.white : Colors.black;
}

const knownServices = [
  KnownService('Instagram', 'instagram.com', Color(0xFFE1306C),
      packages: ['com.instagram.android', 'com.instagram.lite']),
  KnownService('Facebook', 'facebook.com', Color(0xFF1877F2),
      packages: ['com.facebook.katana', 'com.facebook.lite']),
  KnownService('TikTok', 'tiktok.com', Color(0xFF111111),
      packages: ['com.zhiliaoapp.musically', 'com.ss.android.ugc.trill', 'com.zhiliaoapp.musically.go']),
  KnownService('YouTube', 'youtube.com', Color(0xFFFF0000),
      packages: ['com.google.android.youtube']),
  KnownService('YouTube Shorts', 'youtube.com/shorts', Color(0xFFFF0000)),
  KnownService('X / Twitter', 'x.com', Color(0xFF14171A), packages: ['com.twitter.android']),
  KnownService('Reddit', 'reddit.com', Color(0xFFFF4500), packages: ['com.reddit.frontpage']),
  KnownService('Netflix', 'netflix.com', Color(0xFFE50914), packages: ['com.netflix.mediaclient']),
  KnownService('Twitch', 'twitch.tv', Color(0xFF9146FF), packages: ['tv.twitch.android.app']),
  KnownService('Snapchat', 'snapchat.com', Color(0xFFFFFC00), packages: ['com.snapchat.android']),
  KnownService('Pinterest', 'pinterest.com', Color(0xFFE60023), packages: ['com.pinterest']),
];

KnownService? serviceForDomain(String entry) {
  for (final s in knownServices) {
    if (s.domain == entry) return s;
  }
  return null;
}
