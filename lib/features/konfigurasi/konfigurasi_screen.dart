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
      // 03k: judulnya nomor court walau namanya custom ("Court VIP" tetap "Warna Court 2").
      title: 'Warna Court ${index + 1}',
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
  );

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

  void _next() {
    final config = _config;
    context.push(config.mode == PartnerMode.fixed ? '/pair-setup' : '/schedule', extra: config);
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
    return MabarGroup(
      color: MabarColors.paper,
      children: [
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
          title: switch (method) {
            ScoringMethod.raceTo => 'Target game',
            ScoringMethod.bestOf => 'Game per match',
            ScoringMethod.americano => 'Poin per match',
          },
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
  void _openSheet(String title, Widget Function(BuildContext) group, {bool withDraw = true}) {
    showMabarSheet<void>(
      context,
      title: title,
      builder: (sheetContext) => ValueListenableBuilder<int>(
        valueListenable: _tick,
        builder: (context, _, _) => MabarSection(note: _scoreNote(withDraw: withDraw), child: group(sheetContext)),
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
    final sparingMeta = _fixedSparing && _duration != null ? _sparingMeta() : null;
    final mixed = _mode == PartnerMode.mixed;
    final (scoreFormat, scoreDuration) = ConfigSummary.scoreParts(_format, _duration);
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
                        onChanged: (m) => setState(() => _mode = m),
                        // Sparing hanya dua kartu (keputusan 27, 13h–13j); kolom ketiga = Mexicano (bagian 2).
                        slots: widget.clubs == null ? 3 : 2,
                      ),
                    ),
                    const SizedBox(height: 12),
                    MabarSection(
                      bodyGap: 12,
                      header: const MabarGroupLabel('Skor'),
                      note: _scoreNote(),
                      child: _summaryRow(
                        Text.rich(
                          TextSpan(
                            style: bodyStyle,
                            children: [
                              TextSpan(text: '$scoreFormat · '),
                              TextSpan(
                                text: scoreDuration,
                                style: tooLong || _duration == null ? const TextStyle(color: MabarColors.clay) : null,
                              ),
                            ],
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        () => _openSheet('Skor', _scoreGroup),
                      ),
                    ),
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
                  label: mixed ? 'Mulai Round 1' : 'Lanjut',
                  meta: _duration == null
                      ? null
                      : _fixedSparing
                      ? sparingMeta
                      : tooLong
                      ? null
                      : (mixed
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
