import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/match_score_row.dart';
import '../../models/models.dart';
import '../../services/ranking/ranking_calculator.dart';
import '../schedule/sparing_providers.dart';
import '../schedule/tournament_controller.dart';
import 'widgets/stat_line.dart';

/// Screen 10 · Detail — pemain (Mixed) atau pasangan (Fixed): satu baris angka, cakupan partner/lawan,
/// dan riwayat match dengan bentuk baris Jadwal. Nomor peringkat ikut metode yang dipilih di Peringkat.
class DetailPlayerScreen extends ConsumerWidget {
  final String playerId;
  const DetailPlayerScreen({super.key, required this.playerId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(tournamentProvider);
    // Satu baris Fixed memuat dua pemain; namanya diambil dari baris itu, bukan dari `standing.player`.
    // Sparing: baris dan nomor per klub dari provider klub, bukan nomor lintas klub.
    final clubPos = ref.watch(playerClubPositionProvider(playerId));
    final clubEntry = clubPos == null
        ? null
        : ref.watch(clubStandingEntriesProvider).expand((g) => g.entries).where((e) => e.hasPlayer(playerId)).firstOrNull;
    final entry = clubEntry ?? ref.watch(standingEntriesProvider).where((e) => e.hasPlayer(playerId)).firstOrNull;
    if (active == null || entry == null) {
      return Scaffold(
        backgroundColor: MabarColors.paper,
        body: Center(
          child: Text('Belum ada turnamen berjalan', style: MabarType.body.copyWith(color: MabarColors.ink3)),
        ),
      );
    }

    final config = active.config;
    final format = config.format;
    final fixed = config.mode == PartnerMode.fixed;
    final s = entry.standing;
    final played = entry.position != null;
    final profile = PlayerProfile.of(playerId: playerId, matches: active.matches);
    final totals = coverageTotals(config, playerId, partnerCount: profile.partnerIds.length);
    final unit = '${format.unit[0].toUpperCase()}${format.unit.substring(1)}';
    final woPerWin = _woPointsPerWin(s, profile, playerId);

    final stats = <StatLineItem>[
      (value: played ? '${s.totalPoint}' : '–', unit: null, label: unit),
      (value: played ? '${s.winPercent.round()}' : '–', unit: played ? '%' : null, label: 'Win'),
      (
        value: !played ? '–' : (format.canDraw ? '${s.wins}–${s.losses}–${s.draws}' : '${s.wins}–${s.losses}'),
        unit: null,
        label: format.canDraw ? 'W–L–D' : 'W–L',
      ),
      (
        value: played ? s.diffLabel : '–',
        unit: null,
        label: 'Selisih ${format.unit}',
      ),
    ];

    Widget count(String text) => Text(text, style: MabarType.numM.copyWith(fontSize: 20, color: MabarColors.ink));

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: entry.players.map((p) => p.name).join(' · '),
            subtitle: [
              played ? 'Peringkat ${entry.position}' : 'Belum main',
              if (clubPos != null) clubPos.club.name,
              config.sport.label,
              config.mode.label,
              format.label,
            ].join(' · '),
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                StatLine(items: stats),
                const SizedBox(height: 16),
                MabarGroup(
                  children: [
                    // Di Fixed biasanya 1, jadi hanya tampil kalau pasangannya pernah diatur ulang (10d).
                    if (!fixed || profile.partnerIds.length > 1)
                      MabarRow(title: 'Beda partner', trailing: count('${profile.partnerIds.length} / ${totals.partners}')),
                    MabarRow(title: 'Beda lawan', trailing: count('${profile.opponentIds.length} / ${totals.opponents}')),
                    MabarRow(title: 'Kalah WO', trailing: count('${s.woLosses}')),
                  ],
                ),
                const SizedBox(height: 16),
                MabarSection(
                  header: const MabarGroupLabel('Riwayat match'),
                  child: profile.playedMatches.isEmpty
                      ? Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: Text(
                            'Belum ada match. Muncul setelah skor pertama diisi.',
                            style: MabarType.body.copyWith(color: MabarColors.ink3),
                          ),
                        )
                      : Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            for (final (i, m) in profile.playedMatches.reversed.indexed) ...[
                              if (i > 0) const SizedBox(height: 8),
                              _HistoryRow(
                                active: active,
                                match: m,
                                playerId: playerId,
                                woPoints: woPerWin,
                                pairRow: entry.players.length > 1,
                              ),
                            ],
                          ],
                        ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Nilai satu kemenangan WO; semua kemenangan WO bernilai sama (rata-rata dari seluruh match sendiri).
  static int _woPointsPerWin(PlayerStanding s, PlayerProfile profile, String playerId) {
    final wins = profile.playedMatches.where((m) {
      if (m.status != MatchStatus.wo) return false;
      final own = m.pair1.contains(playerId) ? m.pair1 : m.pair2;
      return m.woLoserPairId != own.id;
    }).length;
    return wins == 0 ? 0 : s.woPoints ~/ wins;
  }
}

/// Satu match di riwayat: baris atas selalu tim pemain ini (nama sendiri dulu), lawan di bawah dengan "vs".
/// Menang WO menulis tambahan nilainya pudar ("+6") supaya jumlah riwayat cocok dengan angka di atas.
class _HistoryRow extends StatelessWidget {
  final ActiveTournament active;
  final MatchGame match;
  final String playerId;
  final int woPoints;

  /// Baris Klasemen ini pasangan Fixed (dua nama), bukan satu pemain.
  final bool pairRow;

  const _HistoryRow({
    required this.active,
    required this.match,
    required this.playerId,
    required this.woPoints,
    required this.pairRow,
  });

  @override
  Widget build(BuildContext context) {
    final ownIsPair1 = match.pair1.contains(playerId);
    final own = ownIsPair1 ? match.pair1 : match.pair2;
    final other = ownIsPair1 ? match.pair2 : match.pair1;
    // Baris pasangan Fixed: urutan pasangan; per pemain (Mixed, atau Fixed yang pasangannya berubah): nama sendiri dulu.
    final ownIds = pairRow ? own.playerIds : [playerId, ...own.playerIds.where((id) => id != playerId)];
    final ownNames = ownIds.map(active.playerName).toList();
    final otherNames = other.playerIds.map(active.playerName).toList();

    final winner = match.winnerPairId;
    final MatchScoreSide top, bottom;
    if (match.status == MatchStatus.wo) {
      final won = winner == own.id;
      top = won
          ? MatchScoreSide(names: ownNames, scores: ['+$woPoints'], tone: MatchScoreTone.credit, win: true)
          : MatchScoreSide(names: ownNames, tag: 'WO');
      bottom = won
          ? MatchScoreSide(names: otherNames, prefix: 'vs ', tag: 'WO')
          : MatchScoreSide(names: otherNames, prefix: 'vs ', win: true);
    } else {
      final ownScore = ownIsPair1 ? match.pair1TotalGames : match.pair2TotalGames;
      final otherScore = ownIsPair1 ? match.pair2TotalGames : match.pair1TotalGames;
      MatchScoreSide side(List<String> names, int score, String pairId, {String prefix = ''}) => MatchScoreSide(
        names: names,
        prefix: prefix,
        scores: ['$score'],
        win: winner == pairId,
        tone: winner != null && winner != pairId ? MatchScoreTone.lost : MatchScoreTone.normal,
      );
      top = side(ownNames, ownScore, own.id);
      bottom = side(otherNames, otherScore, other.id, prefix: 'vs ');
    }
    return MatchScoreRow(
      badge: 'R${match.roundNumber}',
      badgeColor: MabarColors.ink,
      badgeFontSize: 14,
      compact: true,
      top: top,
      bottom: bottom,
      note: match.status == MatchStatus.done && winner == null ? 'Seri' : null,
    );
  }
}
