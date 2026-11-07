import 'package:flutter/material.dart';

import '../../../core/app_version.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/court_painter.dart';
import '../../../core/widgets/mabar_ball.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../models/models.dart';

/// Baris kecil sparing tanpa nama: "PB Garuda 6 – 4 Matcha Club". Angka sudah jadi teks dari `ClubResult`.
class CourtBannerClubs {
  final String club1, club2;

  /// "6 – 4", "6½ – 3½", "0 – 0".
  final String score;

  const CourtBannerClubs({required this.club1, required this.score, required this.club2});
}

/// Isi `.liveblock`: turnamen yang sedang berjalan, ditulis di zona belakang lapangan.
class CourtBannerLive {
  /// Nama turnamen atau "Padel · Mixed · 8 pemain"; satu baris, elipsis.
  final String subtitle;

  /// "Round 3".
  final String title;

  /// 0–1, isi bilah `.prog`.
  final double progress;

  /// "6 dari 8 match".
  final String matches;
  final VoidCallback onContinue;

  /// Kalau ada, menggantikan [subtitle] (sparing tanpa nama, 14x).
  final CourtBannerClubs? clubs;

  const CourtBannerLive({
    this.clubs,
    required this.subtitle,
    required this.title,
    required this.progress,
    required this.matches,
    required this.onContinue,
  });
}

/// `.court-band` — banner Beranda: sudut lapangan [sport] ([CourtPainter]), wordmark, lalu nama
/// olahraga dicat besar di service box, atau info turnamen berjalan ([live]). Mengisi tinggi yang
/// diberikan; gambarnya menempel ke atas mengikuti safe area (frame: status bar 47).
///
/// Ganti [sport] = animasi 01g: 450 ms `easeInOutCubic`, garis bergerak dan warna menyapu dari dinding
/// belakang, nama crossfade. Dengan reduce motion hanya crossfade 150 ms.
class CourtBanner extends StatefulWidget {
  final SportType sport;
  final CourtBannerLive? live;

  const CourtBanner({super.key, required this.sport, this.live});

  @override
  State<CourtBanner> createState() => _CourtBannerState();
}

class _CourtBannerState extends State<CourtBanner> with SingleTickerProviderStateMixin {
  static const _duration = Duration(milliseconds: 450), _reducedDuration = Duration(milliseconds: 150);

  /// Posisi garis: 0 = tennis, 1 = padel. Berganti arah di tengah jalan = lanjut dari posisi sekarang
  /// (`animateTo`), jadi garis tidak meloncat; `Curves.easeInOutCubic` tidak simetris sempurna.
  late final _position = AnimationController(vsync: this, value: _target(widget.sport));

  static double _target(SportType sport) => sport == SportType.padel ? 1 : 0;

  @override
  void didUpdateWidget(CourtBanner old) {
    super.didUpdateWidget(old);
    if (old.sport == widget.sport) return;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final target = _target(widget.sport);
    final distance = (target - _position.value).abs();
    _position.animateTo(
      target,
      duration: (reduced ? _reducedDuration : _duration) * distance,
      curve: reduced ? Curves.linear : Curves.easeInOutCubic,
    );
  }

  @override
  void dispose() {
    _position.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final reduced = MediaQuery.disableAnimationsOf(context);
    final layout = CourtLayout.banner.withTop(top + CourtLayout.banner.cornerTop - 47);
    return ClipRect(
      child: AnimatedBuilder(
        animation: _position,
        builder: (context, _) {
          final to = widget.sport;
          final from = to == SportType.padel ? SportType.tennis : SportType.padel;
          // Seberapa jauh menuju olahraga baru, 0–1.
          final progress = 1 - (_target(to) - _position.value).abs();
          final done = progress == 1;
          final Widget court;
          if (done || !reduced) {
            court = CustomPaint(painter: CourtPainter(t: _position.value, toward: to, layout: layout));
          } else {
            court = Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: CourtPainter.of(from, layout: layout)),
                Opacity(opacity: progress, child: CustomPaint(painter: CourtPainter.of(to, layout: layout))),
              ],
            );
          }
          // Nama lama sudah hilang di 30% jalan supaya dua kata tidak bertumpuk (01g 200 ms: hanya
          // "Padel" setengah pudar); dengan reduce motion crossfade biasa.
          final fadeOut = reduced ? 1 - progress : (1 - progress / 0.3).clamp(0.0, 1.0);
          return Stack(
            fit: StackFit.expand,
            children: [
              court,
              Positioned(left: 16, right: 16, top: top + 11, child: const _Wordmark()),
              Positioned(right: 16, top: top + 11, height: 28, child: const _AppVersion()),
              if (widget.live case final live?)
                _LiveBlock(live: live, sport: to, top: top)
              else ...[
                if (!done) _sportName(from, top, fadeOut),
                _sportName(to, top, progress),
              ],
            ],
          );
        },
      ),
    );
  }

  /// `.sportname` — nama olahraga di dalam service box.
  Widget _sportName(SportType sport, double top, double opacity) => Positioned(
    left: 16,
    top: top + 93,
    child: Opacity(
      opacity: opacity,
      child: Text(sport.label, style: MabarType.scoreXl.copyWith(color: Colors.white)),
    ),
  );
}

/// `.appver` — "v3.2.0" di kanan atas, sejajar dasar wordmark, di run-off biru di atas dinding lapangan
/// (jadi sama untuk tennis dan padel dan tidak bertabrakan dengan info round). Bukan tombol.
class _AppVersion extends StatelessWidget {
  const _AppVersion();

  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.bottomRight,
    // Rata bawah dengan padding 3 di kotak setinggi wordmark (CSS `.appver`).
    child: Padding(
      padding: const EdgeInsets.only(bottom: 3),
      child: Text(
        'v$appVersion',
        style: MabarType.caption.copyWith(
          fontWeight: FontWeight.w500,
          height: 1,
          color: Colors.white,
          fontFeatures: MabarType.tabular,
        ),
      ),
    ),
  );
}

/// `.wordmark` — bola brand + "Match Addict" lebar. Di layar sempit atau teks diperbesar wordmark mengecil,
/// tidak terpotong: namanya dua kata panjang, tidak seperti "mabar" dulu.
class _Wordmark extends StatelessWidget {
  const _Wordmark();

  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      const MabarBall(size: 30),
      const SizedBox(width: 9),
      Flexible(
        child: FittedBox(
          fit: BoxFit.scaleDown,
          alignment: Alignment.centerLeft,
          child: Text('Match Addict', style: MabarType.wordmark.copyWith(color: Colors.white)),
        ),
      ),
    ],
  );
}

/// `.liveblock` — padel di antara dinding dan service line (lebar 300), tennis di dalam kotak singles
/// supaya tidak menyentuh garis alley (lebar 250).
class _LiveBlock extends StatelessWidget {
  final CourtBannerLive live;
  final SportType sport;
  final double top;

  const _LiveBlock({required this.live, required this.sport, required this.top});

  @override
  Widget build(BuildContext context) {
    final padel = sport == SportType.padel;
    final text = MabarType.body.copyWith(fontSize: 14, color: Colors.white);
    return Positioned(
      left: 16,
      top: top + (padel ? 73 : 77),
      width: padel ? 300 : 250,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (live.clubs case final clubs?)
            // Satu baris; tiap nama klub berelipsis sendiri, skor tebal tidak pernah terpotong.
            Row(
              children: [
                Flexible(child: Text(clubs.club1, style: text, maxLines: 1, overflow: TextOverflow.ellipsis)),
                Text(' ', style: text),
                Text(clubs.score, style: text.copyWith(fontWeight: FontWeight.w700)),
                Text(' ', style: text),
                Flexible(child: Text(clubs.club2, style: text, maxLines: 1, overflow: TextOverflow.ellipsis)),
              ],
            )
          else
            Text(live.subtitle, style: text, maxLines: 1, overflow: TextOverflow.ellipsis),
          const SizedBox(height: 10),
          Text(live.title, style: MabarType.scoreL.copyWith(color: Colors.white)),
          const SizedBox(height: 10),
          ClipRRect(
            borderRadius: BorderRadius.circular(3),
            child: SizedBox(
              height: 5,
              child: ColoredBox(
                color: const Color(0x33FFFFFF),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: live.progress.clamp(0.0, 1.0),
                  child: const ColoredBox(color: MabarColors.ball),
                ),
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: Text(live.matches, style: text)),
              const SizedBox(width: 12),
              // `.liveblock .btn` 46 pt, lebih rendah dari tombol biasa supaya muat di zona belakang lapangan.
              MabarButton(
                label: 'Lanjutkan',
                variant: MabarButtonVariant.ball,
                expand: false,
                height: 46,
                onPressed: live.onContinue,
              ),
            ],
          ),
        ],
      ),
    );
  }
}
