import 'package:flutter/widgets.dart';

import '../theme/mabar_theme.dart';

/// Bola tennis brand (sprite `#ball` hi-fi, viewBox 48): lingkaran bola bertepi, dua jahitan putih.
/// Dipakai wordmark Beranda dan poster Bagikan; gambar brand, bukan ikon.
class MabarBall extends StatelessWidget {
  final double size;

  const MabarBall({super.key, required this.size});

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size.square(size), painter: const _BallPainter());

  /// Menggambar bola yang sama langsung di [canvas] mengisi [rect] (persegi): untuk painter lain, mis. bola di atas
  /// blok podium, supaya tidak ada salinan kedua dari gambar bola.
  static void paint(Canvas canvas, Rect rect) {
    canvas.save();
    canvas.translate(rect.left, rect.top);
    canvas.scale(rect.width / 48);
    canvas.drawCircle(const Offset(24, 24), 21, Paint()..color = MabarColors.ball);
    canvas.drawCircle(
      const Offset(24, 24),
      21,
      Paint()
        ..color = MabarColors.ballEdge
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    final seam = Paint()
      ..color = const Color(0xFFFFFFFF)
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3
      ..strokeCap = StrokeCap.round;
    canvas.drawPath(Path()..moveTo(6, 15)..cubicTo(14, 20, 20, 26, 20, 42), seam);
    canvas.drawPath(Path()..moveTo(42, 33)..cubicTo(34, 28, 28, 22, 28, 6), seam);
    canvas.restore();
  }
}

/// `.live` — titik bola 7 pt bertepi 1 pt di luar: round yang sedang berjalan (tab), live score yang aktif
/// (menu ⋯, tag "Live"). [off] = titik abu tanpa tepi (tag "Offline").
class LiveDot extends StatelessWidget {
  final bool off;

  const LiveDot({super.key, this.off = false});

  @override
  Widget build(BuildContext context) => Container(
    width: 7,
    height: 7,
    decoration: BoxDecoration(
      color: off ? MabarColors.dim : MabarColors.ball,
      shape: BoxShape.circle,
      border: off ? null : Border.all(color: MabarColors.ballEdge, strokeAlign: BorderSide.strokeAlignOutside),
    ),
  );
}

class _BallPainter extends CustomPainter {
  const _BallPainter();

  @override
  void paint(Canvas canvas, Size size) => MabarBall.paint(canvas, Offset.zero & size);

  @override
  bool shouldRepaint(_BallPainter oldDelegate) => false;
}
