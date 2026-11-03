import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../tournament_controller.dart';
import '../widgets/extend_sheet_parts.dart';

/// Sheet 08c "Lanjutkan turnamen" (Mixed) — tambah jam booking per court (sering cuma sebagian court
/// yang bisa diperpanjang), lalu turnamen aktif lagi tanpa mengulang. [archived] = dari Beranda, turnamen
/// sudah ditutup. Mengembalikan true kalau turnamen jadi dilanjutkan.
Future<bool> showResumeTournamentSheet(BuildContext context, ActiveTournament source, {bool archived = false}) async {
  final n = source.roundCount;
  final resumed = await showMabarSheet<bool>(
    context,
    title: 'Lanjutkan turnamen',
    subtitle: 'Skor & klasemen ${n == 1 ? 'R1' : 'R1–R$n'} tetap',
    builder: (_) => _ResumeTournament(source: source, archived: archived),
  );
  return resumed ?? false;
}

class _ResumeTournament extends ConsumerStatefulWidget {
  final ActiveTournament source;
  final bool archived;

  const _ResumeTournament({required this.source, required this.archived});

  @override
  ConsumerState<_ResumeTournament> createState() => _ResumeTournamentState();
}

class _ResumeTournamentState extends ConsumerState<_ResumeTournament> {
  /// Tambahan jam per court id.
  final Map<String, int> _extraHours = {};

  ActiveTournament get _source => widget.source;

  Map<String, int> get _extraMinutes => {for (final e in _extraHours.entries) e.key: e.value * 60};

  void _resume() {
    ref.read(tournamentProvider.notifier).resume(_extraMinutes, from: widget.archived ? _source : null);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final ahead = _source.capacityAhead(now, _extraMinutes);
    final n = _source.roundCount;
    final unplayed = _source.matches.where((m) => m.status == MatchStatus.cancelled).length;

    final facts = [
      if (ahead.rounds == 1) '1 round (R${n + 1})' else '${ahead.rounds} round (R${n + 1}–R${n + ahead.rounds})',
      if (ahead.matchesPerRound < ahead.courts)
        'maks ${ahead.matchesPerRound} match per round (${_source.activePlayers.length} pemain)'
      else if (ahead.fewerCourtsFrom != null)
        '${ahead.courts} court, berkurang mulai R${n + ahead.fewerCourtsFrom!}'
      else
        '${ahead.courts} court',
    ].join(' · ');
    final unplayedNote = unplayed > 0 ? '$unplayed match yang belum dimainkan bisa diisi lagi' : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        CourtHoursGroup(
          active: _source,
          now: now,
          extraHours: _extraHours,
          onChanged: (id, h) => setState(() => _extraHours[id] = h),
        ),
        const SizedBox(height: 16),
        if (ahead.matches > 0)
          SheetEstimate(number: ahead.matches, label: 'match lagi', lines: [facts, ?unplayedNote])
        else
          SheetEstimateEmpty(unplayedNote ?? 'Tambah jam minimal satu court'),
        const SizedBox(height: 16),
        MabarButton(
          label: 'Lanjutkan',
          icon: MabarIcons.play,
          onPressed: ahead.matches > 0 || unplayed > 0 ? _resume : null,
        ),
      ],
    );
  }
}
