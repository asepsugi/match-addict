import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../../../services/ranking/group_knockout_ranking.dart';
import '../widgets/schedule_match_row.dart';
import '../tournament_controller.dart';
import 'gk_labels.dart';

/// "Buat bagan" (20e → 20g / 20i–20l): sheet pilih slot kalau ada seri yang harus dipilih host, lalu dialog kunci.
/// Pilihan hanya hidup di sini sampai dialog dikonfirmasi; batal atau app ditutup = tanpa perubahan (AC-G7). Mengembalikan
/// true kalau bagan dibuat.
Future<bool> startCreateBracket(BuildContext context, WidgetRef ref) async {
  final plan = GroupKnockoutRanking.qualifierPlan(ref.read(tournamentProvider)!);
  var picks = <int, List<String>>{};
  while (true) {
    if (plan.picks.isNotEmpty) {
      final chosen = await showQualifierPickSheet(context, ref.read(tournamentProvider)!, plan, initial: picks);
      if (chosen == null || !context.mounted) return false;
      picks = chosen;
    }
    // Batal di dialog kembali ke sheet dengan pilihan tetap (20j); tanpa sheet berarti selesai.
    final active = ref.read(tournamentProvider)!;
    final qualifiers = plan.withPicks(picks);
    if (qualifiers == null) return false;
    final ok = await showBuildBracketDialog(context, active, qualifiers);
    if (!context.mounted) return false;
    if (ok) return ref.read(tournamentProvider.notifier).createBracket(picks);
    if (plan.picks.isEmpty) return false;
  }
}

String _pairName(ActiveTournament a, Pair p) => pairNames(a, p).join(' · ');

/// Dialog 20g/20k/20o: match babak pertama bagan dan akibatnya.
Future<bool> showBuildBracketDialog(
  BuildContext context,
  ActiveTournament active,
  List<List<String>> qualifiers,
) async {
  final rows = gkBracketPreview(active, qualifiers, nameOf: (p) => _pairName(active, p));
  final result = await showDialog<bool>(
    context: context,
    useSafeArea: false,
    builder: (context) => BuildBracketDialog(
      rows: rows,
      onCancel: () => Navigator.pop(context, false),
      onConfirm: () => Navigator.pop(context, true),
    ),
  );
  return result ?? false;
}

/// `.dialog` dengan `.bracket` — isi [showBuildBracketDialog]; publik untuk golden.
class BuildBracketDialog extends StatelessWidget {
  final List<BracketPreviewRow> rows;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const BuildBracketDialog({super.key, required this.rows, required this.onCancel, required this.onConfirm});

  @override
  Widget build(BuildContext context) {
    final slot = MabarType.numM.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: MabarColors.ink3);
    final name = MabarType.body.copyWith(fontSize: 15, color: MabarColors.ink);
    Widget line(String s, String n) => Row(
      children: [
        SizedBox(width: 24, child: Text(s, style: slot)),
        const SizedBox(width: 8),
        Expanded(
          child: Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: name),
        ),
      ],
    );
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text('Buat bagan?', style: MabarType.dialogTitle.copyWith(color: MabarColors.ink)),
            const SizedBox(height: 8 + 2),
            for (final (i, r) in rows.indexed)
              Container(
                padding: const EdgeInsets.symmetric(vertical: 8),
                decoration: i == 0
                    ? null
                    : const BoxDecoration(
                        border: Border(top: BorderSide(color: MabarColors.line)),
                      ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SizedBox(
                      width: 36,
                      child: Text(r.code, style: MabarType.numM.copyWith(fontSize: 15, color: MabarColors.ink)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [line(r.slot1, r.name1), const SizedBox(height: 2), line(r.slot2, r.name2)],
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 4 + 8),
            Text(
              'Skor fase grup tidak bisa diubah setelah bagan dibuat.',
              style: MabarType.body.copyWith(fontSize: 15, height: 1.5, color: MabarColors.ink2),
            ),
            const SizedBox(height: 8 + 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                MabarTextButton(label: 'Batal', tone: MabarTextTone.neutral, onPressed: onCancel),
                const SizedBox(width: 4),
                MabarTextButton(label: 'Buat bagan', onPressed: onConfirm),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Sheet 20i–20l: pilih pasangan untuk slot yang seri. Mengembalikan pilihan per grup (ketukan berurutan), null = Batal
/// atau ditutup.
Future<Map<int, List<String>>?> showQualifierPickSheet(
  BuildContext context,
  ActiveTournament active,
  QualifierPlan plan, {
  Map<int, List<String>> initial = const {},
}) => showMabarSheetRoute<Map<int, List<String>>>(
  context,
  builder: (_) => QualifierPickSheet(active: active, picks: plan.picks, initial: initial),
);

/// Isi [showQualifierPickSheet]; publik untuk golden.
class QualifierPickSheet extends StatefulWidget {
  final ActiveTournament active;
  final List<OpenPick> picks;
  final Map<int, List<String>> initial;

  const QualifierPickSheet({super.key, required this.active, required this.picks, this.initial = const {}});

  @override
  State<QualifierPickSheet> createState() => _QualifierPickSheetState();
}

class _QualifierPickSheetState extends State<QualifierPickSheet> {
  late final Map<int, List<String>> _taps = {
    for (final e in widget.initial.entries) e.key: [...e.value],
  };

  @override
  Widget build(BuildContext context) {
    final picks = widget.picks;
    final single = picks.length == 1;
    final missing = gkMissingSlots(picks, _taps);
    return MabarSheet(
      title: gkPickTitle(picks),
      subtitle: single ? gkPickSubtitle(picks.single, widget.active.matches) : null,
      // `flex: 1` dan `flex: 2` CSS membagi sisa lebar setelah padding 20 + 20 tiap tombol (pola sheet WO); alasan tombol
      // mati ikut di labelnya (20i).
      footer: LayoutBuilder(
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
                  label: missing == null ? 'Buat bagan' : 'Buat bagan · $missing',
                  onPressed: missing == null ? () => Navigator.pop(context, _taps) : null,
                ),
              ),
            ],
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final (n, pick) in picks.indexed) ...[
            if (n > 0) const SizedBox(height: 16),
            if (!single) ...[MabarGroupLabel('Grup ${GroupKnockout.letter(pick.group)}'), const SizedBox(height: 8)],
            for (final (i, id) in pick.candidates.indexed) ...[if (i > 0) const SizedBox(height: 16), _option(pick, id)],
          ],
        ],
      ),
    );
  }

  Widget _option(OpenPick pick, String id) {
    final taps = _taps[pick.group] ?? const <String>[];
    final at = taps.indexOf(id);
    final pair = widget.active.pairById(id);
    return MabarOption(
      label: pair == null ? '' : _pairName(widget.active, pair),
      selected: at >= 0,
      slot: at >= 0 ? '${GroupKnockout.letter(pick.group)}${pick.slots[at]}' : null,
      onTap: () => setState(() => _taps[pick.group] = gkTap(pick, taps, id)),
    );
  }
}
