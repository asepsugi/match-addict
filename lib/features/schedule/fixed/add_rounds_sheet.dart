import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../core/time_text.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../../../services/pairing/pair_draft.dart';
import '../../../services/schedule/round_robin_generator.dart';
import '../../pair_edit/pair_edit_screen.dart';
import '../tournament_controller.dart';
import '../widgets/extend_sheet_parts.dart';

/// Sheet 06w–06z / 04h "Tambah round" (Fixed, setelah semua match terisi): jam booking per court, pasangan (Atur
/// pasangan 04f), estimasi match tambahan tiap pasangan. Mengembalikan true kalau round tambahan dibuat.
Future<bool> showAddRoundsSheet(BuildContext context, ActiveTournament source) async {
  final n = source.roundCount;
  final added = await showMabarSheet<bool>(
    context,
    title: 'Tambah round',
    subtitle: 'Skor & klasemen ${n == 1 ? 'R1' : 'R1–R$n'} tetap',
    builder: (_) => AddRoundsSheet(source: source),
  );
  return added ?? false;
}

/// Isi sheet Tambah round; publik supaya golden bisa merendernya lewat [showAddRoundsSheet].
class AddRoundsSheet extends ConsumerStatefulWidget {
  final ActiveTournament source;

  const AddRoundsSheet({super.key, required this.source});

  @override
  ConsumerState<AddRoundsSheet> createState() => _AddRoundsSheetState();
}

class _AddRoundsSheetState extends ConsumerState<AddRoundsSheet> {
  /// Tambahan jam per court id.
  final Map<String, int> _extraHours = {};

  /// Hasil Atur pasangan; null = belum dibuka.
  PairDraft? _draft;

  ActiveTournament get _source => widget.source;
  List<Pair> get _current => _source.config.fixedPairs ?? const [];
  Map<String, int> get _extraMinutes => {for (final e in _extraHours.entries) e.key: e.value * 60};

  /// Pasangan baru hanya kalau memang berubah, supaya id dan urutan pasangan lama tetap.
  List<Pair>? get _pairs => _draft != null && _draft!.changedFrom(_current) ? _draft!.pairs : null;

  Future<void> _editPairs() async {
    final edited = await PairEditScreen.open(
      context,
      initial: _draft ?? PairDraft.of(_source.config),
      sport: _source.config.sport,
      firstRound: _source.roundCount + 1,
    );
    if (edited != null && mounted) setState(() => _draft = edited);
  }

  void _create() {
    final pairs = _pairs;
    ref
        .read(tournamentProvider.notifier)
        .addRounds(_extraMinutes, pairs: pairs, newPlayers: pairs == null ? const [] : _draft!.addedInPairs);
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final now = ref.read(clockProvider)();
    final n = _source.roundCount;
    final plan = RoundRobinGenerator.extraRounds(_source, now, extraMinutes: _extraMinutes, pairs: _pairs);
    final rounds = plan.schedule.matches.isEmpty ? 0 : plan.schedule.roundCount - n;
    final range = rounds == 1 ? 'R${n + 1}' : 'R${n + 1}–R${n + rounds}';

    final draft = _draft ?? PairDraft.of(_source.config);
    final fresh = draft.newPairsFrom(_current);
    final idle = draft.unpaired.length;
    final pairsLine = [
      '${draft.pairs.length} pasangan',
      if (fresh == 0 && idle == 0) 'sama dengan sebelumnya',
      if (fresh > 0) '$fresh baru',
      if (idle > 0) '$idle tidak main',
    ].join(' · ');

    // Court di round pertama = yang masih muat satu round; berkurang kalau salah satunya habis di tengah (sama
    // dengan Lanjutkan 08c). Lewat booking = round sesudah semua court habis.
    final courts = plan.roundsLeft.where((k) => k >= 1).length;
    int? fewerFrom;
    for (var r = 2; r <= rounds && r <= plan.fitRounds; r++) {
      if (plan.roundsLeft.where((k) => k >= r).length < courts) {
        fewerFrom = r;
        break;
      }
    }
    final over = (rounds - plan.fitRounds) * _source.config.matchDurationMinutes;
    final facts = [
      '$rounds round ($range)',
      fewerFrom == null ? '$courts court' : '$courts court, berkurang mulai R${n + fewerFrom}',
      if (over > 0) 'lewat booking ${countdownText(over)}',
    ].join(' · ');

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
        MabarGroup(
          color: MabarColors.paper,
          children: [
            MabarRow(
              padded: true,
              leading: const SizedBox(
                width: 30,
                child: Icon(MabarIcons.users, size: MabarSize.icon, color: MabarColors.ink2),
              ),
              titleWidget: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Pasangan', style: MabarType.body.copyWith(fontWeight: FontWeight.w600, color: MabarColors.ink)),
                  Text(pairsLine, style: MabarType.caption),
                ],
              ),
              chevron: true,
              onTap: _editPairs,
            ),
          ],
        ),
        const SizedBox(height: 16),
        if (plan.perPair > 0)
          SheetEstimate(number: plan.perPair, label: 'match lagi tiap pasangan', lines: [facts])
        else
          const SheetEstimateEmpty('Tambah jam minimal satu court'),
        const SizedBox(height: 16),
        MabarButton(
          label: plan.perPair > 0 ? 'Buat $range' : 'Buat round',
          icon: MabarIcons.plus,
          onPressed: plan.perPair > 0 ? _create : null,
        ),
      ],
    );
  }
}
