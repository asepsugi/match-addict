import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import '../hifi/screens/schedule_fixture.dart';

/// Mexicano (PRD §14, design/spec/logic.md §14.1–§14.4): urutan dari Klasemen Total Point, susunan A/B/C, undian
/// terkunci yang sama dengan prioritas main, dan turunan controller (Batalkan, Kembalikan, Kelola court, kill app).

const _fmt = ScoreFormat(ScoringMethod.americano, 21);
const _names14a = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'];
const _names14b = [..._names14a, 'Indra', 'Joko'];
final _start = DateTime(2026, 11, 11, 19);

/// Undian yang disuntik (logic.md §14.2): urutan daftar = urutan undian. Id pemain di fixture = nama.
Map<String, int> drawOf(List<String> ids) => {for (final (i, id) in ids.indexed) id: i};

List<Court> _courts(List<int> bookings) => [
  for (final (i, b) in bookings.indexed)
    Court(id: 'c${i + 1}', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: b),
];

TournamentConfig _config(List<String> names, {List<int> bookings = const [120, 120]}) => TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.mexicano,
  matchDurationMinutes: 15,
  courts: _courts(bookings),
  players: [for (final n in names) Player(id: n, name: n)],
  format: _fmt,
);

/// "Andi·Citra vs Budi·Dewi": sisi atas dulu, di dalam tim `player1Id` dulu.
String _m(MatchGame m) => '${m.pair1.player1Id}·${m.pair1.player2Id} vs ${m.pair2.player1Id}·${m.pair2.player2Id}';

List<String> _round(List<MatchGame> matches, int n) => [
  for (final m in matches)
    if (m.roundNumber == n) _m(m),
];

/// Turnamen Mexicano dijalankan langsung lewat generator (level service), dengan undian disuntik per round.
class _Sim {
  final TournamentConfig config;
  final List<MatchGame> history = [];
  final Map<int, List<String>> resting = {};
  final Set<String> withdrawn = {};

  _Sim(List<String> names, {List<int> bookings = const [120, 120]}) : config = _config(names, bookings: bookings);

  int get roundCount => history.isEmpty ? 0 : history.last.roundNumber;
  List<Player> get active => [
    for (final p in config.players)
      if (!withdrawn.contains(p.id)) p,
  ];

  EndlessRound next({List<String>? draw, int seed = 7}) {
    final n = roundCount + 1;
    final round = EndlessRoundGenerator.generateMexicanoRound(
      players: active,
      courts: config.courts,
      history: history,
      roundNumber: n,
      seed: seed,
      format: _fmt,
      draw: draw == null ? null : drawOf(draw),
    )!;
    history.addAll(round.matches);
    resting[n] = [for (final p in round.resting) p.id];
    return round;
  }

  /// Skor round [n] per match (urut court), sisi atas–bawah.
  void score(int n, List<(int, int)> scores) {
    final ids = [
      for (final m in history)
        if (m.roundNumber == n) m.id,
    ];
    for (final (i, id) in ids.indexed.take(scores.length)) {
      final k = history.indexWhere((m) => m.id == id);
      history[k] = history[k].withScore([SetScore(side1: scores[i].$1, side2: scores[i].$2)]);
    }
  }

  Map<String, PlayerStanding> standings() => {
    for (final s in RankingCalculator.rank(
      players: config.players,
      matches: history,
      method: RankingMethod.totalGames,
      format: _fmt,
    ))
      s.player.id: s,
  };

  ActiveTournament get tournament => ActiveTournament(
    tournament: Tournament(id: 't-mexicano', createdAt: _start, config: config, matches: [...history]),
    restingPlayerIdsByRound: {...resting},
    withdrawnPlayerIds: {...withdrawn},
  );
}

/// "Citra 26 (+10)".
String _tp(Map<String, PlayerStanding> s, String id) => '$id ${s[id]!.totalPoint} (${s[id]!.diffLabel})';

/// Pemain yang main di [matches].
Set<String> _playersOf(Iterable<MatchGame> matches) => {
  for (final m in matches) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
};

/// Skor sah Americano 21 yang dipakai di test controller (bergiliran per match).
const _scores = [(15, 6), (9, 12), (11, 10), (8, 13), (14, 7), (10, 11)];

void main() {
  group('ScoreFormat.forMexicano (keputusan 34)', () {
    test('Race to / Best of → Americano 21; Americano N tetap', () {
      expect(const ScoreFormat(ScoringMethod.raceTo, 6).forMexicano, _fmt);
      expect(const ScoreFormat(ScoringMethod.bestOf, 5).forMexicano, _fmt);
      expect(
        const ScoreFormat(ScoringMethod.americano, 24).forMexicano,
        const ScoreFormat(ScoringMethod.americano, 24),
      );
    });

    test('PartnerMode: Mexicano di akhir enum, label, isEndless', () {
      expect(PartnerMode.values.last, PartnerMode.mexicano);
      expect(PartnerMode.mexicano.label, 'Mexicano');
      expect([for (final m in PartnerMode.values) m.isEndless], [false, true, true]);
    });
  });

  group('undian terkunci (logic.md §14.2)', () {
    test('lockedDraw identik dengan undian priorityOrder lama: Random(seed + round) dibagikan urut id', () {
      final players = [for (final n in _names14b.reversed) Player(id: n, name: n)];
      for (final (seed, round) in [(0, 1), (138734806, 3), (4242, 9)]) {
        final rng = Random(seed + round);
        final old = {
          for (final id in [..._names14b]..sort()) id: rng.nextInt(1 << 30),
        };
        expect(EndlessRoundGenerator.lockedDraw(players.map((p) => p.id), seed: seed, roundNumber: round), old);
        List<String> order({Map<String, int>? draw}) => [
          for (final p in EndlessRoundGenerator.priorityOrder(
            players: players,
            history: const [],
            roundNumber: round,
            seed: seed,
            slots: 8,
            draw: draw,
          ))
            p.id,
        ];
        expect(order(), order(draw: old));
      }
    });

    test('undian urutan Mexicano = lockedDraw(semua pemain aktif, seed, n), bukan undian pemain yang main saja', () {
      // 14B setelah R1 (Indra, Joko istirahat): di R2 empat pasang pemain seri, jadi undian menentukan urutan.
      final sim = _Sim(_names14b)..next(draw: _names14b);
      sim.score(1, [(15, 6), (9, 12)]);
      var differs = 0;
      for (var seed = 0; seed < 60; seed++) {
        final all = EndlessRoundGenerator.lockedDraw(_names14b, seed: seed, roundNumber: 2);
        EndlessRound gen(Map<String, int>? draw) => EndlessRoundGenerator.generateMexicanoRound(
          players: sim.active,
          courts: sim.config.courts,
          history: sim.history,
          roundNumber: 2,
          seed: seed,
          format: _fmt,
          draw: draw,
        )!;
        final real = gen(null);
        expect(real.matches.map(_m), gen(all).matches.map(_m), reason: 'seed $seed');
        // Kelompok per court dari urutan Mexicano dengan undian tertentu, dibanding kelompok hasil generator.
        final playing = [
          for (final p in sim.active)
            if (_playersOf(real.matches).contains(p.id)) p,
        ];
        List<Set<String>> groups(Map<String, int> draw) {
          final ranked = EndlessRoundGenerator.mexicanoOrder(playing, sim.history, _fmt, draw);
          return [
            for (var i = 0; i < ranked.length; i += 4) {for (final p in ranked.sublist(i, i + 4)) p.id},
          ];
        }

        final actual = [
          for (final m in real.matches) _playersOf([m]),
        ];
        expect(actual, groups(all), reason: 'seed $seed');
        final partial = EndlessRoundGenerator.lockedDraw(playing.map((p) => p.id), seed: seed, roundNumber: 2);
        if (groups(partial).toString() != actual.toString()) differs++;
      }
      expect(differs, greaterThan(0), reason: 'undian sebagian pemain harus memberi round lain untuk sebagian seed');
    });
  });

  group('AC-M4 / AC-M5 contoh 14A (8 pemain, 2 court)', () {
    _Sim upToR2() {
      final sim = _Sim(_names14a)..next(draw: _names14a);
      sim.score(1, [(15, 6), (9, 12)]);
      sim.next(draw: ['Citra', 'Andi', 'Fajar', 'Hadi', 'Gita', 'Eko', 'Budi', 'Dewi']);
      sim.score(2, [(11, 10), (8, 13)]);
      return sim;
    }

    test('AC-M4 R1 dan R2 sama persis dengan tabel 14.6, termasuk court, sisi atas, dan urutan nama', () {
      final sim = upToR2();
      expect(_round(sim.history, 1), ['Andi·Citra vs Budi·Dewi', 'Eko·Gita vs Fajar·Hadi']);
      expect(_round(sim.history, 2), ['Citra·Fajar vs Andi·Hadi', 'Gita·Budi vs Eko·Dewi']);
      for (final n in [1, 2]) {
        expect([for (final m in sim.history.where((m) => m.roundNumber == n)) m.courtId], ['c1', 'c2']);
        expect([for (final m in sim.history.where((m) => m.roundNumber == n)) m.id], ['m-r$n-1', 'm-r$n-2']);
      }
      expect(sim.resting[1], isEmpty);
    });

    test('AC-M5 setelah R2: Total Point + selisih, Hadi dan Eko sama-sama #4, jumlah 168', () {
      final sim = upToR2();
      final s = sim.standings();
      expect(
        [
          for (final id in ['Citra', 'Andi', 'Fajar', 'Hadi', 'Eko', 'Dewi', 'Gita', 'Budi']) _tp(s, id),
        ],
        [
          'Citra 26 (+10)',
          'Andi 25 (+8)',
          'Fajar 23 (+4)',
          'Hadi 22 (+2)',
          'Eko 22 (+2)',
          'Dewi 19 (−4)',
          'Gita 17 (−8)',
          'Budi 14 (−14)',
        ],
      );
      expect(s.values.fold(0, (sum, x) => sum + x.totalPoint), 168);
      final entries = standingEntries(
        standings: RankingCalculator.rank(
          players: sim.config.players,
          matches: sim.history,
          method: RankingMethod.totalGames,
          format: _fmt,
        ),
        method: RankingMethod.totalGames,
      );
      expect(
        {for (final e in entries) e.players.single.id: e.position},
        {'Citra': 1, 'Andi': 2, 'Fajar': 3, 'Eko': 4, 'Hadi': 4, 'Dewi': 5, 'Gita': 6, 'Budi': 7},
      );
    });

    test('AC-M4 R3 (a) undian Hadi di atas Eko: beban 2/0/2 → B di kedua court', () {
      final sim = upToR2()..next(draw: ['Andi', 'Budi', 'Citra', 'Dewi', 'Hadi', 'Eko', 'Fajar', 'Gita']);
      expect(_round(sim.history, 3), ['Citra·Hadi vs Andi·Fajar', 'Eko·Budi vs Dewi·Gita']);
    });

    test('AC-M4 R3 (b) undian Eko di atas Hadi: beban 1/0/1 → B di kedua court', () {
      final sim = upToR2()..next(draw: ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Hadi', 'Fajar', 'Gita']);
      expect(_round(sim.history, 3), ['Citra·Eko vs Andi·Fajar', 'Hadi·Budi vs Dewi·Gita']);
    });

    test('AC-M4 susunan: beban A/B/C R3 (a) dan (b) sesuai tabel', () {
      final sim = upToR2();
      int load(List<String> p, (int, int, int, int) o) {
        int count(String a, String b) =>
            sim.history.where((m) => [m.pair1, m.pair2].any((x) => x.contains(a) && x.contains(b))).length;
        return count(p[o.$1], p[o.$2]) + count(p[o.$3], p[o.$4]);
      }

      const options = [(0, 2, 1, 3), (0, 3, 1, 2), (0, 1, 2, 3)];
      List<int> loads(List<String> p) => [for (final o in options) load(p, o)];
      expect(loads(['Citra', 'Andi', 'Fajar', 'Hadi']), [2, 0, 2]);
      expect(loads(['Eko', 'Dewi', 'Gita', 'Budi']), [2, 0, 2]);
      expect(loads(['Citra', 'Andi', 'Fajar', 'Eko']), [1, 0, 1]);
      expect(loads(['Hadi', 'Dewi', 'Gita', 'Budi']), [1, 0, 1]);
    });

    test('AC-M15 WO R2 Court 2 (Gita · Budi absen): Eko 20, Dewi 17, Gita 9, Budi 6; R3 = R3 (a) undian apa pun', () {
      for (final draw in [
        ['Andi', 'Budi', 'Citra', 'Dewi', 'Hadi', 'Eko', 'Fajar', 'Gita'],
        ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Hadi', 'Fajar', 'Gita'],
        _names14a.reversed.toList(),
      ]) {
        final sim = _Sim(_names14a)..next(draw: _names14a);
        sim.score(1, [(15, 6), (9, 12)]);
        sim.next(draw: ['Citra', 'Andi', 'Fajar', 'Hadi', 'Gita', 'Eko', 'Budi', 'Dewi']);
        sim.score(2, [(11, 10)]);
        final k = sim.history.indexWhere((m) => m.id == 'm-r2-2');
        sim.history[k] = sim.history[k].asWalkover(loserPairId: sim.history[k].pair1.id, reason: WoReason.absent);
        final s = sim.standings();
        expect(
          [
            for (final id in ['Eko', 'Dewi', 'Gita', 'Budi']) _tp(s, id),
          ],
          ['Eko 20 (−3)', 'Dewi 17 (−9)', 'Gita 9 (−3)', 'Budi 6 (−9)'],
        );
        sim.next(draw: draw);
        expect(_round(sim.history, 3), ['Citra·Hadi vs Andi·Fajar', 'Eko·Budi vs Dewi·Gita']);
      }
    });
  });

  group('AC-M6 contoh 14B (10 pemain, 2 court) + 16g', () {
    _Sim upToR2() {
      final sim = _Sim(_names14b)..next(draw: _names14b);
      sim.score(1, [(15, 6), (9, 12)]);
      sim.next(draw: ['Budi', 'Gita', 'Andi', 'Eko', 'Indra', 'Dewi', 'Fajar', 'Joko', 'Citra', 'Hadi']);
      return sim;
    }

    test('AC-M6 R1 Indra, Joko istirahat, match = 14A R1; R2 Citra, Hadi istirahat, match sama persis', () {
      final sim = upToR2();
      expect(sim.resting[1], ['Indra', 'Joko']);
      expect(_round(sim.history, 1), ['Andi·Citra vs Budi·Dewi', 'Eko·Gita vs Fajar·Hadi']);
      expect(sim.resting[2]!.toSet(), {'Citra', 'Hadi'});
      expect(_round(sim.history, 2), ['Andi·Gita vs Fajar·Eko', 'Budi·Indra vs Dewi·Joko']);
    });

    test('AC-M6 R3–R5 dengan undian asli: R3 Citra, Hadi, Indra, Joko main; setelah R5 semua 4 match', () {
      final sim = upToR2();
      sim.score(2, [(12, 9), (10, 11)]);
      for (var n = 3; n <= 5; n++) {
        sim.next();
        if (n == 3) {
          final playing = _playersOf(sim.history.where((m) => m.roundNumber == 3));
          expect(playing.containsAll(['Citra', 'Hadi', 'Indra', 'Joko']), isTrue);
        }
        sim.score(n, [(13, 8), (7, 14)]);
      }
      final s = sim.standings();
      expect({for (final id in _names14b) s[id]!.matchesPlayed}, {4});
    });

    test('16g fixture: R2 12–9, 10–11, Gita keluar, R3 Budi istirahat, A di kedua court', () {
      final sim = upToR2();
      sim.score(2, [(12, 9), (10, 11)]);
      final s = sim.standings();
      expect(
        [
          for (final id in ['Andi', 'Gita', 'Fajar', 'Eko', 'Dewi', 'Budi', 'Citra', 'Hadi', 'Joko', 'Indra'])
            _tp(s, id),
        ],
        [
          'Andi 27 (+12)',
          'Gita 21 (0)',
          'Fajar 21 (0)',
          'Eko 18 (−6)',
          'Dewi 17 (−8)',
          'Budi 16 (−10)',
          'Citra 15 (+9)',
          'Hadi 12 (+3)',
          'Joko 11 (+1)',
          'Indra 10 (−1)',
        ],
      );
      expect(s.values.fold(0, (sum, x) => sum + x.totalPoint), 168);
      sim.withdrawn.add('Gita');
      sim.next(draw: ['Citra', 'Hadi', 'Indra', 'Joko', 'Andi', 'Dewi', 'Eko', 'Fajar', 'Budi']);
      expect(sim.resting[3], ['Budi']);
      expect(_round(sim.history, 3), ['Andi·Eko vs Fajar·Dewi', 'Citra·Joko vs Hadi·Indra']);
    });
  });

  test('AC-M7 contoh 14C (4 pemain, 1 court): R2 A, R3 B, R4 A dengan semua beban 2', () {
    final sim = _Sim(['Andi', 'Budi', 'Citra', 'Dewi'], bookings: [120])..next(draw: ['Andi', 'Budi', 'Citra', 'Dewi']);
    expect(_round(sim.history, 1), ['Andi·Citra vs Budi·Dewi']);
    sim.score(1, [(12, 9)]);
    sim.next(draw: ['Andi', 'Citra', 'Budi', 'Dewi']);
    expect(_round(sim.history, 2), ['Andi·Budi vs Citra·Dewi']);
    sim.score(2, [(10, 11)]);
    final s3 = sim.standings();
    expect(
      [
        for (final id in ['Citra', 'Andi', 'Dewi', 'Budi']) _tp(s3, id),
      ],
      ['Citra 23 (+4)', 'Andi 22 (+2)', 'Dewi 20 (−2)', 'Budi 19 (−4)'],
    );
    sim.next();
    expect(_round(sim.history, 3), ['Citra·Budi vs Andi·Dewi']);
    sim.score(3, [(14, 7)]);
    expect(sim.standings().values.fold(0, (sum, x) => sum + x.totalPoint), 126);
    sim.next();
    expect(_round(sim.history, 4), ['Citra·Andi vs Budi·Dewi']);
    expect(sim.resting.values.every((r) => r.isEmpty), isTrue);
  });

  group('controller', () {
    late ProviderContainer container;
    late TournamentController controller;
    late DateTime now;
    ActiveTournament read() => container.read(tournamentProvider)!;

    ProviderContainer make([ActiveTournament? loaded]) {
      final c = ProviderContainer(
        overrides: [
          if (loaded != null) tournamentProvider.overrideWith(() => LoadedTournament(loaded)),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      addTearDown(c.dispose);
      return c;
    }

    void start(List<String> names, {List<int> bookings = const [120, 120]}) {
      now = _start;
      container = make();
      controller = container.read(tournamentProvider.notifier);
      controller.startIfNeeded(_config(names, bookings: bookings));
    }

    void scoreLast() {
      for (final (i, m) in read().matchesOfRound(read().roundCount).indexed) {
        final (a, b) = _scores[i % _scores.length];
        controller.submitScore(m.id, [SetScore(side1: a, side2: b)]);
      }
      now = now.add(const Duration(minutes: 15));
    }

    /// Round berikutnya yang dibuat generator langsung dari [active] (pemanggilan sama dengan controller).
    List<String> expected(ActiveTournament active) => [
      for (final m in EndlessRoundGenerator.generateMexicanoRound(
        players: active.activePlayers,
        courts: active.courtsAvailableAt(now),
        history: active.matches,
        roundNumber: active.roundCount + 1,
        seed: active.drawSeed,
        format: _fmt,
        draw: EndlessRoundGenerator.lockedDraw(
          active.activePlayers.map((p) => p.id),
          seed: active.drawSeed,
          roundNumber: active.roundCount + 1,
        ),
      )!.matches)
        _m(m),
    ];

    test('AC-M3 startIfNeeded Mexicano langsung membuat R1 (tanpa jadwal awal), memakai undian asli', () {
      start(_names14a);
      final active = read();
      expect(active.roundCount, 1);
      expect(active.matchesOfRound(1).length, 2);
      final empty = ActiveTournament(
        tournament: Tournament(id: active.tournament.id, createdAt: _start, config: active.config),
      );
      expect(_round(active.matches, 1), expected(empty));
    });

    test('turunan isEndless: runningRound, canManageCourts, canCancelLastRound, canResume, isFinal', () {
      start(_names14a);
      expect(read().runningRound, 1);
      expect(read().canManageCourts, isTrue);
      expect(read().canCancelLastRound, isFalse, reason: 'R1 tidak pernah dibatalkan');
      scoreLast();
      controller.generateNextRound();
      expect(read().canCancelLastRound, isTrue);
      expect(read().isFinal(now), isFalse);
      expect(read().canResume(now), isFalse);
      now = _start.add(const Duration(hours: 3));
      expect(read().canResume(now), isTrue);
      scoreLast();
      expect(read().isFinal(now), isTrue);
      controller.resume({'c1': 60});
      expect(read().canGenerateNextRound(now), isTrue, reason: 'Lanjutkan berlaku untuk Mexicano');
    });

    test('AC-M10 tab Klasemen Win % vs Total Point → R(n+1) sama persis', () {
      // 14A setelah R2: urutan Win % berbeda dengan Total Point (Gita 1 menang, Hadi 1 menang …).
      final sim = _Sim(_names14a)..next(draw: _names14a);
      sim.score(1, [(15, 6), (9, 12)]);
      sim.next(draw: ['Citra', 'Andi', 'Fajar', 'Hadi', 'Gita', 'Eko', 'Budi', 'Dewi']);
      sim.score(2, [(11, 10), (8, 13)]);
      now = _start.add(const Duration(minutes: 30));
      final rounds = <List<String>>[];
      for (final method in [RankingMethod.winPercent, RankingMethod.totalGames]) {
        final c = make(sim.tournament);
        c.read(rankingMethodProvider.notifier).state = method;
        c.read(standingsProvider);
        c.read(tournamentProvider.notifier).generateNextRound();
        rounds.add(_round(c.read(tournamentProvider)!.matches, 3));
      }
      expect(rounds[0], hasLength(2));
      expect(rounds[0], rounds[1]);
    });

    test('AC-M11 daftar Istirahat · Prioritas main / Istirahat lagi = hasil Buat R(n+1), apa pun skornya', () {
      start(_names14b, bookings: [120]);
      final shown = EndlessRoundGenerator.restingAfterLastRound(read(), now.add(const Duration(minutes: 15)));
      expect(shown.priority, hasLength(4));
      expect(shown.later, hasLength(2));
      for (final scores in [_scores, _scores.reversed.toList()]) {
        for (final m in read().matchesOfRound(1)) {
          controller.submitScore(m.id, [SetScore(side1: scores[0].$1, side2: scores[0].$2)]);
        }
        now = _start.add(const Duration(minutes: 15));
        controller.generateNextRound();
        final playing = _playersOf(read().matchesOfRound(2));
        expect(playing.containsAll(shown.priority.map((p) => p.id)), isTrue);
        expect(read().restingPlayerIdsByRound[2]!.toSet().containsAll(shown.later.map((p) => p.id)), isTrue);
        controller.cancelLastRound();
      }
    });

    test('AC-M12 Batalkan R3 lalu Buat R3 → identik; Batalkan, keluarkan Gita, Buat R3 → tanpa Gita', () {
      start(_names14a);
      scoreLast();
      controller.generateNextRound();
      scoreLast();
      controller.generateNextRound();
      final r3 = _round(read().matches, 3);
      final resting3 = read().restingPlayerIdsByRound[3];
      controller.cancelLastRound();
      expect(read().roundCount, 2);
      controller.generateNextRound();
      expect(_round(read().matches, 3), r3);
      expect(read().restingPlayerIdsByRound[3], resting3);
      controller.cancelLastRound();
      expect(controller.withdrawPlayer('Gita'), isTrue);
      final before = read();
      controller.generateNextRound();
      final again = read().matchesOfRound(3);
      expect(again.any((m) => m.pair1.contains('Gita') || m.pair2.contains('Gita')), isFalse);
      expect(_round(read().matches, 3), expected(before));
    });

    test('AC-M13 koreksi skor R2 setelah R3 dibuat: R3 tetap, Klasemen berubah, R4 dari angka baru', () {
      start(_names14a);
      scoreLast();
      controller.generateNextRound();
      scoreLast();
      controller.generateNextRound();
      final r3 = _round(read().matches, 3);
      final standingsBefore = {for (final s in container.read(standingsProvider)) s.player.id: s.totalPoint};
      final r2c2 = read().matchesOfRound(2)[1];
      controller.submitScore(r2c2.id, const [SetScore(side1: 2, side2: 19)]);
      expect(_round(read().matches, 3), r3);
      final standingsAfter = {for (final s in container.read(standingsProvider)) s.player.id: s.totalPoint};
      expect(standingsAfter, isNot(standingsBefore));
      scoreLast();
      final before = read();
      controller.generateNextRound();
      expect(_round(read().matches, 4), expected(before));
    });

    test('AC-M14 kill setelah skor R2 lengkap → decode → Buat R3 sama persis dengan tanpa kill', () {
      start(_names14b);
      scoreLast();
      controller.generateNextRound();
      scoreLast();
      final reopened = TournamentCodec.decode(TournamentCodec.encode(read()))!;
      controller.generateNextRound();
      final c = make(reopened);
      c.read(tournamentProvider.notifier).generateNextRound();
      final after = c.read(tournamentProvider)!;
      expect(_round(after.matches, 3), _round(read().matches, 3));
      expect(after.restingPlayerIdsByRound[3], read().restingPlayerIdsByRound[3]);
    });

    test('AC-M16 Kembalikan (16g): keluar setelah R2 dibuat → bisa; R3 tanpa dia → tidak; Batalkan R3 → bisa lagi', () {
      start(_names14b);
      scoreLast();
      controller.generateNextRound();
      expect(controller.withdrawPlayer('Gita'), isTrue);
      expect(read().canReinstate('Gita'), isTrue);
      expect(read().canReinstate('Andi'), isFalse, reason: 'tidak keluar');
      scoreLast();
      controller.generateNextRound();
      expect(read().canReinstate('Gita'), isFalse);
      final blocked = read();
      expect(controller.reinstatePlayer('Gita'), isNull);
      expect(identical(read(), blocked), isTrue, reason: 'ditolak tanpa mengubah state');
      expect(read().withdrawnPlayerIds, {'Gita'});
      controller.cancelLastRound();
      expect(read().canReinstate('Gita'), isTrue);
      expect(controller.reinstatePlayer('Gita'), isNull);
      expect(read().withdrawnPlayerIds, isEmpty);
      expect(read().latePlayerIds, isEmpty);
    });

    test('AC-M16 Mexicano: tambah pemain tidak ada, Keluarkan mati saat aktif 4', () {
      start(['Andi', 'Budi', 'Citra', 'Dewi', 'Eko']);
      final before = read();
      expect(controller.addPlayer('Fajar'), isNull);
      expect(identical(read(), before), isTrue);
      expect(controller.withdrawPlayer('Eko'), isTrue);
      expect(read().canWithdraw('Dewi'), isFalse);
      expect(controller.withdrawPlayer('Dewi'), isFalse);
    });

    test(
      'AC-M17 Kelola court: 12 pemain / 2 court, R1 berjalan, tambah Court 3 → 4 istirahat, susunan A dari undian R1',
      () {
        start([..._names14b, 'Kiki', 'Lina']);
        now = _start.add(const Duration(minutes: 5));
        final active = read();
        final draw1 = EndlessRoundGenerator.lockedDraw(
          active.activePlayers.map((p) => p.id),
          seed: active.drawSeed,
          roundNumber: 1,
        );
        final resting = active.restingPlayerIdsByRound[1]!;
        expect(resting, hasLength(4));
        controller.addCourt(name: '', colorIndex: 2, bookingMinutes: 120);
        final added = read().matchesOfRound(1).last;
        expect(read().matchesOfRound(1), hasLength(3));
        expect(added.courtId, read().config.courts[2].id);
        final four = [...resting]..sort((a, b) => draw1[a]!.compareTo(draw1[b]!));
        expect(_m(added), '${four[0]}·${four[2]} vs ${four[1]}·${four[3]}');
        expect(read().restingPlayerIdsByRound[1], isEmpty);
        scoreLast();
        final before = read();
        controller.generateNextRound();
        final r2 = read().matchesOfRound(2);
        expect([for (final m in r2) m.courtId], [for (final c in read().config.courts) c.id]);
        expect(_round(read().matches, 2), expected(before));
        // Kelompok teratas (urutan Mexicano) di Court 1.
        final draw2 = EndlessRoundGenerator.lockedDraw(
          before.activePlayers.map((p) => p.id),
          seed: before.drawSeed,
          roundNumber: 2,
        );
        final top = EndlessRoundGenerator.mexicanoOrder(before.activePlayers, before.matches, _fmt, draw2).take(4);
        expect({...r2.first.pair1.playerIds, ...r2.first.pair2.playerIds}, {for (final p in top) p.id});
      },
    );

    test('AC-M18 Court 1 habis lebih dulu (menit 60) → R5 kelompok teratas di Court 2, berikutnya Court 3', () {
      start(_names14a, bookings: [60, 120, 120]);
      for (var n = 1; n <= 4; n++) {
        expect([for (final m in read().matchesOfRound(n)) m.courtId], ['c1', 'c2'], reason: 'R$n');
        scoreLast();
        if (n < 4) controller.generateNextRound();
      }
      expect(now, _start.add(const Duration(minutes: 60)));
      final before = read();
      controller.generateNextRound();
      final r5 = read().matchesOfRound(5);
      expect([for (final m in r5) m.courtId], ['c2', 'c3']);
      final draw = EndlessRoundGenerator.lockedDraw(_names14a, seed: before.drawSeed, roundNumber: 5);
      final top = EndlessRoundGenerator.mexicanoOrder(before.activePlayers, before.matches, _fmt, draw).take(4);
      expect({...r5.first.pair1.playerIds, ...r5.first.pair2.playerIds}, {for (final p in top) p.id});
    });

    test('AC-M17 courtMatch Mexicano tanpa Random: random berbeda → match sama (jebakan 4)', () {
      start([..._names14b, 'Kiki', 'Lina']);
      now = _start.add(const Duration(minutes: 5));
      final active = read();
      final court = active.newCourt(id: 'baru', name: '', colorIndex: 2, bookingMinutes: 120, now: now);
      final next = active.withCourt(court);
      final use = EndlessRoundGenerator.courtUse(next, 'baru', now);
      expect(use.use, CourtUse.now);
      final a = EndlessRoundGenerator.courtMatch(next, 'baru', use.players, random: Random(1));
      final b = EndlessRoundGenerator.courtMatch(next, 'baru', use.players, random: Random(99));
      expect(_m(a), _m(b));
    });
  });
}
