import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:uuid/uuid.dart';

import '../../core/theme/mabar_theme.dart';
import '../../core/time_text.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../../services/schedule/sparing_fixed_generator.dart';
import 'widgets/config_pickers.dart';

/// Screen 03 · Konfigurasi — disusun seperti halaman pengaturan: nama turnamen, mode, format skor + durasi, court.
/// Estimasi ada di tombol. Fixed → Pasangan; Mixed → langsung Jadwal dan membuat R1.
class KonfigurasiScreen extends StatefulWidget {
  final SportType sport;
  final List<Player> players;

  /// Sparing: dua klub dari layar Pemain (pemainnya sudah membawa `clubId`); null = turnamen biasa. Ikut ke config
  /// apa adanya.
  final List<Club>? clubs;

  const KonfigurasiScreen({super.key, required this.sport, required this.players, this.clubs});

  @override
  State<KonfigurasiScreen> createState() => _KonfigurasiScreenState();
}

class _KonfigurasiScreenState extends State<KonfigurasiScreen> {
  static const _minCourts = 1;
  static const _defaultCourtCount = 2;
  static const _defaultBookingHours = 2;
  static const _maxBookingHours = 12;
  static const _maxDuration = 180;

  PartnerMode _mode = PartnerMode.fixed;
  ScoreFormat _format = ScoreFormat.standard;
  late int _duration = widget.sport.defaultMatchDurationMinutes;
  final List<_CourtDraft> _courts = [];
  final _name = TextEditingController();
  var _scrolled = false;

  @override
  void initState() {
    super.initState();
    for (var i = 0; i < _defaultCourtCount; i++) {
      _courts.add(_createCourt(i));
    }
  }

  @override
  void dispose() {
    _name.dispose();
    for (final c in _courts) {
      c.dispose();
    }
    super.dispose();
  }

  _CourtDraft _createCourt(int index) => _CourtDraft(
    id: const Uuid().v4(),
    colorIndex: index % MabarColors.courtPalette.length,
    hours: _defaultBookingHours,
  );

  void _setCourtCount(int next) {
    setState(() {
      while (_courts.length < next) {
        _courts.add(_createCourt(_courts.length));
      }
      while (_courts.length > next) {
        _courts.removeLast().dispose();
      }
    });
  }

  Future<void> _pickColor(int index) async {
    final court = _courts[index];
    final picked = await showMabarSheet<int>(
      context,
      title: 'Warna ${court.label(index)}',
      builder: (context) => CourtColorGrid(selected: court.colorIndex, onSelect: (i) => Navigator.pop(context, i)),
    );
    if (picked != null && mounted) setState(() => court.colorIndex = picked);
  }

  TournamentConfig get _config => TournamentConfig(
    sport: widget.sport,
    mode: _mode,
    matchDurationMinutes: _duration,
    courts: [for (var i = 0; i < _courts.length; i++) _courts[i].toCourt(i)],
    players: widget.players,
    format: _format,
    name: _name.text.trim().isEmpty ? null : _name.text.trim(),
    clubs: widget.clubs,
  );

  bool get _fixedSparing => widget.clubs != null && _mode == PartnerMode.fixed;

  /// Sementara: generator Mixed sparing (SP-3) dan layar Mixed (SP-18) belum ada, jadi pasangan acak lintas klub bisa
  /// terbentuk dan simpanan ditolak. Dicabut di SP-18 bersama 13i/13j.
  bool get _mixedSparingBlocked => widget.clubs != null && _mode == PartnerMode.mixed;

  int _clubCount(Club c) => widget.players.where((p) => p.clubId == c.id).length;

  /// Teks tombol Fixed sparing (K10, jadwalnya pasti jadi tanpa "±"): angka dari generator, di sini hanya dirangkai.
  /// Lewat booking → hanya round + kelebihannya; court aktif < court dipesan → tambah "· n court".
  String? _sparingMeta() {
    final clubs = widget.clubs!;
    final e = SparingFixedGenerator.estimate(
      players1: _clubCount(clubs[0]),
      players2: _clubCount(clubs[1]),
      bookingMinutes: [for (final c in _courts) c.hours * 60],
      matchDurationMinutes: _duration,
    );
    if (e.rounds == 0) return null;
    if (e.overMinutes > 0) return '· ${e.rounds} round · lewat booking ${countdownText(e.overMinutes)}';
    final court = e.activeCourts < _courts.length ? ' · ${e.activeCourts} court' : '';
    return '· ${e.rounds} round · ${e.matches} match$court';
  }

  void _next() {
    final config = _config;
    context.push(config.mode == PartnerMode.fixed ? '/pair-setup' : '/schedule', extra: config);
  }

  /// Garis bawah app bar begitu isi tergulir ke bawahnya (court banyak).
  bool _onScroll(ScrollNotification n) {
    if (n.depth == 0) {
      final scrolled = n.metrics.pixels > 0;
      if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    final rounds = _config.maxRounds;
    // Court penyebab "tidak muat" = booking terpendek; yang lebih pendek dari durasi ikut ditandai.
    final shortest = _courts.indexed.reduce((a, b) => b.$2.hours < a.$2.hours ? b : a);
    // Fixed sparing tetap bisa lanjut walau lewat booking (K10): jadwalnya dibuat utuh, host mengakhirinya sendiri.
    final tooLong = rounds == 0 && !_fixedSparing;
    final sparingMeta = _fixedSparing ? _sparingMeta() : null;
    final method = _format.method;
    final mixed = _mode == PartnerMode.mixed;
    final scoreNote = tooLong
        ? MabarGroupNote(
            'Lebih lama dari booking ${shortest.$2.label(shortest.$1)} (${shortest.$2.hours} jam)',
            error: true,
          )
        : method == ScoringMethod.bestOf && _format.canDraw
        ? const MabarGroupNote('Bisa berakhir seri')
        : null;

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
                      child: ModePicker(selected: _mode, onChanged: (m) => setState(() => _mode = m)),
                    ),
                    const SizedBox(height: 12),
                    MabarSection(
                      bodyGap: 12,
                      header: const MabarGroupLabel('Skor'),
                      note: scoreNote,
                      child: MabarGroup(
                        children: [
                          MabarRow.stack(
                            children: [
                              MabarSegmented<ScoringMethod>(
                                options: [for (final m in ScoringMethodX.selectable) (m, m.label)],
                                selected: method,
                                onChanged: (m) => setState(() => _format = ScoreFormat(m, m.defaultTarget)),
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
                              onChanged: (n) => setState(() => _format = ScoreFormat(method, n)),
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
                              error: tooLong,
                              normalizeTyped: TournamentConfig.roundDuration,
                              onChanged: (n) => setState(() => _duration = n),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    MabarSection(
                      bodyGap: 12,
                      header: const MabarGroupLabel('Court'),
                      child: MabarGroup(
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
                                onTap: () => _pickColor(i),
                              ),
                              titleWidget: MabarField.inline(
                                controller: court.name,
                                hint: 'Court ${i + 1}',
                                textCapitalization: TextCapitalization.words,
                                // Nama dipakai judul sheet warna; tidak mengubah estimasi.
                                onChanged: (_) => setState(() {}),
                              ),
                              trailing: MabarStepper(
                                value: court.hours,
                                min: 1,
                                max: _maxBookingHours,
                                unit: 'jam',
                                error: court.hours * 60 < _duration,
                                onChanged: (h) => setState(() => court.hours = h),
                              ),
                            ),
                        ],
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
                  meta: _fixedSparing
                      ? sparingMeta
                      : tooLong
                      ? null
                      : (mixed ? '· ±$rounds round' : '· ±$rounds round · ${rounds * _courts.length} match'),
                  onPressed: tooLong || _mixedSparingBlocked || (_fixedSparing && sparingMeta == null) ? null : _next,
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
