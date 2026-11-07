import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../core/widgets/numbered_lists.dart';
import '../../models/models.dart';
import '../../services/pairing/club_roster.dart';
import '../../services/pairing/player_name_parser.dart';
import 'widgets/name_list_field.dart';

/// Screen 02 · Pemain — satu kotak teks untuk ditempel dari grup WhatsApp, aksinya menempel di bawah kotak.
/// Penomoran/bullet dan duplikat dibersihkan diam-diam; daftar bernomor di bawahnya = hasil akhirnya.
/// Pilihan Mabar / Sparing (13a–13g): Sparing = dua blok klub (`.clubblock`) dengan kotak yang sama. Isi tiap pilihan
/// disimpan di controllernya sendiri, jadi pindah pilihan tidak menghapus ketikan; pilihan tidak diingat antar turnamen.
class SetupPesertaScreen extends StatefulWidget {
  final SportType sport;
  const SetupPesertaScreen({super.key, required this.sport});

  @override
  State<SetupPesertaScreen> createState() => _SetupPesertaScreenState();
}

class _SetupPesertaScreenState extends State<SetupPesertaScreen> {
  static const _sampleNames = ['Andi P', 'Budi S', 'Citra L', 'Dewant R', 'Eko M', 'Fajar K', 'Gina R', 'Hana T'];
  // Beda per klub supaya Contoh tidak pernah membuat nama yang sama di dua klub.
  static const _sampleClub1 = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'];
  static const _sampleClub2 = ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda'];

  final _controller = TextEditingController();
  final _clubName1 = TextEditingController(), _clubName2 = TextEditingController();
  final _clubText1 = TextEditingController(), _clubText2 = TextEditingController();
  late final _all = [_controller, _clubName1, _clubName2, _clubText1, _clubText2];
  ParseResult _result = const ParseResult(names: [], duplicates: []);
  var _sparing = false;
  var _scrolled = false;

  @override
  void initState() {
    super.initState();
    for (final c in _all) {
      c.addListener(_reparse);
    }
  }

  @override
  void dispose() {
    for (final c in _all) {
      c.dispose();
    }
    super.dispose();
  }

  void _reparse() {
    final next = PlayerNameParser.parse(_controller.text);
    setState(() => _result = next);
  }

  SparingRosterCheck get _check => ClubRoster.check(
    rawName1: _clubName1.text,
    rawName2: _clubName2.text,
    rawText1: _clubText1.text,
    rawText2: _clubText2.text,
  );

  /// Kosong: mengganti isi. Ada isi: ditambahkan di baris baru.
  Future<void> _paste(TextEditingController controller) async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text;
    if (text == null || text.trim().isEmpty) return;
    final current = controller.text;
    controller.text = current.trim().isEmpty ? text : '${current.trimRight()}\n$text';
  }

  void _next() {
    const uuid = Uuid();
    if (!_sparing) {
      final players = [for (final name in _result.names) Player(id: uuid.v4(), name: name)];
      context.push('/konfigurasi', extra: (widget.sport, players, null));
      return;
    }
    final check = _check;
    final clubs = [Club(id: uuid.v4(), name: check.name1), Club(id: uuid.v4(), name: check.name2)];
    final players = [
      for (final name in check.roster1.names) Player(id: uuid.v4(), name: name, clubId: clubs[0].id),
      for (final name in check.roster2.names) Player(id: uuid.v4(), name: name, clubId: clubs[1].id),
    ];
    context.push('/konfigurasi', extra: (widget.sport, players, clubs));
  }

  /// Garis bawah app bar begitu isi tergulir ke bawahnya.
  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0) {
      final scrolled = n.metrics.pixels > 0;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    }
    return false;
  }

  /// Kotak teks + toolbar. Contoh mengganti seluruh isi, jadi hanya ada saat kosong.
  Widget _compose(TextEditingController controller, String hint, List<String> sample, Key key) {
    final empty = controller.text.trim().isEmpty;
    return NameListField(
      key: key,
      controller: controller,
      hint: hint,
      tools: [
        MabarTextButton(label: 'Tempel', icon: MabarIcons.clipboardText, onPressed: () => _paste(controller)),
        if (empty)
          MabarTextButton(
            label: 'Contoh',
            icon: MabarIcons.userList,
            onPressed: () => controller.text = sample.join('\n'),
          ),
      ],
      trailingTool: empty
          ? null
          : MabarTextButton(
              label: 'Hapus semua',
              icon: MabarIcons.trash,
              tone: MabarTextTone.danger,
              onPressed: controller.clear,
            ),
    );
  }

  /// Label jumlah + daftar bernomor (kalau ada isi), lalu catatan di bawahnya.
  List<Widget> _rosterAndNotes(ParseResult r, List<Widget> notes) => [
    if (r.count > 0) ...[
      const SizedBox(height: 16),
      MabarGroupLabel('${r.count} pemain'),
      const SizedBox(height: 8),
      RosterPreview(names: r.names),
    ],
    for (final note in notes) ...[const SizedBox(height: 8), note],
  ];

  List<Widget> _mabarBlocks() {
    final count = _result.count;
    final notes = [
      // Kurang dari 4 bukan error: host masih mengetik.
      if (count > 0 && count < TournamentConfig.minPlayers)
        const MabarGroupNote('Minimal ${TournamentConfig.minPlayers} pemain'),
      if (count > TournamentConfig.maxPlayers)
        const MabarGroupNote('Maksimal ${TournamentConfig.maxPlayers} pemain', error: true),
      if (_result.duplicates.isNotEmpty) MabarGroupNote('Duplikat dibuang: ${_result.duplicates.join(', ')}'),
    ];
    return [
      _compose(_controller, '1. Andi P\n2. Budi S\n3) Citra L', _sampleNames, const ValueKey('mabar')),
      ..._rosterAndNotes(_result, notes),
    ];
  }

  Widget _noteOf(ClubNote n) => MabarGroupNote(n.text, error: n.error);

  /// `.clubblock`: kotak nama klub lalu kotak nama pemain; catatan nama klub di bawah kotaknya (`.gnote` -2 → 6).
  List<Widget> _clubBlock({
    required int index,
    required TextEditingController name,
    required TextEditingController text,
    required String nameHint,
    required String hint,
    required List<String> sample,
    required ParseResult roster,
    required ClubNote? nameNote,
    required bool nameError,
    required List<ClubNote> listNotes,
  }) => [
    MabarField(
      key: ValueKey('club-name-$index'),
      controller: name,
      hint: nameHint,
      error: nameError,
      textInputAction: TextInputAction.done,
      inputFormatters: [LengthLimitingTextInputFormatter(ClubRoster.maxNameLength)],
    ),
    if (nameNote != null) ...[const SizedBox(height: 6), _noteOf(nameNote)],
    const SizedBox(height: 8),
    _compose(text, hint, sample, ValueKey('club-text-$index')),
    ..._rosterAndNotes(roster, [for (final n in listNotes) _noteOf(n)]),
  ];

  List<Widget> _sparingBlocks(SparingRosterCheck c) => [
    ..._clubBlock(
      index: 1,
      name: _clubName1,
      text: _clubText1,
      nameHint: 'Nama klub pertama',
      hint: '1. Andi P\n2. Budi S\n3) Citra L',
      sample: _sampleClub1,
      roster: c.roster1,
      nameNote: c.nameNote1,
      nameError: false,
      listNotes: c.listNotes1,
    ),
    const SizedBox(height: 16),
    ..._clubBlock(
      index: 2,
      name: _clubName2,
      text: _clubText2,
      nameHint: 'Nama klub kedua',
      hint: '1. Indra W\n2. Joko S\n3) Kiki A',
      sample: _sampleClub2,
      roster: c.roster2,
      nameNote: c.nameNote2,
      nameError: c.name2Error,
      listNotes: c.listNotes2,
    ),
  ];

  @override
  Widget build(BuildContext context) {
    final check = _check;
    final canContinue = _sparing ? check.canContinue : _result.isValid;
    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(title: 'Pemain', subtitle: widget.sport.label, onBack: () => context.pop(), scrolled: _scrolled),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MabarSegmented<bool>(
                      options: const [(false, 'Mabar'), (true, 'Sparing')],
                      selected: _sparing,
                      onChanged: (v) => setState(() => _sparing = v),
                    ),
                    const SizedBox(height: 16),
                    ..._sparing ? _sparingBlocks(check) : _mabarBlocks(),
                  ],
                ),
              ),
            ),
          ),
          MabarActionBar(
            children: [
              Expanded(
                child: MabarButton(label: 'Lanjut', onPressed: canContinue ? _next : null),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
