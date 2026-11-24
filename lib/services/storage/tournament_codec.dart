import 'dart:convert';

import '../../core/app_version.dart';
import '../../models/models.dart';
import '../schedule/group_stage.dart';
import '../schedule/knockout_bracket.dart';

/// Serialisasi [ActiveTournament] ke JSON dan kembali. Dipisah dari Hive supaya
/// bisa dites tanpa plugin, dan supaya format simpanan tidak terikat ke
/// TypeAdapter yang butuh codegen + nomor typeId.
/// Turnamen yang kalau ditulis tidak bisa dibaca kembali (docs/data.md → Aturan baca). Tipe sendiri supaya StateError
/// lain dari encode (`.first`, …) tidak ikut ditelan penangkapnya.
class UnreadableTournamentError extends StateError {
  UnreadableTournamentError()
    : super('Turnamen melanggar bentuk simpanan (docs/data.md → Aturan baca); decode akan menolaknya.');
}

class TournamentCodec {
  /// Dinaikkan kalau bentuk JSON berubah tidak kompatibel. Payload dengan versi
  /// lain dibuang, bukan dipaksa dibaca — turnamen lama hilang lebih baik
  /// daripada app gagal start. Skema 2 = app v2: simpanan app lama (skema 1, skor
  /// per set) sengaja tidak dimuat — keputusan host 2026-10-22.
  static const schemaVersion = 2;

  /// Penanda sparing di `bye` (docs/data.md → Sparing). Sengaja kunci yang bukan angka: decoder 3.1.0 meng-`int.parse`
  /// tiap kunci `bye`, jadi app lama yang masih ter-cache menolak payload sparing (null) alih-alih membacanya sebagai
  /// turnamen biasa dan menimpa simpanannya tanpa klub. Jangan dihapus.
  static const _sparingKey = 'sparing';

  /// Revisi bentuk sparing; revisi tak kompatibel berikutnya menaikkannya supaya pembaca lama menolak.
  static const _sparingRevision = '1';

  /// Penanda Grup + Gugur di `bye` (GU15, docs/data.md → Grup + Gugur). Kunci non-angka seperti `sparing`: decoder
  /// ≤ 3.7.x meng-`int.parse` tiap kunci `bye`, jadi app lama menolak payload Grup + Gugur alih-alih membacanya sebagai
  /// round-robin biasa (yang mengabaikan `phase`). Jangan dihapus.
  static const _groupKnockoutKey = 'gg';

  /// Revisi bentuk Grup + Gugur; revisi tak kompatibel berikutnya menaikkannya.
  static const _groupKnockoutRevision = '1';

  /// Batas `roundNumber` yang dibaca. Turnamen nyata jauh di bawahnya; payload live dengan nomor raksasa membuat tab
  /// penonton membeku karena banyak turunan mengulang 1..roundCount (docs/security.md #4).
  static const maxRoundNumber = 1000;

  /// Bentuk yang akan diterima decode lagi. Dipakai [encode] (juga di rilis) dan assert auto-save di controller, supaya
  /// bug mutator gagal keras di test walau [TournamentStore] melewati tulisannya.
  static bool canEncode(ActiveTournament active) =>
      active.matches.every((m) => m.roundNumber >= 1 && m.roundNumber <= maxRoundNumber) &&
      _isValidMexicano(active.config) &&
      (!active.config.isSparing || (active.extraPutaran >= 0 && _isValidSparing(active.tournament))) &&
      _isValidGroupKnockout(active);

  /// Mexicano tanpa klub dan hanya Americano (keputusan 27, logic.md §14.6): payload lain tidak bisa ditulis penulis
  /// mana pun, jadi rusak. Mode tidak dikenal sudah ditolak `byName` — jangan diberi fallback (versi lama menolak
  /// Mexicano dengan cara yang sama).
  static bool _isValidMexicano(TournamentConfig config) =>
      config.mode != PartnerMode.mexicano || (config.clubs == null && config.format.method == ScoringMethod.americano);

  /// Melempar [UnreadableTournamentError] kalau bentuknya akan ditolak decode: pemanggil jangan menimpa simpanan/kiriman
  /// sah terakhir dengannya (docs/security.md #1).
  static String encode(ActiveTournament active) {
    if (!canEncode(active)) throw UnreadableTournamentError();
    // Kunci sparing hanya untuk turnamen sparing: encode turnamen biasa harus byte-sama dengan 3.1.0 (AC-S19).
    final sparing = active.config.isSparing;
    final groupKnockout = active.config.isGroupKnockout;
    return jsonEncode({
      'schema': schemaVersion,
      // Versi app yang menulis data ini, untuk mengenali simpanan saat format berubah lagi.
      'appVersion': appVersion,
      'tournament': _tournament(active.tournament),
      // Kunci JSON wajib String, jadi nomor round di-stringify.
      'bye': {
        if (sparing) _sparingKey: _sparingRevision,
        if (groupKnockout) _groupKnockoutKey: _groupKnockoutRevision,
        for (final e in active.byePairIdByRound.entries) '${e.key}': e.value,
      },
      'resting': {for (final e in active.restingPlayerIdsByRound.entries) '${e.key}': e.value},
      if (sparing && active.restingPairIdsByRound.isNotEmpty)
        'restingPairs': {for (final e in active.restingPairIdsByRound.entries) '${e.key}': e.value},
      'withdrawn': active.withdrawnPlayerIds.toList(),
      'extraPutaran': active.extraPutaran,
    });
  }

  /// Mengembalikan null kalau payload kosong, rusak, dari skema lain, atau tanpa versi app.
  static ActiveTournament? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      if (json['schema'] != schemaVersion || json['appVersion'] is! String) return null;
      final tournament = _readTournament(json['tournament'] as Map<String, dynamic>);
      if (tournament.matches.any((m) => m.roundNumber < 1 || m.roundNumber > maxRoundNumber)) return null;
      final config = tournament.config;
      if (!_isValidMexicano(config)) return null;
      // Penanda dibuang sebelum nomor round dibaca; kunci non-angka lain tetap membuat payload rusak.
      final bye = Map<String, dynamic>.of(json['bye'] as Map<String, dynamic>);
      final hasMarker = bye.containsKey(_sparingKey);
      final marker = bye.remove(_sparingKey);
      // GR1/GR2: penanda Grup + Gugur persis "1" dan hanya bersama `config.groupKnockout` (dan sebaliknya).
      final hasGgMarker = bye.containsKey(_groupKnockoutKey);
      final ggMarker = bye.remove(_groupKnockoutKey);
      if (hasGgMarker != config.isGroupKnockout || (hasGgMarker && ggMarker != _groupKnockoutRevision)) return null;
      final restingPairs = json['restingPairs'] as Map<String, dynamic>?;
      final extraPutaran = (json['extraPutaran'] as int?) ?? 0;
      if (config.isSparing) {
        if (marker != _sparingRevision || extraPutaran < 0 || !_isValidSparing(tournament)) return null;
      } else if (hasMarker || restingPairs != null || config.players.any((p) => p.clubId != null)) {
        // Kunci sparing tanpa `clubs` tidak bisa ditulis oleh penulis mana pun: payload rusak.
        return null;
      }
      final active = ActiveTournament(
        tournament: tournament,
        byePairIdByRound: {for (final e in bye.entries) int.parse(e.key): e.value as String},
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
        extraPutaran: extraPutaran,
        // Baru di 3.2.0, hanya Fixed sparing (beberapa pasangan istirahat per round).
        restingPairIdsByRound: {
          for (final e in (restingPairs ?? const <String, dynamic>{}).entries)
            int.parse(e.key): [for (final id in e.value as List) id as String],
        },
      );
      return _isValidGroupKnockout(active) ? active : null;
    } catch (_) {
      // Payload rusak (mis. app di-kill di tengah tulis) tidak boleh membuat
      // app gagal dibuka — turnamennya saja yang hilang.
      return null;
    }
  }

  /// Bentuk sparing yang wajib dijaga saat baca (docs/data.md → Aturan baca): layar sparing menurunkan klub pasangan
  /// dari anggotanya dan menaruh `pair1` di atas tanpa penjagaan sendiri, jadi payload yang melanggar S2/S4 harus
  /// ditolak di sini, bukan membuat widget melempar. Keadaan (id `restingPairs` tak dikenal, jumlah pemain/pasangan per
  /// klub) sengaja tidak diperiksa.
  static bool _isValidSparing(Tournament t) {
    final config = t.config;
    final clubs = config.clubs!;
    if (clubs.length != 2) return false;
    final first = clubs[0], second = clubs[1];
    if (first.id.isEmpty || second.id.isEmpty || first.id == second.id) return false;
    if (first.name.isEmpty || second.name.isEmpty) return false;
    if (config.players.any((p) => config.clubById(p.clubId) == null)) return false;
    // Id pemain dari uuid v4, jadi duplikat hanya ada di payload buatan: tanpa ini pemain yang sama tampil di tabel kedua
    // klub (docs/security.md #2).
    if (config.players.map((p) => p.id).toSet().length != config.players.length) return false;
    if ((config.fixedPairs ?? const <Pair>[]).any((pair) => config.clubOfPair(pair) == null)) return false;
    return t.matches.every(
      (m) => config.clubOfPair(m.pair1)?.id == first.id && config.clubOfPair(m.pair2)?.id == second.id,
    );
  }

  /// Bentuk Grup + Gugur (GR3–GR17, docs/data.md → Aturan baca), dipakai [decode] dan [canEncode]. Turnamen lain: tanpa
  /// `phase` dan tanpa sisi tbd (GR10). Total: tidak melempar untuk model apa pun. Tidak memanggil `resolve`/`formatFor`
  /// (keduanya ber-assert) sebelum bentuknya lolos.
  static bool _isValidGroupKnockout(ActiveTournament active) {
    final config = active.config;
    final matches = active.matches;
    final gk = config.groupKnockout;
    if (gk == null) return matches.every((m) => m.phase == null && !m.pair1.isTbd && !m.pair2.isTbd);

    // GR3
    if (config.mode != PartnerMode.fixed || config.isSparing || active.restingPairIdsByRound.isNotEmpty) return false;
    if (config.players.any((p) => p.clubId != null)) return false;
    // GR17
    if (active.byePairIdByRound.isNotEmpty ||
        active.restingPlayerIdsByRound.isNotEmpty ||
        active.withdrawnPlayerIds.isNotEmpty ||
        active.extraPutaran != 0) {
      return false;
    }
    // GR4, GR5
    final pairs = config.fixedPairs;
    if (pairs == null || pairs.isEmpty) return false;
    final groupCount = gk.groups.length;
    // decodableGroupCounts, bukan groupCountsFor (data lama 2 × 3 / 4 × 3). 3 grup baru sah setelah GP-4 (GR18–GR19).
    if (gk.groupCount != groupCount || groupCount == 3) return false;
    if (!GroupStage.decodableGroupCounts(pairs.length).contains(groupCount)) return false;
    // GR9
    final playerIds = {for (final p in config.players) p.id};
    if (playerIds.length != config.players.length) return false;
    final memberIds = [for (final p in pairs) ...p.playerIds];
    if (memberIds.toSet().length != memberIds.length || !memberIds.every(playerIds.contains)) return false;
    // GR6
    final byId = {for (final p in pairs) p.id: p};
    if (byId.length != pairs.length || byId.containsKey('')) return false;
    final flat = [for (final g in gk.groups) ...g];
    final coversOnce = flat.length == pairs.length && flat.toSet().length == flat.length;
    if (!coversOnce || !flat.every(byId.containsKey)) return false;
    // GR7
    final sizes = GroupStage.sizes(pairs.length, groupCount);
    for (var g = 0; g < groupCount; g++) {
      if (gk.groups[g].length != sizes[g]) return false;
    }
    // GR8
    final wanted = {
      KnockoutRound.semifinal,
      KnockoutRound.thirdPlace,
      KnockoutRound.finalRound,
      if (groupCount == 4) KnockoutRound.quarterfinal,
    };
    if (gk.formats.length != wanted.length || !wanted.every(gk.formats.containsKey)) return false;
    if (gk.formats.values.any((f) => !f.isValidKnockout)) return false;

    bool same(Pair a, Pair b) => a.id == b.id && a.player1Id == b.player1Id && a.player2Id == b.player2Id;
    bool isFixed(Pair p) => !p.isTbd && byId[p.id] != null && same(p, byId[p.id]!);

    // GR10, GR11
    final met = <int, Set<String>>{};
    final knockout = <KnockoutPhase, MatchGame>{};
    var lastGroupRound = 0;
    for (final m in matches) {
      switch (m.phase) {
        case null:
          return false;
        case GroupPhase(:final group):
          if (group < 0 || group >= groupCount) return false;
          if (!isFixed(m.pair1) || !isFixed(m.pair2) || m.pair1.id == m.pair2.id) return false;
          final members = gk.groups[group];
          if (!members.contains(m.pair1.id) || !members.contains(m.pair2.id)) return false;
          final key = ([m.pair1.id, m.pair2.id]..sort()).join('\u0000');
          if (!(met[group] ??= {}).add(key)) return false;
          if (m.roundNumber > lastGroupRound) lastGroupRound = m.roundNumber;
        case final KnockoutPhase p:
          if (p.round == KnockoutRound.quarterfinal && groupCount != 4) return false;
          // GR12: kode ganda
          if (knockout.containsKey(p)) return false;
          knockout[p] = m;
      }
    }
    // GR12
    final expected = KnockoutBracket.phases(groupCount: groupCount, thirdPlace: gk.thirdPlace);
    if (knockout.isNotEmpty && (knockout.length != expected.length || !expected.every(knockout.containsKey))) {
      return false;
    }
    for (final MapEntry(key: phase, value: m) in knockout.entries) {
      // GR13
      if (m.roundNumber <= lastGroupRound) return false;
      final (s1, s2) = KnockoutBracket.sources(phase, groupCount: groupCount);
      for (final s in [s1, s2]) {
        if (s is ResultSource && m.roundNumber <= knockout[s.match]!.roundNumber) return false;
      }
      // GR14
      if (s1 is SeedSource && (m.pair1.isTbd || m.pair2.isTbd)) return false;
      for (final (s, side) in [(s1, m.pair1), (s2, m.pair2)]) {
        if (!side.isTbd && !isFixed(side)) return false;
        if (s is SeedSource && !gk.groups[s.group].contains(side.id)) return false;
      }
      // GR15 (sisi tbd hanya di match tanpa hasil), GR16
      final hasResult = m.status == MatchStatus.done || m.status == MatchStatus.wo;
      if (hasResult && (m.pair1.isTbd || m.pair2.isTbd || m.winnerPairId == null)) return false;
    }
    for (var g = 0; g < groupCount; g++) {
      final slot1 = _seedPair(knockout, groupCount, g, 1), slot2 = _seedPair(knockout, groupCount, g, 2);
      if (slot1 != null && slot1 == slot2) return false;
    }
    return KnockoutBracket.isResolved(config, matches);
  }

  /// Id pasangan di slot lolos [slot] grup [group] dari match babak pertama; null kalau belum ada.
  static String? _seedPair(Map<KnockoutPhase, MatchGame> knockout, int groupCount, int group, int slot) {
    for (final MapEntry(key: phase, value: m) in knockout.entries) {
      final (s1, s2) = KnockoutBracket.sources(phase, groupCount: groupCount);
      if (s1 is SeedSource && s1.group == group && s1.slot == slot) return m.pair1.id;
      if (s2 is SeedSource && s2.group == group && s2.slot == slot) return m.pair2.id;
    }
    return null;
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
    // Sparing (3.2.0): turnamen biasa tidak punya kunci ini.
    if (c.clubs != null)
      'clubs': [
        for (final club in c.clubs!) {'id': club.id, 'name': club.name},
      ],
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
      for (final p in c.players) {'id': p.id, 'name': p.name, if (c.isSparing && p.clubId != null) 'club': p.clubId},
    ],
    'fixedPairs': c.fixedPairs == null ? null : [for (final pair in c.fixedPairs!) _pair(pair)],
    // Grup + Gugur (3.8.0): turnamen lain tidak punya kunci ini. `groupCount` = groups.length, tidak ditulis.
    if (c.groupKnockout != null) 'groupKnockout': _groupKnockout(c.groupKnockout!),
  };

  static const _formatKeys = {
    KnockoutRound.quarterfinal: 'PF',
    KnockoutRound.semifinal: 'SF',
    KnockoutRound.thirdPlace: 'J3',
    KnockoutRound.finalRound: 'F',
  };

  static Map<String, dynamic> _groupKnockout(GroupKnockout gk) => {
    'groups': [for (final g in gk.groups) g],
    // Urutan enum KnockoutRound (PF, SF, J3, F).
    'formats': {
      for (final r in KnockoutRound.values)
        if (gk.formats[r] case final f?) _formatKeys[r]!: {'scoring': f.method.name, 'target': f.target},
    },
    'thirdPlace': gk.thirdPlace,
  };

  static Map<String, dynamic> _pair(Pair p) => {'id': p.id, 'player1Id': p.player1Id, 'player2Id': p.player2Id};

  static Map<String, dynamic> _match(MatchGame m) => {
    'id': m.id,
    'roundNumber': m.roundNumber,
    'matchNumberInRound': m.matchNumberInRound,
    'courtId': m.courtId,
    // Sisi gugur yang belum diketahui = null (bukan objek berid kosong).
    'pair1': m.pair1.isTbd ? null : _pair(m.pair1),
    'pair2': m.pair2.isTbd ? null : _pair(m.pair2),
    'sets': [
      for (final s in m.sets) {'side1': s.side1, 'side2': s.side2},
    ],
    'status': m.status.name,
    'woLoserPairId': m.woLoserPairId,
    'woReason': m.woReason?.name,
    if (m.phase != null) 'phase': m.phase!.code,
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
    clubs: j['clubs'] == null
        ? null
        : [
            for (final c in j['clubs'] as List)
              Club(id: (c as Map<String, dynamic>)['id'] as String, name: c['name'] as String),
          ],
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
    players: [
      for (final p in j['players'] as List)
        Player(id: p['id'] as String, name: p['name'] as String, clubId: p['club'] as String?),
    ],
    fixedPairs: j['fixedPairs'] == null
        ? null
        : [for (final p in j['fixedPairs'] as List) _readPair(p as Map<String, dynamic>)],
    // Kunci ada tapi null/bukan map = rusak (melempar → decode null), beda dengan kunci yang tidak ada.
    groupKnockout: j.containsKey('groupKnockout')
        ? _readGroupKnockout(j['groupKnockout'] as Map<String, dynamic>)
        : null,
  );

  static GroupKnockout _readGroupKnockout(Map<String, dynamic> j) {
    final groups = [
      for (final g in j['groups'] as List) [for (final id in g as List) id as String],
    ];
    final formats = <KnockoutRound, ScoreFormat>{};
    for (final e in (j['formats'] as Map<String, dynamic>).entries) {
      final round = _formatKeys.entries.firstWhere((k) => k.value == e.key).key;
      final f = e.value as Map<String, dynamic>;
      formats[round] = ScoreFormat(ScoringMethod.values.byName(f['scoring'] as String), f['target'] as int);
    }
    return GroupKnockout(
      groupCount: groups.length,
      groups: groups,
      formats: formats,
      thirdPlace: j['thirdPlace'] as bool,
    );
  }

  /// Hanya kode yang ditulis [MatchPhase.code]; selain itu melempar (payload rusak).
  static MatchPhase _readPhase(String code) {
    const groups = ['A', 'B', 'C', 'D'];
    if (groups.contains(code)) return GroupPhase(groups.indexOf(code));
    return switch (code) {
      'PF1' => const KnockoutPhase(KnockoutRound.quarterfinal, 1),
      'PF2' => const KnockoutPhase(KnockoutRound.quarterfinal, 2),
      'PF3' => const KnockoutPhase(KnockoutRound.quarterfinal, 3),
      'PF4' => const KnockoutPhase(KnockoutRound.quarterfinal, 4),
      'SF1' => const KnockoutPhase(KnockoutRound.semifinal, 1),
      'SF2' => const KnockoutPhase(KnockoutRound.semifinal, 2),
      'J3' => const KnockoutPhase(KnockoutRound.thirdPlace, 1),
      'F' => const KnockoutPhase(KnockoutRound.finalRound, 1),
      _ => throw FormatException('phase tak dikenal: $code'),
    };
  }

  /// `null` = sisi gugur yang belum diketahui; objek berid kosong tidak pernah ditulis, jadi ditolak.
  static Pair _readSide(Object? j) {
    if (j == null) return Pair.tbd;
    final pair = _readPair(j as Map<String, dynamic>);
    if (pair.isTbd) throw const FormatException('sisi berid kosong');
    return pair;
  }

  static ScoreFormat _readFormat(Map<String, dynamic> j) =>
      ScoreFormat(ScoringMethod.values.byName(j['scoring'] as String), j['target'] as int);

  static Pair _readPair(Map<String, dynamic> j) =>
      Pair(id: j['id'] as String, player1Id: j['player1Id'] as String, player2Id: j['player2Id'] as String);

  static MatchGame _readMatch(Map<String, dynamic> j) => MatchGame(
    id: j['id'] as String,
    roundNumber: j['roundNumber'] as int,
    matchNumberInRound: j['matchNumberInRound'] as int,
    courtId: j['courtId'] as String,
    pair1: _readSide(j['pair1']),
    pair2: _readSide(j['pair2']),
    sets: [for (final s in j['sets'] as List) SetScore(side1: s['side1'] as int, side2: s['side2'] as int)],
    status: MatchStatus.values.byName(j['status'] as String),
    woLoserPairId: j['woLoserPairId'] as String?,
    woReason: j['woReason'] == null ? null : WoReason.values.byName(j['woReason'] as String),
    phase: j['phase'] == null ? null : _readPhase(j['phase'] as String),
  );
}
