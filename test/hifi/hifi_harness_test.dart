import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';

import 'hifi_golden.dart';

/// Memastikan alat pembanding hi-fi sendiri benar sebelum dipakai untuk layar sungguhan
/// (lihat design/spec/README.md). Layar app belum dibandingkan di sini karena desain v2 belum diimplementasi.
double _width(TextStyle style) =>
    (TextPainter(text: TextSpan(text: 'Round 3', style: style), textDirection: TextDirection.ltr)..layout()).width;

/// Jumlah piksel gelap saat [icon] digambar hitam 48 pt di atas putih.
Future<int> _inkedPixels(WidgetTester tester, IconData icon) async {
  final key = GlobalKey();
  await tester.pumpWidget(RepaintBoundary(
    key: key,
    child: Directionality(
      textDirection: TextDirection.ltr,
      child: ColoredBox(color: const Color(0xFFFFFFFF), child: Center(child: Icon(icon, size: 48, color: const Color(0xFF000000)))),
    ),
  ));
  final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
  return (await tester.runAsync(() async {
    final image = await boundary.toImage();
    final bytes = (await image.toByteData(format: ui.ImageByteFormat.rawRgba))!.buffer.asUint8List();
    var dark = 0;
    for (var i = 0; i < bytes.length; i += 4) {
      if (bytes[i] < 128) dark++;
    }
    return dark;
  }))!;
}

void main() {
  testWidgets('frame hi-fi yang ditampilkan ulang identik dengan dirinya', (tester) async {
    final frame = await hifiFrame(tester, '03a');
    final diff = await compareWithHifi(
      tester,
      RawImage(image: frame, width: hifiScreenSize.width, height: hifiScreenSize.height, fit: BoxFit.fill, filterQuality: FilterQuality.none),
      '03a',
    );
    expect(diff.differentPixels, 0, reason: '$diff');
  });

  // Toleransi geseran (HifiDiff.shiftTolerance) hanya menyerap pembulatan piksel renderer: frame yang
  // digeser 0,5 pt lolos, digeser 2 pt gagal — baik satu layar maupun satu wilayah komponen.
  for (final (shift, region, passes) in [
    (0.5, null, true),
    (2.0, null, false),
    (0.5, 'group', true),
    (2.0, 'group', false),
  ]) {
    testWidgets('frame digeser $shift pt${region == null ? '' : ' (wilayah .$region)'} → ${passes ? 'lolos' : 'gagal'}', (tester) async {
      final frame = await hifiFrame(tester, '03a');
      final diff = await compareWithHifi(
        tester,
        ColoredBox(
          color: const Color(0xFFEEF2F5),
          child: Transform.translate(
            offset: Offset(0, shift),
            child: RawImage(image: frame, width: hifiScreenSize.width, height: hifiScreenSize.height, fit: BoxFit.fill),
          ),
        ),
        '03a',
        region: region == null ? null : hifiRect('03a', region, text: 'Race to'),
      );
      expect(diff.ratio <= 0.02, passes, reason: '$diff');
    });
  }

  testWidgets('layar yang salah terdeteksi', (tester) async {
    final diff = await compareWithHifi(tester, const ColoredBox(color: Color(0xFFEEF2F5)), '03a');
    expect(diff.ratio, greaterThan(0.05), reason: '$diff');
  });

  test('Archivo variabel: wdth dan wght bekerja di flutter_test', () async {
    await loadHifiFonts();
    const base = TextStyle(fontFamily: 'Archivo', fontSize: 54, fontWeight: FontWeight.w800);
    final condensed = _width(base.copyWith(fontVariations: const [ui.FontVariation('wdth', 72)]));
    final normal = _width(base);
    final wide = _width(base.copyWith(fontVariations: const [ui.FontVariation('wdth', 125)]));
    expect(condensed, lessThan(normal));
    expect(wide, greaterThan(normal));
    // fontWeight diteruskan ke sumbu wght, jadi tidak perlu FontVariation('wght', ...).
    expect(_width(base.copyWith(fontWeight: FontWeight.w400)), lessThan(normal));
  });

  testWidgets('ikon Phosphor Bold ter-render, bukan kotak pengganti', (tester) async {
    await loadHifiFonts();
    final check = await _inkedPixels(tester, MabarIcons.check);
    // Keluarga yang tidak dimuat menggambar kotak pengganti (±780 piksel di 48 pt); centang Bold ±260.
    final missing = await _inkedPixels(tester, const IconData(0xe182, fontFamily: 'TidakDimuat'));
    expect(check, greaterThan(0));
    expect(check, lessThan(missing / 2));
  });
}
