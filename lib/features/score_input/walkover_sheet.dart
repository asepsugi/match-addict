import 'package:flutter/material.dart';

import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../../services/schedule/knockout_bracket.dart';
import 'knockout_text.dart';

class WalkoverResult {
  final String loserPairId;
  final WoReason? reason;

  const WalkoverResult({required this.loserPairId, this.reason});
}

/// Sheet 07j "Walkover" — pilih pasangan yang tidak main (lawan menang WO) dan alasan opsional. Membuka
/// WO yang sudah ada: pilihan dan alasan terisi.
Future<WalkoverResult?> showWalkoverSheet(
  BuildContext context, {
  required ActiveTournament active,
  required MatchGame match,
}) {
  final court = active.courtById(match.courtId).name;
  return showMabarSheet<WalkoverResult>(
    context,
    title: 'Walkover',
    subtitle: knockoutWalkoverSubtitle(active, match) ?? 'Round ${match.roundNumber} · $court',
    builder: (_) => _Walkover(active: active, match: match),
  );
}

class _Walkover extends StatefulWidget {
  final ActiveTournament active;
  final MatchGame match;

  const _Walkover({required this.active, required this.match});

  @override
  State<_Walkover> createState() => _WalkoverState();
}

class _WalkoverState extends State<_Walkover> {
  late String? _loserPairId = widget.match.woLoserPairId;
  late WoReason? _reason = widget.match.woReason;

  String _names(Pair pair, String separator) =>
      pair.playerIds.map(widget.active.playerName).join(separator);

  /// Nilai menang WO ikut format (PRD 4.4): Race to N → N game; Best of / Americano → rata-rata sendiri,
  /// minimal skor menang terkecil.
  String _winnerNote(Pair winner) {
    final format = widget.active.config.formatFor(widget.match);
    final phase = widget.match.phase;
    // Gugur (21n): akibatnya = babak berikutnya, tanpa nilai WO (peringkat gugur dari babak, 16.7).
    if (phase is KnockoutPhase) return knockoutWalkoverNote(phase, _names(winner, ' & '));
    final who = '${_names(winner, ' & ')} menang WO dan dapat';
    return format.method == ScoringMethod.raceTo
        ? '$who ${format.target} ${format.unit}.'
        : '$who ${format.unit} rata-rata mereka, minimal ${format.minWinningScore}.';
  }

  @override
  Widget build(BuildContext context) {
    final match = widget.match;
    final loser = _loserPairId;
    final winner = loser == null ? null : (loser == match.pair1.id ? match.pair2 : match.pair1);
    // Gugur: WO yang membalik pemenang ditolak kalau babak berikutnya sudah ada skor (GU11), sama dengan 21l.
    final flip = winner == null || match.phase is! KnockoutPhase
        ? null
        : KnockoutBracket.flipCheck(widget.active, match.id, winner.id);
    final blocked = flip is FlipBlocked
        ? knockoutBlockedMessage(
            flip,
            match.phase! as KnockoutPhase,
            _names(match.winnerPairId == match.pair1.id ? match.pair1 : match.pair2, ' & '),
          )
        : null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const MabarGroupLabel('Siapa yang tidak main?'),
        const SizedBox(height: 8),
        for (final (i, pair) in [match.pair1, match.pair2].indexed) ...[
          if (i > 0) const SizedBox(height: 16),
          MabarOption(
            label: _names(pair, ' · '),
            sublabel: loser == pair.id ? 'Kalah WO' : null,
            selected: loser == pair.id,
            onTap: () => setState(() => _loserPairId = pair.id),
          ),
        ],
        if (blocked != null)
          ...[const SizedBox(height: 16), MabarGroupNote(blocked, error: true)]
        else if (winner != null) ...[const SizedBox(height: 16), MabarGroupNote(_winnerNote(winner))],
        const SizedBox(height: 16),
        const MabarGroupLabel('Alasan'),
        const SizedBox(height: 8),
        MabarChipWrap(
          children: [
            for (final reason in WoReason.values)
              MabarChip(
                label: reason.label,
                selected: _reason == reason,
                // Ketuk lagi = lepas; alasan lama benar-benar terhapus (MatchGame.asWalkover).
                onTap: () => setState(() => _reason = _reason == reason ? null : reason),
              ),
          ],
        ),
        const SizedBox(height: 16),
        // `flex: 1` dan `flex: 2` CSS membagi sisa lebar setelah padding 20 + 20 tiap tombol, bukan lebar penuh.
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
                    label: 'Simpan WO',
                    variant: MabarButtonVariant.danger,
                    onPressed: loser == null || blocked != null
                        ? null
                        : () => Navigator.pop(context, WalkoverResult(loserPairId: loser, reason: _reason)),
                  ),
                ),
              ],
            );
          },
        ),
      ],
    );
  }
}
