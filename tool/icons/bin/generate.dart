// Generuje ikony WSGuard pre Android a iOS zo zdrojového obrázka.
// Spustenie (z priečinka tool/icons):  dart run bin/generate.dart
// ignore_for_file: avoid_print
import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

const project = '../..';
const source = '$project/assets/branding/wsguard_source.webp';

// Farby pozadia namerané zo zdrojového obrázka (hore -> dole).
final bgTop = [4, 57, 127];
final bgBottom = [2, 36, 90];

void main() {
  final src = img.decodeImage(File(source).readAsBytesSync())!;
  final logo = _extractLogo(src);
  print('Logo: ${logo.width}x${logo.height}');

  _android(logo);
  _ios(logo);
  _write('$project/assets/branding/wsguard_playstore.png', _square(logo, 512, round: false));
  // Značka do hlavičky aplikácie – iba štít (bez nápisu, ten je hneď vedľa ako text).
  final mark = _square(_shieldOnly(logo), 192, round: true);
  _write('$project/assets/branding/wsguard_mark.png', mark);
  _write('$project/android/app/src/main/res/drawable-nodpi/wsguard_mark.png', mark);
  print('Hotovo.');
}

/// Oddelí logo (biela, červená, svetlomodrá) od modrého pozadia -> priehľadné PNG.
img.Image _extractLogo(img.Image src) {
  List<int> bgAt(int y) {
    final t = y / (src.height - 1);
    return List.generate(3, (i) => (bgTop[i] + (bgBottom[i] - bgTop[i]) * t).round());
  }

  // Farba svetlomodrého textu "WS" – priemer typických pixelov.
  var sum = [0, 0, 0], n = 0;
  for (final p in src) {
    if (p.b > 200 && p.r < 120 && p.g > 110 && p.g < 210) {
      sum = [sum[0] + p.r.toInt(), sum[1] + p.g.toInt(), sum[2] + p.b.toInt()];
      n++;
    }
  }
  final blue = n > 0 ? sum.map((v) => v ~/ n).toList() : [40, 160, 240];
  final palette = [
    [253, 253, 253],
    [252, 39, 60],
    blue,
  ];

  final out = img.Image(width: src.width, height: src.height, numChannels: 4);
  var minX = src.width, minY = src.height, maxX = 0, maxY = 0;

  for (var y = 0; y < src.height; y++) {
    final bg = bgAt(y);
    for (var x = 0; x < src.width; x++) {
      final p = src.getPixel(x, y);
      if (p.a < 250) continue; // priehľadné rohy
      final c = [p.r.toInt(), p.g.toInt(), p.b.toInt()];

      // Pixel = bg + a * (fg - bg). Nájdeme farbu z palety, ktorá ho vysvetlí najlepšie.
      double bestA = 0, bestErr = double.infinity;
      List<int> bestFg = palette.first;
      for (final fg in palette) {
        final d = List.generate(3, (i) => fg[i] - bg[i]);
        final v = List.generate(3, (i) => c[i] - bg[i]);
        final dd = d.fold<num>(0, (s, e) => s + e * e);
        var a = (v[0] * d[0] + v[1] * d[1] + v[2] * d[2]) / dd;
        a = a.clamp(0.0, 1.0);
        var err = 0.0;
        for (var i = 0; i < 3; i++) {
          final e = c[i] - (bg[i] + a * d[i]);
          err += e * e;
        }
        if (err < bestErr) {
          bestErr = err;
          bestA = a;
          bestFg = fg;
        }
      }
      // Odstráni jemný šum pozadia.
      var a = ((bestA - 0.06) / 0.94).clamp(0.0, 1.0);
      if (a <= 0) continue;
      out.setPixelRgba(x, y, bestFg[0], bestFg[1], bestFg[2], (a * 255).round());
      if (a > 0.3) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
        minY = math.min(minY, y);
        maxY = math.max(maxY, y);
      }
    }
  }
  const pad = 4;
  return img.copyCrop(out,
      x: minX - pad, y: minY - pad, width: maxX - minX + 2 * pad, height: maxY - minY + 2 * pad);
}

/// Odreže nápis "WSGuard" – nájde prázdny riadok medzi štítom a textom.
img.Image _shieldOnly(img.Image logo) {
  bool emptyRow(int y) {
    for (var x = 0; x < logo.width; x++) {
      if (logo.getPixel(x, y).a > 20) return false;
    }
    return true;
  }

  var cut = logo.height;
  for (var y = (logo.height * 0.6).round(); y < logo.height; y++) {
    if (emptyRow(y)) {
      cut = y;
      break;
    }
  }
  var minX = logo.width, maxX = 0;
  for (var y = 0; y < cut; y++) {
    for (var x = 0; x < logo.width; x++) {
      if (logo.getPixel(x, y).a > 20) {
        minX = math.min(minX, x);
        maxX = math.max(maxX, x);
      }
    }
  }
  return img.copyCrop(logo, x: minX, y: 0, width: maxX - minX + 1, height: cut);
}

img.Image _gradient(int w, int h) {
  final g = img.Image(width: w, height: h, numChannels: 4);
  for (var y = 0; y < h; y++) {
    final t = h == 1 ? 0 : y / (h - 1);
    final c = List.generate(3, (i) => (bgTop[i] + (bgBottom[i] - bgTop[i]) * t).round());
    for (var x = 0; x < w; x++) {
      g.setPixelRgba(x, y, c[0], c[1], c[2], 255);
    }
  }
  return g;
}

/// Logo zmenšené tak, aby sa zmestilo do obdĺžnika maxW x maxH.
img.Image _fit(img.Image logo, double maxW, double maxH) {
  final s = math.min(maxW / logo.width, maxH / logo.height);
  return img.copyResize(logo,
      width: math.max(1, (logo.width * s).round()),
      height: math.max(1, (logo.height * s).round()),
      interpolation: img.Interpolation.average);
}

img.Image _center(img.Image canvas, img.Image item) {
  return img.compositeImage(canvas, item,
      dstX: (canvas.width - item.width) ~/ 2, dstY: (canvas.height - item.height) ~/ 2);
}

/// Štvorcová ikona: modrý prechod + logo (78 % veľkosti), voliteľne so zaoblenými rohmi.
img.Image _square(img.Image logo, int size, {required bool round}) {
  final canvas = _center(_gradient(size, size), _fit(logo, size * 0.78, size * 0.78));
  if (!round) return canvas;
  final r = size * 0.22;
  for (var y = 0; y < size; y++) {
    for (var x = 0; x < size; x++) {
      final dx = math.max(0, math.max(r - x - 0.5, x + 0.5 - (size - r)));
      final dy = math.max(0, math.max(r - y - 0.5, y + 0.5 - (size - r)));
      final dist = math.sqrt(dx * dx + dy * dy);
      final cov = (r - dist + 0.5).clamp(0.0, 1.0);
      if (cov < 1) {
        final p = canvas.getPixel(x, y);
        p.a = (p.a * cov).round();
      }
    }
  }
  return canvas;
}

void _android(img.Image logo) {
  const res = '$project/android/app/src/main/res';
  const densities = {'mdpi': 1.0, 'hdpi': 1.5, 'xhdpi': 2.0, 'xxhdpi': 3.0, 'xxxhdpi': 4.0};

  // Adaptívna ikona: plátno 108 dp, logo musí byť v bezpečnom kruhu s polomerom ~33 dp.
  // Vypočítame najvzdialenejší viditeľný bod loga od jeho stredu.
  var maxDist = 0.0;
  final cx = logo.width / 2, cy = logo.height / 2;
  for (final p in logo) {
    if (p.a > 40) {
      maxDist = math.max(maxDist, math.sqrt(math.pow(p.x - cx, 2) + math.pow(p.y - cy, 2)));
    }
  }

  densities.forEach((name, d) {
    final canvas = (108 * d).round();
    final scale = (33 * d) / maxDist;
    final fg = img.copyResize(logo,
        width: (logo.width * scale).round(),
        height: (logo.height * scale).round(),
        interpolation: img.Interpolation.average);
    _write('$res/mipmap-$name/ic_launcher_foreground.png',
        _center(img.Image(width: canvas, height: canvas, numChannels: 4), fg));
    _write('$res/mipmap-$name/ic_launcher_background.png', _gradient(canvas, canvas));
    _write('$res/mipmap-$name/ic_launcher.png', _square(logo, (48 * d).round(), round: true));
  });

  Directory('$res/mipmap-anydpi-v26').createSync(recursive: true);
  File('$res/mipmap-anydpi-v26/ic_launcher.xml').writeAsStringSync('''<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
    <background android:drawable="@mipmap/ic_launcher_background" />
    <foreground android:drawable="@mipmap/ic_launcher_foreground" />
    <monochrome android:drawable="@mipmap/ic_launcher_foreground" />
</adaptive-icon>
''');
}

void _ios(img.Image logo) {
  final dir = Directory('$project/ios/Runner/Assets.xcassets/AppIcon.appiconset');
  final re = RegExp(r'Icon-App-([\d.]+)x[\d.]+@(\d)x\.png');
  for (final f in dir.listSync().whereType<File>()) {
    final m = re.firstMatch(f.uri.pathSegments.last);
    if (m == null) continue;
    final size = (double.parse(m.group(1)!) * int.parse(m.group(2)!)).round();
    // iOS si rohy zaobľuje sám a ikona nesmie mať priehľadnosť.
    final icon = _square(logo, size, round: false).convert(numChannels: 3);
    _write(f.path, icon);
  }
}

void _write(String path, img.Image image) {
  File(path)
    ..createSync(recursive: true)
    ..writeAsBytesSync(img.encodePng(image));
  print('  $path (${image.width}x${image.height})');
}
