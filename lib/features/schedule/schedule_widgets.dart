import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_layers.dart';

/// Dialog 06e "Akhiri turnamen?" — dipakai Jadwal Fixed dan Mixed.
Future<bool> confirmFinishTournament(BuildContext context) => showMabarConfirm(
  context,
  title: 'Akhiri turnamen?',
  message: 'Match yang belum main tidak dihitung.',
  confirmLabel: 'Akhiri',
  destructive: true,
);

/// Tombol Klasemen di action bar Jadwal: tombol utama "Lihat klasemen" setelah Final (06c, 12l), sekunder selama
/// turnamen berjalan (06a, 12h). Dipakai Jadwal Fixed dan Jadwal penonton.
class LeaderboardButton extends StatelessWidget {
  final bool isFinal;
  const LeaderboardButton({super.key, required this.isFinal});

  @override
  Widget build(BuildContext context) => MabarButton(
    label: isFinal ? 'Lihat klasemen' : 'Klasemen',
    icon: MabarIcons.ranking,
    variant: isFinal ? MabarButtonVariant.primary : MabarButtonVariant.secondary,
    onPressed: () => context.push('/leaderboard'),
  );
}

/// Back di Jadwal (tombol ‹, back HP, back browser) selalu ke Beranda, bukan ke Atur turnamen/Pasangan di bawahnya:
/// dari sana "Buat jadwal" memulai turnamen baru dan skor yang sudah diisi hilang (keputusan host 2026-11-11).
/// Penonton live tidak punya layar di bawahnya, jadi back-nya dibiarkan.
class ScheduleBackToHome extends StatelessWidget {
  final bool enabled;
  final Widget child;

  const ScheduleBackToHome({super.key, required this.enabled, required this.child});

  @override
  Widget build(BuildContext context) {
    if (!enabled) return child;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.go('/');
      },
      child: child,
    );
  }
}
