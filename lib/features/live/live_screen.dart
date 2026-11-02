import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_ball.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../models/models.dart';
import '../schedule/schedule_fixed_screen.dart';
import '../schedule/schedule_mixed_screen.dart';
import '../schedule/tournament_controller.dart';
import 'live_view_controller.dart';
import 'open_home.dart';

/// Halaman penonton `#/live/KODE` (12h–12o): Jadwal Fixed/Mixed yang sama dengan host dalam mode baca saja,
/// atau keadaan memuat / tidak ditemukan.
class LiveScreen extends ConsumerWidget {
  const LiveScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Live dihentikan saat penonton membuka Klasemen/Detail: layar itu kehilangan turnamennya, jadi kembali ke sini
    // untuk menampilkan pesannya.
    ref.listen(liveViewProvider.select((v) => v?.status), (_, status) {
      if (status == LiveViewStatus.gone || status == LiveViewStatus.unreadable) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    });
    final status = ref.watch(liveViewProvider.select((v) => v?.status));
    final active = ref.watch(tournamentProvider);
    return switch (status) {
      null || LiveViewStatus.gone => const _LiveMessage('Live tidak ditemukan'),
      LiveViewStatus.unreadable => const _LiveMessage('Live tidak bisa dibuka'),
      _ when active == null => const _LiveLoading(),
      _ =>
        active.config.mode == PartnerMode.fixed
            ? ScheduleFixedScreen(config: active.config)
            : ScheduleMixedScreen(config: active.config),
    };
  }
}

/// `.centermsg` — isi di tengah ruang di bawah app bar kosong, 80 pt lebih tinggi dari tengah layar.
class _Centered extends StatelessWidget {
  final Widget child;
  const _Centered({required this.child});

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: MabarColors.paper,
    body: Padding(
      // App bar tanpa judul: 7 pt di bawah safe area + padding bawah 12.
      padding: EdgeInsets.fromLTRB(32, MediaQuery.paddingOf(context).top + 19, 32, 80),
      child: Center(child: child),
    ),
  );
}

class _LiveMessage extends StatelessWidget {
  final String title;
  const _LiveMessage(this.title);

  @override
  Widget build(BuildContext context) => _Centered(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: TextAlign.center,
          style: MabarType.sheetTitle.copyWith(color: MabarColors.ink, height: 1.15),
        ),
        const SizedBox(height: 14),
        const MabarButton(label: 'Buka Match Addict', variant: MabarButtonVariant.secondary, small: true, onPressed: openHome),
      ],
    ),
  );
}

/// 12o: bola wordmark berputar sampai pengecekan pertama kembali (diam kalau animasi dimatikan).
class _LiveLoading extends StatefulWidget {
  const _LiveLoading();

  @override
  State<_LiveLoading> createState() => _LiveLoadingState();
}

class _LiveLoadingState extends State<_LiveLoading> with SingleTickerProviderStateMixin {
  late final _spin = AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (MediaQuery.disableAnimationsOf(context)) {
      _spin.stop();
    } else if (!_spin.isAnimating) {
      _spin.repeat();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _Centered(
    child: RotationTransition(turns: _spin, child: const MabarBall(size: 40)),
  );
}
