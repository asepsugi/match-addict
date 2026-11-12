import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';
import 'package:match_addict/core/widgets/match_score_row.dart';

/// Pembanding layar Flutter dengan frame hi-fi (`design/frames/<id>.png`).
///
/// Frame di-render `tool/hifi_extract.py` dari `design/hifi.html` pada 2x, jadi layar app berukuran
/// 390×844 pt = 780×1688 px. Di sini ukuran, rasio piksel, font Archivo, dan font ikon Phosphor Bold
/// disamakan; tanpa [loadHifiFonts] `flutter test` memakai Ahem dan hasilnya pasti beda total.
///
/// Anti-alias teks Chrome dan Skia tidak pernah identik, jadi piksel dihitung "beda" hanya kalau salah
/// satu kanalnya selisih lebih dari [HifiDiff.channelTolerance] terhadap piksel frame di posisi itu dan di
/// tetangganya sejauh [HifiDiff.shiftTolerance], dan layar lolos kalau rasio piksel beda tidak melebihi
/// `maxDiffRatio`. Kalau gagal, `build/hifi_diff/<id>.png` (merah = beda) dan
/// `build/hifi_diff/<id>_flutter.png` ditulis untuk dilihat.
const hifiScreenSize = Size(390, 844);
const hifiPixelRatio = 2.0;
const _fonts = {'Archivo': 'assets/fonts/Archivo[wdth,wght].ttf', 'PhosphorBold': 'assets/fonts/Phosphor-Bold.ttf'};

bool _fontsLoaded = false;

/// Memuat font Archivo variabel dan font ikon Phosphor Bold (`MabarIcons`) sekali per proses test.
/// Berat cukup lewat `fontWeight` (Flutter meneruskannya ke sumbu `wght`); lebar lewat
/// `FontVariation('wdth', n)` = `font-stretch: n%` di hi-fi.
Future<void> loadHifiFonts() async {
  if (_fontsLoaded) return;
  for (final MapEntry(key: family, value: path) in _fonts.entries) {
    final bytes = File(path).readAsBytesSync();
    await (FontLoader(family)..addFont(Future.value(ByteData.sublistView(bytes)))).load();
  }
  _fontsLoaded = true;
}

class HifiDiff {
  /// Selisih kanal (0–255) yang masih dianggap sama.
  static const channelTolerance = 32;

  /// Geseran (piksel perangkat) yang diserap. Chrome membulatkan ascent, descent, dan half-leading ke
  /// piksel perangkat (`baseline = floor((L − (A+D)) / 2) + A`, cocok dengan semua ukuran yang diukur),
  /// Flutter tidak dan membulatkan tinggi baris ke pt bulat; glyph yang sama bisa bergeser 1–2 piksel
  /// tergantung ukuran huruf. Tanpa toleransi ini, frame yang sama digeser 1 piksel pun gagal (2,08%);
  /// dengan 2 piksel vertikal, geseran 2 pt seluruh layar malah lolos. 1 piksel: dua-duanya benar
  /// (lihat `hifi_harness_test`).
  static const shiftTolerance = (x: 1, y: 1);

  final String frameId;

  /// Piksel yang dibandingkan: seluruh layar, atau hanya wilayah komponen.
  final int comparedPixels;
  final int differentPixels;

  const HifiDiff(this.frameId, this.comparedPixels, this.differentPixels);

  double get ratio => differentPixels / comparedPixels;

  @override
  String toString() => '$frameId: ${(ratio * 100).toStringAsFixed(2)}% piksel beda ($differentPixels dari $comparedPixels)';
}

Future<ui.Image> _decode(Uint8List png) async {
  final codec = await ui.instantiateImageCodec(png);
  return (await codec.getNextFrame()).image;
}

Future<Uint8List> _rgba(ui.Image image) async =>
    (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();

/// Gambar frame hi-fi apa adanya (untuk dibandingkan atau ditampilkan di test).
Future<ui.Image> hifiFrame(WidgetTester tester, String frameId) async =>
    (await tester.runAsync(() => _decode(File('design/frames/$frameId.png').readAsBytesSync())))!;

/// Ukuran frame dalam pt: 390×844 untuk layar, atau ukuran lembar gambar (poster Feed/Story, 11d dst.),
/// dibaca dari header PNG-nya.
Size hifiFrameSize(String frameId) {
  final header = File('design/frames/$frameId.png').openSync()..setPositionSync(16);
  final bytes = ByteData.sublistView(header.readSync(8));
  header.closeSync();
  return Size(bytes.getUint32(0) / hifiPixelRatio, bytes.getUint32(4) / hifiPixelRatio);
}

Map<String, dynamic>? _rects;

/// Posisi satu elemen di frame hi-fi (pt, relatif ke layar), dari `design/spec/rects.json` yang ditulis
/// `tool/hifi_extract.py`. [cssClass] tanpa titik; elemen dipilih dengan [index] di antara yang teksnya
/// memuat [text] (atau semua elemen berkelas itu), urut dokumen.
Rect hifiRect(String frameId, String cssClass, {String? text, int index = 0}) {
  _rects ??= jsonDecode(File('design/spec/rects.json').readAsStringSync()) as Map<String, dynamic>;
  final all = ((_rects![frameId] as Map<String, dynamic>?)?[cssClass] as List?) ?? const [];
  final matches = [
    for (final r in all.cast<List>())
      if (text == null || (r[4] as String).contains(text)) r,
  ];
  if (index >= matches.length) {
    throw StateError('$frameId: .$cssClass${text == null ? '' : ' "$text"'} #$index tidak ada (${matches.length} cocok)');
  }
  final r = matches[index];
  return Rect.fromLTWH((r[0] as num).toDouble(), (r[1] as num).toDouble(), (r[2] as num).toDouble(), (r[3] as num).toDouble());
}

/// Me-render [screen] seukuran layar hi-fi lalu membandingkannya dengan `design/frames/<frameId>.png`.
/// [screen] harus sudah lengkap (MaterialApp, tema, data); helper ini hanya mengatur ukuran layar.
/// Dengan [region] (pt), hanya piksel di dalamnya yang dihitung — dipakai golden per komponen.
Future<HifiDiff> compareWithHifi(
  WidgetTester tester,
  Widget screen,
  String frameId, {
  Rect? region,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  await loadHifiFonts();
  tester.view.physicalSize = hifiFrameSize(frameId) * hifiPixelRatio;
  tester.view.devicePixelRatio = hifiPixelRatio;
  addTearDown(tester.view.reset);

  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(key: key, child: screen));
  await tester.pumpAndSettle();
  // Frame dialog/sheet: buka lewat ketukan yang sama dengan host, lalu tunggu animasinya selesai.
  if (act != null) {
    await act(tester);
    await tester.pumpAndSettle();
  }
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;

  return (await tester.runAsync(() async {
    final actual = await boundary.toImage(pixelRatio: hifiPixelRatio);
    final expected = await _decode(File('design/frames/$frameId.png').readAsBytesSync());
    if (actual.width != expected.width || actual.height != expected.height) {
      throw StateError('$frameId: ukuran render ${actual.width}×${actual.height} ≠ hi-fi ${expected.width}×${expected.height}');
    }
    final a = await _rgba(actual), e = await _rgba(expected);
    final diff = Uint8List(a.length);
    var different = 0, counted = 0;
    // Wilayah dalam piksel; tepi dibulatkan ke dalam supaya piksel separuh-latar di tepi tidak ikut.
    final px = region == null
        ? null
        : Rect.fromLTRB(
            (region.left * hifiPixelRatio).ceilToDouble(),
            (region.top * hifiPixelRatio).ceilToDouble(),
            (region.right * hifiPixelRatio).floorToDouble(),
            (region.bottom * hifiPixelRatio).floorToDouble(),
          );
    for (var i = 0; i < a.length; i += 4) {
      final p = i ~/ 4;
      final inside = px == null || px.contains(Offset((p % actual.width).toDouble(), (p ~/ actual.width).toDouble()));
      if (!inside) {
        final grey = ((e[i] + e[i + 1] + e[i + 2]) ~/ 3) ~/ 4 + 190;
        diff[i] = diff[i + 1] = diff[i + 2] = grey;
        diff[i + 3] = 255;
        continue;
      }
      counted++;
      final isDifferent = !_matchesNear(a, e, i, actual.width, actual.height);
      if (isDifferent) different++;
      // Gambar selisih: piksel beda merah, sisanya hi-fi dipudarkan supaya posisinya tetap terbaca.
      final grey = ((e[i] + e[i + 1] + e[i + 2]) ~/ 3) ~/ 3 + 170;
      diff[i] = isDifferent ? 230 : grey;
      diff[i + 1] = isDifferent ? 40 : grey;
      diff[i + 2] = isDifferent ? 40 : grey;
      diff[i + 3] = 255;
    }
    final result = HifiDiff(frameId, counted, different);
    if (different > 0) await _writeDiff(frameId, actual, diff);
    return result;
  }))!;
}

/// Jumlah ikon tukar pemain (`.w.swap`) di baris match tiap frame Jadwal yang tampil berikon atau yang wajib tanpa ikon
/// (06a Fixed, 06m diakhiri, 06t round lewat, 16b Mexicano, 12h penonton, 17r tidak ada yang istirahat). Golden 2%
/// bisa lolos tanpa ikon (16 pt x beberapa baris), jadi [expectMatchesHifi] menghitungnya dengan finder. Angkanya dari
/// `design/hifi.html` (kelas `w swap` per frame).
const hifiSwapIcons = {
  '06a': 0, '06f': 2, '06h': 4, '06i': 4, '06j': 4, '06k': 4, '06m': 0, '06o': 2, '06p': 2, '06q': 4,
  '06s': 2, '06t': 0, '06u': 2, '08a': 2, '08e': 2, '08g': 4, '08h': 4, '08i': 4, '08j': 2, '08k': 2,
  '12a': 4, '12b': 4, '12c': 4, '12d': 4, '12e': 4, '12g': 4, '12h': 0, '13m': 2, '15b': 4, '15c': 4,
  '15d': 2, '15e': 2, '15g': 4, '15h': 4, '15k': 4, '15l': 2, '15m': 2, '15n': 4, '15o': 4, '15p': 3,
  '16b': 0, '17a': 2, '17b': 2, '17c': 2, '17d': 2, '17e': 2, '17f': 4, '17g': 4, '17h': 4, '17i': 4,
  '17j': 2, '17k': 4, '17l': 4, '17m': 4, '17n': 2, '17o': 4, '17p': 4, '17q': 4, '17r': 0,
};

/// [compareWithHifi] + `expect`. Toleransi bawaan 2% piksel: cukup untuk perbedaan anti-alias, tapi
/// pergeseran 4 pt atau warna yang salah di satu komponen sudah melewatinya.
Future<void> expectMatchesHifi(
  WidgetTester tester,
  Widget screen,
  String frameId, {
  double maxDiffRatio = 0.02,
  Future<void> Function(WidgetTester tester)? act,
}) async {
  final diff = await compareWithHifi(tester, screen, frameId, act: act);
  expect(diff.ratio, lessThanOrEqualTo(maxDiffRatio),
      reason: '$diff — lihat build/hifi_diff/$frameId.png (merah = beda) dan ${frameId}_flutter.png');
  final icons = hifiSwapIcons[frameId];
  if (icons != null) {
    // Hanya ikon di baris match: tombol "Tukar" di sheet memakai ikon yang sama.
    final inRows = find.descendant(
      of: find.byType(MatchScoreRow),
      matching: find.byIcon(MabarIcons.arrowsLeftRight),
    );
    expect(inRows, findsNWidgets(icons), reason: '$frameId: jumlah ikon tukar di baris match');
  }
}

/// Golden per komponen: [stage] (biasanya [hifiStage]) dibandingkan dengan frame hanya di [region].
/// Toleransinya sama dengan layar penuh. Wilayah kecil berisi teks memang lebih peka anti-alias daripada
/// layar yang sebagian besar latar polos; kalau satu komponen butuh lebih, tulis alasannya di test.
Future<void> expectRegionMatchesHifi(
  WidgetTester tester,
  Widget stage,
  String frameId,
  Rect region, {
  required String label,
  double maxDiffRatio = 0.02,
}) async {
  final diff = await compareWithHifi(tester, stage, frameId, region: region);
  final name = '${frameId}_$label';
  if (diff.differentPixels > 0) await _renameDiff(frameId, name);
  expect(diff.ratio, lessThanOrEqualTo(maxDiffRatio),
      reason: '$label di $diff — lihat build/hifi_diff/$name.png (merah = beda) dan ${name}_flutter.png');
}

/// Safe area frame: status bar 47 di atas (app bar mulai 7 pt di bawahnya), home indicator 34 di bawah.
const hifiSafeArea = EdgeInsets.only(top: 47, bottom: 34);

/// Satu komponen diletakkan di posisi [at] (pt) di atas latar [background], seukuran layar hi-fi dengan
/// safe area [hifiSafeArea]. Lebar dikunci ke wilayah frame, tinggi dibiarkan alami supaya selisih tinggi
/// ikut terlihat di diff.
Widget hifiStage({required Widget child, required Rect at, required ThemeData theme, Color? background, double? height}) =>
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: theme,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(padding: hifiSafeArea, viewPadding: hifiSafeArea),
        child: child!,
      ),
      home: Material(
        color: background ?? theme.scaffoldBackgroundColor,
        child: Stack(
          children: [Positioned(left: at.left, top: at.top, width: at.width, height: height, child: child)],
        ),
      ),
    );

/// Mendekode gambar aset lebih dulu: di `flutter_test` `Image.asset` baru tampil kalau gambarnya sudah
/// ada di cache sebelum frame digambar (dekodenya butuh `runAsync`).
Future<void> precacheHifiAssets(WidgetTester tester, List<String> paths) async {
  await tester.runAsync(() async {
    for (final path in paths) {
      final done = Completer<void>();
      AssetImage(path).resolve(ImageConfiguration.empty).addListener(
            ImageStreamListener((_, _) => done.complete(), onError: (e, s) => done.completeError(e, s ?? StackTrace.current)),
          );
      await done.future;
    }
  });
}

Future<void> _renameDiff(String frameId, String name) async {
  for (final suffix in ['', '_flutter']) {
    final f = File('build/hifi_diff/$frameId$suffix.png');
    if (f.existsSync()) f.renameSync('build/hifi_diff/$name$suffix.png');
  }
}

/// Piksel frame di indeks [i] cocok dengan piksel render di posisi sama atau tetangganya (lihat
/// [HifiDiff.shiftTolerance]).
bool _matchesNear(Uint8List a, Uint8List e, int i, int width, int height) {
  bool same(int j) {
    for (var c = 0; c < 3; c++) {
      if ((a[j + c] - e[i + c]).abs() > HifiDiff.channelTolerance) return false;
    }
    return true;
  }

  if (same(i)) return true;
  final p = i ~/ 4, x = p % width, y = p ~/ width;
  const t = HifiDiff.shiftTolerance;
  for (var dy = -t.y; dy <= t.y; dy++) {
    for (var dx = -t.x; dx <= t.x; dx++) {
      final nx = x + dx, ny = y + dy;
      if (nx < 0 || ny < 0 || nx >= width || ny >= height) continue;
      if (same((ny * width + nx) * 4)) return true;
    }
  }
  return false;
}

Future<void> _writeDiff(String frameId, ui.Image actual, Uint8List diffRgba) async {
  final dir = Directory('build/hifi_diff')..createSync(recursive: true);
  final png = await actual.toByteData(format: ui.ImageByteFormat.png);
  File('${dir.path}/${frameId}_flutter.png').writeAsBytesSync(png!.buffer.asUint8List());
  final buffer = await ui.ImmutableBuffer.fromUint8List(diffRgba);
  final descriptor = ui.ImageDescriptor.raw(buffer, width: actual.width, height: actual.height, pixelFormat: ui.PixelFormat.rgba8888);
  final image = (await (await descriptor.instantiateCodec()).getNextFrame()).image;
  final diffPng = await image.toByteData(format: ui.ImageByteFormat.png);
  File('${dir.path}/$frameId.png').writeAsBytesSync(diffPng!.buffer.asUint8List());
}
