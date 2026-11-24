import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_inputs.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../../../services/schedule/config_summary.dart';
import '../tournament_controller.dart';

/// Menu ⋯ → "Format playoff" (23m → 23n): sheet Playoff dari Jadwal, satu baris per babak. Ketuk baris → sheet babak
/// ([showRoundFormatSheet]). Perubahan langsung berlaku lewat controller, tanpa dialog (G16).
Future<void> showPlayoffSheet(BuildContext context) =>
    showMabarSheetRoute<void>(context, builder: (_) => const PlayoffFormatSheet());

/// Sheet satu babak (23o–23r) di atas sheet yang sedang terbuka: format babak, dan Ada / Tidak ada untuk Perebutan
/// juara 3. Dipakai menu ⋯ dan label kolom Bagan (keputusan 120).
Future<void> showRoundFormatSheet(BuildContext context, KnockoutRound round) =>
    showMabarSheetRoute<void>(context, builder: (_) => RoundFormatSheet(round: round));

/// Isi [showPlayoffSheet]; publik untuk golden.
class PlayoffFormatSheet extends ConsumerWidget {
  const PlayoffFormatSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(tournamentProvider);
    final locks = ref.watch(playoffLocksProvider);
    final gk = active?.config.groupKnockout;
    if (active == null || gk == null || locks == null) return const SizedBox.shrink();
    // Urutan main; Juara 3 selalu ada di daftar, matinya tertulis "Tidak ada" (19e).
    final rounds = [
      if (gk.groupCount >= 3) KnockoutRound.quarterfinal,
      KnockoutRound.semifinal,
      KnockoutRound.thirdPlace,
      KnockoutRound.finalRound,
    ];
    return MabarSheet(
      title: 'Playoff',
      subtitle: ConfigSummary.playoffOpening(gk.groupCount),
      child: MabarGroup(
        color: MabarColors.paper,
        children: [
          for (final r in rounds)
            _row(
              context,
              r,
              value: r == KnockoutRound.thirdPlace && !gk.thirdPlace
                  ? 'Tidak ada'
                  : active.config.groupKnockout!.formats[r]!.label,
              lock: locks.formats[r],
            ),
        ],
      ),
    );
  }

  /// Babak yang ada skor: alasan di bawah judul + ikon kunci tanpa chevron (23q); ketuk tetap membuka sheet terkunci.
  Widget _row(BuildContext context, KnockoutRound r, {required String value, String? lock}) => MabarRow(
    key: ValueKey(r),
    title: r.label,
    subtitle: lock,
    padded: lock != null,
    value: value,
    chevron: lock == null,
    trailing: lock == null
        ? null
        : const Icon(MabarIcons.lockSimple, size: MabarSize.iconInButton, color: MabarColors.faint),
    onTap: () => showRoundFormatSheet(context, r),
  );
}

/// Isi [showRoundFormatSheet]; publik untuk golden. Kontrol mati kalau terkunci, alasannya di subjudul.
class RoundFormatSheet extends ConsumerWidget {
  final KnockoutRound round;
  const RoundFormatSheet({super.key, required this.round});

  static String _targetTitle(ScoringMethod method) => switch (method) {
    ScoringMethod.raceTo => 'Target game',
    ScoringMethod.bestOf => 'Game per match',
    ScoringMethod.americano => 'Poin per match',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(tournamentProvider);
    final locks = ref.watch(playoffLocksProvider);
    final gk = active?.config.groupKnockout;
    final format = gk?.formats[round];
    if (active == null || gk == null || locks == null || format == null) return const SizedBox.shrink();
    final controller = ref.read(tournamentProvider.notifier);
    final isThird = round == KnockoutRound.thirdPlace;
    final formatLock = locks.formats[round];
    final thirdLock = isThird ? locks.thirdPlace : null;
    final method = format.method;
    final odd = method != ScoringMethod.raceTo;
    final subtitle = formatLock != null
        ? 'Terkunci · $formatLock'
        : (thirdLock != null ? 'Ada / Tidak ada terkunci · $thirdLock' : null);
    return MabarSheet(
      title: round.label,
      subtitle: subtitle,
      child: MabarGroup(
        color: MabarColors.paper,
        children: [
          if (isThird)
            MabarRow.stack(
              children: [
                MabarSegmented<bool>(
                  options: const [(true, 'Ada'), (false, 'Tidak ada')],
                  selected: gk.thirdPlace,
                  enabled: thirdLock == null,
                  onChanged: controller.setThirdPlace,
                ),
              ],
            ),
          // Tidak ada menyembunyikan formatnya, bukan menghapusnya (19g).
          if (!isThird || gk.thirdPlace) ...[
            MabarRow.stack(
              children: [
                MabarSegmented<ScoringMethod>(
                  options: [for (final m in ScoringMethodX.selectable) (m, m.label)],
                  selected: method,
                  enabled: formatLock == null,
                  onChanged: (m) => controller.setPlayoffFormat(round, ScoreFormat(m, m.defaultTarget)),
                ),
              ],
            ),
            MabarRow(title: _targetTitle(method), trailing: _stepper(controller, format, odd, formatLock != null)),
          ],
        ],
      ),
    );
  }

  Widget _stepper(TournamentController controller, ScoreFormat format, bool odd, bool locked) {
    final method = format.method;
    // Americano 2 tidak ganjil: batas bawahnya 3 (sama dengan sheet babak Konfigurasi).
    final min = odd && method.minTarget.isEven ? method.minTarget + 1 : method.minTarget;
    final stepper = MabarStepper(
      semanticName: _targetTitle(method).toLowerCase(),
      value: format.target,
      // Terkunci: batas = nilai, jadi kedua tombol pudar; IgnorePointer menutup ketik angka.
      min: locked ? format.target : min,
      max: locked ? format.target : method.maxTarget,
      step: odd ? 2 : 1,
      unit: method == ScoringMethod.americano ? null : method.unit,
      normalizeTyped: odd ? (n) => n.isEven ? n + 1 : n : null,
      onChanged: (n) => controller.setPlayoffFormat(round, ScoreFormat(method, n)),
    );
    return locked ? IgnorePointer(child: stepper) : stepper;
  }
}
