import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/mabar_theme.dart';
import '../../core/time_text.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../../services/schedule/config_summary.dart';
import '../../services/schedule/endless_round_generator.dart';
import '../../services/schedule/group_stage.dart';
import '../../services/schedule/sparing_fixed_generator.dart';
import '../schedule/tournament_controller.dart';
import 'widgets/config_pickers.dart';

/// Screen 03 · Konfigurasi — satu layar yang selalu muat (keputusan 33): nama turnamen, Pasangan, lalu Skor dan Court
/// masing-masing satu baris berisi nilainya; rinciannya di sheet jenis kelola (tiap perubahan langsung berlaku).
/// Dibuka dengan pengaturan terakhir olahraga ini (keputusan 36). Estimasi ada di tombol. Fixed → Pasangan; Mixed →
/// langsung Jadwal dan membuat R1.
class KonfigurasiScreen extends ConsumerStatefulWidget {
  final SportType sport;
  final List<Player> players;

  /// Sparing: dua klub dari layar Pemain (pemainnya sudah membawa `clubId`); null = turnamen biasa. Ikut ke config
  /// apa adanya.
  final List<Club>? clubs;

  const KonfigurasiScreen({super.key, required this.sport, required this.players, this.clubs});

  @override
  ConsumerState<KonfigurasiScreen> createState() => _KonfigurasiScreenState();
}

class _KonfigurasiScreenState extends ConsumerState<KonfigurasiScreen> {
  static const _minCourts = 1;
  static const _defaultCourtCount = 2;
  static const _defaultBookingHours = 2;
  static const _maxBookingHours = 12;
  static const _maxDuration = 180;

  PartnerMode _mode = PartnerMode.fixed;
  ScoreFormat _format = ScoreFormat.standard;

  /// Format Grup + Gugur (19a–19l). Dipilih hanya berlaku kalau segmented-nya tampil ([_knockoutOn]); pindah ke
  /// Mixed lalu kembali ke Fixed memulihkan pilihan ini (asumsi 19a).
  bool _knockout = false;
  int _groupCount = 2;
  bool _thirdPlace = true;

  /// Format babak yang sudah diubah host; babak yang tidak ada di sini ikut format grup (GU9, [_roundFormat]).
  final Map<KnockoutRound, ScoreFormat> _roundFormats = {};

  /// Null = durasi dikosongkan host (03p); tetap kosong sampai diisi.
  late int? _duration = widget.sport.defaultMatchDurationMinutes;
  final List<_CourtDraft> _courts = [];
  final _name = TextEditingController();
  var _scrolled = false;

  /// Mengabari isi sheet yang terbuka supaya ikut berubah bersama baris di belakangnya.
  final _tick = ValueNotifier(0);

  @override
  void initState() {
    super.initState();
    var last = ref.read(tournamentStoreProvider).loadLastSettings(widget.sport);
    if (widget.clubs != null) last = last?.forSparing();
    if (last != null) {
      _mode = last.mode;
      _format = last.format;
      _duration = last.matchDurationMinutes;
      final gk = last.groupKnockout;
      if (gk != null && _knockoutOffered) {
        // Turunan saat dibaca (docs/data.md): 4 grup di bawah 12 pasangan → 2 grup, format Perempat final dibuang.
        _knockout = true;
        _groupCount = GroupStage.groupCountsFor(_pairs).contains(gk.groupCount) ? gk.groupCount : 2;
        _thirdPlace = gk.thirdPlace;
        for (final MapEntry(key: round, value: format) in gk.formats.entries) {
          if (round == KnockoutRound.quarterfinal && _groupCount == 2) continue;
          if (format != _format.forKnockout) _roundFormats[round] = format;
        }
      }
      for (final (i, c) in last.courts.indexed) {
        _courts.add(_createCourt(i, colorIndex: c.colorIndex, hours: c.bookingMinutes ~/ 60)..name.text = c.name ?? '');
      }
    } else {
      for (var i = 0; i < _defaultCourtCount; i++) {
        _courts.add(_createCourt(i));
      }
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _tick.dispose();
    for (final c in _courts) {
      c.dispose();
    }
    super.dispose();
  }

  // Court dari simpanan tetap mendapat id baru: id milik turnamen, bukan pengaturan.
  _CourtDraft _createCourt(int index, {int? colorIndex, int? hours}) => _CourtDraft(
    id: const Uuid().v4(),
    colorIndex: colorIndex ?? index % MabarColors.courtPalette.length,
    hours: hours ?? _defaultBookingHours,
  );

  void _change(VoidCallback fn) {
    setState(fn);
    _tick.value++;
  }

  void _setCourtCount(int next) {
    _change(() {
      while (_courts.length < next) {
        _courts.add(_createCourt(_courts.length));
      }
      while (_courts.length > next) {
        _courts.removeLast().dispose();
      }
    });
  }

  Future<void> _pickColor(BuildContext sheetContext, int index) async {
    final court = _courts[index];
    final picked = await showMabarSheet<int>(
      sheetContext,
      // 03k, keputusan 42: judul memakai nama court ("Warna Court VIP"); nama kosong = "Court n".
      title: 'Warna ${court.label(index)}',
      builder: (context) => CourtColorGrid(selected: court.colorIndex, onSelect: (i) => Navigator.pop(context, i)),
    );
    if (picked != null && mounted) _change(() => court.colorIndex = picked);
  }

  TournamentConfig get _config => TournamentConfig(
    sport: widget.sport,
    mode: _mode,
    matchDurationMinutes: _duration ?? 0,
    courts: [for (var i = 0; i < _courts.length; i++) _courts[i].toCourt(i)],
    players: widget.players,
    format: _format,
    name: _name.text.trim().isEmpty ? null : _name.text.trim(),
    clubs: widget.clubs,
    groupKnockout: _knockoutOn
        ? GroupKnockout(
            groupCount: _groupCount,
            formats: {for (final r in _knockoutRounds) r: _roundFormat(r)},
            thirdPlace: _thirdPlace,
          )
        : null,
  );

  int get _pairs => widget.players.length ~/ 2;

  /// Segmented Round-robin / Grup + Gugur: hanya Fixed biasa dengan 6+ pasangan (AC-G1, GU14).
  bool get _knockoutOffered => widget.clubs == null && GroupStage.groupCountsFor(_pairs).isNotEmpty;

  bool get _knockoutOn => _mode == PartnerMode.fixed && _knockoutOffered && _knockout;

  /// Babak urut main (urutan baris sheet Gugur 19e); juara 3 selalu ada di sini, matinya lewat [_thirdPlace].
  List<KnockoutRound> get _knockoutRounds => [
    if (_groupCount == 4) KnockoutRound.quarterfinal,
    KnockoutRound.semifinal,
    KnockoutRound.thirdPlace,
    KnockoutRound.finalRound,
  ];

  ScoreFormat _roundFormat(KnockoutRound r) => _roundFormats[r] ?? _format.forKnockout;

  bool get _fixedSparing => widget.clubs != null && _mode == PartnerMode.fixed;

  int _clubCount(Club c) => widget.players.where((p) => p.clubId == c.id).length;

  /// Teks tombol Fixed sparing (K10, jadwalnya pasti jadi tanpa "±"): angka dari generator, di sini hanya dirangkai.
  /// Lewat booking → hanya round + kelebihannya; court aktif < court dipesan → tambah "· n court".
  String? _sparingMeta() {
    final clubs = widget.clubs!;
    final e = SparingFixedGenerator.estimate(
      players1: _clubCount(clubs[0]),
      players2: _clubCount(clubs[1]),
      bookingMinutes: [for (final c in _courts) c.hours * 60],
      matchDurationMinutes: _duration!,
    );
    if (e.rounds == 0) return null;
    if (e.overMinutes > 0) return '· ${e.rounds} round · lewat booking ${countdownText(e.overMinutes)}';
    final court = e.activeCourts < _courts.length ? ' · ${e.activeCourts} court' : '';
    return '· ${e.rounds} round · ${e.matches} match$court';
  }

  /// Teks tombol Mixed sparing (13i, 13j): angka dari `sparingEstimate`, di sini hanya dirangkai. Court aktif < court
  /// dipesan → tambah "· n court".
  String _mixedSparingMeta(int rounds) {
    final clubs = widget.clubs!;
    final e = EndlessRoundGenerator.sparingEstimate(
      maxRounds: rounds,
      courts: _courts.length,
      club1: _clubCount(clubs[0]),
      club2: _clubCount(clubs[1]),
    );
    final court = e.activeCourts < _courts.length ? ' · ${e.activeCourts} court' : '';
    return '· ±${e.rounds} round$court';
  }

  /// Mexicano hanya Americano (AC-M1): format berubah saat kartu dipilih dan tidak kembali ketika pindah mode lagi.
  void _pickMode(PartnerMode m) => setState(() {
    _mode = m;
    if (m == PartnerMode.mexicano) _format = _format.forMexicano;
  });

  /// Tombol Grup + Gugur (19b, 19i, 19k): jadwalnya pasti, jadi tanpa "±"; lewat booking → round + kelebihan saja.
  String? _knockoutMeta() {
    final e = GroupStage.estimate(
      players: widget.players.length,
      groups: _groupCount,
      bookingMinutes: [for (final c in _courts) c.hours * 60],
      matchDurationMinutes: _duration!,
      thirdPlace: _thirdPlace,
    );
    return ConfigSummary.groupKnockoutMeta(e.rounds, e.matches, e.overMinutes);
  }

  void _next() {
    final config = _config;
    context.push(config.mode.isEndless ? '/schedule' : '/pair-setup', extra: config);
  }

  /// Garis bawah app bar begitu isi tergulir ke bawahnya.
  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0) {
      final scrolled = n.metrics.pixels > 0;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    }
    return false;
  }

  /// Fixed sparing tetap bisa lanjut walau lewat booking (K10): jadwalnya dibuat utuh, host mengakhirinya sendiri.
  bool get _tooLong => _duration != null && _config.maxRounds == 0 && !_fixedSparing;

  /// Catatan di bawah grup Skor, di layar dan di sheet Skor/Court (03f, 03l–03n, 03p): satu sumber.
  Widget? _scoreNote({bool withDraw = true}) {
    if (_duration == null) return const MabarGroupNote('Isi durasi match', error: true);
    if (_tooLong) {
      // Court penyebab "tidak muat" = booking terpendek.
      final shortest = _courts.indexed.reduce((a, b) => b.$2.hours < a.$2.hours ? b : a);
      return MabarGroupNote(
        'Lebih lama dari booking ${shortest.$2.label(shortest.$1)} (${shortest.$2.hours} jam)',
        error: true,
      );
    }
    if (withDraw && _format.method == ScoringMethod.bestOf && _format.canDraw) return const MabarGroupNote('Bisa berakhir seri');
    return null;
  }

  /// Isi sheet Skor (03d): segmented, angka format, durasi. Grup berlatar paper di dalam sheet.
  Widget _scoreGroup(BuildContext sheetContext) {
    final method = _format.method;
    final counts = GroupStage.groupCountsFor(_pairs);
    return MabarGroup(
      color: MabarColors.paper,
      children: [
        // Sheet Fase grup (19d): 2 atau 4 grup; hanya 2 grup → tanpa pilihan, jumlahnya jadi subjudul sheet (19c).
        if (_knockoutOn && counts.length > 1)
          MabarRow.stack(
            children: [
              MabarSegmented<int>(
                options: [for (final n in counts) (n, '$n grup')],
                selected: _groupCount,
                onChanged: (n) => _change(() => _groupCount = n),
              ),
            ],
          ),
        // Mexicano hanya Americano: tanpa segmented, formatnya tertulis sebagai subjudul (03e).
        if (_mode != PartnerMode.mexicano)
          MabarRow.stack(
            children: [
              MabarSegmented<ScoringMethod>(
                options: [for (final m in ScoringMethodX.selectable) (m, m.label)],
                selected: method,
                onChanged: (m) => _change(() => _format = ScoreFormat(m, m.defaultTarget)),
              ),
            ],
          ),
        MabarRow(
          title: _targetTitle(method),
          trailing: MabarStepper(
            value: _format.target,
            min: method.minTarget,
            max: method.maxTarget,
            // Americano tanpa satuan: "21" sudah jelas poin.
            unit: method == ScoringMethod.americano ? null : method.unit,
            onChanged: (n) => _change(() => _format = ScoreFormat(method, n)),
          ),
        ),
        MabarRow(
          title: 'Durasi match',
          trailing: MabarStepper(
            value: _duration,
            min: TournamentConfig.durationStep,
            max: _maxDuration,
            step: TournamentConfig.durationStep,
            unit: 'mnt',
            error: _tooLong,
            normalizeTyped: TournamentConfig.roundDuration,
            onCleared: () => _change(() => _duration = null),
            onChanged: (n) => _change(() => _duration = n),
          ),
        ),
      ],
    );
  }

  static String _targetTitle(ScoringMethod method) => switch (method) {
    ScoringMethod.raceTo => 'Target game',
    ScoringMethod.bestOf => 'Game per match',
    ScoringMethod.americano => 'Poin per match',
  };

  /// Isi sheet Gugur (19e, 19j): satu baris per babak urut main; ketuk → sheet babak.
  Widget _knockoutGroup(BuildContext sheetContext) => MabarGroup(
    color: MabarColors.paper,
    children: [
      for (final r in _knockoutRounds)
        MabarRow(
          key: ValueKey(r),
          title: r.label,
          value: r == KnockoutRound.thirdPlace && !_thirdPlace ? 'Tidak ada' : _roundFormat(r).label,
          chevron: true,
          onTap: () => _openSheet(r.label, (c) => _roundGroup(r), over: sheetContext, showNote: false),
        ),
    ],
  );

  /// Isi sheet babak (19f–19h): tanpa durasi; Best of / Americano melangkah 2 supaya tetap ganjil (G10, GU9). Juara 3
  /// punya Ada / Tidak ada di atas; Tidak ada menyembunyikan formatnya, bukan menghapusnya (19g).
  Widget _roundGroup(KnockoutRound round) {
    final format = _roundFormat(round);
    final method = format.method;
    final odd = method != ScoringMethod.raceTo;
    return MabarGroup(
      color: MabarColors.paper,
      children: [
        if (round == KnockoutRound.thirdPlace)
          MabarRow.stack(
            children: [
              MabarSegmented<bool>(
                options: const [(true, 'Ada'), (false, 'Tidak ada')],
                selected: _thirdPlace,
                onChanged: (on) => _change(() => _thirdPlace = on),
              ),
            ],
          ),
        if (round != KnockoutRound.thirdPlace || _thirdPlace) ...[
          MabarRow.stack(
            children: [
              MabarSegmented<ScoringMethod>(
                options: [for (final m in ScoringMethodX.selectable) (m, m.label)],
                selected: method,
                onChanged: (m) => _change(() => _roundFormats[round] = ScoreFormat(m, m.defaultTarget)),
              ),
            ],
          ),
          MabarRow(
            title: _targetTitle(method),
            trailing: MabarStepper(
              value: format.target,
              // Americano 2 tidak ganjil: batas bawahnya 3.
              min: odd && method.minTarget.isEven ? method.minTarget + 1 : method.minTarget,
              max: method.maxTarget,
              step: odd ? 2 : 1,
              unit: method == ScoringMethod.americano ? null : method.unit,
              normalizeTyped: odd ? (n) => n.isEven ? n + 1 : n : null,
              onChanged: (n) => _change(() => _roundFormats[round] = ScoreFormat(method, n)),
            ),
          ),
        ],
      ],
    );
  }

  /// Isi sheet Court (03g, 03i, 03j): jumlah, lalu satu baris per court.
  Widget _courtGroup(BuildContext sheetContext) {
    final duration = _duration ?? 0;
    return MabarGroup(
      color: MabarColors.paper,
      children: [
        MabarRow(
          title: 'Jumlah court',
          trailing: MabarStepper(
            value: _courts.length,
            min: _minCourts,
            max: TournamentConfig.maxCourts,
            onChanged: _setCourtCount,
          ),
        ),
        for (final (i, court) in _courts.indexed)
          MabarRow(
            key: ValueKey(court.id),
            leading: CourtSwatch(
              color: MabarColors.courtPalette[court.colorIndex],
              number: i + 1,
              onTap: () => _pickColor(sheetContext, i),
            ),
            titleWidget: MabarField.inline(
              controller: court.name,
              hint: 'Court ${i + 1}',
              textCapitalization: TextCapitalization.words,
              // Nama dipakai judul sheet warna; tidak mengubah estimasi.
              onChanged: (_) => _change(() {}),
            ),
            trailing: MabarStepper(
              value: court.hours,
              min: 1,
              max: _maxBookingHours,
              unit: 'jam',
              error: _duration != null && court.hours * 60 < duration,
              onChanged: (h) => _change(() => court.hours = h),
            ),
          ),
      ],
    );
  }

  /// Sheet jenis kelola: tanpa footer, isi dibangun ulang tiap [_change].
  /// [over] = sheet di bawahnya (19f–19h ditumpuk di atas Gugur, seperti sheet warna 03k).
  void _openSheet(
    String title,
    Widget Function(BuildContext) group, {
    bool withDraw = true,
    String? subtitle,
    BuildContext? over,
    bool showNote = true,
  }) {
    showMabarSheet<void>(
      over ?? context,
      title: title,
      subtitle: subtitle,
      builder: (sheetContext) => ValueListenableBuilder<int>(
        valueListenable: _tick,
        builder: (context, _, _) =>
            MabarSection(note: showNote ? _scoreNote(withDraw: withDraw) : null, child: group(sheetContext)),
      ),
    );
  }

  /// Baris ringkasan yang membuka sheet: nilai di judul, chevron di kanan.
  Widget _summaryRow(Widget text, VoidCallback onTap) =>
      MabarGroup(children: [MabarRow(titleWidget: text, chevron: true, onTap: onTap)]);

  @override
  Widget build(BuildContext context) {
    final rounds = _config.maxRounds;
    final tooLong = _tooLong;
    final knockoutMeta = _knockoutOn && _duration != null && !tooLong ? _knockoutMeta() : null;
    final sparingMeta = _fixedSparing && _duration != null ? _sparingMeta() : null;
    final endless = _mode.isEndless;
    final (scoreFormat, scoreDuration) = ConfigSummary.scoreParts(_format, _duration);
    final groupFormat = ConfigSummary.groupPhaseParts(_groupCount, _format, _duration).$1;
    final bodyStyle = MabarType.body.copyWith(color: MabarColors.ink);

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: 'Atur turnamen',
            subtitle: widget.clubs == null
                ? '${widget.sport.label} · ${widget.players.length} pemain'
                : '${widget.sport.label} · ${[for (final c in widget.clubs!) '${c.name} ${_clubCount(c)}'].join(' · ')}',
            onBack: () => context.pop(),
            scrolled: _scrolled,
          ),
          Expanded(
            child: NotificationListener<ScrollNotification>(
              onNotification: _onScroll,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    // Tanpa label grup: isinya sudah menjelaskan diri, seperti nama court.
                    MabarField(
                      controller: _name,
                      hint: 'Nama turnamen',
                      textCapitalization: TextCapitalization.words,
                      textInputAction: TextInputAction.done,
                      inputFormatters: [LengthLimitingTextInputFormatter(TournamentConfig.maxNameLength)],
                    ),
                    const SizedBox(height: 12),
                    MabarSection(
                      bodyGap: 12,
                      header: const MabarGroupLabel('Pasangan'),
                      child: ModePicker(
                        selected: _mode,
                        onChanged: _pickMode,
                        // Sparing hanya dua kartu (keputusan 27, 13h–13j).
                        modes: widget.clubs == null
                            ? const [PartnerMode.fixed, PartnerMode.mixed, PartnerMode.mexicano]
                            : const [PartnerMode.fixed, PartnerMode.mixed],
                        slots: widget.clubs == null ? 3 : 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    // 19a: tepat di bawah kartu mode, tanpa label.
                    if (_mode == PartnerMode.fixed && _knockoutOffered) ...[
                      MabarSegmented<bool>(
                        options: const [(false, 'Round-robin'), (true, 'Grup + Gugur')],
                        selected: _knockout,
                        onChanged: (on) => _change(() => _knockout = on),
                      ),
                      const SizedBox(height: 12),
                    ],
                    MabarSection(
                      bodyGap: 12,
                      header: MabarGroupLabel(_knockoutOn ? 'Fase grup' : 'Skor'),
                      note: _scoreNote(),
                      child: _summaryRow(
                        Text.rich(
                          TextSpan(
                            style: bodyStyle,
                            children: [
                              TextSpan(text: '${_knockoutOn ? groupFormat : scoreFormat} · '),
                              TextSpan(
                                text: scoreDuration,
                                style: tooLong || _duration == null ? const TextStyle(color: MabarColors.clay) : null,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        // Mexicano: formatnya tertulis sebagai subjudul fakta (03e); segmented tidak ada.
                        () => _openSheet(
                          _knockoutOn ? 'Fase grup' : 'Skor',
                          _scoreGroup,
                          subtitle: _knockoutOn
                              ? (GroupStage.groupCountsFor(_pairs).length > 1 ? null : '$_groupCount grup')
                              : _mode == PartnerMode.mexicano
                              ? _format.method.label
                              : null,
                        ),
                      ),
                    ),
                    if (_knockoutOn) ...[
                      const SizedBox(height: 12),
                      MabarSection(
                        bodyGap: 12,
                        header: const MabarGroupLabel('Gugur'),
                        child: _summaryRow(
                          Text(
                            ConfigSummary.knockout({
                              for (final r in _knockoutRounds) r: _roundFormat(r),
                            }, thirdPlace: _thirdPlace),
                            style: bodyStyle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          () => _openSheet('Gugur', _knockoutGroup, showNote: false),
                        ),
                      ),
                    ],
                    const SizedBox(height: 12),
                    MabarSection(
                      bodyGap: 12,
                      header: const MabarGroupLabel('Court'),
                      child: _summaryRow(
                        Text(
                          ConfigSummary.courts([for (final c in _courts) c.hours * 60]),
                          style: bodyStyle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        () => _openSheet('Court', _courtGroup, withDraw: false),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          MabarActionBar(
            children: [
              Expanded(
                child: MabarButton(
                  label: endless ? 'Mulai Round 1' : 'Lanjut',
                  meta: _duration == null
                      ? null
                      : _fixedSparing
                      ? sparingMeta
                      : _knockoutOn
                      ? knockoutMeta
                      : tooLong
                      ? null
                      : (endless
                            ? (widget.clubs != null ? _mixedSparingMeta(rounds) : '· ±$rounds round')
                            : '· ±$rounds round · ${rounds * _courts.length} match'),
                  onPressed: _duration == null || tooLong || (_fixedSparing && sparingMeta == null) ? null : _next,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// State satu baris court selama masih di form.
class _CourtDraft {
  final String id;
  final TextEditingController name = TextEditingController();
  int colorIndex;
  int hours;

  _CourtDraft({required this.id, required this.colorIndex, required this.hours});

  void dispose() => name.dispose();

  /// Nama kosong jadi "Court n".
  String label(int index) {
    final custom = name.text.trim();
    return custom.isEmpty ? 'Court ${index + 1}' : custom;
  }

  Court toCourt(int index) =>
      Court(id: id, name: label(index), colorIndex: colorIndex, bookingDurationMinutes: hours * 60);
}
