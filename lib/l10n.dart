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

  // ---- čas ----
  /// "2 h 15 min", "3 d 4 h", "45 min", "< 1 min"
  String duration(Duration d) {
    if (d.inMinutes < 1) return '< 1 min';
    final days = d.inDays, hours = d.inHours % 24, mins = d.inMinutes % 60;
    if (days > 0) return hours > 0 ? '$days d $hours h' : '$days d';
    if (d.inHours > 0) return mins > 0 ? '${d.inHours} h $mins min' : '${d.inHours} h';
    return '${d.inMinutes} min';
  }

  /// "dnes 18:30", "zajtra 9:05", "14. 10. 18:30" / "today 18:30", "Oct 14, 18:30"
  String dateTime(DateTime t) {
    final now = DateTime.now();
    final time = '${t.hour}:${t.minute.toString().padLeft(2, '0')}';
    final day = DateTime(t.year, t.month, t.day);
    final today = DateTime(now.year, now.month, now.day);
    final diff = day.difference(today).inDays;
    if (diff == 0) return en ? 'today $time' : 'dnes $time';
    if (diff == 1) return en ? 'tomorrow $time' : 'zajtra $time';
    const months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];
    return en ? '${months[t.month - 1]} ${t.day}, $time' : '${t.day}. ${t.month}. $time';
  }

  // ---- časové blokovanie ----
  String get hour1 => en ? '1 hour' : '1 hodina';
  String get day1 => en ? '1 day' : '1 deň';
  String get week1 => en ? '1 week' : '1 týždeň';
  String get customTime => en ? 'Custom…' : 'Vlastný čas…';
  String until(DateTime t) => en ? 'until ${dateTime(t)}' : 'do ${dateTime(t)}';
  String get blockForTime => en ? 'Block for a time' : 'Zablokovať na čas';
  String get extendBlock => en ? 'Extend blocking' : 'Predĺžiť blokovanie';
  String onlyLonger(DateTime end) => en
      ? 'blocked until ${dateTime(end)}, can only be extended'
      : 'blokované do ${dateTime(end)}, dá sa iba predĺžiť';
  String get shorterThanCurrent =>
      en ? 'Shorter than the current block' : 'Kratšie ako bežiace blokovanie';
  String mustBeLonger(DateTime end) => en
      ? 'Pick a time after ${dateTime(end)} – blocking can only be extended'
      : 'Zvoľ čas po ${dateTime(end)} – blokovanie sa dá iba predĺžiť';
  String get pickFuture => en ? 'Pick a time in the future' : 'Zvoľ čas v budúcnosti';
  String get timedConfirmTitle => en ? 'Start timed blocking?' : 'Spustiť časové blokovanie?';
  String timedConfirmBody(DateTime end, int minutes, int perDay) {
    final unblock = perDay <= 0
        ? (en
            ? 'Temporary unblocking is off (set to “Never” in settings).'
            : 'Dočasne odblokovať sa nedá (v nastaveniach je „Nikdy“).')
        : (en
            ? 'You can unblock it for $minutes min, at most $perDay× a day.'
            : 'Dočasne odblokovať sa dá na $minutes min, najviac $perDay× za deň.');
    return en
        ? 'Until ${dateTime(end)} this block can\'t be turned off, shortened or removed, and WSGuard '
            'protection can\'t be turned off either.\n\n$unblock\n\n'
            'Changed your mind? You can cancel it within 10 minutes.'
        : 'Do ${dateTime(end)} sa toto blokovanie nedá vypnúť, skrátiť ani odstrániť a nedá sa vypnúť '
            'ani ochrana WSGuard.\n\n$unblock\n\n'
            'Ak si to rozmyslíš, do 10 minút ho ešte môžeš zrušiť.';
  }

  String cancelTimerButton(Duration left) =>
      en ? 'Cancel block · ${duration(left)} left' : 'Zrušiť blokovanie · ešte ${duration(left)}';
  String get cancelTimerTitle => en ? 'Cancel timed blocking?' : 'Zrušiť časové blokovanie?';
  String cancelTimerBody(String name) => en
      ? '$name goes back to how it was before you started the timed blocking.'
      : '$name sa vráti do stavu pred spustením časového blokovania.';
  String get cancelTimerConfirm => en ? 'Cancel blocking' : 'Zrušiť blokovanie';
  String get keepBlocking => en ? 'Keep' : 'Ponechať';
  String timerCancelled(String name) =>
      en ? 'Timed blocking of $name was cancelled' : 'Časové blokovanie – $name – bolo zrušené';
  String get cancelTooLate => en
      ? 'Too late – more than 10 minutes have passed'
      : 'Už je neskoro – od spustenia uplynulo viac ako 10 minút';

  String get start => en ? 'Start' : 'Spustiť';
  String statusTimed(Duration left) => en ? 'Blocked · ${duration(left)} left' : 'Blokované ešte ${duration(left)}';
  String statusPaused(Duration left) =>
      en ? 'Unblocked · ${duration(left)} left' : 'Odblokované ešte ${duration(left)}';
  String unblockFor(int minutes) => en ? 'Unblock for $minutes min' : 'Odblokovať na $minutes min';
  String unblocksLeft(int n) => en ? '$n× left' : 'ešte $n×';
  String get unblockLimit =>
      en ? 'Today\'s unblock limit is used up' : 'Dnešný limit odblokovaní je vyčerpaný';
  String unblocked(String name, int minutes) =>
      en ? '$name is unblocked for $minutes min' : '$name je odblokované na $minutes min';
  String get remindTurnOn =>
      en ? 'Don\'t forget to turn on protection 👆' : 'Nezabudni zapnúť ochranu 👆';
  String timedStarted(String name, DateTime end) =>
      en ? '$name is blocked until ${dateTime(end)}' : '$name je zablokované do ${dateTime(end)}';
  String lockedBanner(DateTime end) => en
      ? 'Timed blocking runs until ${dateTime(end)} – protection can\'t be turned off until then.'
      : 'Časové blokovanie beží do ${dateTime(end)} – ochrana sa dovtedy nedá vypnúť.';
  String lockedShort(DateTime end) => en ? 'Locked until ${dateTime(end)}' : 'Zamknuté do ${dateTime(end)}';
  String get lockedToast =>
      en ? 'This can\'t be changed during timed blocking' : 'Počas časového blokovania sa to nedá zmeniť';
  String get moreOptions => en ? 'More options' : 'Ďalšie možnosti';

  // ---- zoznamy ----
  String get lists => en ? 'Lists' : 'Zoznamy';
  String get listsHint =>
      en ? 'Group apps and sites and block them at once.' : 'Zoskup aplikácie a stránky a blokuj ich naraz.';
  String get newList => en ? 'New list' : 'Nový zoznam';
  String get editList => en ? 'Edit list' : 'Upraviť zoznam';
  String get listName => en ? 'List name' : 'Názov zoznamu';
  String get listNameHint => en ? 'e.g. Social media' : 'napr. Sociálne siete';
  String get nameRequired => en ? 'Enter a list name' : 'Zadaj názov zoznamu';
  String get listIcon => en ? 'Icon' : 'Ikona';
  String get listItemsTitle => en ? 'Items' : 'Položky';
  String get addItems => en ? 'Add items' : 'Pridať položky';
  String get listEmptyItems =>
      en ? 'The list is empty – add apps or sites.' : 'Zoznam je prázdny – pridaj aplikácie alebo stránky.';
  String listSummary(int apps, int sites) {
    if (apps + sites == 0) return en ? 'Empty' : 'Prázdny';
    return and([if (apps > 0) this.apps(apps), if (sites > 0) this.sites(sites)]);
  }

  String get templates => en ? 'Start from a template' : 'Začni zo šablóny';
  String get tplSocial => en ? 'Social media' : 'Sociálne siete';
  String get tplVideo => en ? 'Video & streaming' : 'Videá a streamovanie';
  String get tplEmpty => en ? 'Empty' : 'Prázdny';
  String get edit => en ? 'Edit' : 'Upraviť';
  String get deleteList => en ? 'Delete list' : 'Odstrániť zoznam';
  String listDeleted(String name) => en ? 'List “$name” deleted' : 'Zoznam „$name“ bol odstránený';
  String get listLockedEdit => en
      ? 'Timed blocking is running – items can only be added.'
      : 'Beží časové blokovanie – položky sa dajú iba pridávať.';
  String get noLists => en ? 'No lists yet' : 'Zatiaľ nemáš žiadny zoznam';

  // ---- nastavenia: dočasné odblokovanie ----
  String get tempUnblock => en ? 'Temporary unblock' : 'Dočasné odblokovanie';
  String get tempUnblockHint => en
      ? 'Applies to timed blocking. These settings can\'t be changed while timed blocking runs.'
      : 'Platí pre časové blokovanie. Kým časové blokovanie beží, tieto nastavenia sa meniť nedajú.';
  String get unblockLength => en ? 'Length' : 'Dĺžka';
  String get unblockPerDayLabel => en ? 'Times per day (per item)' : 'Koľkokrát za deň (pre položku)';
  String get never => en ? 'Never' : 'Nikdy';

  // ---- nastavenia: ochrana proti odinštalovaniu ----
  String get uninstallProtection => en ? 'Uninstall protection' : 'Ochrana proti odinštalovaniu';
  String get uninstallProtectionHint => en
      ? 'WSGuard can\'t be uninstalled or turned off in phone settings until you turn this off here with your password.'
      : 'WSGuard sa nedá odinštalovať ani vypnúť v nastaveniach telefónu, kým túto ochranu nevypneš tu heslom.';
  String get needsPassword => en ? 'Set a password first' : 'Najprv si nastav heslo';
  String get needsA11y => en
      ? 'For full protection also turn on “Apps and browsers” – it guards the phone settings.'
      : 'Pre úplnú ochranu zapni aj režim „Aplikácie a prehliadače“ – stráži nastavenia telefónu.';
  String get protectionOnToast =>
      en ? 'Uninstall protection is on' : 'Ochrana proti odinštalovaniu je zapnutá';
  String get protectionOffToast =>
      en ? 'Uninstall protection is off – WSGuard can be uninstalled' : 'Ochrana je vypnutá – WSGuard sa dá odinštalovať';
  String get protectionNotActivated =>
      en ? 'Protection was not activated' : 'Ochrana nebola aktivovaná';
  String get turnOffProtectionFirst =>
      en ? 'Turn off uninstall protection first' : 'Najprv vypni ochranu proti odinštalovaniu';
  String get uninstallGuideTitle => en ? 'How to uninstall WSGuard' : 'Ako odinštalovať WSGuard';
  String get uninstallGuideNormalTitle => en ? 'Normal way' : 'Bežný postup';
  String get uninstallGuideNormal => en
      ? '1. Wait until no timed blocking is running.\n'
          '2. In WSGuard settings turn off “Uninstall protection” and enter your password.\n'
          '3. Uninstall WSGuard as any other app (long-press the icon → Uninstall).'
      : '1. Počkaj, kým nebeží žiadne časové blokovanie.\n'
          '2. V nastaveniach WSGuard vypni „Ochrana proti odinštalovaniu“ a zadaj heslo.\n'
          '3. WSGuard odinštaluj ako každú inú aplikáciu (podrž ikonu → Odinštalovať).';
  String get uninstallGuideForgotTitle =>
      en ? 'Forgotten password' : 'Zabudnuté heslo';
  String get uninstallGuideForgot => en
      ? '1. Restart the phone into safe mode: hold the power button, then long-press “Power off” '
          'and confirm “Safe mode”. (On some phones: hold Volume down while the phone starts.)\n'
          '2. In safe mode WSGuard\'s protection doesn\'t run. Open Settings → Security → '
          'Device admin apps (sometimes under “More security settings”) and turn off WSGuard.\n'
          '3. Uninstall WSGuard and restart the phone normally.'
      : '1. Reštartuj telefón do núdzového režimu: podrž vypínač, potom podrž „Vypnúť“ a potvrď '
          '„Núdzový režim“. (Na niektorých telefónoch: pri štarte drž tlačidlo zníženia hlasitosti.)\n'
          '2. V núdzovom režime ochrana WSGuard nebeží. Otvor Nastavenia → Zabezpečenie → '
          'Aplikácie na správu zariadenia (niekedy v „Ďalšie nastavenia zabezpečenia“) a vypni WSGuard.\n'
          '3. WSGuard odinštaluj a telefón normálne reštartuj.';
  String get uninstallGuidePcTitle => en ? 'Using a computer (advanced)' : 'Cez počítač (pre pokročilých)';
  String get uninstallGuidePc => en
      ? 'With USB debugging on, run:\n'
          'adb shell dpm remove-active-admin sk.webostudio.web_blocker/.GuardAdminReceiver\n'
          'adb uninstall sk.webostudio.web_blocker'
      : 'So zapnutým ladením USB spusti:\n'
          'adb shell dpm remove-active-admin sk.webostudio.web_blocker/.GuardAdminReceiver\n'
          'adb uninstall sk.webostudio.web_blocker';
  String get close => en ? 'Close' : 'Zavrieť';
}

/// Sprístupní texty v aktuálnom jazyku celému stromu widgetov.
class L10nScope extends InheritedWidget {
  const L10nScope({super.key, required this.strings, required super.child});

  final S strings;

  @override
  bool updateShouldNotify(L10nScope oldWidget) => oldWidget.strings.lang != strings.lang;
}
