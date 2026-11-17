import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/time_text.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/match_score_row.dart';
import '../../../models/models.dart';
import '../../../services/schedule/knockout_bracket.dart';

/// Subjudul app bar Jadwal: "Tennis · Race to 6", atau "… · diakhiri". Waktu tidak di sini: court bisa mulai di
/// jam berbeda, jadi sisa booking ditulis di strip court masing-masing ([ScheduleMatchRow]). [named] = halaman
/// penonton: nama turnamen menggantikan olahraga kalau ada, seperti Beranda (12h).
String scheduleSubtitle(ActiveTournament active, {bool named = false}) {
  final config = active.config;
  final lead = named ? config.name ?? config.sport.label : config.sport.label;
  return '$lead · ${config.format.label}${active.tournament.isFinished ? ' · diakhiri' : ''}';
}

/// Nama lengkap pasangan (baris match, Istirahat Fixed "Andi P · Budi S"). Bukan nama depan: dua pemain bernama depan
/// sama ("Lia Ibun", "Lia Ncii") jadi tidak terbedakan (06u).
List<String> pairNames(ActiveTournament active, Pair pair) => [for (final id in pair.playerIds) active.playerName(id)];

/// Satu match di Jadwal sebagai [MatchScoreRow]: strip court bernomor (42 pt), nama pasangan "Andi P · Budi S",
/// skor / WO / Seri / "Tidak dimainkan". [onTap] null = tidak bisa diketuk (round terkunci, dibatalkan).
/// [onFill] = tombol "Isi skor" untuk match yang belum diisi. Di round yang sedang berjalan strip-nya membawa sisa
/// booking court itu pada [now]. [onSwapTop] / [onSwapBottom] = ikon tukar pemain di tim atas / bawah (null = tanpa
/// ikon). [preview] = pratinjau di sheet Tukar pemain: tanpa hitung mundur, latar paper.
class ScheduleMatchRow extends StatelessWidget {
  final ActiveTournament active;
  final MatchGame match;
  final DateTime now;
  final VoidCallback? onTap;
  final VoidCallback? onFill;
  final VoidCallback? onSwapTop;
  final VoidCallback? onSwapBottom;
  final bool preview;

  const ScheduleMatchRow({
    super.key,
    required this.active,
    required this.match,
    required this.now,
    this.onTap,
    this.onFill,
    this.onSwapTop,
    this.onSwapBottom,
    this.preview = false,
  });

  @override
  Widget build(BuildContext context) {
    final courts = active.config.courts;
    final court = active.courtById(match.courtId);

    final winner = match.winnerPairId;
    final phase = match.phase;
    final gk = active.config.groupKnockout;
    // Grup + Gugur: sisi gugur yang belum diketahui ditulis dari asalnya ("Pemenang SF1"), bukan pairById('').
    final sources = phase is KnockoutPhase && gk != null
        ? KnockoutBracket.sources(phase, groupCount: gk.groupCount)
        : null;
    final hasTbd = match.pair1.isTbd || match.pair2.isTbd;
    MatchScoreSide side(Pair pair, int score, VoidCallback? onSwap, SideSource? source) {
      if (pair.isTbd) {
        return MatchScoreSide(
          names: [if (source != null) KnockoutBracket.sourceLabel(source)],
          seed: '',
          tbd: true,
        );
      }
      final names = pairNames(active, pair);
      final seed = phase is KnockoutPhase ? (KnockoutBracket.seedOf(active, pair.id) ?? '') : null;
      return switch (match.status) {
        MatchStatus.done => MatchScoreSide(
          names: names,
          seed: seed,
          scores: ['$score'],
          win: winner == pair.id,
          tone: winner != null && winner != pair.id ? MatchScoreTone.lost : MatchScoreTone.normal,
        ),
        MatchStatus.wo when match.woLoserPairId == pair.id => MatchScoreSide(
          names: names,
          seed: seed,
          tag: match.woReason == null ? 'WO' : 'WO · ${match.woReason!.label}',
        ),
        MatchStatus.wo => MatchScoreSide(names: names, seed: seed, win: true),
        _ => MatchScoreSide(names: names, seed: seed, onSwap: onSwap),
      };
    }

    final cancelled = match.status == MatchStatus.cancelled;
    final draw = match.status == MatchStatus.done && winner == null;
    return MatchScoreRow(
      badge: '${courts.indexOf(court) + 1}',
      badgeColor: MabarColors.courtPalette[court.colorIndex],
      badgeWidth: 42,
      fill: preview ? MabarColors.paper : MabarColors.card,
      countdown: !preview && match.roundNumber == active.runningRound
          ? countdownText(active.remainingBookingMinutes(court, now))
          : null,
      label: switch (phase) {
        GroupPhase() => 'Grup ${phase.code}',
        KnockoutPhase() => KnockoutBracket.matchLabel(active.config, match),
        null => null,
      },
      labelOverlap: phase is KnockoutPhase ? 2 : 4,
      top: side(match.pair1, match.pair1TotalGames, onSwapTop, sources?.$1),
      bottom: side(match.pair2, match.pair2TotalGames, onSwapBottom, sources?.$2),
      cancelled: cancelled,
      note: cancelled ? 'Tidak dimainkan' : (draw ? 'Seri' : null),
      trailing: onFill == null || hasTbd ? null : MabarButton(label: 'Isi skor', small: true, onPressed: onFill),
      onTap: cancelled || hasTbd ? null : onTap,
    );
  }
}
