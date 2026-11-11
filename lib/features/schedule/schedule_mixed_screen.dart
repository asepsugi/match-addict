import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/minute_ticker.dart';
import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../../services/schedule/endless_round_generator.dart';
import '../live/live_score.dart';
import '../live/live_view_controller.dart';
import 'club_score_view.dart';
import 'mixed/manage_courts_sheet.dart';
import 'mixed/manage_players_sheet.dart';
import 'mixed/mixed_guide_sheet.dart';
import 'mixed/resume_tournament_sheet.dart';
import 'schedule_widgets.dart';
import 'sparing_providers.dart';
import 'tournament_controller.dart';
import 'widgets/resting_list.dart';
import 'widgets/round_tabs.dart';
import 'widgets/schedule_match_row.dart';

enum _MenuAction { live, courts, guide, finish }

/// Screen 06 · Jadwal Mixed — round dibuat satu per satu. Tab default = round terakhir; tombol bawah
/// selalu untuk round berikutnya dan menulis alasannya kalau belum bisa. Di halaman penonton (12h) baca saja.
class ScheduleMixedScreen extends ConsumerStatefulWidget {
  final TournamentConfig config;
  const ScheduleMixedScreen({super.key, required this.config});

  @override
  ConsumerState<ScheduleMixedScreen> createState() => _ScheduleMixedScreenState();
}

class _ScheduleMixedScreenState extends ConsumerState<ScheduleMixedScreen> {
  /// Null = round terakhir; kembali ke sana setelah Buat/Batalkan. Mengetuk tab round terakhir juga null, jadi
  /// penonton di round terakhir ikut pindah saat host membuat round baru.
  int? _selectedRound;
  MinuteTicker? _clock;

  @override
  void initState() {
    super.initState();
    // Provider tidak boleh diubah selama widget sedang dibangun, jadi turnamen dimulai sesudah frame ini.
    Future.microtask(() {
      if (!mounted || ref.read(liveCodeProvider) != null) return;
      final before = ref.read(tournamentProvider);
      ref.read(tournamentProvider.notifier).startIfNeeded(widget.config);
      final after = ref.read(tournamentProvider);
      // Cara kerja Mixed muncul sendiri sekali, saat R1 baru saja dibuat dari Konfigurasi.
      if (after != null && !identical(before, after) && after.roundCount == 1) showMixedGuideSheet(context, after);
    });
    // Kotak jam di strip court, daftar Prioritas, dan "Waktu habis" mengikuti jam sungguhan: ditik di setiap
    // pergantian menit sejak turnamen dimulai.
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

  Future<void> _openMenu(BuildContext anchor, ActiveTournament active) async {
    final picked = await showMabarMenu<_MenuAction>(
      anchor,
      items: [
        liveScoreMenuItem(ref, _MenuAction.live),
        if (active.canManageCourts)
          const MabarMenuItem(icon: MabarIcons.squareSplitHorizontal, label: 'Kelola court', value: _MenuAction.courts),
        const MabarMenuItem(icon: MabarIcons.info, label: 'Cara kerja Mixed', value: _MenuAction.guide),
        if (!active.tournament.isFinished)
          const MabarMenuItem(
            icon: MabarIcons.flag,
            label: 'Akhiri turnamen',
            value: _MenuAction.finish,
            danger: true,
            dividerBefore: true,
          ),
      ],
    );
    if (!mounted) return;
    switch (picked) {
      case _MenuAction.live:
        await openLiveScore(context, ref);
      case _MenuAction.courts:
        await showManageCourtsSheet(context);
      case _MenuAction.guide:
        await showMixedGuideSheet(context, active);
      case _MenuAction.finish:
        if (!await confirmFinishTournament(context)) return;
        ref.read(tournamentProvider.notifier).finishNow();
        if (mounted) context.push('/leaderboard');
      case null:
    }
  }

  void _generateNext() {
    ref.read(tournamentProvider.notifier).generateNextRound();
    setState(() => _selectedRound = null);
  }

  Future<void> _cancelLastRound(int round) async {
    final ok = await showMabarConfirm(
      context,
      title: 'Batalkan R$round?',
      message: 'Jadwal R$round dihapus. Tambahkan pemain yang baru datang lewat Kelola pemain, lalu tekan "Buat R$round" lagi.',
      confirmLabel: 'Batalkan R$round',
      destructive: true,
    );
    if (!ok) return;
    ref.read(tournamentProvider.notifier).cancelLastRound();
    setState(() => _selectedRound = null);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    if (active == null || active.roundCount == 0) return const Scaffold(backgroundColor: MabarColors.paper);

    final watching = ref.watch(liveCodeProvider) != null;
    final clubScore = ref.watch(clubScoreProvider);
    final now = ref.read(clockProvider)();
    final finished = active.tournament.isFinished;
    final last = active.roundCount;
    final selected = (_selectedRound ?? last).clamp(1, last);
    final onLast = selected == last;
    final matches = active.matchesOfRound(selected);
    final played = matches.where((m) => m.status == MatchStatus.done || m.status == MatchStatus.wo).length;
    final pending = active.matchesOfRound(last).where((m) => m.status == MatchStatus.pending).length;
    final nextCourts = active.courtsAvailableAt(now).length;
    final timeUp = !finished && nextCourts == 0;

    void openScore(MatchGame m) => context.push('/score-input', extra: m.id);

    // Round terakhir: dari pemain aktif sekarang, dibagi menurut slot R(n+1). Round lewat: catatan saat
    // round itu dibuat.
    final List<Widget> resting;
    // Sparing: papan skor klub di atas daftar (ikut tergulir, 13m) dan Istirahat per klub dua kolom.
    if (active.config.isSparing) {
      if (onLast) {
        // Per klub, bukan gabungan: tiap klub punya slot dan prioritasnya sendiri (AC-S11).
        final split = EndlessRoundGenerator.restingByClubAfterLastRound(active, now);
        List<RestingClub> column(
          List<Player> Function(({Club club, List<Player> priority, List<Player> later})) pick,
        ) => [
          for (final c in split) RestingClub(club: c.club.name, names: [for (final p in pick(c)) p.name]),
        ];
        final priority = column((c) => c.priority);
        final later = column((c) => c.later);
        resting = [
          if (priority.any((c) => c.names.isNotEmpty)) RestingList.clubs(clubs: priority, priorityRound: last + 1),
          if (later.any((c) => c.names.isNotEmpty))
            RestingList.clubs(clubs: later, priorityRound: last + 1, later: true),
        ];
      } else {
        final past = [
          for (final c in active.restingPlayersByClub(selected))
            RestingClub(club: c.club.name, names: [for (final p in c.players) p.name]),
        ];
        resting = [if (past.any((c) => c.names.isNotEmpty)) RestingList.clubs(clubs: past)];
      }
    } else if (onLast) {
      final split = EndlessRoundGenerator.restingAfterLastRound(active, now);
      resting = [
        if (split.priority.isNotEmpty)
          RestingList(names: [for (final p in split.priority) p.name], priorityRound: last + 1),
        if (split.later.isNotEmpty) RestingList.later(names: [for (final p in split.later) p.name], nextRound: last + 1),
      ];
    } else {
      final ids = active.restingPlayerIdsByRound[selected] ?? const [];
      resting = [if (ids.isNotEmpty) RestingList(names: [for (final id in ids) active.playerName(id)])];
    }

    final Widget primary;
    if (active.canResume(now)) {
      primary = MabarButton(
        label: finished ? 'Lanjutkan turnamen' : 'Tambah jam',
        icon: MabarIcons.clock,
        onPressed: () => showResumeTournamentSheet(context, active),
      );
    } else if (pending > 0) {
      primary = MabarButton(
        label: 'Buat R${last + 1}',
        meta: '· tunggu $pending match',
        variant: MabarButtonVariant.wait,
      );
    } else {
      // Court yang habis di tengah: round berikutnya dapat court lebih sedikit dari round terakhir.
      // Sparing: yang dihitung court aktif C' (court yang muat, dibatasi pemain tiap klub), bukan court tersedia.
      final (club1, club2) = active.activePlayersByClub;
      final nextActive = active.config.isSparing
          ? ActiveTournament.sparingActiveCourts(courts: nextCourts, club1: club1.length, club2: club2.length)
          : nextCourts;
      final fewer = nextActive < active.matchesOfRound(last).map((m) => m.courtId).toSet().length;
      primary = MabarButton(
        label: 'Buat R${last + 1}',
        meta: fewer ? '· $nextActive court' : null,
        icon: MabarIcons.plus,
        onPressed: _generateNext,
      );
    }

    return ScheduleBackToHome(
      enabled: !watching,
      child: Scaffold(
        backgroundColor: MabarColors.paper,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MabarAppBar(
              title: 'Round $selected',
              subtitle: scheduleSubtitle(active, named: watching),
              onBack: watching ? null : () => context.go('/'),
              actions: [
                if (!watching)
                  Builder(
                    builder: (anchor) => MabarIconButton(
                      icon: MabarIcons.dotsThree,
                      semanticLabel: 'Menu',
                      onPressed: () => _openMenu(anchor, active),
                    ),
                  )
                else if (!active.isFinal(now))
                  const LiveTag(),
              ],
            ),
            RoundTabs(
              count: last,
              selected: selected,
              onSelect: (r) => setState(() => _selectedRound = r == last ? null : r),
              liveRound: !finished && !active.isRoundComplete(last) ? last : null,
              meta: timeUp ? 'Waktu habis' : '$played/${matches.length} match',
              metaAlert: timeUp,
            ),
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
                children: [
                  if (clubScore != null) ...[clubScoreOf(clubScore), const SizedBox(height: 16)],
                  for (final (i, m) in matches.indexed) ...[
                    if (i > 0) const SizedBox(height: 8),
                    ScheduleMatchRow(
                      active: active,
                      match: m,
                      now: now,
                      onTap: watching ? null : () => openScore(m),
                      onFill: !watching && m.status == MatchStatus.pending ? () => openScore(m) : null,
                    ),
                  ],
                  for (final list in resting) ...[const SizedBox(height: 16), list],
                  // Hanya di tab round terakhir: di tab lain bisa terbaca membatalkan round yang dilihat.
                  if (!watching && onLast && active.canCancelLastRound) ...[
                    const SizedBox(height: 16),
                    Center(
                      child: MabarButton(
                        label: 'Batalkan R$last',
                        icon: MabarIcons.arrowCounterClockwise,
                        variant: MabarButtonVariant.ghost,
                        small: true,
                        onPressed: () => _cancelLastRound(last),
                      ),
                    ),
                  ],
                ],
              ),
            ),
            MabarActionBar(
              children: watching
                  ? [Expanded(child: LeaderboardButton(isFinal: active.isFinal(now)))]
                  : [
                      MabarIconButton(
                        icon: MabarIcons.ranking,
                        semanticLabel: 'Klasemen',
                        solid: true,
                        onPressed: () => context.push('/leaderboard'),
                      ),
                      if (!finished)
                        MabarIconButton(
                          icon: MabarIcons.users,
                          semanticLabel: 'Pemain',
                          solid: true,
                          count: active.activePlayers.length,
                          onPressed: () => showManagePlayersSheet(context),
                        ),
                      Expanded(child: primary),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
