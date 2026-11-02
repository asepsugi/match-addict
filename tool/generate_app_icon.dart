import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/court_painter.dart';
import 'package:match_addict/core/widgets/mabar_ball.dart';
import 'package:match_addict/models/models.dart';

/// Membuat sumber ikon app (opsi A, frame 01j) dari painter yang sama dengan banner Beranda:
/// sudut lapangan tennis + bola brand di service box, garis putih penuh.
///
/// Bukan test — generator sekali jalan, ditaruh di `tool/` supaya tidak ikut `flutter test`. Jalankan
/// ulang setiap kali `CourtPainter`/`CourtLayout.icon` atau bola berubah:
///
///   flutter test tool/generate_app_icon.dart
///   dart run flutter_launcher_icons
///
/// Hasilnya tiga PNG 1024×1024 di `assets/icon/`: ikon utuh (iOS, web, fallback), latar dan foreground
/// terpisah untuk adaptive icon Android.
void main() {
  const size = 1024.0;
  // Bola `#appicon-a`: x 249, y 339, 400×400 di kanvas 1024.
  const ball = Rect.fromLTWH(249, 339, 400, 400);

  // Adaptive icon: yang terlihat hanya 72 dari 108 dp di tengah. Komposisi ikon utuh dikecilkan ke
  // dua pertiga tengah, lapangan dan run-off tetap mengisi sampai tepi, jadi mask apa pun memotong
  // gambar yang sama dengan ikon utuh. Bolanya tetap di dalam safe zone 66 dp.
  const f = 72 / 108, inset = size * (1 - f) / 2;
  final icon = CourtLayout.icon;
  final adaptive = CourtLayout(
    cornerRight: inset + icon.cornerRight * f,
    cornerTop: inset + icon.cornerTop * f,
    scale: icon.scale * f,
    baselineWidth: icon.baselineWidth * f,
    lineWidth: icon.lineWidth * f,
    centerMark: icon.centerMark * f,
    marksOpacity: 1,
    designWidth: size,
  );
  final adaptiveBall = Rect.fromLTWH(inset + ball.left * f, inset + ball.top * f, ball.width * f, ball.height * f);

  Widget court(CourtLayout layout) => CustomPaint(painter: CourtPainter.of(SportType.tennis, layout: layout));
  Widget at(Rect r) => Positioned.fromRect(rect: r, child: MabarBall(size: r.width));

  testWidgets('render sumber ikon', (tester) async {
    await _capture(tester, 'assets/icon/app_icon.png', Stack(fit: StackFit.expand, children: [court(icon), at(ball)]));
    await _capture(tester, 'assets/icon/app_icon_background.png', court(adaptive));
    await _capture(tester, 'assets/icon/app_icon_foreground.png', Stack(children: [at(adaptiveBall)]));
  });
}

Future<void> _capture(WidgetTester tester, String path, Widget child) async {
  // Surface test default 800×600 memotong kanvas 1024 persegi.
  await tester.binding.setSurfaceSize(const Size(1024, 1024));

  final key = GlobalKey();
  await tester.pumpWidget(
    Directionality(
      textDirection: TextDirection.ltr,
      child: Center(
        child: RepaintBoundary(key: key, child: SizedBox(width: 1024, height: 1024, child: child)),
      ),
    ),
  );

  await tester.runAsync(() async {
    final boundary = key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    File(path).writeAsBytesSync(data!.buffer.asUint8List());
  });

  debugPrint('wrote $path');
}
