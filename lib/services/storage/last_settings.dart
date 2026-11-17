import 'dart:convert';

import '../../models/models.dart';

/// Satu court di [LastSettings]. Nama null = "Court n" bawaan; id tidak disimpan (court baru dapat id baru tiap
/// turnamen).
class LastCourt {
  final String? name;
  final int colorIndex;
  final int bookingMinutes;

  const LastCourt({this.name, required this.colorIndex, required this.bookingMinutes});

  @override
  bool operator ==(Object other) =>
      other is LastCourt &&
      other.name == name &&
      other.colorIndex == colorIndex &&
      other.bookingMinutes == bookingMinutes;

  @override
  int get hashCode => Object.hash(name, colorIndex, bookingMinutes);
}

/// Pengaturan turnamen terakhir yang dimulai di HP ini, satu per olahraga (logic.md §14.5, keputusan 36). Tidak ikut:
/// nama turnamen, pemain, klub, pasangan. Dart murni; hanya dibaca layar Konfigurasi dan ditulis `startIfNeeded`.
class LastSettings {
  static const _version = 1;
  static const _maxColor = 9;
  static const _minBooking = 60;
  static const _maxBooking = 720;
  static const _maxDuration = 180;
  static const _maxJsonLength = 16 * 1024;

  final PartnerMode mode;
  final ScoreFormat format;
  final int matchDurationMinutes;
  final List<LastCourt> courts;

  /// Grup + Gugur terakhir (19i): jumlah grup, format tiap babak, juara 3; `groups` selalu kosong (anggota grup tidak
  /// ikut pengaturan). Null = round-robin. Konfigurasi yang menurunkannya saat dibaca (4 grup di bawah 24 pemain → 2).
  final GroupKnockout? groupKnockout;

  const LastSettings({
    required this.mode,
    required this.format,
    required this.matchDurationMinutes,
    required this.courts,
    this.groupKnockout,
  });

  /// Nama court sama dengan label bawaan "Court n" → null (nama bawaan ditulis ke config saat kosong, jadi yang
  /// dibandingkan label bawaan, bukan string kosong).
  factory LastSettings.fromConfig(TournamentConfig config) => LastSettings(
    mode: config.mode,
    format: config.format,
    matchDurationMinutes: config.matchDurationMinutes,
    courts: [
      for (final (i, c) in config.courts.indexed)
        LastCourt(
          name: c.name.trim().isEmpty || c.name == 'Court ${i + 1}' ? null : c.name,
          colorIndex: c.colorIndex,
          bookingMinutes: c.bookingDurationMinutes,
        ),
    ],
    groupKnockout: config.groupKnockout == null
        ? null
        : GroupKnockout(
            groupCount: config.groupKnockout!.groupCount,
            formats: config.groupKnockout!.formats,
            thirdPlace: config.groupKnockout!.thirdPlace,
          ),
  );

  /// Konfigurasi Sparing: Mexicano tidak ditawarkan (keputusan 27), jadi jatuh ke Mixed dengan format dan court yang
  /// sama; Grup + Gugur juga tidak (GU14) dan dibuang; mode lain tetap.
  LastSettings forSparing() => mode == PartnerMode.mexicano || groupKnockout != null
      ? LastSettings(
          mode: mode == PartnerMode.mexicano ? PartnerMode.mixed : mode,
          format: format,
          matchDurationMinutes: matchDurationMinutes,
          courts: courts,
        )
      : this;

  String toJson() => jsonEncode({
    'v': _version,
    'mode': mode.name,
    'scoring': format.method.name,
    'target': format.target,
    'duration': matchDurationMinutes,
    'courts': [
      for (final c in courts) {'name': c.name, 'colorIndex': c.colorIndex, 'bookingMinutes': c.bookingMinutes},
    ],
    // Kunci opsional, v tetap 1 (docs/data.md): round-robin ter-encode byte-sama dengan 3.7.x.
    if (groupKnockout != null) 'groupKnockout': _knockoutJson(groupKnockout!),
  });

  // Urutan PF, SF, J3, F; J3 selalu ditulis walau juara 3 mati, supaya "Ada" lagi memulihkan formatnya (19g).
  static const _roundKeys = {
    KnockoutRound.quarterfinal: 'PF',
    KnockoutRound.semifinal: 'SF',
    KnockoutRound.thirdPlace: 'J3',
    KnockoutRound.finalRound: 'F',
  };

  static Map<String, Object> _knockoutJson(GroupKnockout g) => {
    'groupCount': g.groupCount,
    'thirdPlace': g.thirdPlace,
    'formats': {
      for (final r in KnockoutRound.values)
        if (g.formats[r] != null)
          _roundKeys[r]!: {'scoring': g.formats[r]!.method.name, 'target': g.formats[r]!.target},
    },
  };

  /// Aturan baca docs/data.md → Grup + Gugur: mode fixed, 2 atau 4 grup, `formats` persis {SF, J3, F} (+ PF iff 4 grup)
  /// dan tiap format sah untuk gugur. Pelanggaran = null, dan `read` membuang seluruh entri.
  static GroupKnockout? _readKnockout(Object? raw, PartnerMode mode) {
    if (raw is! Map || mode != PartnerMode.fixed) throw const FormatException('groupKnockout');
    final count = raw['groupCount'], third = raw['thirdPlace'], formats = raw['formats'];
    if (count is! int || (count != 2 && count != 4) || third is! bool || formats is! Map) {
      throw const FormatException('groupKnockout');
    }
    final wanted = {
      for (final r in KnockoutRound.values)
        if (r != KnockoutRound.quarterfinal || count == 4) _roundKeys[r]!: r,
    };
    if (formats.length != wanted.length || !formats.keys.every(wanted.containsKey)) {
      throw const FormatException('groupKnockout.formats');
    }
    final result = <KnockoutRound, ScoreFormat>{};
    for (final MapEntry(key: key, value: round) in wanted.entries) {
      final f = formats[key];
      if (f is! Map) throw const FormatException('groupKnockout.format');
      final format = ScoreFormat(ScoringMethod.values.byName(f['scoring'] as String), f['target'] as int);
      if (!format.isValidKnockout) throw const FormatException('groupKnockout.format');
      result[round] = format;
    }
    return GroupKnockout(groupCount: count, formats: result, thirdPlace: third);
  }

  /// Null = tidak ada, tak terbaca, atau di luar batas: layar memakai default. Tidak pernah melempar.
  static LastSettings? read(String? raw) {
    // Jaring untuk data rusak/raksasa (docs/data.md).
    if (raw == null || raw.length > _maxJsonLength) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['v'] is! int || j['v'] != _version) return null;
      final mode = PartnerMode.values.byName(j['mode'] as String);
      final format = ScoreFormat(ScoringMethod.values.byName(j['scoring'] as String), j['target'] as int);
      // Mexicano selalu Americano (sama dengan aturan baca turnamen, docs/data.md).
      if (mode == PartnerMode.mexicano && format.method != ScoringMethod.americano) return null;
      final duration = j['duration'] as int;
      final rawCourts = j['courts'] as List;
      if (!format.isValid || duration < TournamentConfig.durationStep || duration > _maxDuration) return null;
      if (duration % TournamentConfig.durationStep != 0) return null;
      if (rawCourts.isEmpty || rawCourts.length > TournamentConfig.maxCourts) return null;
      final courts = <LastCourt>[];
      for (final c in rawCourts) {
        final name = (c as Map)['name'];
        final color = c['colorIndex'] as int;
        final booking = c['bookingMinutes'] as int;
        if (name != null && name is! String) return null;
        if (color < 0 || color > _maxColor) return null;
        if (booking < _minBooking || booking > _maxBooking || booking % 60 != 0) return null;
        // Nama kosong/spasi saja = nama bawaan.
        final custom = (name as String?)?.trim();
        courts.add(
          LastCourt(name: custom == null || custom.isEmpty ? null : name, colorIndex: color, bookingMinutes: booking),
        );
      }
      // Kunci tidak ada = round-robin; ada tapi cacat = seluruh entri tak terbaca (dilempar → catch di bawah).
      final knockout = j.containsKey('groupKnockout') ? _readKnockout(j['groupKnockout'], mode) : null;
      return LastSettings(
        mode: mode,
        format: format,
        matchDurationMinutes: duration,
        courts: courts,
        groupKnockout: knockout,
      );
    } catch (_) {
      return null;
    }
  }
}
