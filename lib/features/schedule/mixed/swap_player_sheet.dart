import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_inputs.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../../../services/schedule/player_swap.dart';
import '../tournament_controller.dart';
import '../widgets/resting_list.dart';
import '../widgets/schedule_match_row.dart';

/// Sheet 17b "Tukar pemain" (Mixed) — satu langkah: pilih satu pemain tim yang diganti, pilih satu yang istirahat
/// sebagai pengganti, Tukar. [team] = tim yang ikonnya diketuk. Tukar menutup sheet tanpa dialog atau toast; Batal,
/// scrim, geser, dan back menutup tanpa mengubah apa pun.
Future<void> showSwapPlayerSheet(
  BuildContext context, {
  required ActiveTournament active,
  required MatchGame match,
  required Pair team,
  required DateTime now,
}) {
  final club = active.config.isSparing ? active.config.clubOfPair(team) : null;
  return showMabarSheet<void>(
    context,
    title: 'Tukar pemain',
    subtitle:
        'Round ${match.roundNumber} · ${active.courtById(match.courtId).name}${club == null ? '' : ' · ${club.name}'}',
    builder: (_) => _SwapPlayer(active: active, match: match, team: team, now: now),
  );
}

class _SwapPlayer extends ConsumerStatefulWidget {
  final ActiveTournament active;
  final MatchGame match;
  final Pair team;
  final DateTime now;

  const _SwapPlayer({required this.active, required this.match, required this.team, required this.now});

  @override
  ConsumerState<_SwapPlayer> createState() => _SwapPlayerState();
}

class _SwapPlayerState extends ConsumerState<_SwapPlayer> {
  String? _outId;
  String? _inId;

  /// Ketuk chip terpilih = lepas; chip lain di grup yang sama = ganti pilihan.
  String? _toggle(String? current, String id) => current == id ? null : id;

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final match = widget.match;
    final out = _outId, incoming = _inId;
    final ready = out != null && incoming != null;
    // Pratinjau memakai fungsi yang sama dengan Tukar, jadi pratinjau = hasil. Sebelum dua pilihan: match apa adanya.
    final shown = ready ? PlayerSwap.swapped(match, outId: out, inId: incoming) : match;
    final candidates = PlayerSwap.candidates(active, match, widget.team, widget.now);
    final next = active.roundCount + 1;

    Widget chips(List<({String id, String name})> items, String? selected, void Function(String id) onPick) =>
        MabarChipGrid(
          children: [
            for (final item in items)
              MabarChip(label: item.name, tall: true, selected: selected == item.id, onTap: () => onPick(item.id)),
          ],
        );

    Widget candidateGroup(List<Player> players, Widget label) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        MabarGroupHeader(label: label),
        const SizedBox(height: 8),
        chips(
          [for (final p in players) (id: p.id, name: p.name)],
          _inId,
          (id) => setState(() => _inId = _toggle(_inId, id)),
        ),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        ScheduleMatchRow(active: active, match: shown, now: widget.now, preview: true),
        const SizedBox(height: 16),
        MabarGroupHeader.text('Diganti'),
        const SizedBox(height: 8),
        chips(
          [for (final id in widget.team.playerIds) (id: id, name: active.playerName(id))],
          _outId,
          (id) => setState(() => _outId = _toggle(_outId, id)),
        ),
        if (candidates.priority.isNotEmpty)
          candidateGroup(candidates.priority, RestingList.headerLabel(priorityRound: next)),
        if (candidates.later.isNotEmpty)
          candidateGroup(candidates.later, RestingList.headerLabel(later: true, priorityRound: next)),
        const SizedBox(height: 16),
        // `flex: 1` dan `flex: 2` CSS membagi sisa lebar setelah padding 20 + 20 tiap tombol (pola sheet WO).
        LayoutBuilder(
          builder: (context, constraints) {
            const gap = 10.0, padding = 40.0;
            final share = (constraints.maxWidth - gap - 2 * padding) / 3;
            return Row(
              children: [
                SizedBox(
                  width: padding + share,
                  child: MabarButton(
                    label: 'Batal',
                    variant: MabarButtonVariant.secondary,
                    onPressed: () => Navigator.pop(context),
                  ),
                ),
                const SizedBox(width: gap),
                Expanded(
                  child: MabarButton(
                    label: 'Tukar',
                    icon: MabarIcons.arrowsLeftRight,
                    onPressed: ready ? () => _swap(out, incoming) : null,
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }

  void _swap(String outId, String inId) {
    ref.read(tournamentProvider.notifier).swapPlayer(matchId: widget.match.id, outId: outId, inId: inId);
    Navigator.pop(context);
  }
}
