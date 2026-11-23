import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../models/models.dart';
import '../../services/ranking/club_score.dart';
import '../../services/ranking/group_knockout_ranking.dart';
import '../../services/schedule/knockout_bracket.dart';
import '../../services/ranking/ranking_calculator.dart';
import '../live/live_view_controller.dart';
import '../schedule/club_score_view.dart';
import '../schedule/sparing_providers.dart';
import '../schedule/tournament_controller.dart';
import 'widgets/standing_table.dart';

/// Status di subjudul Peringkat: "Sementara · R3 · 6 dari 6 match" atau, setelah final, jumlah round dan
/// match yang dimainkan ("Final · 4 round · 7 match") — progres round tidak bermakna lagi setelah selesai.
String rankingStatus(ActiveTournament active, DateTime now) => active.isFinal(now)
    ? 'Final · ${active.playedRoundCount} round · ${active.playedMatchCount} match'
    : 'Sementara · R${active.currentRound} · ${active.playedMatchCount} dari ${active.matches.length} match';

/// Mode di subjudul Klasemen. Grup + Gugur menulis fase yang berjalan selama Sementara ("Fase grup", "Playoff" keputusan 133) dan
/// "Grup + Gugur" setelah Final (20d, 22a, 22d); mode lain tetap `mode.label`.
String rankingModeLabel(ActiveTournament active, DateTime now) {
  final config = active.config;
  if (!config.isGroupKnockout) return config.mode.label;
  if (active.isFinal(now)) return 'Group - Playoff';
  return active.hasBracket ? 'Playoff' : 'Fase grup';
}

/// Tab Klasemen Grup + Gugur setelah bagan dibuat atau turnamen diakhiri (22a, 22b, 22g).
enum _GroupTab { standing, groups }

/// Screen 09 · Peringkat — tabel rapat, status di subjudul. Metode yang dipilih di sini juga dipakai Detail
/// dan Bagikan ([rankingMethodProvider]). Baris diketuk → Detail.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key});

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  bool _scrolled = false;
  _GroupTab _tab = _GroupTab.standing;

  /// Garis bawah app bar begitu isi tergulir ke bawahnya (13o, 14p), sama dengan Konfigurasi.
  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0) {
      final scrolled = n.metrics.pixels > 0;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    if (active == null) return const Scaffold(backgroundColor: MabarColors.paper);

    final watching = ref.watch(liveCodeProvider) != null;
    final method = ref.watch(rankingMethodProvider);
    final config = active.config;
    final format = config.format;
    final fixed = config.mode == PartnerMode.fixed;
    final groupKnockout = config.isGroupKnockout;

    // Sparing: papan skor klub tetap di atas dan satu tabel per klub, nomor mulai #1 di tiap klub (PRD §13, K3).
    final clubResult = ref.watch(clubScoreProvider);
    final clubGroups = clubResult == null ? const <ClubStandings>[] : ref.watch(clubStandingEntriesProvider);
    // Nomor lintas klub tidak dipakai di sparing, jadi provider ini hanya dibaca untuk turnamen biasa.
    final entries = clubResult == null ? ref.watch(standingEntriesProvider) : const <StandingEntry>[];
    // Grup + Gugur: satu tabel per grup; `finalEntries` (lewat standingEntriesProvider) hanya untuk tab Peringkat.
    final groupTables = groupKnockout ? ref.watch(groupTablesProvider) : const <GroupTable>[];
    // Sebelum bagan dan belum diakhiri: hanya tabel grup, tanpa tab (20d, 20f, 20n).
    final showTabs = groupKnockout && (active.hasBracket || active.tournament.isFinished);
    final showStanding = groupKnockout && showTabs && _tab == _GroupTab.standing;

    String record(PlayerStanding s) => format.canDraw ? '${s.wins}–${s.losses}–${s.draws}' : '${s.wins}–${s.losses}';
    final unit = format.unit;

    // [tableMethod]: tabel grup memakai metode default format (keputusan 21), bukan pilihan host. [slotPairIds]: id pasangan per baris → kode lolos
    // A1/A2 di kanan nama (22b). [stage]: peringkat akhir, kolom Babak mengganti angka (22a).
    Widget table(List<StandingEntry> entries, {RankingMethod? tableMethod, List<String>? slotPairIds, bool stage = false}) {
      final shown = tableMethod ?? method;
      final idle = [
        for (final e in entries)
          if (e.position == null) [for (final p in e.players) p.name],
      ];
      return StandingTable(
        subjectLabel: fixed ? 'Pasangan' : 'Pemain',
        recordLabel: format.canDraw ? 'W–L–D' : 'W–L',
        valueLabel: switch (shown) {
          RankingMethod.totalGames => '${unit[0].toUpperCase()}${unit.substring(1)}',
          RankingMethod.pointPercent => 'Point %',
          RankingMethod.winPercent => 'Win %',
        },
        stageLabel: stage ? 'Babak' : null,
        rows: [
          for (final (i, e) in entries.indexed)
            if (e.position case final position?)
              StandingTableRow(
                position: position,
                names: [for (final p in e.players) p.name],
                played: e.standing.matchesPlayed,
                record: record(e.standing),
                diff: e.standing.diffLabel,
                value: switch (shown) {
                  RankingMethod.totalGames => '${e.standing.totalPoint}',
                  RankingMethod.pointPercent => '${e.standing.pointPercent}',
                  RankingMethod.winPercent => '${e.standing.winPercent.round()}',
                },
                tag: slotPairIds == null ? null : KnockoutBracket.seedOf(active, slotPairIds[i]),
                stage: stage ? e.stage : null,
                // Fixed: anggota pertama mewakili pasangannya (statistiknya sama).
                onTap: () => context.push('/detail-player', extra: e.players.first.id),
              ),
        ],
        idleNames: idle,
      );
    }

    final notes = [
      for (final (status, label) in [(MatchStatus.wo, 'match WO'), (MatchStatus.cancelled, 'match tidak dimainkan')])
        if (active.matches.where((m) => m.status == status).length case final n when n > 0) '$n $label',
    ];

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: 'Klasemen',
            subtitle: '${config.sport.label} · ${rankingModeLabel(active, ref.read(clockProvider)())} · ${rankingStatus(active, ref.read(clockProvider)())}',
            scrolled: _scrolled,
            onBack: () => context.pop(),
          ),
          // `.clubscore` di luar ListView: tetap di tempat saat tabel digulir, sama dengan tab metode (13o).
          if (clubResult != null)
            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: clubScoreOf(clubResult)),
          if (clubResult != null) const SizedBox(height: 12),
          if (showTabs)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MabarSegmented<_GroupTab>(
                options: const [(_GroupTab.standing, 'Peringkat'), (_GroupTab.groups, 'Fase grup')],
                selected: _tab,
                onChanged: (t) => setState(() => _tab = t),
              ),
            )
          else if (!groupKnockout)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: MabarSegmented<RankingMethod>(
                options: const [
                  (RankingMethod.totalGames, 'Total Point'),
                  (RankingMethod.pointPercent, 'Point %'),
                  (RankingMethod.winPercent, 'Win %'),
                ],
                selected: method,
                onChanged: (m) => ref.read(rankingMethodProvider.notifier).state = m,
              ),
            ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: ListView(
                padding: EdgeInsets.only(top: 12, bottom: 16 + (watching ? MediaQuery.paddingOf(context).bottom : 0)),
                children: [
                  if (showStanding)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: table(entries, stage: true))
                  else if (groupKnockout)
                    for (final (i, group) in groupTables.indexed)
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, i == 0 ? 0 : 10, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MabarGroupHeader.text('Grup ${GroupKnockout.letter(group.group)}'),
                            const SizedBox(height: 2),
                            table(
                              group.entries,
                              tableMethod: group.method,
                              slotPairIds: active.hasBracket ? group.pairIds : null,
                            ),
                          ],
                        ),
                      )
                  else if (clubResult == null)
                    Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: table(entries))
                  else
                    for (final (i, group) in clubGroups.indexed)
                      Padding(
                        padding: EdgeInsets.fromLTRB(16, i == 0 ? 0 : 10, 16, 0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            MabarGroupHeader.text(group.club.name),
                            const SizedBox(height: 2),
                            table(group.entries),
                          ],
                        ),
                      ),
                  if (notes.isNotEmpty)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 10, 20, 0),
                      child: Text(notes.join(' · '), style: MabarType.caption.copyWith(color: MabarColors.ink3)),
                    ),
                ],
              ),
            ),
          ),
          // Penonton (12j) tidak membagikan poster.
          if (!watching)
            MabarActionBar(
              children: [
                Expanded(
                  child: MabarButton(label: 'Bagikan', icon: MabarIcons.shareNetwork, onPressed: () => context.push('/share')),
                ),
              ],
            ),
        ],
      ),
    );
  }
}
