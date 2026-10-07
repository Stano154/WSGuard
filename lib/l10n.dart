import 'package:flutter/widgets.dart';

/// Všetky texty aplikácie v slovenčine a angličtine.
/// Použitie: `final s = S.of(context); Text(s.addTitle)`.
class S {
  const S(this.lang);

  final String lang;

  bool get en => lang == 'en';

  static S of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<L10nScope>()?.strings ?? const S('sk');

  String _p(int n, String one, String few, String many) {
    if (n == 1) return one;
    if (!en && n >= 2 && n <= 4) return few;
    return many;
  }

  // ---- počty ----
  String wApps(int n) => en ? _p(n, 'app', '', 'apps') : _p(n, 'aplikácia', 'aplikácie', 'aplikácií');
  String wSites(int n) => en ? _p(n, 'site', '', 'sites') : _p(n, 'stránka', 'stránky', 'stránok');
  String wBlocks(int n) =>
      en ? _p(n, 'block', '', 'blocks') : _p(n, 'zablokovanie', 'zablokovania', 'zablokovaní');
  String apps(int n) => '$n ${wApps(n)}';
  String sites(int n) => '$n ${wSites(n)}';
  String appsAcc(int n) =>
      en ? apps(n) : '$n ${_p(n, 'aplikáciu', 'aplikácie', 'aplikácií')}';
  String sitesAcc(int n) => en ? sites(n) : '$n ${_p(n, 'stránku', 'stránky', 'stránok')}';
  String and(List<String> parts) => parts.join(en ? ' and ' : ' a ');

  // ---- hlavná obrazovka ----
  String get settings => en ? 'Settings' : 'Nastavenia';
  String get add => en ? 'Add' : 'Pridať';
  String get protectionOn => en ? 'Protection is on' : 'Ochrana je zapnutá';
  String get protectionOff => en ? 'Protection is off' : 'Ochrana je vypnutá';
  String get offSubtitle =>
      en ? 'Apps and sites on your list can be opened' : 'Aplikácie a stránky zo zoznamu sa dajú otvoriť';
  String get addSomething => en ? 'Add what you want to block' : 'Pridaj, čo chceš blokovať';
  String blocking(String what) => en ? 'Blocking $what' : 'Blokujem $what';
  String get turnOn => en ? 'Turn on protection' : 'Zapnúť ochranu';
  String get turnOff => en ? 'Turn off protection' : 'Vypnúť ochranu';
  String get turnedOff => en ? 'Protection is off' : 'Ochrana je vypnutá';
  String get vpnDenied => en
      ? 'Without VPN permission sites can\'t be blocked device-wide'
      : 'Bez povolenia VPN nie je možné blokovať celé zariadenie';
  String get unsupported =>
      en ? 'Blocking is available on Android only for now' : 'Blokovanie je zatiaľ dostupné iba na Androide';
  String get iosBanner => en
      ? 'Blocking doesn\'t work on this device yet. The iOS version is coming.'
      : 'Na tomto zariadení zatiaľ blokovanie nefunguje. Verzia pre iOS je v príprave.';
  String added(String what) => en ? 'Added: $what' : 'Pridané: $what';
  String addedTurnOn(String what) =>
      en ? 'Added: $what. Don\'t forget to turn on protection 👆' : 'Pridané: $what. Nezabudni zapnúť ochranu 👆';
  String removed(String what) => en ? '$what removed from the list' : '$what odstránená zo zoznamu';
  String get undo => en ? 'Undo' : 'Späť';
  String paused(String what) => en ? '$what is not blocked now' : '$what sa teraz neblokuje';
  String resumed(String what) => en ? '$what is blocked again' : '$what sa znova blokuje';

  // ---- spôsoby blokovania ----
  String get methods => en ? 'Blocking methods' : 'Spôsob blokovania';
  String get vpnTitle => en ? 'Sites on the whole device' : 'Stránky v celom zariadení';
  String get vpnSubtitle => en
      ? 'Blocks sites in all browsers. Uses a local VPN – your data never leaves the phone.'
      : 'Blokuje stránky vo všetkých prehliadačoch. Používa lokálnu VPN – tvoje dáta nikam neodchádzajú.';
  String get a11yTitle => en ? 'Apps and browsers' : 'Aplikácie a prehliadače';
  String get a11ySubtitle => en
      ? 'Blocks apps (e.g. Instagram) and parts of sites like youtube.com/shorts, and shows a warning.'
      : 'Blokuje aplikácie (napr. Instagram) aj časti stránok, napr. youtube.com/shorts, a zobrazí upozornenie.';
  String get a11yNeedsSettings =>
      en ? 'Still needs to be allowed in Settings → Accessibility' : 'Treba ešte povoliť v Nastaveniach → Prístupnosť';

  // ---- dialóg prístupnosti ----
  String get a11yDialogTitle => en ? 'Allow the accessibility service' : 'Povoľ službu prístupnosti';
  String get a11yDialogBody => en
      ? 'To know which app or site you are opening, WSGuard needs the accessibility service.\n\n'
          '1. Tap “Open settings”\n'
          '2. Find “WSGuard” (often under Downloaded apps)\n'
          '3. Turn it on and confirm\n\n'
          'WSGuard only reads the name of the open app and the address in the browser. Nothing is sent anywhere.'
      : 'Aby WSGuard vedel, ktorú aplikáciu alebo stránku práve otváraš, treba mu povoliť službu prístupnosti.\n\n'
          '1. Klepni na „Otvoriť nastavenia“\n'
          '2. Nájdi „WSGuard“ (často v časti Stiahnuté aplikácie)\n'
          '3. Zapni ho a potvrď\n\n'
          'WSGuard zisťuje iba názov otvorenej aplikácie a adresu v prehliadači. Nič nikam neodosiela.';
  String get cancel => en ? 'Cancel' : 'Zrušiť';
  String get openSettings => en ? 'Open settings' : 'Otvoriť nastavenia';

  // ---- zoznam ----
  String get whatIBlock => en ? 'What I block' : 'Čo blokujem';
  String get filterAll => en ? 'All' : 'Všetko';
  String get filterApps => en ? 'Apps' : 'Aplikácie';
  String get filterSites => en ? 'Sites' : 'Stránky';
  String get groupApps => en ? 'Apps' : 'Aplikácie';
  String get groupSites => en ? 'Websites' : 'Webové stránky';
  String get app => en ? 'App' : 'Aplikácia';
  String get appMissing => en ? 'App is not installed' : 'Aplikácia nie je nainštalovaná';
  String get pathOnly => en ? 'Only this part of the site' : 'Iba táto časť stránky';
  String get wholeSite => en ? 'Whole site incl. subdomains' : 'Celá stránka vrátane subdomén';
  String get statusBlocked => en ? 'Blocked' : 'Blokované';
  String get statusInactive => en ? 'Inactive' : 'Neaktívne';
  String get statusAllowed => en ? 'Allowed' : 'Povolené';
  String get remove => en ? 'Remove' : 'Odstrániť';
  String get toggleTooltip => en ? 'Block / allow' : 'Blokovať / povoliť';
  String get noticeOff =>
      en ? 'Protection is off – nothing on the list is blocked now.' : 'Ochrana je vypnutá – nič zo zoznamu sa teraz neblokuje.';
  String noticeInactive(String what, {required bool many}) => en
      ? '$what ${many ? 'are' : 'is'} not blocked. Turn on “Apps and browsers”.'
      : '$what sa ${many ? 'neblokujú' : 'neblokuje'}. Zapni režim „Aplikácie a prehliadače“.';
  String get turnOnShort => en ? 'Turn on' : 'Zapnúť';
  String get noApps => en ? 'You don\'t block any app yet.' : 'Zatiaľ neblokuješ žiadnu aplikáciu.';
  String get noSites => en ? 'You don\'t block any site yet.' : 'Zatiaľ neblokuješ žiadnu stránku.';
  String get addApp => en ? 'Add app' : 'Pridať aplikáciu';
  String get addSite => en ? 'Add site' : 'Pridať stránku';
  String get emptyTitle => en ? 'Nothing blocked yet' : 'Zatiaľ nič neblokuješ';
  String get emptyBody => en
      ? 'Add apps or sites that distract you – social networks, for example.'
      : 'Pridaj aplikácie alebo stránky, ktoré ťa rozptyľujú – napríklad sociálne siete.';
  String get emptyApp => en ? 'App' : 'Aplikáciu';
  String get emptySite => en ? 'Site' : 'Stránku';

  // ---- pridávanie ----
  String get addTitle => en ? 'Add to block list' : 'Pridať do blokovania';
  String get kindSite => en ? 'Site' : 'Stránka';
  String get kindApp => en ? 'App' : 'Aplikácia';
  String get siteHint => en ? 'e.g. instagram.com' : 'napr. instagram.com';
  String get siteTip => en
      ? 'Tip: “youtube.com/shorts” blocks only Shorts (in Apps and browsers mode).'
      : 'Tip: „youtube.com/shorts“ zablokuje iba Shorts (v režime Aplikácie a prehliadače).';
  String get popular => en ? 'Popular' : 'Obľúbené';
  String get popularHint => en
      ? 'Blocks the site and the app too, if it is installed.'
      : 'Zablokuje sa stránka aj aplikácia, ak ju máš nainštalovanú.';
  String get invalidSite =>
      en ? 'This doesn\'t look like a web address (e.g. instagram.com)' : 'Toto nevyzerá ako webová adresa (napr. instagram.com)';
  String alreadyListed(String e) => en ? '$e is already on your list' : '$e už v zozname máš';
  String get pickSomething =>
      en ? 'Type an address or pick something from Popular' : 'Napíš adresu alebo vyber niečo z obľúbených';
  String get pickApp => en ? 'Pick at least one app' : 'Vyber aspoň jednu aplikáciu';
  String get searchApp => en ? 'Search apps' : 'Hľadať aplikáciu';
  String get nothingFound => en ? 'Nothing found' : 'Nič sa nenašlo';
  String get alreadyBlocked => en ? 'Already blocked' : 'Už je blokovaná';
  String get block => en ? 'Block' : 'Blokovať';

  // ---- nastavenia ----
  String get appearance => en ? 'Appearance' : 'Vzhľad';
  String get theme => en ? 'Theme' : 'Téma';
  String get themeLight => en ? 'Light' : 'Svetlý';
  String get themeSystem => en ? 'System' : 'Systém';
  String get themeDark => en ? 'Dark' : 'Tmavý';
  String get language => en ? 'Language' : 'Jazyk';
  String get security => en ? 'Security' : 'Zabezpečenie';
  String get lockApp => en ? 'Lock app with password' : 'Zamknúť aplikáciu heslom';
  String get lockAppHint => en
      ? 'Asks for the password when opening WSGuard, so nobody else can turn off blocking.'
      : 'Pri otvorení WSGuard bude treba zadať heslo, aby blokovanie nikto iný nevypol.';
  String get changePassword => en ? 'Change password' : 'Zmeniť heslo';
  String get about => en ? 'About' : 'O aplikácii';
  String get aboutBody => en
      ? 'Blocks distracting apps and websites. Everything runs on your phone, no data is sent anywhere.'
      : 'Blokuje rozptyľujúce aplikácie a webové stránky. Všetko beží v tvojom telefóne, žiadne dáta sa nikam neposielajú.';
  String get version => en ? 'Version' : 'Verzia';

  // ---- heslo ----
  String get setPassword => en ? 'Set password' : 'Nastaviť heslo';
  String get newPassword => en ? 'New password' : 'Nové heslo';
  String get repeatPassword => en ? 'Repeat password' : 'Zopakuj heslo';
  String get currentPassword => en ? 'Current password' : 'Súčasné heslo';
  String get passwordTooShort => en ? 'At least 4 characters' : 'Aspoň 4 znaky';
  String get passwordsDontMatch => en ? 'Passwords don\'t match' : 'Heslá sa nezhodujú';
  String get wrongPassword => en ? 'Wrong password' : 'Nesprávne heslo';
  String get save => en ? 'Save' : 'Uložiť';
  String get confirm => en ? 'Confirm' : 'Potvrdiť';
  String get passwordSet => en ? 'Password set – WSGuard is locked' : 'Heslo je nastavené – WSGuard je zamknutý';
  String get passwordRemoved => en ? 'Password removed' : 'Heslo bolo zrušené';
  String get passwordChanged => en ? 'Password changed' : 'Heslo bolo zmenené';
  String get removePasswordTitle => en ? 'Remove password' : 'Zrušiť heslo';
  String get lockedTitle => en ? 'WSGuard is locked' : 'WSGuard je zamknutý';
  String get lockedHint => en ? 'Enter the password to continue' : 'Zadaj heslo na pokračovanie';
  String get password => en ? 'Password' : 'Heslo';
  String get unlock => en ? 'Unlock' : 'Odomknúť';
}

/// Sprístupní texty v aktuálnom jazyku celému stromu widgetov.
class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.strings, required super.child});

  final S strings;

  @override
  bool updateShouldNotify(L10nScope oldWidget) => oldWidget.strings.lang != strings.lang;
}
