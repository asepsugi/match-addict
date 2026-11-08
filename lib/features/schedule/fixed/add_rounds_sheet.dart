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
import '../../../services/schedule/sparing_fixed_generator.dart';
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
    final draft = _draft ?? PairDraft.of(_source.config);
    final fresh = draft.newPairsFrom(_current);
    final idle = draft.unpaired.length;
    final clubs = _source.config.clubs;
    final pairCount = clubs == null
        ? '${draft.pairs.length}'
        : clubs.map((c) => draft.pairsOf(c.id).length).join(' + ');
    final pairsLine = [
      '$pairCount pasangan',
      if (fresh == 0 && idle == 0) 'sama dengan sebelumnya',
      if (fresh > 0) '$fresh baru',
      if (idle > 0) '$idle tidak main',
    ].join(' · ');

    final Widget estimate;
    var stackedEstimate = false;
    final int rounds;
    final String range;
    if (clubs == null) {
      final plan = RoundRobinGenerator.extraRounds(_source, now, extraMinutes: _extraMinutes, pairs: _pairs);
      rounds = plan.schedule.matches.isEmpty ? 0 : plan.schedule.roundCount - n;
      range = rounds == 1 ? 'R${n + 1}' : 'R${n + 1}–R${n + rounds}';

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
      estimate = plan.perPair > 0
          ? SheetEstimate(number: plan.perPair, label: 'match lagi tiap pasangan', lines: [facts])
          : const SheetEstimateEmpty('Tambah jam minimal satu court');
    } else {
      // Sparing (14n): satu satuan = KPK(pasangan klub 1, klub 2) match; tambahan per pasangan beda antar klub.
      final p1 = draft.pairsOf(clubs[0].id), p2 = draft.pairsOf(clubs[1].id);
      final plan = SparingFixedGenerator.extraRounds(_source, now, club1: p1, club2: p2, extraMinutes: _extraMinutes);
      rounds = plan.schedule.matches.isEmpty ? 0 : plan.schedule.roundCount - n;
      range = rounds == 1 ? 'R${n + 1}' : 'R${n + 1}–R${n + rounds}';
      int courtsAt(int r) =>
          SparingFixedGenerator.activeCourts(plan.roundsLeft.where((k) => k >= r).length, p1.length, p2.length);
      final courts = courtsAt(1);
      int? fewerFrom;
      for (var r = 2; r <= rounds && r <= plan.fitRounds; r++) {
        if (courtsAt(r) < courts) {
          fewerFrom = r;
          break;
        }
      }
      final facts = [
        '$rounds round ($range)',
        fewerFrom == null ? '$courts court' : '$courts court, berkurang mulai R${n + fewerFrom}',
        if (plan.overMinutes > 0) 'lewat booking ${countdownText(plan.overMinutes)}',
      ].join(' · ');
      const label = 'match lagi tiap pasangan';
      stackedEstimate = rounds > 0 && plan.perPair.club1 != plan.perPair.club2;
      estimate = rounds == 0
          ? const SheetEstimateEmpty('Tambah jam minimal satu court')
          : plan.perPair.club1 == plan.perPair.club2
          ? SheetEstimate(number: plan.perPair.club1, label: label, lines: [facts])
          // Dua baris klub (14n): jarak ke baris Pasangan dan ke tombol diukur dari frame, bukan padding 06w.
          : Padding(
              padding: const EdgeInsets.only(bottom: 1.5),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SheetEstimate(
                    number: plan.perPair.club1,
                    label: '$label ${clubs[0].name}',
                    lines: const [],
                    stacked: true,
                  ),
                  SheetEstimate(
                    number: plan.perPair.club2,
                    label: '$label ${clubs[1].name}',
                    lines: [facts],
                    stacked: true,
                  ),
                ],
              ),
            );
    }

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
                  Text(
                    'Pasangan',
                    style: MabarType.body.copyWith(fontWeight: FontWeight.w600, color: MabarColors.ink),
                  ),
                  Text(pairsLine, style: MabarType.caption),
                ],
              ),
              chevron: true,
              onTap: _editPairs,
            ),
          ],
        ),
        SizedBox(height: stackedEstimate ? 12.5 : 16),
        estimate,
        const SizedBox(height: 16),
        MabarButton(
          label: rounds > 0 ? 'Buat $range' : 'Buat round',
          icon: MabarIcons.plus,
          onPressed: rounds > 0 ? _create : null,
        ),
      ],
    );
  }
}
