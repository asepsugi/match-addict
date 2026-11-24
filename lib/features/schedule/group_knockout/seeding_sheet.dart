import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../../../services/ranking/group_knockout_ranking.dart';
import '../../../services/schedule/config_summary.dart';
import '../tournament_controller.dart';
import '../widgets/schedule_match_row.dart';
import 'create_bracket_flow.dart';
import 'gk_labels.dart';

/// Hasil sheet Buat bagan 3 grup: pilihan seri di dalam grup + pilihan seri wildcard (urut ketukan).
typedef SeedingChoice = ({Map<int, List<String>> picks, List<String> wildcards});

/// Sheet Buat bagan 3 grup (23c, 23e, 23f): juara grup + wildcard dengan nilai metode Playoff, selalu muncul sebelum
/// dialog kunci (AC-G24). Seri di dalam grup (20i) ikut di sheet yang sama, bagian wildcard muncul setelah pilihan
/// grup lengkap. Null = Batal atau ditutup.
Future<SeedingChoice?> showSeedingSheet(
  BuildContext context,
  ActiveTournament active,
  QualifierPlan plan, {
  SeedingChoice? initial,
}) => showMabarSheetRoute<SeedingChoice>(
  context,
  builder: (_) => SeedingSheet(active: active, plan: plan, initial: initial),
);

/// Isi [showSeedingSheet]; publik untuk golden. Rencana seeding dibaca dari [seedingPlanProvider], tidak diturunkan di
/// sini.
class SeedingSheet extends ConsumerStatefulWidget {
  final ActiveTournament active;
  final QualifierPlan plan;
  final SeedingChoice? initial;

  const SeedingSheet({super.key, required this.active, required this.plan, this.initial});

  @override
  ConsumerState<SeedingSheet> createState() => _SeedingSheetState();
}

class _SeedingSheetState extends ConsumerState<SeedingSheet> {
  late final Map<int, List<String>> _taps = {
    for (final e in (widget.initial?.picks ?? const <int, List<String>>{}).entries) e.key: [...e.value],
  };
  late final List<String> _wild = [...?widget.initial?.wildcards];

  String _name(String id) {
    final pair = widget.active.pairById(id);
    return pair == null ? '' : pairNames(widget.active, pair).join(' · ');
  }

  @override
  Widget build(BuildContext context) {
    final active = widget.active;
    final picks = widget.plan.picks;
    final seeding = ref.watch(seedingPlanProvider(BracketPicks(_taps)));
    final wc = seeding?.pick;
    final sure = seeding == null ? 0 : seeding.candidates.where((r) => r.qualified).length;
    final missing = gkMissingSlots(picks, _taps) ?? (wc == null ? null : gkWildcardMissing(wc, sure, _wild.length));
    final method = GroupKnockoutRanking.playoffMethod(active.config).label;
    final groups = active.config.groupKnockout?.groupCount ?? 3;

    return MabarSheet(
      title: 'Buat bagan',
      subtitle: '$groups grup · ${ConfigSummary.playoffOpening(groups)}',
      footer: LayoutBuilder(
        builder: (context, constraints) {
          // Batal flex 1, Buat bagan flex 2, sama dengan sheet pilih slot (20i).
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
                  onPressed: missing == null
                      ? () => Navigator.pop<SeedingChoice>(context, (picks: _taps, wildcards: _wild))
                      : null,
                ),
              ),
            ],
          );
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          ...qualifierPickSections(active, picks, _taps, (pick, id) {
            setState(() {
              _taps[pick.group] = gkTap(pick, _taps[pick.group] ?? const [], id);
              _wild.clear();
            });
          }),
          if (seeding != null) ...[
            if (picks.isNotEmpty) const SizedBox(height: 16),
            const MabarGroupLabel('Juara grup'),
            const SizedBox(height: 8),
            _SeedTable(
              method: method,
              rows: [
                for (final (i, r) in seeding.champions.indexed)
                  _SeedLine(
                    name: _name(r.pairId),
                    row: r,
                    lead: _Lead.rank('${i + 1}'),
                    small: '${GroupKnockout.letter(r.group)}1',
                  ),
              ],
            ),
            const SizedBox(height: 16),
            MabarGroupLabel(gkWildcardLabel(wc, sure, _wild.length)),
            const SizedBox(height: 8),
            _SeedTable(method: method, rows: _wildcardLines(seeding, wc)),
          ],
        ],
      ),
    );
  }

  List<_SeedLine> _wildcardLines(SeedingPlan seeding, WildcardPick? pick) {
    var slot = 0;
    return [
      for (final r in seeding.candidates)
        if (pick != null && pick.candidates.contains(r.pairId))
          _SeedLine(
            name: _name(r.pairId),
            row: r,
            lead: _Lead.radio,
            small: '${GroupKnockout.letter(r.group)}3',
            on: _wild.contains(r.pairId),
            onTap: () => setState(() {
              if (_wild.contains(r.pairId)) {
                _wild.remove(r.pairId);
              } else if (_wild.length < pick.need) {
                _wild.add(r.pairId);
              } else {
                _wild[_wild.length - 1] = r.pairId;
              }
            }),
          )
        else if (r.qualified)
          _SeedLine(
            name: _name(r.pairId),
            row: r,
            lead: _Lead.slot('WC${++slot}'),
            small: '${GroupKnockout.letter(r.group)}3',
          )
        else
          _SeedLine(
            name: _name(r.pairId),
            row: r,
            lead: _Lead.out,
            small: '${GroupKnockout.letter(r.group)}3',
            out: true,
          ),
    ];
  }
}

enum _LeadKind { rank, slot, radio, out }

/// Isi kolom # (`.r`, `.gg-slot`, `.radio`, "–").
class _Lead {
  final _LeadKind kind;
  final String text;
  const _Lead._(this.kind, this.text);
  const _Lead.rank(String t) : this._(_LeadKind.rank, t);
  const _Lead.slot(String t) : this._(_LeadKind.slot, t);
  static const radio = _Lead._(_LeadKind.radio, '');
  static const out = _Lead._(_LeadKind.out, '–');
}

class _SeedLine {
  final String name;
  final SeedRow row;
  final _Lead lead;
  final String small;
  final bool on;
  final bool out;
  final VoidCallback? onTap;
  const _SeedLine({
    required this.name,
    required this.row,
    required this.lead,
    required this.small,
    this.on = false,
    this.out = false,
    this.onTap,
  });
}

/// `.rank.gg-wc`: kolom 36 · nama · 44 · 84, baris 52, kepala 32.
class _SeedTable extends StatelessWidget {
  final String method;
  final List<_SeedLine> rows;
  const _SeedTable({required this.method, required this.rows});

  @override
  Widget build(BuildContext context) {
    final head = MabarType.body.copyWith(fontSize: 12, fontWeight: FontWeight.w700, color: MabarColors.ink3);
    return Container(
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(color: MabarColors.paper, borderRadius: BorderRadius.circular(MabarRadius.group)),
      child: Column(
        children: [
          Container(
            height: 32,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Row(
              children: [
                SizedBox(width: 36, child: Text('#', style: head)),
                const SizedBox(width: 6),
                Expanded(child: Text('Pasangan', style: head)),
                const SizedBox(width: 6),
                SizedBox(
                  width: 44,
                  child: Text(method, style: head, textAlign: TextAlign.right, maxLines: 1),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 84,
                  child: Text('+/− per match', style: head, textAlign: TextAlign.right, maxLines: 1),
                ),
              ],
            ),
          ),
          for (final line in rows) _row(line),
        ],
      ),
    );
  }

  Widget _row(_SeedLine l) {
    final dim = l.out;
    final lead = switch (l.lead.kind) {
      _LeadKind.rank || _LeadKind.out => Text(
        l.lead.text,
        textAlign: TextAlign.center,
        style: MabarType.numM.copyWith(fontSize: 18, color: MabarColors.ink2),
      ),
      _LeadKind.slot => Text(l.lead.text, style: MabarType.numM.copyWith(fontSize: 15, color: MabarColors.ink)),
      _LeadKind.radio => Align(
        alignment: Alignment.centerLeft,
        child: Container(
          width: 22,
          height: 22,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: l.on ? MabarColors.ink : const Color(0xFFB9C4CE), width: l.on ? 7 : 2),
          ),
        ),
      ),
    };
    final content = Container(
      constraints: const BoxConstraints(minHeight: 52),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      decoration: BoxDecoration(
        color: l.on ? MabarColors.card : null,
        border: const Border(top: BorderSide(color: MabarColors.line)),
      ),
      child: Row(
        children: [
          SizedBox(width: 36, child: lead),
          const SizedBox(width: 6),
          Expanded(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Flexible(
                  child: Text(
                    l.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MabarType.body.copyWith(
                      fontWeight: dim ? FontWeight.w500 : FontWeight.w600,
                      color: dim ? MabarColors.ink3 : MabarColors.ink,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text(l.small, style: MabarType.numM.copyWith(fontSize: 13, color: MabarColors.ink3)),
              ],
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 44,
            child: Text(
              l.row.value,
              textAlign: TextAlign.right,
              style: MabarType.numM.copyWith(color: dim ? MabarColors.ink3 : MabarColors.ink),
            ),
          ),
          const SizedBox(width: 6),
          SizedBox(
            width: 84,
            child: Text(
              l.row.perMatch,
              textAlign: TextAlign.right,
              style: MabarType.numM.copyWith(fontSize: 18, color: dim ? MabarColors.ink3 : MabarColors.ink2),
            ),
          ),
        ],
      ),
    );
    return l.onTap == null ? content : InkWell(onTap: l.onTap, child: content);
  }
}
