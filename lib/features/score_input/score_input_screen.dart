import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/minute_ticker.dart';
import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/time_text.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../../services/schedule/knockout_bracket.dart';
import '../../services/scoring/score_entry.dart';
import '../../services/scoring/score_reset.dart';
import '../schedule/tournament_controller.dart';
import 'knockout_text.dart';
import 'reset_text.dart';
import 'walkover_sheet.dart';
import 'widgets/score_board.dart';

/// Screen 08 · Input Skor — papan skor gelap dengan satu angka per tim dan keypad sendiri, untuk ketiga
/// format. Aturan keypad dan sah/tidaknya skor di [ScoreEntry] / [ScoreRules]. Simpan → kembali ke Jadwal.
class ScoreInputScreen extends ConsumerStatefulWidget {
  final String matchId;
  const ScoreInputScreen({super.key, required this.matchId});

  @override
  ConsumerState<ScoreInputScreen> createState() => _ScoreInputScreenState();
}

class _ScoreInputScreenState extends ConsumerState<ScoreInputScreen> {
  ScoreEntry? _entry;
  MinuteTicker? _clock;

  @override
  void initState() {
    super.initState();
    // Sisa booking court di subjudul mengikuti jam sungguhan, sama dengan kotak jam di Jadwal.
    _clock = MinuteTicker(
      clock: ref.read(clockProvider),
      origin: () => ref.read(tournamentProvider)?.tournament.createdAt,
      onTick: () {
        if (mounted) setState(() {});
      },
    );
  }

  @override
  void dispose() {
    _clock?.cancel();
    super.dispose();
  }

  /// Skor tersimpan (juga skor lama match WO) dibuka terisi, belum ada kotak aktif sampai diketuk. Match gugur memakai
  /// format babaknya (`formatFor`, 21g/21h).
  ScoreEntry _initial(ActiveTournament active, MatchGame match) => match.sets.isEmpty
      ? ScoreEntry.start(active.config.formatFor(match))
      : ScoreEntry.edit(active.config.formatFor(match), match.sets.first);

  /// Gugur: pemenang berganti dan match lain ikut berganti → dialog susunan baru dulu (21k); Batal = tetap di papan.
  Future<bool> _confirmFlip(ActiveTournament active, MatchGame match, FlipCheck flip) async {
    final phase = match.phase;
    if (flip is! FlipAllowed || flip.preview.isEmpty || phase is! KnockoutPhase) return true;
    return showMabarConfirm(
      context,
      title: knockoutFlipTitle(phase),
      message: knockoutFlipMessage(active, flip.preview),
      confirmLabel: 'Ganti',
    );
  }

  Future<void> _save(ActiveTournament active, MatchGame match, SetScore score, FlipCheck? flip) async {
    if (flip != null && !await _confirmFlip(active, match, flip)) return;
    if (!mounted) return;
    ref.read(tournamentProvider.notifier).submitScore(match.id, [score]);
    context.pop();
  }

  /// Kosongkan skor (07q): dialog akibatnya dulu; menutup ke Jadwal hanya kalau controller `true`. Sengaja bukan
  /// [_confirmFlip] (dia `true` untuk `FlipBlocked`); tombolnya sudah mati untuk yang ditolak.
  Future<void> _clear(ActiveTournament active, MatchGame match, ResetAllowed allowed) async {
    final ok = await showMabarConfirm(
      context,
      title: resetDialogTitle(active, match, ResetAction.clearScore),
      message: resetDialogMessage(active, allowed),
      confirmLabel: resetConfirmLabel(ResetAction.clearScore),
      destructive: true,
    );
    if (!ok || !mounted) return;
    if (ref.read(tournamentProvider.notifier).clearScore(match.id)) context.pop();
  }

  Future<void> _walkover(ActiveTournament active, MatchGame match) async {
    final outcome = await showWalkoverSheet(context, active: active, match: match);
    if (outcome == null || !mounted) return;
    final WalkoverResult result;
    switch (outcome) {
      case RemoveWalkover():
        // Dialog sudah dikonfirmasi di sheet; sheet dan papan menutup hanya kalau mutasinya benar-benar jalan.
        if (ref.read(tournamentProvider.notifier).removeWalkover(match.id)) context.pop();
        return;
      case final WalkoverResult r:
        result = r;
    }
    final winner = result.loserPairId == match.pair1.id ? match.pair2.id : match.pair1.id;
    if (!await _confirmFlip(active, match, KnockoutBracket.flipCheck(active, match.id, winner)) || !mounted) return;
    ref.read(tournamentProvider.notifier).markWalkover(match.id, loserPairId: result.loserPairId, reason: result.reason);
    context.pop();
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    final match = active?.matchById(widget.matchId);
    if (active == null || match == null) return const Scaffold(backgroundColor: MabarColors.paper);

    final entry = _entry ??= _initial(active, match);
    List<String> names(Pair pair) => pair.playerIds.map(active.playerName).toList();
    String team(Pair pair) => names(pair).join(' & ');
    final format = active.config.formatFor(match);
    final score = entry.score;
    final verdict = entry.verdict;
    // Gugur (GU11, AC-G9): pemenang yang diketik dicek sebelum disimpan; ditolak → pesan merah, tombol mati (21l).
    final knockout = match.phase is KnockoutPhase ? match.phase! as KnockoutPhase : null;
    final typedWinner = verdict is ScoreWin ? (verdict.winnerSide == 1 ? match.pair1 : match.pair2) : null;
    final flip = knockout != null && typedWinner != null
        ? KnockoutBracket.flipCheck(active, match.id, typedWinner.id)
        : null;
    final blocked = flip is FlipBlocked ? flip : null;
    final oldWinner = match.winnerPairId == match.pair1.id ? match.pair1 : match.pair2;
    // Pengaman saja: format gugur (Race to / Best of) tidak bisa seri, tapi gugur selalu butuh pemenang, jadi kalau
    // verdict seri tetap jangan bisa disimpan (controller juga menolaknya).
    final canSave = score != null && blocked == null && !(knockout != null && verdict is ScoreDraw);
    // Match Selesai yang kedua kotaknya dikosongkan (07p/07s/07x): tombol jadi Kosongkan skor kalau diizinkan, mati +
    // pesan 21l kalau gugur ditolak, selain itu Perbarui skor mati seperti 3.8.1. Ketersediaan dari ScoreReset.
    final reset = match.status == MatchStatus.done && entry.isEmpty
        ? ScoreReset.check(active, match.id, ResetAction.clearScore)
        : null;
    final resetBlocked = reset is ResetBlocked ? reset : null;
    final typed = switch (verdict) {
      ScoreWin(:final winnerSide, :final winnerScore, :final loserScore) =>
        '${team(winnerSide == 1 ? match.pair1 : match.pair2)} menang $winnerScore–$loserScore',
      ScoreDraw() => 'Seri',
      ScoreInvalid(:final message) => message,
      null => null,
    };
    final feedback = blocked != null
        ? knockoutBlockedMessage(blocked, knockout!, team(oldWinner))
        : resetBlocked != null
        ? knockoutBlockedMessage(resetBlocked.flip, knockout!, team(oldWinner))
        : typed;

    // Sisa booking court ini, hanya untuk match di round yang sedang berjalan; kurang dari satu match → clay.
    final court = active.courtById(match.courtId);
    String? left;
    var short = false;
    if (match.roundNumber == active.runningRound) {
      final minutes = active.remainingBookingMinutes(court, ref.read(clockProvider)());
      left = minutes > 0 ? 'sisa ${countdownText(minutes)}' : 'waktu habis';
      short = minutes < active.config.matchDurationMinutes;
    }

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: court.name,
            subtitle:
                '${knockoutScoreSubtitle(active, match) ?? 'Round ${match.roundNumber} · ${format.label}'}'
                '${left != null && !short ? ' · $left' : ''}',
            subtitleAlert: short ? left : null,
            onBack: () => context.pop(),
            actions: [
              MabarTextButton(label: 'WO', tone: MabarTextTone.danger, onPressed: () => _walkover(active, match)),
            ],
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: ScoreBoard(
              entry: entry,
              names: (names(match.pair1), names(match.pair2)),
              onSelect: (side) => setState(() => _entry = entry.select(side)),
            ),
          ),
          if (feedback != null)
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 0),
              child: Text(
                feedback,
                style: verdict is ScoreInvalid || blocked != null || resetBlocked != null
                    ? MabarType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, color: MabarColors.clay)
                    : MabarType.body.copyWith(fontSize: 15, color: MabarColors.ink2),
              ),
            ),
          const Spacer(),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: reset is ResetAllowed || resetBlocked != null
                ? MabarButton(
                    label: 'Kosongkan skor',
                    variant: MabarButtonVariant.secondaryDanger,
                    onPressed: reset is ResetAllowed ? () => _clear(active, match, reset) : null,
                  )
                : MabarButton(
                    label: match.status == MatchStatus.pending ? 'Simpan skor' : 'Perbarui skor',
                    icon: canSave ? MabarIcons.check : null,
                    onPressed: canSave ? () => _save(active, match, score, flip) : null,
                  ),
          ),
          ScoreKeypad(entry: entry, onChanged: (next) => setState(() => _entry = next)),
        ],
      ),
    );
  }
}
