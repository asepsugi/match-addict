import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/app_version.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';
import 'package:uuid/uuid.dart';

// --- Simpanan 3.1.0 (literal) ------------------------------------------------
// Ditulis persis seperti keluaran encoder 3.1.0 (diverifikasi dengan encoder 3.1.0 sebelum kode sparing masuk), jadi
// `encode(decode(x)) == x` membuktikan encode turnamen biasa tidak berubah satu byte (AC-S19).

String _match(
  String id,
  int round,
  String court,
  String pair1,
  String pair2,
  String sets,
  String status, [
  String wo = 'null',
  String reason = 'null',
]) =>
    '{"id":"$id","roundNumber":$round,"matchNumberInRound":1,"courtId":"$court","pair1":$pair1,"pair2":$pair2,'
    '"sets":$sets,"status":"$status","woLoserPairId":$wo,"woReason":$reason}';

const _pa = '{"id":"A","player1Id":"p1","player2Id":"p2"}';
const _pb = '{"id":"B","player1Id":"p3","player2Id":"p4"}';
const _pc = '{"id":"C","player1Id":"p5","player2Id":"p6"}';
const _players6 =
    '[{"id":"p1","name":"Andi"},{"id":"p2","name":"Budi"},{"id":"p3","name":"Citra"},'
    '{"id":"p4","name":"Dewi"},{"id":"p5","name":"Eko"},{"id":"p6","name":"Fajar"}]';

/// Fixed 3.1.0: nama turnamen, bye per round, round tambahan (`extraPutaran`), satu WO.
final _fixed310 =
    '{"schema":2,"appVersion":"3.1.0","tournament":{"id":"t-fixed","createdAt":"2026-11-03T19:00:00.000",'
    '"isFinished":false,"config":{"sport":"padel","mode":"fixed","matchDurationMinutes":15,"scoring":"raceTo",'
    '"target":6,"name":"Mabar Jumat PB Garuda","courts":[{"id":"c1","name":"Court 1","colorIndex":0,'
    '"bookingDurationMinutes":120}],"players":$_players6,"fixedPairs":[$_pa,$_pb,$_pc]},"matches":['
    '${_match('m1', 1, 'c1', _pa, _pb, '[{"side1":6,"side2":3}]', 'done')},'
    '${_match('m2', 2, 'c1', _pb, _pc, '[]', 'wo', '"C"', '"absent"')},'
    '${_match('m3', 3, 'c1', _pc, _pa, '[{"side1":4,"side2":6}]', 'done')},'
    '${_match('m4', 4, 'c1', _pa, _pb, '[]', 'pending')}'
    ']},"bye":{"1":"C","2":"A","3":"B","4":"C"},"resting":{},"withdrawn":[],"extraPutaran":1}';

/// Mixed 3.1.0: court tambahan di tengah (`startMinute`), pemain keluar (`withdrawn`), istirahat per round.
final _mixed310 =
    '{"schema":2,"appVersion":"3.1.0","tournament":{"id":"t-mixed","createdAt":"2026-11-03T19:00:00.000",'
    '"isFinished":false,"config":{"sport":"tennis","mode":"mixed","matchDurationMinutes":20,"scoring":"americano",'
    '"target":21,"courts":[{"id":"c1","name":"Court 1","colorIndex":0,"bookingDurationMinutes":120},'
    '{"id":"c2","name":"Court 2","colorIndex":1,"bookingDurationMinutes":60,"startMinute":30}],'
    '"players":$_players6,"fixedPairs":null},"matches":['
    '${_match('m1', 1, 'c1', '{"id":"x1","player1Id":"p1","player2Id":"p2"}', '{"id":"x2","player1Id":"p3","player2Id":"p4"}', '[{"side1":12,"side2":9}]', 'done')},'
    '${_match('m2', 2, 'c1', '{"id":"x3","player1Id":"p5","player2Id":"p1"}', '{"id":"x4","player1Id":"p6","player2Id":"p3"}', '[]', 'pending')}'
    ']},"bye":{},"resting":{"1":["p5","p6"],"2":["p2","p4"]},"withdrawn":["p2"],"extraPutaran":0}';

/// Skema 2 minimal (2.0.0): tanpa `name`, `startMinute`, `withdrawn`, `extraPutaran`.
final _minimal200 =
    '{"schema":2,"appVersion":"2.0.0","tournament":{"id":"t-min","createdAt":"2026-10-22T19:00:00.000",'
    '"isFinished":false,"config":{"sport":"padel","mode":"fixed","matchDurationMinutes":15,"scoring":"raceTo",'
    '"target":6,"courts":[{"id":"c1","name":"Court 1","colorIndex":0,"bookingDurationMinutes":120}],'
    '"players":[{"id":"p1","name":"Andi"},{"id":"p2","name":"Budi"},{"id":"p3","name":"Citra"},'
    '{"id":"p4","name":"Dewi"}],"fixedPairs":[$_pa,$_pb]},"matches":['
    '${_match('m1', 1, 'c1', _pa, _pb, '[]', 'pending')}'
    ']},"bye":{},"resting":{}}';

/// Encoder selalu mencap versi app yang menulis, jadi pembanding byte memakai cap versi sekarang.
String _stamped(String payload) => payload.replaceFirst(RegExp(r'"appVersion":"[^"]*"'), '"appVersion":"$appVersion"');

// --- Sparing 13A / 13B (logic.md §13.11) -------------------------------------------------------------------------

const _garuda = Club(id: 'club-1', name: 'PB Garuda');
const _matcha = Club(id: 'club-2', name: 'Matcha Club');

Player _p(String name, Club club) => Player(id: 'p-${name.toLowerCase()}', name: name, clubId: club.id);

final _garudaPlayers = [
  for (final n in ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi']) _p(n, _garuda),
];
final _matchaPlayers = [
  for (final n in ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda']) _p(n, _matcha),
];

Pair _pair(String id, String a, String b) => Pair(id: id, player1Id: 'p-$a', player2Id: 'p-$b');

/// Urutan map = urutan daftar pasangan (klub pertama dulu) = indeks generator.
final _pairs13a = {
  'G1': _pair('pair-g1', 'andi', 'budi'),
  'G2': _pair('pair-g2', 'citra', 'dewi'),
  'G3': _pair('pair-g3', 'eko', 'fajar'),
  'G4': _pair('pair-g4', 'gita', 'hadi'),
  'M1': _pair('pair-m1', 'indra', 'joko'),
  'M2': _pair('pair-m2', 'kiki', 'lina'),
  'M3': _pair('pair-m3', 'maya', 'nanda'),
};

/// Atur pasangan setelah R6 (14o/14p): Dewi pulang → Citra · Gilang mengisi slot G2; Nanda pulang → Maya · Oki di M3.
final _pairsReplaced = {
  ..._pairs13a,
  'G2': _pair('pair-g2b', 'citra', 'gilang'),
  'M3': _pair('pair-m3b', 'maya', 'oki'),
};

/// Tabel 13A R1–R6 lalu round tambahan R7–R12 (14n): per round [Court 1, Court 2].
const _rounds13a = [
  [
    ['G1', 'M1'],
    ['G2', 'M2'],
  ],
  [
    ['G3', 'M3'],
    ['G4', 'M1'],
  ],
  [
    ['G1', 'M2'],
    ['G2', 'M3'],
  ],
  [
    ['G3', 'M1'],
    ['G4', 'M2'],
  ],
  [
    ['G1', 'M3'],
    ['G2', 'M1'],
  ],
  [
    ['G3', 'M2'],
    ['G4', 'M3'],
  ],
];
const _extra13a = [
  [
    ['G1', 'M2'],
    ['G2', 'M3'],
  ],
  [
    ['G3', 'M1'],
    ['G4', 'M2'],
  ],
  [
    ['G1', 'M3'],
    ['G2', 'M1'],
  ],
  [
    ['G3', 'M2'],
    ['G4', 'M3'],
  ],
  [
    ['G1', 'M1'],
    ['G2', 'M2'],
  ],
  [
    ['G3', 'M3'],
    ['G4', 'M1'],
  ],
];

/// Skor 13C urut R1 C1, R1 C2, …; null = WO (R3 Court 2, G2 absen).
const _scores13c = [
  [6, 3], [4, 6], [6, 5], [6, 4], [6, 4], null, [6, 2], [3, 6], [2, 6], [6, 1], [6, 0], [5, 6], //
];

const _courts = [
  Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
  Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
];

/// Fixed sparing 13A: [filled] round pertama berskor 13C, [finished] = diakhiri, [withExtra] = R7–R12 dibuat
/// (1 satuan), [replaced] = Atur pasangan dengan Gilang dan Oki sebelum R7.
ActiveTournament _fixed13a({
  int filled = 0,
  bool finished = false,
  bool withExtra = false,
  bool replaced = false,
  String? name,
}) {
  final players = [
    ..._garudaPlayers,
    if (replaced) _p('Gilang', _garuda),
    ..._matchaPlayers,
    if (replaced) _p('Oki', _matcha),
  ];
  final matches = <MatchGame>[];
  final resting = <int, List<String>>{};
  void addRound(int round, List<List<String>> courts, Map<String, Pair> pairs) {
    for (var c = 0; c < courts.length; c++) {
      final index = matches.length;
      var match = MatchGame(
        id: 'm$round-${c + 1}',
        roundNumber: round,
        matchNumberInRound: c + 1,
        courtId: _courts[c].id,
        pair1: pairs[courts[c][0]]!,
        pair2: pairs[courts[c][1]]!,
      );
      if (round <= filled) {
        final score = _scores13c[index];
        match = score == null
            ? match.asWalkover(loserPairId: match.pair1.id, reason: WoReason.absent)
            : match.withScore([SetScore(side1: score[0], side2: score[1])]);
      }
      matches.add(match);
    }
    final playing = {for (final court in courts) ...court};
    resting[round] = [
      for (final e in pairs.entries)
        if (!playing.contains(e.key)) e.value.id,
    ];
  }

  for (var r = 0; r < _rounds13a.length; r++) {
    addRound(r + 1, _rounds13a[r], _pairs13a);
  }
  if (withExtra) {
    for (var r = 0; r < _extra13a.length; r++) {
      addRound(r + 7, _extra13a[r], replaced ? _pairsReplaced : _pairs13a);
    }
  }
  return ActiveTournament(
    tournament: Tournament(
      id: 't-13a',
      createdAt: DateTime(2026, 11, 6, 19),
      isFinished: finished,
      config: TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.fixed,
        matchDurationMinutes: 15,
        courts: _courts,
        players: players,
        fixedPairs: (replaced ? _pairsReplaced : _pairs13a).values.toList(),
        name: name,
        clubs: const [_garuda, _matcha],
      ),
      matches: matches,
    ),
    restingPairIdsByRound: resting,
    extraPutaran: withExtra ? 1 : 0,
  );
}

/// Mixed sparing 13B ringkas: Garuda 8, Matcha 6, 2 court. Nanda keluar dan Oki masuk Matcha setelah R3; R4 berjalan.
ActiveTournament _mixed13b() {
  final oki = _p('Oki', _matcha);
  final matches = <MatchGame>[];
  final resting = <int, List<String>>{};
  for (var r = 1; r <= 4; r++) {
    final garuda = [for (var k = 0; k < 4; k++) _garudaPlayers[((r - 1) * 4 + k) % 8]];
    final matchaActive = r <= 3 ? _matchaPlayers : [..._matchaPlayers.where((p) => p.name != 'Nanda'), oki];
    final matcha = r <= 3 ? [for (var k = 0; k < 4; k++) matchaActive[((r - 1) * 4 + k) % 6]] : matchaActive.sublist(2);
    for (var i = 0; i < 2; i++) {
      var match = MatchGame(
        id: 'm$r-${i + 1}',
        roundNumber: r,
        matchNumberInRound: i + 1,
        courtId: _courts[i].id,
        pair1: Pair(id: 'x$r-${i + 1}a', player1Id: garuda[2 * i].id, player2Id: garuda[2 * i + 1].id),
        pair2: Pair(id: 'x$r-${i + 1}b', player1Id: matcha[2 * i].id, player2Id: matcha[2 * i + 1].id),
      );
      if (r <= 3) match = match.withScore([SetScore(side1: 12 - i, side2: 9 + i)]);
      matches.add(match);
    }
    final playing = {...garuda, ...matcha}.map((p) => p.id).toSet();
    resting[r] = [
      for (final p in [..._garudaPlayers, ...matchaActive])
        if (!playing.contains(p.id)) p.id,
    ];
  }
  return ActiveTournament(
    tournament: Tournament(
      id: 't-13b',
      createdAt: DateTime(2026, 11, 6, 19),
      config: TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.mixed,
        matchDurationMinutes: 15,
        courts: _courts,
        players: [..._garudaPlayers, ..._matchaPlayers, oki],
        format: const ScoreFormat(ScoringMethod.americano, 21),
        clubs: const [_garuda, _matcha],
      ),
      matches: matches,
    ),
    restingPlayerIdsByRound: resting,
    withdrawnPlayerIds: const {'p-nanda'},
  );
}

Map<String, dynamic> _json(ActiveTournament a) => jsonDecode(TournamentCodec.encode(a)) as Map<String, dynamic>;

/// Payload sah [base] (literal JSON atau turnamen) yang diubah [mutate], lalu dibaca.
ActiveTournament? _decodeMutated(Object base, void Function(Map<String, dynamic> j) mutate) {
  final j = base is String ? jsonDecode(base) as Map<String, dynamic> : _json(base as ActiveTournament);
  mutate(j);
  return TournamentCodec.decode(jsonEncode(j));
}

Map<String, dynamic> _config(Map<String, dynamic> j) => j['tournament']['config'] as Map<String, dynamic>;
List<dynamic> _players(Map<String, dynamic> j) => _config(j)['players'] as List;
Map<String, dynamic> _firstMatch(Map<String, dynamic> j) => (j['tournament']['matches'] as List).first;

/// Id klub [from] diganti [to] di `clubs` dan semua pemain, supaya hanya aturan klubnya yang diuji.
void _renameClub(Map<String, dynamic> j, String from, String to) {
  for (final c in _config(j)['clubs'] as List) {
    if (c['id'] == from) c['id'] = to;
  }
  for (final p in _players(j)) {
    if (p['club'] == from) p['club'] = to;
  }
}

void main() {
  group('AC-S19 simpanan 3.1.0 = turnamen biasa', () {
    test('Fixed dengan extraPutaran: encode ulang byte-sama', () {
      expect(TournamentCodec.encode(TournamentCodec.decode(_fixed310)!), _stamped(_fixed310));
    });

    test('Mixed dengan withdrawn: encode ulang byte-sama', () {
      expect(TournamentCodec.encode(TournamentCodec.decode(_mixed310)!), _stamped(_mixed310));
    });

    test('skema 2 minimal terbaca; encode hanya menambah withdrawn + extraPutaran', () {
      final restored = TournamentCodec.decode(_minimal200)!;
      expect(
        TournamentCodec.encode(restored),
        _stamped('${_minimal200.substring(0, _minimal200.length - 1)},"withdrawn":[],"extraPutaran":0}'),
      );
    });
    test('encode turnamen biasa tidak memuat kunci sparing', () {
      for (final payload in [_fixed310, _mixed310, _minimal200]) {
        final encoded = TournamentCodec.encode(TournamentCodec.decode(payload)!);
        for (final key in ['"clubs"', '"club"', '"restingPairs"', '"sparing"']) {
          expect(encoded.contains(key), isFalse, reason: key);
        }
      }
    });

    test('dibaca sebagai turnamen biasa: isSparing false, clubId null semua', () {
      for (final payload in [_fixed310, _mixed310, _minimal200]) {
        final restored = TournamentCodec.decode(payload)!;
        expect(restored.config.isSparing, isFalse);
        expect(restored.config.clubs, isNull);
        expect(restored.config.players.every((p) => p.clubId == null), isTrue);
        expect(restored.restingPairIdsByRound, isEmpty);
      }
      expect(TournamentCodec.decode(_fixed310)!.extraPutaran, 1);
      expect(TournamentCodec.decode(_fixed310)!.byePairIdByRound, {1: 'C', 2: 'A', 3: 'B', 4: 'C'});
      expect(TournamentCodec.decode(_mixed310)!.withdrawnPlayerIds, {'p2'});
    });

    test('sisa klub/istirahat pasangan di model turnamen biasa tidak ikut ditulis', () {
      // Penjagaan: turnamen biasa tidak pernah menulis kunci yang membuat payload-nya ditolak.
      final restored = TournamentCodec.decode(_fixed310)!;
      final stray = restored.copyWith(
        tournament: restored.tournament.copyWith(
          config: restored.config.copyWith(
            players: [for (final p in restored.config.players) Player(id: p.id, name: p.name, clubId: 'club-1')],
          ),
        ),
        restingPairs: const {
          1: ['A'],
        },
      );
      expect(TournamentCodec.encode(stray), _stamped(_fixed310));
    });
  });

  group('AC-S20 round trip sparing: encode(decode(x)) == x', () {
    test('13A setelah R3: klub, anggota, istirahat per round', () {
      final x = TournamentCodec.encode(_fixed13a(filled: 3));
      final restored = TournamentCodec.decode(x)!;
      expect(TournamentCodec.encode(restored), x);

      final config = restored.config;
      expect(config.isSparing, isTrue);
      expect(config.clubs!.map((c) => '${c.id}:${c.name}'), ['club-1:PB Garuda', 'club-2:Matcha Club']);
      expect(config.playersOfClub('club-1').map((p) => p.name), [
        'Andi',
        'Budi',
        'Citra',
        'Dewi',
        'Eko',
        'Fajar',
        'Gita',
        'Hadi',
      ]);
      expect(config.playersOfClub('club-2').map((p) => p.name), ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda']);
      expect(config.pairsOfClub('club-1').map((p) => p.id), ['pair-g1', 'pair-g2', 'pair-g3', 'pair-g4']);
      expect(config.pairsOfClub('club-2').map((p) => p.id), ['pair-m1', 'pair-m2', 'pair-m3']);
      expect(restored.byePairIdByRound, isEmpty);
      expect(restored.restingPairIdsByRound[1], ['pair-g3', 'pair-g4', 'pair-m3']);
      expect(restored.restingPairIdsByRound[6], ['pair-g1', 'pair-g2', 'pair-m1']);
      expect(restored.matchById('m3-2')!.status, MatchStatus.wo);
      expect(restored.matchById('m3-2')!.woLoserPairId, 'pair-g2');
      expect(restored.playedMatchCount, 6);
    });

    test('13A diakhiri di R6', () {
      final x = TournamentCodec.encode(_fixed13a(filled: 6, finished: true));
      final restored = TournamentCodec.decode(x)!;
      expect(TournamentCodec.encode(restored), x);
      expect(restored.tournament.isFinished, isTrue);
      expect(restored.playedMatchCount, 12);
    });

    test('13A + round tambahan R7–R12: extraPutaran = 1 satuan', () {
      final x = TournamentCodec.encode(_fixed13a(filled: 6, withExtra: true));
      final restored = TournamentCodec.decode(x)!;
      expect(TournamentCodec.encode(restored), x);
      expect(restored.extraPutaran, 1);
      expect(restored.roundCount, 12);
      expect(restored.restingPairIdsByRound[7], ['pair-g3', 'pair-g4', 'pair-m1']);
      expect(restored.restingPairIdsByRound[12], ['pair-g1', 'pair-g2', 'pair-m2']);
    });

    test('pemain pengganti Atur pasangan (Gilang, Oki) membawa klubnya', () {
      final x = TournamentCodec.encode(_fixed13a(filled: 6, withExtra: true, replaced: true));
      final restored = TournamentCodec.decode(x)!;
      expect(TournamentCodec.encode(restored), x);

      final config = restored.config;
      expect(config.clubOfPlayer('p-gilang')?.name, 'PB Garuda');
      expect(config.clubOfPlayer('p-oki')?.name, 'Matcha Club');
      // Slot dipertahankan: pasangan baru di tempat G2/M3 lama.
      expect(config.pairsOfClub('club-1').map((p) => p.id), ['pair-g1', 'pair-g2b', 'pair-g3', 'pair-g4']);
      expect(config.pairsOfClub('club-2').map((p) => p.id), ['pair-m1', 'pair-m2', 'pair-m3b']);
      // Pasangan lama hanya tercatat di match-nya, klubnya tetap terbaca.
      expect(restored.clubOfPairId('pair-g2')?.id, 'club-1');
      expect(restored.clubOfPairId('pair-m3')?.id, 'club-2');
      expect(restored.restingPairIdsByRound[7], ['pair-g3', 'pair-g4', 'pair-m1']);
    });

    test('Mixed sparing: pemain keluar dan pemain baru berklub', () {
      final x = TournamentCodec.encode(_mixed13b());
      final restored = TournamentCodec.decode(x)!;
      expect(TournamentCodec.encode(restored), x);

      expect(restored.config.isSparing, isTrue);
      expect(restored.withdrawnPlayerIds, {'p-nanda'});
      expect(restored.activePlayersOfClub('club-2').map((p) => p.name), [
        'Indra',
        'Joko',
        'Kiki',
        'Lina',
        'Maya',
        'Oki',
      ]);
      // Yang keluar tetap di config.players dengan klubnya.
      expect(restored.config.clubOfPlayer('p-nanda')?.id, 'club-2');
      expect(restored.restingPlayerIdsByRound[4], ['p-andi', 'p-budi', 'p-citra', 'p-dewi', 'p-indra', 'p-joko']);
      expect(restored.restingPairIdsByRound, isEmpty);
      expect(_json(restored).containsKey('restingPairs'), isFalse);
      expect(restored.extraPutaran, 0);
    });

    test('urutan kunci: clubs setelah name, club setelah name pemain, restingPairs setelah resting', () {
      final j = _json(_fixed13a(filled: 3, name: 'PB Garuda x Matcha Club'));
      expect(j.keys, [
        'schema',
        'appVersion',
        'tournament',
        'bye',
        'resting',
        'restingPairs',
        'withdrawn',
        'extraPutaran',
      ]);
      final configKeys = _config(j).keys.toList();
      expect(configKeys.indexOf('clubs'), configKeys.indexOf('name') + 1);
      expect((_players(j).first as Map).keys, ['id', 'name', 'club']);
      expect(j['bye'], {'sparing': '1'});
    });
  });

  group('penanda bye.sparing', () {
    test(
      'kunci bye sparing tidak bisa di-int.parse (decoder 3.1.0 menolak), decoder 3.2.0 tidak menjadikannya round',
      () {
        final x = TournamentCodec.encode(_fixed13a(filled: 3));
        final bye = (jsonDecode(x) as Map<String, dynamic>)['bye'] as Map<String, dynamic>;
        // Persis cara decoder 3.1.0 membaca `bye`.
        expect(() => {for (final e in bye.entries) int.parse(e.key): e.value as String}, throwsFormatException);
        expect(TournamentCodec.decode(x)!.byePairIdByRound, isEmpty);
      },
    );

    test('kunci bye non-angka selain "sparing" tetap rusak', () {
      expect(_decodeMutated(_fixed13a(filled: 3), (j) => j['bye']['sparingx'] = 'pair-g1'), isNull);
    });
  });

  group('payload sparing rusak → null', () {
    test('payload dasar yang dipakai di grup ini sah', () {
      expect(_decodeMutated(_fixed13a(filled: 3), (_) {}), isNotNull);
      expect(_decodeMutated(_mixed13b(), (_) {}), isNotNull);
    });

    test('tanpa clubs tapi ada club di pemain', () {
      expect(_decodeMutated(_fixed310, (j) => _players(j).first['club'] = 'club-1'), isNull);
      expect(_decodeMutated(_fixed13a(filled: 3), (j) => _config(j).remove('clubs')), isNull);
    });

    test('tanpa clubs tapi ada restingPairs', () {
      expect(
        _decodeMutated(
          _fixed310,
          (j) => j['restingPairs'] = {
            '1': ['C'],
          },
        ),
        isNull,
      );
    });

    test('id pemain duplikat lintas klub (docs/security.md #2)', () {
      for (final base in [_fixed13a(filled: 3), _mixed13b()]) {
        expect(
          _decodeMutated(base, (j) {
            final players = _players(j);
            final other = players.firstWhere((p) => p['club'] != players.first['club']);
            other['id'] = players.first['id'];
          }),
          isNull,
        );
      }
    });

    test('tanpa clubs tapi ada bye.sparing', () {
      expect(_decodeMutated(_fixed310, (j) => j['bye']['sparing'] = '1'), isNull);
    });

    test('clubs bukan list tepat 2 / elemen bukan {id: String, name: String} / id kosong atau sama / nama kosong', () {
      final base = _fixed13a(filled: 3);
      final invalid = <void Function(Map<String, dynamic>)>[
        (j) => _config(j)['clubs'] = {'id': 'club-1', 'name': 'PB Garuda'},
        (j) => (_config(j)['clubs'] as List).removeLast(),
        (j) => (_config(j)['clubs'] as List).add({'id': 'club-3', 'name': 'Klub Lain'}),
        (j) => _config(j)['clubs'] = ['club-1', 'club-2'],
        (j) => (_config(j)['clubs'] as List).first['id'] = 1,
        (j) => (_config(j)['clubs'] as List).first['name'] = null,
        (j) => _renameClub(j, 'club-1', ''),
        (j) => _renameClub(j, 'club-2', 'club-1'),
        (j) => (_config(j)['clubs'] as List).last['name'] = '',
      ];
      for (var i = 0; i < invalid.length; i++) {
        expect(_decodeMutated(base, invalid[i]), isNull, reason: 'kasus $i');
      }
      // Pembanding: ganti id saja (tetap tak kosong, tetap beda) sah — yang ditolak memang aturan klubnya.
      expect(_decodeMutated(base, (j) => _renameClub(j, 'club-1', 'garuda')), isNotNull);
    });

    test('bye.sparing tidak ada atau bukan "1" padahal ada clubs', () {
      final base = _fixed13a(filled: 3);
      expect(_decodeMutated(base, (j) => j['bye'].remove('sparing')), isNull);
      expect(_decodeMutated(base, (j) => j['bye']['sparing'] = '2'), isNull);
      expect(_decodeMutated(base, (j) => j['bye']['sparing'] = 1), isNull);
    });

    test('pemain tanpa club, atau club bukan salah satu id klub', () {
      final base = _fixed13a(filled: 6, withExtra: true, replaced: true);
      // Pengganti (Gilang) tanpa klub.
      expect(_decodeMutated(base, (j) => _players(j).firstWhere((p) => p['id'] == 'p-gilang').remove('club')), isNull);
      expect(_decodeMutated(base, (j) => _players(j).first['club'] = 'club-9'), isNull);
      // Pemain yang keluar (Nanda) juga wajib berklub.
      expect(
        _decodeMutated(_mixed13b(), (j) => _players(j).firstWhere((p) => p['id'] == 'p-nanda').remove('club')),
        isNull,
      );
    });

    test('anggota pasangan tidak ada di config.players atau beda klub', () {
      final base = _fixed13a(filled: 3);
      List<dynamic> pairs(Map<String, dynamic> j) => _config(j)['fixedPairs'] as List;
      expect(_decodeMutated(base, (j) => pairs(j).first['player2Id'] = 'p-x'), isNull);
      expect(_decodeMutated(base, (j) => pairs(j).first['player2Id'] = 'p-indra'), isNull);
      expect(_decodeMutated(base, (j) => _firstMatch(j)['pair1']['player2Id'] = 'p-x'), isNull);
      expect(_decodeMutated(base, (j) => _firstMatch(j)['pair2']['player1Id'] = 'p-andi'), isNull);
      expect(_decodeMutated(_mixed13b(), (j) => _firstMatch(j)['pair1']['player2Id'] = 'p-kiki'), isNull);
    });

    test('pair1 bukan klub pertama atau pair2 bukan klub kedua (S4)', () {
      void swap(Map<String, dynamic> j) {
        final m = _firstMatch(j);
        final pair1 = m['pair1'];
        m['pair1'] = m['pair2'];
        m['pair2'] = pair1;
      }

      expect(_decodeMutated(_fixed13a(filled: 3), swap), isNull);
      expect(_decodeMutated(_mixed13b(), swap), isNull);
    });

    test('restingPairs bukan {angka: [String]}', () {
      final base = _fixed13a(filled: 3);
      final invalid = <Object>[
        {
          'x': ['pair-g1'],
        },
        {'1': 'pair-g1'},
        {
          '1': [1],
        },
        ['pair-g1'],
      ];
      for (final value in invalid) {
        expect(_decodeMutated(base, (j) => j['restingPairs'] = value), isNull, reason: '$value');
      }
      // Id yang tidak ketemu bukan pelanggaran bentuk (helper klub total).
      expect(
        _decodeMutated(
          base,
          (j) => j['restingPairs'] = {
            '1': ['pair-hilang'],
          },
        ),
        isNotNull,
      );
    });

    test('extraPutaran bukan int, atau negatif', () {
      final base = _fixed13a(filled: 6, withExtra: true);
      expect(_decodeMutated(base, (j) => j['extraPutaran'] = '1'), isNull);
      expect(_decodeMutated(base, (j) => j['extraPutaran'] = 1.5), isNull);
      expect(_decodeMutated(base, (j) => j['extraPutaran'] = -1), isNull);
    });

    test('payload terpotong', () {
      final x = TournamentCodec.encode(_fixed13a(filled: 3));
      expect(TournamentCodec.decode(x.substring(0, x.length ~/ 2)), isNull);
      expect(TournamentCodec.decode(x.substring(0, x.length - 1)), isNull);
    });
  });

  group('encode menolak bentuk sparing yang tidak bisa dibaca kembali (UnreadableTournamentError, juga di rilis)', () {
    test('pemain sparing tanpa klub', () {
      final active = _fixed13a(filled: 3);
      final broken = active.copyWith(
        tournament: active.tournament.copyWith(
          config: active.config.copyWith(
            players: [for (final p in active.config.players) p.id == 'p-andi' ? Player(id: p.id, name: p.name) : p],
          ),
        ),
      );
      expect(() => TournamentCodec.encode(broken), throwsA(isA<UnreadableTournamentError>()));
    });

    test('pair1 dari klub kedua', () {
      final active = _fixed13a(filled: 3);
      final first = active.matches.first;
      final swapped = MatchGame(
        id: first.id,
        roundNumber: first.roundNumber,
        matchNumberInRound: first.matchNumberInRound,
        courtId: first.courtId,
        pair1: first.pair2,
        pair2: first.pair1,
      );
      final broken = active.copyWith(
        tournament: active.tournament.copyWith(matches: [swapped, ...active.matches.skip(1)]),
      );
      expect(() => TournamentCodec.encode(broken), throwsA(isA<UnreadableTournamentError>()));
    });

    test('TournamentStore tidak menimpa simpanan sah terakhir dengan bentuk rusak (security #1)', () async {
      final active = _fixed13a(filled: 3);
      final broken = active.copyWith(
        tournament: active.tournament.copyWith(
          config: active.config.copyWith(
            players: [for (final p in active.config.players) p.id == 'p-andi' ? Player(id: p.id, name: p.name) : p],
          ),
        ),
      );
      final store = TournamentStore.memory();
      await store.saveActive(active);
      final saved = TournamentCodec.encode(store.loadActive()!);

      await store.saveActive(broken);
      expect(TournamentCodec.encode(store.loadActive()!), saved);

      // Menutup turnamen: slot aktif dibiarkan supaya turnamennya kembali saat app dibuka, bukan hilang.
      await store.archiveActive(broken);
      expect(TournamentCodec.encode(store.loadActive()!), saved);
      expect(store.loadLastFinished(), isNull);
    });
  });

  group('helper klub total (id tak dikenal tidak melempar)', () {
    test('turnamen biasa: semua null / kosong', () {
      final config = TournamentCodec.decode(_fixed310)!.config;
      expect(config.clubById('club-1'), isNull);
      expect(config.clubById(null), isNull);
      expect(config.clubOfPlayer('p1'), isNull);
      expect(config.clubOfPair(config.fixedPairs!.first), isNull);
      expect(config.playersOfClub('club-1'), isEmpty);
      expect(config.pairsOfClub('club-1'), isEmpty);
      expect(config.playerById('p1')?.name, 'Andi');
    });

    test('sparing: id tak dikenal → null / kosong', () {
      final active = _fixed13a(filled: 3);
      final config = active.config;
      expect(config.playerById('nope'), isNull);
      expect(config.clubById('club-9'), isNull);
      expect(config.clubOfPlayer('nope'), isNull);
      expect(config.clubOfPair(const Pair(id: 'x', player1Id: 'p-andi', player2Id: 'nope')), isNull);
      // Beda klub bukan pasangan sah: tidak punya klub.
      expect(config.clubOfPair(const Pair(id: 'x', player1Id: 'p-andi', player2Id: 'p-indra')), isNull);
      expect(config.playersOfClub('club-9'), isEmpty);
      expect(config.pairsOfClub('club-9'), isEmpty);
      expect(active.clubOfPairId('nope'), isNull);
      expect(active.activePlayersOfClub('club-9'), isEmpty);
      expect(active.clubOfPairId('pair-m2')?.name, 'Matcha Club');
    });

    test('copyWith membawa klub, clubId, dan istirahat pasangan', () {
      final active = _fixed13a(filled: 3);
      final config = active.config.copyWith(
        courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 60)],
      );
      expect(identical(config.clubs, active.config.clubs), isTrue);
      expect(config.format, active.config.format);
      expect(active.config.players.first.copyWith(name: 'Andika').clubId, 'club-1');
      expect(identical(active.copyWith(extraPutaran: 2).restingPairIdsByRound, active.restingPairIdsByRound), isTrue);
    });
  });

  test(
    'ukuran: 7/8 pasangan (30 pemain, 56 match per satuan) + 2 satuan tambahan, encode < 256 KB (MAX_BYTES relay)',
    () {
      // Terukur 2026-11-07: 168 match (56 + 2 × 56), id UUID, semua match berskor → 106 681 byte (±104 KB, ±635 B
      // per match), 41% dari batas. Jadwal di sini buatan, hanya untuk ukuran (satu pasangan bisa muncul dua kali
      // dalam satu round): jangan disalin sebagai data jadwal.
      const uuid = Uuid();
      const p1 = 7, p2 = 8, courtCount = 4;
      final players = [
        for (var i = 0; i < 30; i++)
          Player(id: uuid.v4(), name: 'Pemain Nomor ${i + 1}', clubId: i < 2 * p1 ? 'club-1' : 'club-2'),
      ];
      final pairs = [
        for (var i = 0; i < 15; i++)
          Pair(id: uuid.v4(), player1Id: players[2 * i].id, player2Id: players[2 * i + 1].id),
      ];
      final first = pairs.sublist(0, p1), second = pairs.sublist(p1);
      final courts = [
        for (var c = 0; c < courtCount; c++)
          Court(id: uuid.v4(), name: 'Court ${c + 1}', colorIndex: c, bookingDurationMinutes: 120),
      ];
      // Blok diagonal logic.md §13.2: g = FPB(7, 8) = 1, jadi jadwal awal = blok 0, dua satuan tambahan = blok 1 dan 2.
      const l = p1 * p2;
      final matches = <MatchGame>[];
      for (var k = 0; k < 3; k++) {
        for (var s = 0; s < l; s++) {
          final n = matches.length;
          matches.add(
            MatchGame(
              id: uuid.v4(),
              roundNumber: n ~/ courtCount + 1,
              matchNumberInRound: n % courtCount + 1,
              courtId: courts[n % courtCount].id,
              pair1: first[s % p1],
              pair2: second[(s + k) % p2],
              sets: const [SetScore(side1: 6, side2: 4)],
              status: MatchStatus.done,
            ),
          );
        }
      }
      final resting = {
        for (var r = 1; r <= matches.last.roundNumber; r++)
          r: [
            for (final pair in pairs)
              if (!matches.any((m) => m.roundNumber == r && (m.pair1.id == pair.id || m.pair2.id == pair.id))) pair.id,
          ],
      };
      final active = ActiveTournament(
        tournament: Tournament(
          id: uuid.v4(),
          createdAt: DateTime(2026, 11, 6, 19),
          config: TournamentConfig(
            sport: SportType.padel,
            mode: PartnerMode.fixed,
            matchDurationMinutes: 15,
            courts: courts,
            players: players,
            fixedPairs: pairs,
            name: 'Sparing PB Garuda x Matcha Club 2026',
            clubs: const [_garuda, _matcha],
          ),
          matches: matches,
        ),
        restingPairIdsByRound: resting,
        extraPutaran: 2,
      );

      final encoded = TournamentCodec.encode(active);
      final bytes = utf8.encode(encoded).length;
      expect(matches, hasLength(168));
      expect(TournamentCodec.decode(encoded), isNotNull);
      expect(bytes, lessThan(256 * 1024));
    },
  );
}
