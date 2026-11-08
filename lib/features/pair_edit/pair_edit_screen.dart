import 'package:flutter/material.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../core/widgets/numbered_lists.dart';
import '../../models/models.dart';
import '../../services/pairing/pair_draft.dart';

/// Screen 04f–04g · Atur pasangan sebelum round tambahan Fixed. Dibuka dari sheet Tambah round; "Simpan pasangan"
/// mengembalikan [PairDraft], kembali (←) membuangnya. Belum ada yang berubah di turnamen sampai "Buat R…" di sheet.
class PairEditScreen extends StatefulWidget {
  final PairDraft initial;
  final SportType sport;

  /// Round tambahan pertama ("mulai R15").
  final int firstRound;

  const PairEditScreen({super.key, required this.initial, required this.sport, required this.firstRound});

  /// Push di atas sheet Tambah round; null kalau host kembali tanpa menyimpan.
  static Future<PairDraft?> open(
    BuildContext context, {
    required PairDraft initial,
    required SportType sport,
    required int firstRound,
  }) => Navigator.of(context).push<PairDraft>(
    MaterialPageRoute(
      builder: (_) => PairEditScreen(initial: initial, sport: sport, firstRound: firstRound),
    ),
  );

  @override
  State<PairEditScreen> createState() => _PairEditScreenState();
}

class _PairEditScreenState extends State<PairEditScreen> {
  static const _uuid = Uuid();

  /// Riwayat untuk "Urungkan"; yang terakhir = sekarang.
  late final List<PairDraft> _history = [widget.initial];

  /// Pemain yang sudah diketuk dan menunggu pasangannya.
  Player? _picked;

  final _name = TextEditingController();
  String? _error;

  /// Sparing: satu kotak pemain baru per klub (14o), dan klub tempat pesan error terakhir muncul.
  late final Map<String, TextEditingController> _clubNames = {
    for (final c in widget.initial.clubs ?? const <Club>[]) c.id: TextEditingController(),
  };
  String? _errorClubId;

  PairDraft get _draft => _history.last;

  @override
  void dispose() {
    _name.dispose();
    for (final c in _clubNames.values) {
      c.dispose();
    }
    super.dispose();
  }

  void _push(PairDraft next) => setState(() {
    _history.add(next);
    _picked = null;
  });

  void _undo() => setState(() {
    _history.removeLast();
    _picked = null;
  });

  void _tapPlayer(Player p) {
    final picked = _picked;
    if (picked == null) return setState(() => _picked = p);
    if (picked.id == p.id) return setState(() => _picked = null);
    // Sparing: pasangan hanya sesama klub; beda klub memindah pilihan ke yang diketuk (sama dengan 14b).
    if (!_draft.canPair(picked, p)) return setState(() => _picked = p);
    _push(_draft.pair(picked, p, id: _uuid.v4()));
  }

  /// [clubId] hanya di sparing: pemain baru masuk klub bagian tempat ia diketik (K8).
  void _add({String? clubId}) {
    final field = clubId == null ? _name : _clubNames[clubId]!;
    final result = _draft.add(field.text, id: _uuid.v4(), clubId: clubId);
    setState(() {
      _error = result.error;
      _errorClubId = clubId;
    });
    if (result.draft == null) return;
    field.clear();
    _push(result.draft!);
  }

  /// Sparing: bagian satu klub (14o) — daftar pasangan klub itu, chip yang belum berpasangan, lalu kotak pemain baru.
  Widget _clubSection(Club club, {required bool first}) {
    final draft = _draft;
    final pairs = draft.pairsOf(club.id);
    final chips = draft.unpairedOf(club.id);
    final picked = _picked;
    // Catatan chip untuk klub pemain yang dipilih; tanpa pilihan, untuk tiap klub yang punya dua chip atau lebih.
    final showNote = chips.length >= 2 && (picked == null || picked.clubId == club.id);
    final error = _errorClubId == club.id ? _error : null;
    return MabarSection(
      header: MabarGroupHeader.text(
        '${club.name} · ${pairs.length} pasangan',
        trailing: !first
            ? null
            : MabarTextButton(
                label: 'Urungkan',
                icon: MabarIcons.arrowCounterClockwise,
                onPressed: _history.length > 1 ? _undo : null,
              ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (pairs.isNotEmpty)
            PairList(
              pairs: [for (final p in pairs) (draft.nameOf(p.player1Id), draft.nameOf(p.player2Id))],
              onEdit: (i) => _push(draft.split(pairs[i])),
            ),
          if (chips.isNotEmpty) ...[
            if (pairs.isNotEmpty) const SizedBox(height: 16),
            MabarSection(
              note: !showNote
                  ? null
                  : MabarGroupNote(
                      picked == null
                          ? 'Ketuk dua pemain untuk membuat pasangan'
                          : 'Ketuk satu lagi untuk dipasangkan dengan ${picked.name}',
                    ),
              child: MabarChipGrid(
                children: [
                  for (final p in chips)
                    MabarChip(label: p.name, tall: true, selected: p.id == picked?.id, onTap: () => _tapPlayer(p)),
                ],
              ),
            ),
          ],
          const SizedBox(height: 16),
          _newPlayerRow(_clubNames[club.id]!, error: error, clubId: club.id),
        ],
      ),
    );
  }

  /// Kotak "Nama pemain baru" + Tambah + pesan error di bawahnya; dipakai Fixed biasa dan tiap bagian klub sparing.
  Widget _newPlayerRow(TextEditingController controller, {required String? error, String? clubId}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MabarField(
                controller: controller,
                hint: 'Nama pemain baru',
                error: error != null,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => _add(clubId: clubId),
              ),
            ),
            const SizedBox(width: 8),
            // Sama tinggi dengan kolom nama di sebelahnya, seperti Kelola pemain (08a).
            MabarButton(
              label: 'Tambah',
              expand: false,
              height: 48,
              onPressed: () => _add(clubId: clubId),
            ),
          ],
        ),
        if (error != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              error,
              style: MabarType.caption.copyWith(color: MabarColors.clay, fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final pairs = draft.pairs;
    final unpaired = draft.unpaired;
    final picked = _picked;
    final clubs = draft.clubs;
    // Sparing: syaratnya satu pasangan tiap klub (§13.5), bukan dua pasangan.
    final enough = clubs == null ? pairs.length >= 2 : draft.hasPairEachClub;

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: 'Atur pasangan',
            subtitle: '${widget.sport.label} · mulai R${widget.firstRound}',
            onBack: () => Navigator.pop(context),
          ),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (clubs != null)
                    for (final (i, club) in clubs.indexed) ...[
                      if (i > 0) const SizedBox(height: 16),
                      _clubSection(club, first: i == 0),
                    ]
                  else ...[
                    MabarSection(
                      header: MabarGroupHeader.text(
                        '${pairs.length} pasangan',
                        trailing: MabarTextButton(
                          label: 'Urungkan',
                          icon: MabarIcons.arrowCounterClockwise,
                          onPressed: _history.length > 1 ? _undo : null,
                        ),
                      ),
                      child: PairList(
                        pairs: [for (final p in pairs) (draft.nameOf(p.player1Id), draft.nameOf(p.player2Id))],
                        onEdit: (i) => _push(draft.split(pairs[i])),
                      ),
                    ),
                    const SizedBox(height: 16),
                    _newPlayerRow(_name, error: _error),
                    if (unpaired.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      MabarSection(
                        header: MabarGroupLabel('${unpaired.length} belum berpasangan'),
                        // Satu chip tidak bisa dipasangkan dengan siapa pun, jadi petunjuknya hilang (04g).
                        note: unpaired.length < 2
                            ? null
                            : MabarGroupNote(
                                picked == null
                                    ? 'Ketuk dua pemain untuk membuat pasangan'
                                    : 'Ketuk satu lagi untuk dipasangkan dengan ${picked.name}',
                              ),
                        child: MabarChipGrid(
                          children: [
                            for (final p in unpaired)
                              MabarChip(
                                label: p.name,
                                tall: true,
                                selected: p.id == picked?.id,
                                onTap: () => _tapPlayer(p),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ],
              ),
            ),
          ),
          MabarActionBar(
            children: [
              Expanded(
                child: enough
                    ? MabarButton(
                        label: 'Simpan pasangan',
                        meta: unpaired.isEmpty ? null : '· ${unpaired.length} tidak main',
                        onPressed: () => Navigator.pop(context, draft),
                      )
                    : MabarButton(
                        label: 'Simpan pasangan',
                        meta: clubs == null ? '· minimal 2 pasangan' : '· minimal 1 pasangan tiap klub',
                        variant: MabarButtonVariant.wait,
                      ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
