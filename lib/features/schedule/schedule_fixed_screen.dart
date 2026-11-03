import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/minute_ticker.dart';
import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../live/live_score.dart';
import '../live/live_view_controller.dart';
import 'fixed/add_rounds_sheet.dart';
import 'schedule_widgets.dart';
import 'tournament_controller.dart';
import 'widgets/resting_list.dart';
import 'widgets/round_tabs.dart';
import 'widgets/schedule_match_row.dart';

enum _MenuAction { live, finish }

/// Screen 05 · Jadwal Fixed — round-robin penuh sudah dibuat. Semua round bisa dibuka lewat tab, tapi
/// round di depan round berjalan terkunci sampai semua skor round itu terisi. Setelah semua terisi, Tambah round
/// (06v) membuat round per putaran. Di halaman penonton (12i) baca saja.
class ScheduleFixedScreen extends ConsumerStatefulWidget {
  final TournamentConfig config;
  const ScheduleFixedScreen({super.key, required this.config});

  @override
  ConsumerState<ScheduleFixedScreen> createState() => _ScheduleFixedScreenState();
}

class _ScheduleFixedScreenState extends ConsumerState<ScheduleFixedScreen> {
  /// Pilihan tab bertahan; tidak pindah otomatis saat round selesai.
  int? _selectedRound;
  MinuteTicker? _clock;

  @override
  void initState() {
    super.initState();
    // Provider tidak boleh diubah selama widget sedang dibangun, jadi turnamen dimulai sesudah frame ini.
    Future.microtask(() {
      if (mounted && ref.read(liveCodeProvider) == null) {
        ref.read(tournamentProvider.notifier).startIfNeeded(widget.config);
      }
    });
    // Kotak jam di strip court mengikuti jam sungguhan: ditik di setiap pergantian menit sejak turnamen dimulai.
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

  Future<void> _openMenu(BuildContext anchor, bool finished) async {
    final picked = await showMabarMenu<_MenuAction>(
      anchor,
      items: [
        liveScoreMenuItem(ref, _MenuAction.live),
        if (!finished)
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
      case _MenuAction.finish:
        if (!await confirmFinishTournament(context)) return;
        ref.read(tournamentProvider.notifier).finishNow();
        if (mounted) context.push('/leaderboard');
      case null:
    }
  }

  /// Tambah round (06v → 06w): round baru ada di depan, jadi tab kembali mengikuti round berjalan (R15).
  Future<void> _addRounds(ActiveTournament active) async {
    if (await showAddRoundsSheet(context, active) && mounted) setState(() => _selectedRound = null);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    if (active == null) return const Scaffold(backgroundColor: MabarColors.paper);

    final watching = ref.watch(liveCodeProvider) != null;
    final now = ref.read(clockProvider)();
    final finished = active.tournament.isFinished;
    final current = active.currentRound;
    final live = !finished && !active.isRoundComplete(current);
    final selected = (_selectedRound ?? current).clamp(1, active.roundCount);
    final locked = !finished && selected > current;
    final matches = active.matchesOfRound(selected);
    final played = matches.where((m) => m.status == MatchStatus.done || m.status == MatchStatus.wo).length;
    final byePairId = active.byePairIdByRound[selected];
    final byePair = byePairId == null ? null : active.pairById(byePairId);

    void openScore(MatchGame m) => context.push('/score-input', extra: m.id);
    final readOnly = watching || locked;

    Widget faded(double opacity, Widget child) => locked ? Opacity(opacity: opacity, child: child) : child;

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: 'Round $selected',
            subtitle: scheduleSubtitle(active, named: watching),
            onBack: watching ? null : () => context.pop(),
            actions: [
              if (!watching)
                Builder(
                  builder: (anchor) => MabarIconButton(
                    icon: MabarIcons.dotsThree,
                    semanticLabel: 'Menu',
                    // Setelah diakhiri menunya tinggal Live score (12f).
                    onPressed: () => _openMenu(anchor, finished),
                  ),
                )
              else if (!active.isFinal(now))
                const LiveTag(),
            ],
          ),
          RoundTabs(
            count: active.roundCount,
            selected: selected,
            onSelect: (r) => setState(() => _selectedRound = r),
            liveRound: live ? current : null,
            isFuture: finished ? null : (r) => r > current,
            meta: '$played/${matches.length} match',
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              children: [
                if (locked) ...[
                  Row(
                    children: [
                      const Icon(MabarIcons.lockSimple, size: MabarSize.iconInButton, color: MabarColors.ink3),
                      const SizedBox(width: 8),
                      Text(
                        'Terbuka setelah semua skor R${selected - 1} terisi',
                        style: MabarType.body.copyWith(fontSize: 14, color: MabarColors.ink3),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                ],
                faded(
                  0.5,
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (final (i, m) in matches.indexed) ...[
                        if (i > 0) const SizedBox(height: 8),
                        ScheduleMatchRow(
                          active: active,
                          match: m,
                          now: now,
                          onTap: readOnly ? null : () => openScore(m),
                          onFill: readOnly || m.status != MatchStatus.pending ? null : () => openScore(m),
                        ),
                      ],
                    ],
                  ),
                ),
                if (byePair != null) ...[
                  const SizedBox(height: 16),
                  faded(0.6, RestingList(names: [pairNames(active, byePair).join(' · ')])),
                ],
              ],
            ),
          ),
          MabarActionBar(
            // Semua match terisi dan belum diakhiri (06v): Klasemen jadi ikon, seperti Mixed saat waktu habis.
            children: !watching && active.canAddRounds
                ? [
                    MabarIconButton(
                      icon: MabarIcons.ranking,
                      semanticLabel: 'Klasemen',
                      solid: true,
                      onPressed: () => context.push('/leaderboard'),
                    ),
                    Expanded(
                      child: MabarButton(
                        label: 'Tambah round',
                        icon: MabarIcons.plus,
                        onPressed: () => _addRounds(active),
                      ),
                    ),
                  ]
                : [Expanded(child: LeaderboardButton(isFinal: active.isFinal(now)))],
          ),
        ],
      ),
    );
  }
}
