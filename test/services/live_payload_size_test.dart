import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';
import 'package:match_addict/services/schedule/round_robin_generator.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import 'group_knockout_fixture.dart';

/// Ukuran payload live 32 pemain (AC-B9, docs/data.md → Ukuran payload live): batas relay `MAX_BYTES` 256 KB
/// (`relay/src/index.js`), kasus dasar wajib di bawah separuhnya. Id memakai bentuk uuid supaya ukurannya realistis.

String _uuid(String kind, int n) => '$kind-${n.toRadixString(16).padLeft(8, '0')}-4000-8000-000000000000';

Player _player(int i) => Player(id: _uuid('11111111', i), name: 'Pemain ${i + 1}');

List<Court> _courts(int n) => [
  for (var i = 0; i < n; i++)
    Court(id: _uuid('22222222', i), name: 'Court ${i + 1}', colorIndex: i % 10, bookingDurationMinutes: 120),
];

List<Pair> _pairs(List<Player> players) => [
  for (var i = 0; i + 1 < players.length; i += 2)
    Pair(id: 'pair-${players[i].id}-${players[i + 1].id}', player1Id: players[i].id, player2Id: players[i + 1].id),
];

List<MatchGame> _scored(List<MatchGame> matches) => [
  for (final (i, m) in matches.indexed) m.withScore([SetScore(side1: 6, side2: i % 5)]),
];

const _kb = 1024;

void _measure(String name, ActiveTournament Function() build, {required int limit, required int matches}) {
  test(name, () {
    final a = build();
    expect(a.matches.length, matches);
    final raw = TournamentCodec.encode(a);
    final bytes = utf8.encode(raw).length;
    expect(bytes, lessThan(limit));
    expect(TournamentCodec.decode(raw), isNotNull);
  });
}

/// Fixed 16 pasangan (32 pemain), 2 court, round-robin + [extraPutaran] putaran tambahan penuh.
ActiveTournament _fixed16({int extraPutaran = 0}) {
  final players = [for (var i = 0; i < 32; i++) _player(i)];
  final pairs = _pairs(players);
  final courts = _courts(2);
  final base = RoundRobinGenerator.generate(pairs: pairs, courts: courts);
  var matches = [...base.matches];
  if (extraPutaran > 0) {
    // roundsLeft = 60 round per putaran penuh (15 circle round × 4 round pada 2 court).
    final extra = RoundRobinGenerator.extend(
      pairs: pairs,
      courts: courts,
      roundsLeft: [60 * extraPutaran, 60 * extraPutaran],
      putaranDone: 0,
      firstRound: base.roundCount + 1,
    );
    matches = [...matches, ...extra.schedule.matches];
  }
  final config = TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.fixed,
    matchDurationMinutes: 15,
    courts: courts,
    players: players,
    fixedPairs: pairs,
    format: ScoreFormat.standard,
  );
  return ActiveTournament(
    tournament: Tournament(
      id: _uuid('33333333', 0),
      createdAt: DateTime(2026, 11, 24),
      config: config,
      matches: _scored(matches),
    ),
    byePairIdByRound: base.byePairIdByRound,
    extraPutaran: extraPutaran,
  );
}

/// Mixed 32 pemain, [courtCount] court, [rounds] round dari generator asli (daftar istirahat ikut ditulis).
ActiveTournament _mixed32(int courtCount, int rounds) {
  final players = [for (var i = 0; i < 32; i++) _player(i)];
  final courts = _courts(courtCount);
  final matches = <MatchGame>[];
  final resting = <int, List<String>>{};
  for (var r = 1; r <= rounds; r++) {
    final round = EndlessRoundGenerator.generateRound(
      players: players,
      courts: courts,
      history: matches,
      roundNumber: r,
      seed: 7,
    )!;
    matches.addAll(round.matches);
    if (round.resting.isNotEmpty) resting[r] = [for (final p in round.resting) p.id];
  }
  final config = TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.mixed,
    matchDurationMinutes: 15,
    courts: courts,
    players: players,
    format: ScoreFormat.standard,
  );
  return ActiveTournament(
    tournament: Tournament(
      id: _uuid('33333333', 1),
      createdAt: DateTime(2026, 11, 24),
      config: config,
      matches: _scored(matches),
    ),
    restingPlayerIdsByRound: resting,
  );
}

/// Group - Playoff 16 pasangan: grup terisi, bagan dibuat, semua match gugur selesai. Id pasangan = nama panjang
/// (lebih panjang dari id asli, jadi ukurannya konservatif).
ActiveTournament _groupPlayoff(List<int> sizes) {
  final names = [for (var i = 0; i < 16; i++) 'pair-${_uuid('11111111', 2 * i)}-${_uuid('11111111', 2 * i + 1)}'];
  var at = 0;
  final groups = [
    for (final s in sizes) [for (var i = 0; i < s; i++) names[at++]],
  ];
  var a = gkTournament(groups: groups, courts: 2);
  a = a.withMatches(_scored(a.matches));
  if (sizes.length == 3) {
    final seeding = Seeding(
      groupSlots: [
        for (final g in groups) [g[0], g[1]],
      ],
      champions: const [0, 1, 2],
      wildcards: [groups[1][2], groups[2][2]],
    );
    final b = KnockoutBracket.build(a, seeding);
    a = ActiveTournament(
      tournament: a.tournament.copyWith(config: b.config, matches: [...a.matches, ...b.matches]),
    );
  } else {
    a = a.bracket([
      for (final g in groups) [g[0], g[1]],
    ]);
  }
  for (final code in [
    if (sizes.length >= 3) ...['PF1', 'PF2', 'PF3', 'PF4'],
    'SF1',
    'SF2',
    'J3',
    'F',
  ]) {
    a = a.ko(code, 6, 3);
  }
  return a;
}

void main() {
  group('kasus dasar 32 pemain < 128 KB (AC-B9)', () {
    _measure('Group - Playoff 2 grup × 8 + bagan', () => _groupPlayoff([8, 8]), limit: 128 * _kb, matches: 60);
    _measure('Group - Playoff 3 grup [6, 5, 5] + bagan', () => _groupPlayoff([6, 5, 5]), limit: 128 * _kb, matches: 43);
    _measure('Group - Playoff 4 grup × 4 + bagan', () => _groupPlayoff([4, 4, 4, 4]), limit: 128 * _kb, matches: 32);
    _measure('Fixed 16 pasangan round-robin, 2 court', _fixed16, limit: 128 * _kb, matches: 120);
    _measure('Mixed 32 pemain, 8 court, 16 round', () => _mixed32(8, 16), limit: 128 * _kb, matches: 128);
    _measure('Mixed 32 pemain, 1 court, 30 round + istirahat', () => _mixed32(1, 30), limit: 128 * _kb, matches: 30);
  });

  group('di atas 128 KB tetap < 256 KB (batas relay)', () {
    _measure('Fixed 16 pasangan + 1 putaran tambahan', () => _fixed16(extraPutaran: 1), limit: 256 * _kb, matches: 240);
    _measure('Fixed 16 pasangan + 2 putaran tambahan', () => _fixed16(extraPutaran: 2), limit: 256 * _kb, matches: 360);
    _measure('Mixed 32 pemain, 8 court, 50 round', () => _mixed32(8, 50), limit: 256 * _kb, matches: 400);
  });
}
