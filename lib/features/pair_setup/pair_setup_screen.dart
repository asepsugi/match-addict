import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../core/widgets/numbered_lists.dart';
import '../../models/models.dart';
import '../../services/pairing/pair_generator.dart';

/// Screen 04 · Pasangan (Fixed) — satu daftar pasangan bernomor. Acak langsung saat dibuka; Manual
/// memasangkan chip pemain dua-dua. Peringatan "tidak bisa diubah" ada di dialog Buat jadwal.
/// Sparing (14a–14e): satu daftar + chip per klub, pasangan hanya sesama klub, tombol dan "Acak ulang"/"Urungkan"
/// tetap satu untuk kedua klub.
class PairSetupScreen extends StatefulWidget {
  final TournamentConfig config;

  /// Sumber acak pasangan; diisi test supaya hasil acak sama dengan frame.
  final Random? random;

  const PairSetupScreen({super.key, required this.config, this.random});

  @override
  State<PairSetupScreen> createState() => _PairSetupScreenState();
}

class _PairSetupScreenState extends State<PairSetupScreen> {
  var _manual = false;
  List<Pair> _pairs = const [];

  /// Manual: pemain yang sudah diketuk dan menunggu pasangannya.
  Player? _picked;

  List<Player> get _players => widget.config.players;

  List<Club>? get _clubs => widget.config.clubs;

  @override
  void initState() {
    super.initState();
    _pairs = _shuffled();
  }

  List<Pair> _shuffled() {
    final clubs = _clubs;
    return clubs == null
        ? PairGenerator.random(_players, random: widget.random).pairs
        : PairGenerator.randomByClub(_players, clubs, random: widget.random).pairs;
  }

  /// Pindah ke Manual mengosongkan pasangan; kembali ke Acak membuang hasil manual.
  void _switchMode(bool manual) {
    if (manual == _manual) return;
    setState(() {
      _manual = manual;
      _picked = null;
      _pairs = manual ? const [] : _shuffled();
    });
  }

  void _tapPlayer(Player p) {
    setState(() {
      final picked = _picked;
      if (picked == null) {
        _picked = p;
      } else if (picked == p) {
        _picked = null;
      } else {
        final pair = PairGenerator.manual(picked, p);
        // Beda klub (sparing, AC-S4): bukan pasangan, pilihan pindah ke pemain yang baru diketuk (14b).
        if (pair == null) {
          _picked = p;
        } else {
          _pairs = [..._pairs, pair];
          _picked = null;
        }
      }
    });
  }

  /// Melepas pasangan terakhir dan pilihan yang menggantung.
  void _undo() => setState(() {
    _pairs = [..._pairs]..removeLast();
    _picked = null;
  });

  /// Kembali ke layar Pemain (di bawah Konfigurasi) dengan daftar nama tetap terisi.
  void _editPlayers() => Navigator.of(context)
    ..pop()
    ..pop();

  Future<void> _create() async {
    final ok = await showMabarConfirm(
      context,
      title: 'Buat jadwal?',
      message: 'Pasangan tidak bisa diubah setelah jadwal dibuat.',
      confirmLabel: 'Buat jadwal',
    );
    if (!ok || !mounted) return;
    context.push('/schedule', extra: widget.config.copyWith(fixedPairs: _pairs));
  }

  /// Sparing: bagian satu klub (14a–14c, 14e). [first] membawa Acak ulang/Urungkan, [last] membawa catatan ganjil.
  Widget _clubSection(Club club, {required bool first, required String? chipNoteClubId, required bool oddNote}) {
    final members = widget.config.playersOfClub(club.id);
    final pairs = [
      for (final pair in _pairs)
        if (widget.config.clubOfPair(pair)?.id == club.id) pair,
    ];
    final paired = {for (final pair in _pairs) ...pair.playerIds};
    final unpaired = [
      for (final p in members)
        if (!paired.contains(p.id)) p,
    ];
    final leftover = unpaired.length == 1 ? unpaired.single : null;
    final chips = leftover == null ? unpaired : const <Player>[];
    final slots = members.length ~/ 2;
    final picked = _picked;
    String name(String id) => _players.firstWhere((p) => p.id == id).name;

    final Widget? chipNote = chipNoteClubId != club.id
        ? null
        : MabarGroupNote(
            picked == null
                ? 'Ketuk dua pemain satu klub untuk membuat pasangan'
                : 'Ketuk satu lagi untuk dipasangkan dengan ${picked.name}',
          );
    final Widget? note = oddNote
        ? MabarGroupHeader(
            label: Text('Fixed butuh pemain genap per klub', style: MabarType.caption),
            trailing: MabarTextButton(label: 'Ubah pemain', onPressed: _editPlayers),
          )
        : null;

    return MabarSection(
      header: MabarGroupHeader.text(
        _manual ? '${club.name} · ${pairs.length} dari $slots pasangan' : '${club.name} · ${pairs.length} pasangan',
        trailing: !first
            ? null
            : _manual
            ? MabarTextButton(
                label: 'Urungkan',
                icon: MabarIcons.arrowCounterClockwise,
                onPressed: _pairs.isEmpty ? null : _undo,
              )
            : MabarTextButton(
                label: 'Acak ulang',
                icon: MabarIcons.arrowClockwise,
                onPressed: () => setState(() => _pairs = _shuffled()),
              ),
      ),
      note: note,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pairs.isNotEmpty || leftover != null)
            PairList(
              pairs: [for (final pair in pairs) (name(pair.player1Id), name(pair.player2Id))],
              leftover: leftover?.name,
            ),
          if (chips.isNotEmpty) ...[
            if (pairs.isNotEmpty || leftover != null) const SizedBox(height: 16),
            MabarSection(
              note: chipNote,
              child: MabarChipGrid(
                children: [
                  for (final p in chips)
                    MabarChip(label: p.name, tall: true, selected: p == picked, onTap: () => _tapPlayer(p)),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Sparing: tombol Buat jadwal menghitung pasangan yang belum jadi di kedua klub, lalu sisa ganjil (K12).
  Widget _sparingBody(List<Club> clubs) {
    final paired = {for (final pair in _pairs) ...pair.playerIds};
    final oddClubs = [
      for (final c in clubs)
        if (widget.config.playersOfClub(c.id).length.isOdd) c,
    ];
    // Catatan chip: di bawah klub pemain yang dipilih, tanpa pilihan di klub terakhir yang masih punya chip (14b, 14e).
    bool hasChips(Club c) => widget.config.playersOfClub(c.id).where((p) => !paired.contains(p.id)).length > 1;
    final noteClub = _picked != null ? _picked!.clubId : clubs.where(hasChips).lastOrNull?.id;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final (i, club) in clubs.indexed) ...[
          if (i > 0) const SizedBox(height: 16),
          _clubSection(
            club,
            first: i == 0,
            chipNoteClubId: noteClub,
            oddNote: oddClubs.isNotEmpty && i == clubs.length - 1,
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final clubs = _clubs;
    String name(String id) => _players.firstWhere((p) => p.id == id).name;
    final paired = {for (final pair in _pairs) ...pair.playerIds};
    final unpaired = [
      for (final p in _players)
        if (!paired.contains(p.id)) p,
    ];
    // Satu pemain tersisa (jumlah ganjil) masuk daftar sebagai baris "–"; sisanya chip (Manual).
    final leftover = unpaired.length == 1 ? unpaired.single : null;
    final chips = leftover == null ? unpaired : const <Player>[];
    // Sparing: tiap klub punya slot sendiri; sisa ganjil (satu per klub) tidak pernah dipasangkan lintas klub.
    final slots = clubs == null
        ? _players.length ~/ 2
        : [for (final c in clubs) widget.config.playersOfClub(c.id).length ~/ 2].fold(0, (a, b) => a + b);
    final remaining = slots - _pairs.length;
    final picked = _picked;
    final unpairedCount = _players.length - _pairs.length * 2;

    final pairSection = MabarSection(
      header: MabarGroupHeader.text(
        _manual ? '${_pairs.length} dari $slots pasangan' : '${_pairs.length} pasangan',
        trailing: _manual
            ? MabarTextButton(
                label: 'Urungkan',
                icon: MabarIcons.arrowCounterClockwise,
                onPressed: _pairs.isEmpty ? null : _undo,
              )
            : MabarTextButton(
                label: 'Acak ulang',
                icon: MabarIcons.arrowClockwise,
                onPressed: () => setState(() => _pairs = _shuffled()),
              ),
      ),
      note: leftover == null
          ? null
          : MabarGroupHeader(
              label: Text('Fixed butuh jumlah pemain genap', style: MabarType.caption),
              trailing: MabarTextButton(label: 'Ubah pemain', onPressed: _editPlayers),
            ),
      child: PairList(
        pairs: [for (final pair in _pairs) (name(pair.player1Id), name(pair.player2Id))],
        leftover: leftover?.name,
      ),
    );

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: 'Pasangan',
            subtitle: clubs == null
                ? '${widget.config.sport.label} · ${_players.length} pemain'
                : '${widget.config.sport.label} · ${[for (final c in clubs) '${c.name} ${widget.config.playersOfClub(c.id).length}'].join(' · ')}',
            onBack: () => context.pop(),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  MabarSegmented<bool>(
                    options: const [(false, 'Acak'), (true, 'Manual')],
                    selected: _manual,
                    onChanged: _switchMode,
                  ),
                  const SizedBox(height: 16),
                  if (clubs != null) _sparingBody(clubs) else pairSection,
                  if (clubs == null && chips.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    MabarSection(
                      header: MabarGroupLabel('${chips.length} belum berpasangan'),
                      note: MabarGroupNote(
                        picked == null
                            ? 'Ketuk dua pemain untuk membuat pasangan'
                            : 'Ketuk satu lagi untuk dipasangkan dengan ${picked.name}',
                      ),
                      child: MabarChipGrid(
                        children: [
                          for (final p in chips)
                            MabarChip(label: p.name, tall: true, selected: p == picked, onTap: () => _tapPlayer(p)),
                        ],
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
          MabarActionBar(
            children: [
              Expanded(
                child: remaining > 0
                    ? MabarButton(
                        label: 'Buat jadwal',
                        meta: '· $remaining pasangan lagi',
                        variant: MabarButtonVariant.wait,
                      )
                    : unpairedCount > 0
                    ? MabarButton(
                        label: 'Buat jadwal',
                        meta: '· $unpairedCount pemain tanpa pasangan',
                        variant: MabarButtonVariant.wait,
                      )
                    : MabarButton(label: 'Buat jadwal', icon: MabarIcons.lockSimple, onPressed: _create),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
