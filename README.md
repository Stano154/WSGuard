# WSGuard – blokovanie webových stránok

Flutter aplikácia (Android, neskôr iOS) na blokovanie stránok, ktoré si pridá používateľ.

## Dva spôsoby blokovania (Android)

| | **Stránky v celom zariadení** (lokálna VPN) | **Aplikácie a prehliadače** (prístupnosť) |
|---|---|---|
| Kde funguje | všetky prehliadače aj aplikácie | celé aplikácie (napr. Instagram) + Chrome, Firefox, Samsung Internet, Edge, Brave, Opera, DuckDuckGo… |
| Čo blokuje | celé domény (+ subdomény) | aplikácie, domény aj konkrétne cesty (`youtube.com/shorts`) |
| Čo uvidí používateľ | stránka sa nenačíta (chyba DNS) | obrazovka „Aplikácia/Stránka je zablokovaná“ |
| Obmedzenie | nemôže bežať súčasne s inou VPN | Google Play prísne kontroluje použitie prístupnosti |

Oba režimy môžu bežať naraz.

### Ako funguje VPN režim
`BlockerVpnService` nastaví systému falošný DNS server `10.111.222.2` a do tunela smeruje
**iba** premávku naň. DNS dotazy na zablokované domény dostanú odpoveď `NXDOMAIN`,
ostatné sa prepošlú na `1.1.1.1` (záloha `8.8.8.8`). Ostatná premávka cez tunel nejde.

Poznámka: prehliadač si môže DNS odpoveď chvíľu pamätať – po pridaní stránky môže
blokovanie začať platiť s malým oneskorením (alebo po reštarte prehliadača).

## Štruktúra

```
lib/
  main.dart            – téma, jazyk, zámok heslom
  home_page.dart       – hlavná obrazovka
  blocked_list.dart    – zoznam „Čo blokujem“ (filtre, vypínače, stav)
  add_site_sheet.dart  – pridanie stránky/aplikácie + obľúbené
  settings_page.dart   – nastavenia (téma, jazyk, heslo)
  lock_screen.dart     – zamykacia obrazovka a dialógy hesla
  app_settings.dart    – uloženie nastavení, hash hesla
  l10n.dart            – všetky texty SK/EN
  known_services.dart  – Instagram, Facebook, TikTok… (doména, farba, balíky aplikácií)
  blocker_api.dart     – MethodChannel most na natívnu časť
android/app/src/main/kotlin/sk/webostudio/web_blocker/
  MainActivity.kt                 – MethodChannel, povolenie VPN
  BlockStore.kt                   – zoznam stránok, porovnávanie domén
  BlockerVpnService.kt            – DNS filter cez VpnService
  BlockerAccessibilityService.kt  – sledovanie adresného riadku
  BlockedActivity.kt              – obrazovka „Stránka je zablokovaná“
  BootReceiver.kt                 – obnovenie VPN po reštarte
```

## Spustenie

```
flutter run
```

Ak Gradle na Windows hlási `Unable to establish loopback connection`, nastav pred buildom
(PowerShell):

```
$env:JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=$PWD\.gradle-tmp"
```

## Ikona

Zdroj je `assets/branding/wsguard_source.webp`. Po jeho výmene ikony pre Android
(adaptívna aj klasická), iOS a Google Play (`assets/branding/wsguard_playstore.png`) znovu vygeneruješ:

```
cd tool/icons
dart run bin/generate.dart
```

## iOS (do budúcna)

UI je pripravené, natívne blokovanie zatiaľ nie (aplikácia na iOS zobrazí upozornenie).
Na iOS sa použije **Screen Time API** (`FamilyControls` + `ManagedSettings`,
`webDomains` blokovanie) – vyžaduje Mac s Xcode, Apple Developer účet a schválenie
oprávnenia *Family Controls* od Apple.
