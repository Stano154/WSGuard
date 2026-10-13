# Ako spustiť WSGuard

## A) Na vlastnom telefóne – najjednoduchšie (bez počítača)

1. Stiahni `WSGuard.apk` z [GitHub Releases](https://github.com/Stano154/WSGuard/releases/latest)
   priamo v telefóne, alebo ho do telefónu skopíruj z priečinka projektu
   (USB káblom, cez Google Drive alebo si ho pošli e-mailom).
2. V telefóne ho otvor (napr. v aplikácii **Súbory**).
3. Android sa spýta, či povoliť inštaláciu z neznámych zdrojov → **Povoliť** → **Inštalovať**.
4. Ak Google Play Protect zobrazí varovanie „neznámy vývojár“, zvoľ **Napriek tomu nainštalovať**
   (aplikácia ešte nie je v obchode Play, preto ju nepozná).

Novú verziu nainštaluješ rovnako – prepíše starú a zoznam stránok zostane zachovaný.

## B) V emulátore na počítači

1. Otvor **Android Studio** → **Device Manager** (ikona telefónu vpravo) → pri
   *Medium Phone API 35* klikni na ▶.
2. Keď emulátor nabehne, pretiahni súbor `WSGuard.apk` myšou do okna emulátora – nainštaluje sa sám.
3. Aplikáciu WSGuard nájdeš medzi aplikáciami (potiahni prstom/myšou zdola nahor).

## C) Pri vývoji – s okamžitým prejavením zmien (hot reload)

Stačí, ak beží emulátor alebo je pripojený telefón s **USB ladením**
(Nastavenia → Informácie o telefóne → 7× ťukni na *Číslo zostavy* →
späť → Možnosti pre vývojárov → zapni *Ladenie USB*).

V PowerShelli:

```
cd WSGuard
$env:JAVA_TOOL_OPTIONS="-Djdk.net.unixdomain.tmpdir=$PWD\.gradle-tmp"
flutter run
```

Počas behu: **r** = prejaviť zmeny v kóde (hot reload), **R** = reštart, **q** = koniec.

Nový inštalačný súbor vyrobíš príkazom:

```
flutter build apk --release
```

Výsledok: `WSGuard\build\app\outputs\flutter-apk\app-release.apk`

## Prvé použitie aplikácie

1. **Pridať** → karta *Stránka* (napíš adresu alebo vyber z *Obľúbených* – zablokuje sa
   stránka aj aplikácia) alebo karta *Aplikácia* (vyber zo zoznamu) → **Blokovať**.
2. **Zapnúť ochranu** → potvrď systémovú otázku o VPN (**OK**). Hore sa objaví ikonka kľúča.
3. Na blokovanie **aplikácií** treba režim **Aplikácie a prehliadače** → *Otvoriť nastavenia* →
   Prístupnosť → **WSGuard** → zapnúť. Vie blokovať aj časti stránok (napr. `youtube.com/shorts`).
4. V zozname *Čo blokujem* vidíš pri každej položke, či sa naozaj blokuje (zelené **Blokované**)
   alebo nie (**Neaktívne**) – vtedy sa hore zobrazí tlačidlo **Zapnúť**.
5. **Vypínač** pri položke ju dočasne povolí (**Povolené**) bez vymazania zo zoznamu;
   menu **⋮ → Odstrániť** ju odstráni úplne (dá sa vrátiť tlačidlom *Späť*).

## Časové blokovanie

- Pri položke alebo zozname: **⋮ → Zablokovať na čas** → 1 hodina, 1 deň, 1 týždeň alebo vlastný čas.
- Kým časové blokovanie beží, **nedá sa vypnúť, skrátiť ani odstrániť** a nedá sa vypnúť ani celá
  ochrana WSGuard (VPN, režim Aplikácie a prehliadače). Dá sa iba **predĺžiť** – kratšie možnosti
  sú sivé.
- Jediná výnimka: **Odblokovať na 15 min** – predvolene najviac 3× za deň pre každú položku.
  Dĺžku a počet (Nikdy, 1×–10×) zmeníš v nastaveniach (*Dočasné odblokovanie*), ale iba keď
  nebeží žiadne časové blokovanie. Pri „Nikdy“ sa tlačidlo na odblokovanie vôbec nezobrazí.
- **Zmena dátumu alebo času v telefóne blokovanie neskráti** – WSGuard si posun hodín všimne
  a odpočíta ho (meria čas od zapnutia telefónu, ktorý sa zmeniť nedá).
- Po skončení sa položka prepne na **Povolené** (ostane v zozname) a príde upozornenie.

## Zoznamy

- **Nový zoznam** → názov, ikona a položky (aplikácie aj stránky). Dá sa začať zo šablóny
  *Sociálne siete* alebo *Videá a streamovanie*.
- Celý zoznam zapneš/vypneš jedným vypínačom alebo ho zablokuješ na čas.
- Počas časového blokovania zoznamu sa doň dajú položky iba pridávať, nie odoberať.

## Nastavenia (ozubené koliesko vpravo hore)

- **Téma:** Svetlý / Systém / Tmavý
- **Jazyk:** Slovenčina / English (platí aj pre obrazovku „zablokované“)
- **Zamknúť aplikáciu heslom:** pri otvorení WSGuard (a po návrate po viac ako 30 s) bude treba
  zadať heslo. Heslo sa ukladá iba ako odtlačok (SHA-256 so soľou), nie v čitateľnej podobe.
  Ak ho zabudneš, jediná cesta je WSGuard odinštalovať a nainštalovať znova.
- **Dočasné odblokovanie:** dĺžka (5–60 min) a koľkokrát za deň (Nikdy, 1×–10×).
- **Ochrana proti odinštalovaniu:** vyžaduje nastavené heslo. WSGuard sa stane správcom zariadenia
  (Android ho nedovolí odinštalovať) a s režimom *Aplikácie a prehliadače* stráži aj systémové
  nastavenia – obrazovky, kde by sa dal WSGuard odinštalovať, vynútene zastaviť alebo vypnúť.
  Vypnúť sa dá iba heslom a iba keď nebeží časové blokovanie.

## Ako WSGuard odinštalovať (aj tlačidlo ⓘ v nastaveniach)

1. Počkaj, kým nebeží žiadne časové blokovanie.
2. V nastaveniach WSGuard vypni **Ochrana proti odinštalovaniu** a zadaj heslo.
3. Odinštaluj WSGuard ako každú inú aplikáciu.

**Zabudnuté heslo:** reštartuj telefón do **núdzového režimu** (podrž vypínač → podrž *Vypnúť* →
*Núdzový režim*). V ňom ochrana nebeží: Nastavenia → Zabezpečenie → *Aplikácie na správu
zariadenia* → vypni WSGuard → odinštaluj → reštartuj telefón.

**Cez počítač (ladenie USB):**

```
adb shell dpm remove-active-admin sk.webostudio.web_blocker/.GuardAdminReceiver
adb uninstall sk.webostudio.web_blocker
```
