import 'package:flutter_test/flutter_test.dart';
import 'package:web_blocker/blocker_api.dart';
import 'package:web_blocker/l10n.dart';

void main() {
  test('normalizeEntry upraví adresu na doménu', () {
    expect(normalizeEntry('https://www.Facebook.com/'), 'facebook.com');
    expect(normalizeEntry('  instagram.com  '), 'instagram.com');
    expect(normalizeEntry('m.youtube.com/shorts/?x=1'), 'm.youtube.com/shorts');
    expect(normalizeEntry('http://reddit.com:443/r/all#top'), 'reddit.com/r/all');
  });

  test('slovenské a anglické tvary čísloviek', () {
    const sk = S('sk'), en = S('en');
    expect(sk.apps(1), '1 aplikácia');
    expect(sk.apps(3), '3 aplikácie');
    expect(sk.apps(5), '5 aplikácií');
    expect(sk.sitesAcc(1), '1 stránku');
    expect(en.apps(1), '1 app');
    expect(en.apps(3), '3 apps');
    expect(en.sites(0), '0 sites');
  });

  test('normalizeEntry odmietne neplatný vstup', () {
    expect(normalizeEntry('facebook'), isNull);
    expect(normalizeEntry('ahoj svet'), isNull);
    expect(normalizeEntry(''), isNull);
  });
}
