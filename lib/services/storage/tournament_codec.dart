import 'dart:convert';

import '../../core/app_version.dart';
import '../../models/models.dart';

/// Serialisasi [ActiveTournament] ke JSON dan kembali. Dipisah dari Hive supaya
/// bisa dites tanpa plugin, dan supaya format simpanan tidak terikat ke
/// TypeAdapter yang butuh codegen + nomor typeId.
class TournamentCodec {
  /// Dinaikkan kalau bentuk JSON berubah tidak kompatibel. Payload dengan versi
  /// lain dibuang, bukan dipaksa dibaca — turnamen lama hilang lebih baik
  /// daripada app gagal start. Skema 2 = app v2: simpanan app lama (skema 1, skor
  /// per set) sengaja tidak dimuat — keputusan host 2026-10-22.
  static const schemaVersion = 2;

  static String encode(ActiveTournament active) => jsonEncode({
    'schema': schemaVersion,
    // Versi app yang menulis data ini, untuk mengenali simpanan saat format berubah lagi.
    'appVersion': appVersion,
    'tournament': _tournament(active.tournament),
    // Kunci JSON wajib String, jadi nomor round di-stringify.
    'bye': {for (final e in active.byePairIdByRound.entries) '${e.key}': e.value},
    'resting': {for (final e in active.restingPlayerIdsByRound.entries) '${e.key}': e.value},
    'withdrawn': active.withdrawnPlayerIds.toList(),
    'extraPutaran': active.extraPutaran,
  });

  /// Mengembalikan null kalau payload kosong, rusak, dari skema lain, atau tanpa versi app.
  static ActiveTournament? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schema'] != schemaVersion || json['appVersion'] is! String) return null;
      return ActiveTournament(
        tournament: _readTournament(json['tournament'] as Map<String, dynamic>),
        byePairIdByRound: {
          for (final e in (json['bye'] as Map<String, dynamic>).entries) int.parse(e.key): e.value as String,
        },
        restingPlayerIdsByRound: {
          for (final e in (json['resting'] as Map<String, dynamic>).entries)
            int.parse(e.key): [for (final id in e.value as List) id as String],
        },
        // Kunci ini baru ada belakangan; payload lama tanpanya tetap sah (belum
        // ada yang keluar), jadi schema tidak dinaikkan. Kunci `credits` (kredit
        // pemain telat sampai 2.6) sengaja diabaikan: pemain yang tertinggal
        // sekarang menyusul lewat urutan prioritas, bukan disejajarkan.
        withdrawnPlayerIds: {for (final id in (json['withdrawn'] as List?) ?? const []) id as String},
        // Baru di 3.1.0 (round tambahan Fixed); simpanan lama belum punya putaran tambahan.
        extraPutaran: (json['extraPutaran'] as int?) ?? 0,
      );
    } catch (_) {
      // Payload rusak (mis. app di-kill di tengah tulis) tidak boleh membuat
      // app gagal dibuka — turnamennya saja yang hilang.
      return null;
    }
  }

  // --- encode -------------------------------------------------------------

  static Map<String, dynamic> _tournament(Tournament t) => {
    'id': t.id,
    'createdAt': t.createdAt.toIso8601String(),
    'isFinished': t.isFinished,
    'config': _config(t.config),
    'matches': [for (final m in t.matches) _match(m)],
  };

  static Map<String, dynamic> _config(TournamentConfig c) => {
    'sport': c.sport.name,
    'mode': c.mode.name,
    'matchDurationMinutes': c.matchDurationMinutes,
    'scoring': c.format.method.name,
    'target': c.format.target,
    // Opsional: turnamen tanpa nama (dan simpanan sebelum 2.3) tidak punya kunci ini.
    if (c.name != null) 'name': c.name,
    'courts': [
      for (final court in c.courts)
        {
          'id': court.id,
          'name': court.name,
          'colorIndex': court.colorIndex,
          'bookingDurationMinutes': court.bookingDurationMinutes,
          // Opsional: court dari Konfigurasi mulai bersama turnamen (0); simpanan 2.1 tetap terbaca.
          if (court.startMinute != 0) 'startMinute': court.startMinute,
        },
    ],
    'players': [
      for (final p in c.players) {'id': p.id, 'name': p.name},
    ],
    'fixedPairs': c.fixedPairs == null ? null : [for (final pair in c.fixedPairs!) _pair(pair)],
  };

  static Map<String, dynamic> _pair(Pair p) => {'id': p.id, 'player1Id': p.player1Id, 'player2Id': p.player2Id};

  static Map<String, dynamic> _match(MatchGame m) => {
    'id': m.id,
    'roundNumber': m.roundNumber,
    'matchNumberInRound': m.matchNumberInRound,
    'courtId': m.courtId,
    'pair1': _pair(m.pair1),
    'pair2': _pair(m.pair2),
    'sets': [
      for (final s in m.sets) {'side1': s.side1, 'side2': s.side2},
    ],
    'status': m.status.name,
    'woLoserPairId': m.woLoserPairId,
    'woReason': m.woReason?.name,
  };

  // --- decode -------------------------------------------------------------

  static Tournament _readTournament(Map<String, dynamic> j) => Tournament(
    id: j['id'] as String,
    createdAt: DateTime.parse(j['createdAt'] as String),
    isFinished: j['isFinished'] as bool,
    config: _readConfig(j['config'] as Map<String, dynamic>),
    matches: [for (final m in j['matches'] as List) _readMatch(m as Map<String, dynamic>)],
  );

  static TournamentConfig _readConfig(Map<String, dynamic> j) => TournamentConfig(
    sport: SportType.values.byName(j['sport'] as String),
    mode: PartnerMode.values.byName(j['mode'] as String),
    matchDurationMinutes: j['matchDurationMinutes'] as int,
    format: _readFormat(j),
    name: j['name'] as String?,
    courts: [
      for (final c in j['courts'] as List)
        Court(
          id: c['id'] as String,
          name: c['name'] as String,
          colorIndex: c['colorIndex'] as int,
          bookingDurationMinutes: c['bookingDurationMinutes'] as int,
          startMinute: c['startMinute'] as int? ?? 0,
        ),
    ],
    players: [for (final p in j['players'] as List) Player(id: p['id'] as String, name: p['name'] as String)],
    fixedPairs: j['fixedPairs'] == null
        ? null
        : [for (final p in j['fixedPairs'] as List) _readPair(p as Map<String, dynamic>)],
  );

  static ScoreFormat _readFormat(Map<String, dynamic> j) =>
      ScoreFormat(ScoringMethod.values.byName(j['scoring'] as String), j['target'] as int);

  static Pair _readPair(Map<String, dynamic> j) =>
      Pair(id: j['id'] as String, player1Id: j['player1Id'] as String, player2Id: j['player2Id'] as String);

  static MatchGame _readMatch(Map<String, dynamic> j) => MatchGame(
    id: j['id'] as String,
    roundNumber: j['roundNumber'] as int,
    matchNumberInRound: j['matchNumberInRound'] as int,
    courtId: j['courtId'] as String,
    pair1: _readPair(j['pair1'] as Map<String, dynamic>),
    pair2: _readPair(j['pair2'] as Map<String, dynamic>),
    sets: [for (final s in j['sets'] as List) SetScore(side1: s['side1'] as int, side2: s['side2'] as int)],
    status: MatchStatus.values.byName(j['status'] as String),
    woLoserPairId: j['woLoserPairId'] as String?,
    woReason: j['woReason'] == null ? null : WoReason.values.byName(j['woReason'] as String),
  );
}
