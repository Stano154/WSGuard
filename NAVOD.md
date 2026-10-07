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
   kôš ju odstráni úplne (dá sa vrátiť tlačidlom *Späť*).

## Nastavenia (ozubené koliesko vpravo hore)

- **Téma:** Svetlý / Systém / Tmavý
- **Jazyk:** Slovenčina / English (platí aj pre obrazovku „zablokované“)
- **Zamknúť aplikáciu heslom:** pri otvorení WSGuard (a po návrate po viac ako 30 s) bude treba
  zadať heslo. Heslo sa ukladá iba ako odtlačok (SHA-256 so soľou), nie v čitateľnej podobe.
  Ak ho zabudneš, jediná cesta je WSGuard odinštalovať a nainštalovať znova.
