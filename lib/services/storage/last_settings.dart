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

  const LastSettings({
    required this.mode,
    required this.format,
    required this.matchDurationMinutes,
    required this.courts,
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
  );

  /// Konfigurasi Sparing: mode tetap bila Sparing menawarkannya. Mode yang tidak ditawarkan Sparing (Mexicano, bagian
  /// 2) jatuh ke Mixed dengan format dan court yang sama.
  LastSettings forSparing() => this;

  String toJson() => jsonEncode({
    'v': _version,
    'mode': mode.name,
    'scoring': format.method.name,
    'target': format.target,
    'duration': matchDurationMinutes,
    'courts': [
      for (final c in courts) {'name': c.name, 'colorIndex': c.colorIndex, 'bookingMinutes': c.bookingMinutes},
    ],
  });

  /// Null = tidak ada, tak terbaca, atau di luar batas: layar memakai default. Tidak pernah melempar.
  static LastSettings? read(String? raw) {
    // Jaring untuk data rusak/raksasa (docs/data.md).
    if (raw == null || raw.length > _maxJsonLength) return null;
    try {
      final j = jsonDecode(raw);
      if (j is! Map || j['v'] != _version) return null;
      final mode = PartnerMode.values.byName(j['mode'] as String);
      final format = ScoreFormat(ScoringMethod.values.byName(j['scoring'] as String), j['target'] as int);
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
      return LastSettings(mode: mode, format: format, matchDurationMinutes: duration, courts: courts);
    } catch (_) {
      return null;
    }
  }
}
