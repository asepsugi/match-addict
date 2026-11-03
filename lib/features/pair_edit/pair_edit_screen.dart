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
  static Future<PairDraft?> open(BuildContext context, {required PairDraft initial, required SportType sport, required int firstRound}) =>
      Navigator.of(context).push<PairDraft>(
        MaterialPageRoute(builder: (_) => PairEditScreen(initial: initial, sport: sport, firstRound: firstRound)),
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

  PairDraft get _draft => _history.last;

  @override
  void dispose() {
    _name.dispose();
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
    _push(_draft.pair(picked, p, id: _uuid.v4()));
  }

  void _add() {
    final result = _draft.add(_name.text, id: _uuid.v4());
    setState(() => _error = result.error);
    if (result.draft == null) return;
    _name.clear();
    _push(result.draft!);
  }

  @override
  Widget build(BuildContext context) {
    final draft = _draft;
    final pairs = draft.pairs;
    final unpaired = draft.unpaired;
    final picked = _picked;
    final enough = pairs.length >= 2;

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
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: MabarField(
                          controller: _name,
                          hint: 'Nama pemain baru',
                          error: _error != null,
                          textCapitalization: TextCapitalization.words,
                          textInputAction: TextInputAction.done,
                          onSubmitted: (_) => _add(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Sama tinggi dengan kolom nama di sebelahnya, seperti Kelola pemain (08a).
                      MabarButton(label: 'Tambah', expand: false, height: 48, onPressed: _add),
                    ],
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 10),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: Text(
                        _error!,
                        style: MabarType.caption.copyWith(color: MabarColors.clay, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
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
                            MabarChip(label: p.name, tall: true, selected: p.id == picked?.id, onTap: () => _tapPlayer(p)),
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
                child: enough
                    ? MabarButton(
                        label: 'Simpan pasangan',
                        meta: unpaired.isEmpty ? null : '· ${unpaired.length} tidak main',
                        onPressed: () => Navigator.pop(context, draft),
                      )
                    : const MabarButton(
                        label: 'Simpan pasangan',
                        meta: '· minimal 2 pasangan',
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
