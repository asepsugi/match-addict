import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../core/time_text.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_inputs.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../../../services/schedule/endless_round_generator.dart';
import '../../konfigurasi/widgets/config_pickers.dart';
import '../tournament_controller.dart';
import '../widgets/resting_list.dart';

/// Sheet 08e–08g "Kelola court" (menu ⋯ Mixed): daftar court dengan jendela jam dan sisanya (ketuk → detail court,
/// 08h–08k), lalu court baru. Court baru langsung dipakai kalau round terakhir masih berjalan dan cukup yang
/// istirahat; selain itu tombolnya menulis kapan dipakai (logic.md §10).
Future<void> showManageCourtsSheet(BuildContext context) async {
  final picked = await showMabarSheetRoute<String>(context, builder: (_) => const _ManageCourts());
  if (picked != null && context.mounted) await showCourtDetailSheet(context, picked);
}

/// Sheet detail court (08h–08k): nama, warna, dan jam hanya pratinjau sampai Simpan, karena menambah jam court yang
/// sudah habis bisa membuat match baru. "Hapus" di kanan atas untuk court bernomor terakhir yang belum punya skor.
Future<void> showCourtDetailSheet(BuildContext context, String courtId) =>
    showMabarSheetRoute<void>(context, builder: (_) => _CourtDetail(courtId: courtId));

/// "19.00–21.00" — jendela booking court pada jam dinding.
String _window(ActiveTournament active, Court court) {
  final start = active.tournament.createdAt;
  return '${clockText(start.add(Duration(minutes: court.startMinute)))}–'
      '${clockText(start.add(Duration(minutes: court.endMinute)))}';
}

/// "19.00–21.00 · sisa 00:58" / "19.00–21.00 · waktu habis".
String _windowLeft(ActiveTournament active, Court court, DateTime now) {
  final left = active.remainingBookingMinutes(court, now);
  return '${_window(active, court)} · ${left > 0 ? 'sisa ${countdownText(left)}' : 'waktu habis'}';
}

const _maxBookingHours = 12;

/// "Langsung main di R4": satu daftar nama; sparing memakai kolom klub seperti Istirahat (15o), pemainnya
/// dikelompokkan lewat klubnya, bukan indeks.
Widget _landing(ActiveTournament active, List<Player> players) {
  final title = 'Langsung main di R${active.roundCount}';
  final clubs = active.config.clubs;
  if (clubs == null) return RestingList(title: title, names: [for (final p in players) p.name]);
  return RestingList.clubs(
    title: title,
    clubs: [
      for (final c in clubs)
        RestingClub(club: c.name, names: [for (final p in players) if (p.clubId == c.id) p.name]),
    ],
  );
}

class _ManageCourts extends ConsumerStatefulWidget {
  const _ManageCourts();

  @override
  ConsumerState<_ManageCourts> createState() => _ManageCourtsState();
}

class _ManageCourtsState extends ConsumerState<_ManageCourts> {
  final _name = TextEditingController();
  int? _colorIndex;
  int _hours = 2;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickColor(int number, int current) async {
    final picked = await showMabarSheet<int>(
      context,
      title: 'Warna ${_name.text.trim().isEmpty ? 'Court $number' : _name.text.trim()}',
      builder: (context) => CourtColorGrid(selected: current, onSelect: (i) => Navigator.pop(context, i)),
    );
    if (picked != null && mounted) setState(() => _colorIndex = picked);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    if (active == null) return const SizedBox();
    final now = ref.read(clockProvider)();
    final courts = active.config.courts;
    final duration = active.config.matchDurationMinutes;
    final expired = courts.where((c) => active.remainingBookingMinutes(c, now) == 0).length;
    final canAdd = courts.length < TournamentConfig.maxCourts;

    final number = courts.length + 1;
    final colorIndex = _colorIndex ?? courts.length % MabarColors.courtPalette.length;
    final tooShort = _hours * 60 < duration;
    final draft = active.newCourt(
      id: '_baru',
      name: _name.text,
      colorIndex: colorIndex,
      bookingMinutes: _hours * 60,
      now: now,
    );
    final use = EndlessRoundGenerator.courtUse(active.withCourt(draft), draft.id, now);
    final until = active.tournament.createdAt.add(Duration(minutes: draft.endMinute));

    return MabarSheet(
      title: 'Kelola court',
      footer: canAdd
          ? MabarButton(
              label: 'Tambah court',
              icon: MabarIcons.plus,
              meta: tooShort
                  ? null
                  : switch (use.use) {
                      CourtUse.now => null,
                      CourtUse.nextRound => '· mulai R${active.roundCount + 1}',
                      CourtUse.unused => '· belum terpakai',
                    },
              onPressed: tooShort
                  ? null
                  : () {
                      ref
                          .read(tournamentProvider.notifier)
                          .addCourt(name: _name.text, colorIndex: colorIndex, bookingMinutes: _hours * 60);
                      Navigator.pop(context);
                    },
            )
          : null,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarSection(
            // Jumlah ditulis angka dulu, seperti "10 pemain aktif · 1 keluar" di Kelola pemain.
            header: MabarGroupLabel(expired > 0 ? '${courts.length} court · $expired habis' : '${courts.length} court'),
            child: MabarGroup(
              color: MabarColors.paper,
              children: [
                for (final (i, c) in courts.indexed)
                  MabarRow(
                    padded: true,
                    leading: CourtSwatch(color: MabarColors.courtPalette[c.colorIndex], number: i + 1),
                    titleWidget: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          c.name,
                          style: MabarType.body.copyWith(fontWeight: FontWeight.w600, color: MabarColors.ink),
                        ),
                        Text(_windowLeft(active, c, now), style: MabarType.caption),
                      ],
                    ),
                    chevron: true,
                    onTap: () => Navigator.pop(context, c.id),
                  ),
              ],
            ),
          ),
          if (canAdd) ...[
            const SizedBox(height: 16),
            MabarSection(
              header: const MabarGroupLabel('Court baru'),
              note: tooShort
                  ? MabarGroupNote('Lebih pendek dari durasi match ($duration mnt)', error: true)
                  : MabarGroupNote('Sampai ${clockText(until)}'),
              child: MabarGroup(
                color: MabarColors.paper,
                children: [
                  MabarRow(
                    padded: true,
                    leading: CourtSwatch(
                      color: MabarColors.courtPalette[colorIndex],
                      number: number,
                      onTap: () => _pickColor(number, colorIndex),
                    ),
                    titleWidget: MabarField.inline(
                      controller: _name,
                      hint: 'Court $number',
                      fillColor: MabarColors.card,
                      textCapitalization: TextCapitalization.words,
                      onChanged: (_) => setState(() {}),
                    ),
                    trailing: MabarStepper(
                      value: _hours,
                      min: 1,
                      max: _maxBookingHours,
                      unit: 'jam',
                      error: tooShort,
                      onChanged: (h) => setState(() => _hours = h),
                    ),
                  ),
                ],
              ),
            ),
            if (!tooShort && use.use == CourtUse.now) ...[
              const SizedBox(height: 16),
              _landing(active, use.players),
            ],
          ],
        ],
      ),
    );
  }
}

class _CourtDetail extends ConsumerStatefulWidget {
  final String courtId;
  const _CourtDetail({required this.courtId});

  @override
  ConsumerState<_CourtDetail> createState() => _CourtDetailState();
}

class _CourtDetailState extends ConsumerState<_CourtDetail> {
  late final TextEditingController _name;
  late int _colorIndex;

  /// Panjang booking dalam jam; court yang sudah habis mulai dari 0 (dipesan ulang dari sekarang).
  late int _hours;
  late final int _minHours;

  @override
  void initState() {
    super.initState();
    final active = ref.read(tournamentProvider)!;
    final court = active.courtById(widget.courtId);
    final live = active.remainingBookingMinutes(court, ref.read(clockProvider)()) > 0;
    // Nama bawaan tampil sebagai placeholder, seperti baris court Konfigurasi.
    final number = active.config.courts.indexOf(court) + 1;
    _name = TextEditingController(text: court.name == 'Court $number' ? '' : court.name);
    _colorIndex = court.colorIndex;
    _hours = live ? court.bookingDurationMinutes ~/ 60 : 0;
    _minHours = live ? 1 : 0;
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _pickColor(String label) async {
    final picked = await showMabarSheet<int>(
      context,
      title: 'Warna $label',
      builder: (context) => CourtColorGrid(selected: _colorIndex, onSelect: (i) => Navigator.pop(context, i)),
    );
    if (picked != null && mounted) setState(() => _colorIndex = picked);
  }

  Future<void> _remove(ActiveTournament active, Court court) async {
    final pending = active.matches.where((m) => m.courtId == court.id && m.status == MatchStatus.pending);
    if (pending.isNotEmpty) {
      final ok = await showMabarConfirm(
        context,
        title: 'Hapus ${court.name}?',
        message: 'Match R${pending.first.roundNumber} di court ini ikut dihapus.',
        confirmLabel: 'Hapus',
        destructive: true,
      );
      if (!ok || !mounted) return;
    }
    ref.read(tournamentProvider.notifier).removeCourt(court.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    if (active == null) return const SizedBox();
    final now = ref.read(clockProvider)();
    final original = active.courtById(widget.courtId);
    final number = active.config.courts.indexOf(original) + 1;
    final duration = active.config.matchDurationMinutes;

    final name = _name.text.trim().isEmpty ? 'Court $number' : _name.text.trim();
    final preview = active.withBookingHours(original, _hours, now).copyWith(name: name, colorIndex: _colorIndex);
    final changed =
        preview.name != original.name ||
        preview.colorIndex != original.colorIndex ||
        preview.startMinute != original.startMinute ||
        preview.bookingDurationMinutes != original.bookingDurationMinutes;
    final tooShort = _hours > 0 && _hours * 60 < duration;
    final wasAvailable = active.remainingBookingMinutes(original, now) >= duration;
    final use = EndlessRoundGenerator.courtUse(active.withCourt(preview), original.id, now, wasAvailable: wasAvailable);

    return MabarSheet(
      title: original.name,
      subtitle: _windowLeft(active, preview, now),
      action: active.canRemoveCourt(original.id)
          ? MabarTextButton(label: 'Hapus', tone: MabarTextTone.danger, onPressed: () => _remove(active, original))
          : null,
      footer: MabarButton(
        label: 'Simpan',
        icon: MabarIcons.check,
        onPressed: changed && !tooShort
            ? () {
                ref.read(tournamentProvider.notifier).updateCourt(preview);
                Navigator.pop(context);
              }
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarSection(
            note: tooShort ? MabarGroupNote('Lebih pendek dari durasi match ($duration mnt)', error: true) : null,
            child: MabarGroup(
              color: MabarColors.paper,
              children: [
                MabarRow(
                  padded: true,
                  leading: CourtSwatch(
                    color: MabarColors.courtPalette[_colorIndex],
                    number: number,
                    onTap: () => _pickColor(name),
                  ),
                  titleWidget: MabarField.inline(
                    controller: _name,
                    hint: 'Court $number',
                    fillColor: MabarColors.card,
                    textCapitalization: TextCapitalization.words,
                    onChanged: (_) => setState(() {}),
                  ),
                  trailing: MabarStepper(
                    value: _hours,
                    min: _minHours,
                    max: _maxBookingHours,
                    unit: 'jam',
                    error: tooShort,
                    onChanged: (h) => setState(() => _hours = h),
                  ),
                ),
              ],
            ),
          ),
          if (!tooShort && use.use == CourtUse.now) ...[
            const SizedBox(height: 16),
            _landing(active, use.players),
          ],
        ],
      ),
    );
  }
}
