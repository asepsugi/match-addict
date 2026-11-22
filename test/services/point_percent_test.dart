import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';

import '../hifi/screens/ranking_fixture.dart';
import 'point_percent_fixture.dart';
import 'sparing_score_fixture.dart';

/// Point % (PRD §18, logic.md §20). Angka = tabel 20.8, dihitung ulang dari aturan bilangan bulat.

List<PlayerStanding> _rank(
  Iterable<Player> players,
  List<MatchGame> matches,
  ScoreFormat format, [
  RankingMethod method = RankingMethod.pointPercent,
]) => RankingCalculator.rank(players: players.toList(), matches: matches, method: method, format: format);

List<PlayerStanding> _rankNames(
  List<String> names,
  List<MatchGame> matches,
  ScoreFormat format, [
  RankingMethod method = RankingMethod.pointPercent,
]) => _rank(playersOf(names), matches, format, method);

/// "Budi 36/63 57 +9": didapat/dimainkan, Point %, selisih.
String _row(PlayerStanding s) => '${s.player.name} ${s.totalPoint}/${s.pointsPlayed} ${s.pointPercent} ${s.diffLabel}';

/// Seperti [_row] tapi nama = kata pertama (fixture hi-fi memakai nama keluarga: "Budi S").
String _firstName(PlayerStanding s) => _row(s).replaceFirst(s.player.name, s.player.name.split(' ').first);

/// Nomor per label baris (yang belum main tidak bernomor).
Map<String, int> _numbers(
  List<PlayerStanding> ranked, {
  RankingMethod method = RankingMethod.pointPercent,
  List<Pair>? fixedPairs,
}) => {
  for (final e in standingEntries(standings: ranked, method: method, fixedPairs: fixedPairs))
    if (e.position != null) e.label: e.position!,
};

PlayerStanding _s(int won, int lost, {int wins = 1, int losses = 0}) => PlayerStanding(
  player: const Player(id: 'x', name: 'x'),
  wins: wins,
  losses: losses,
  gamesWon: won,
  gamesLost: lost,
);

void main() {
  group('20.8 data uji', () {
    test('AC-RP3 18A: Point % #1 Budi; Total Point dan Win % memberi urutan lain', () {
      final byPoint = _rankNames(names18a, matches18a, americano21);
      expect(
        [for (final s in byPoint) _row(s)],
        ['Budi 36/63 57 +9', 'Dewi 33/63 52 +3', 'Andi 41/84 49 −2', 'Citra 29/63 46 −5', 'Eko 29/63 46 −5'],
      );
      expect(_numbers(byPoint), {'Budi': 1, 'Dewi': 2, 'Andi': 3, 'Citra': 4, 'Eko': 4});
      expect(byPoint.fold(0, (sum, s) => sum + s.totalPoint), 168);

      final byTotal = _rankNames(names18a, matches18a, americano21, RankingMethod.totalGames);
      expect(_numbers(byTotal, method: RankingMethod.totalGames), {
        'Andi': 1,
        'Budi': 2,
        'Dewi': 3,
        'Citra': 4,
        'Eko': 4,
      });
      final byWin = _rankNames(names18a, matches18a, americano21, RankingMethod.winPercent);
      expect([for (final s in byWin) s.player.name], ['Budi', 'Dewi', 'Andi', 'Eko', 'Citra']);
      expect(_numbers(byWin, method: RankingMethod.winPercent), {
        'Budi': 1,
        'Dewi': 2,
        'Andi': 3,
        'Eko': 4,
        'Citra': 5,
      });
    });

    test('AC-RP4 18B: Fixed Race to 6, Win % default vs Point %', () {
      final pairs = pairs18b.values.toList();
      final byWin = _rankNames(names18b, matches18b, raceTo6, RankingMethod.winPercent);
      expect(_numbers(byWin, method: RankingMethod.winPercent, fixedPairs: pairs), {
        'E + F': 1,
        'C + D': 2,
        'A + B': 3,
        'G + H': 4,
      });
      final byPoint = _rankNames(names18b, matches18b, raceTo6);
      final rows = {for (final s in byPoint) s.player.id: _row(s)};
      expect(rows['E'], 'E 18/25 72 +11');
      expect(rows['A'], 'A 16/28 57 +4');
      expect(rows['C'], 'C 12/28 43 −4');
      expect(rows['G'], 'G 7/25 28 −11');
      expect(_numbers(byPoint, fixedPairs: pairs), {'E + F': 1, 'A + B': 2, 'C + D': 3, 'G + H': 4});
      expect(byPoint.fold(0, (sum, s) => sum + s.totalPoint), 53 * 2);
    });

    test('AC-RP5 18C: WO — Budi 17, Andi 14, kalah 16; Point % per pemain', () {
      final ranked = _rankNames(names18c, matches18c, americano21);
      expect(
        [for (final s in ranked) _row(s)],
        [
          'Budi 51/59 86 +26',
          'Andi 42/56 75 +14',
          'Fajar 33/63 52 +3',
          'Gita 33/63 52 +3',
          'Hadi 33/63 52 +3',
          'Eko 27/63 43 −9',
          'Citra 11/58 19 −20',
          'Dewi 11/58 19 −20',
        ],
      );
      final woValues = RankingCalculator.woWinnerValues(
        players: playersOf(names18c),
        matches: matches18c,
        format: americano21,
      );
      expect((woValues['Andi'], woValues['Budi']), (14, 17));
      expect(RankingCalculator.woPairValue(woValues['Andi']!, woValues['Budi']!), 16);
      final byId = {for (final s in ranked) s.player.id: s};
      expect((byId['Citra']!.woPointsConceded, byId['Dewi']!.woPointsConceded), (16, 16));
      expect(byId['Andi']!.woPointsConceded, 0);
      expect(_numbers(ranked)['Citra'], 5);
      expect(ranked.fold(0, (sum, s) => sum + s.totalPoint), 241);
    });

    test('AC-RP5 18C-hapus: WO jadi pending → Andi 67, Budi 81, Citra = Dewi 26; selisih tetap', () {
      final ranked = {for (final s in _rankNames(names18c, matches18cHapus, americano21)) s.player.id: s};
      expect(ranked['Andi']!.pointPercent, 67);
      expect((ranked['Andi']!.totalPoint, ranked['Andi']!.pointsPlayed), (28, 42));
      expect(ranked['Budi']!.pointPercent, 81);
      expect((ranked['Citra']!.pointPercent, ranked['Dewi']!.pointPercent), (26, 26));
      expect((ranked['Andi']!.gameDiff, ranked['Citra']!.gameDiff), (14, -20));
    });

    test('AC-RP6 18E: Point % dari bilangan bulat; batas ,5 naik; nomor dari angka bulat', () {
      final sari = _s(66, 60);
      final qori = _s(44, 40);
      final rani = _s(65, 61);
      final tono = _s(64, 62);
      expect([sari, qori, rani, tono].map((s) => s.pointPercent), [52, 52, 52, 51]);
      // Selisih memisah angka bulat yang sama: Sari +6, Qori +4, Rani +4, Tono +2.
      final ranked = [sari, qori, rani, tono]
        ..sort((a, b) => RankingCalculator.compare(a, b, RankingMethod.pointPercent));
      expect(ranked.map((s) => s.gameDiff), [6, 4, 4, 2]);
      expect(_s(5, 3).pointPercent, 63, reason: 'Best of 5: 3–0 lalu 2–3 → 5/8, 62,5 naik');
    });

    test('AC-RP6 bulat: tabel pembulatan dan 0/0', () {
      expect(
        {
          '5/3': _s(5, 3).pointPercent,
          '44/40': _s(44, 40).pointPercent,
          '65/61': _s(65, 61).pointPercent,
          '64/62': _s(64, 62).pointPercent,
          '16/14': _s(16, 14).pointPercent,
          '16/15': _s(16, 15).pointPercent,
          '10/10': _s(10, 10).pointPercent,
          '0/0': _s(0, 0).pointPercent,
        },
        {'5/3': 63, '44/40': 52, '65/61': 52, '64/62': 51, '16/14': 53, '16/15': 52, '10/10': 50, '0/0': 0},
      );
      expect(_s(0, 0).pointsPlayed, 0);
    });

    test('4.2: Dewi·Citra 16/14 (53) di atas Gita·Andi 16/15 (52) di Point %, kebalikan di Win %', () {
      final gita = _s(16, 15, wins: 2, losses: 1);
      final dewi = _s(16, 14, losses: 2);
      expect(RankingCalculator.compare(gita, dewi, RankingMethod.pointPercent), isPositive);
      expect(RankingCalculator.compare(gita, dewi, RankingMethod.winPercent), isNegative);
    });

    test('AC-RP8: seri 10–10 → 50%, nomor sama #1; pemain lain belum main', () {
      final names = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar'];
      final ranked = _rankNames(names, [mixedMatch(1, 'Andi', 'Budi', 'Citra', 'Dewi', 10, 10)], americano20);
      expect(ranked.take(4).map((s) => s.pointPercent), [50, 50, 50, 50]);
      expect(_numbers(ranked), {'Andi': 1, 'Budi': 1, 'Citra': 1, 'Dewi': 1});
      final idle = ranked.skip(4);
      expect(idle.every((s) => s.pointsPlayed == 0 && s.pointPercent == 0), isTrue);
      expect(standingEntries(standings: ranked, method: RankingMethod.pointPercent).last.position, isNull);
    });

    test('AC-RP12 13C: Sparing Fixed memakai pasangan sendiri, kalah WO 6 untuk G2', () {
      final end = fixedSparing(c13);
      final ranked = {
        for (final s in RankingCalculator.rank(
          players: end.config.players,
          matches: end.matches,
          method: RankingMethod.pointPercent,
          format: end.config.format,
        ))
          s.player.name: s,
      };
      expect((ranked['Eko']!.pointPercent, ranked['Andi']!.pointPercent, ranked['Gita']!.pointPercent), (72, 52, 47));
      expect((ranked['Citra']!.pointPercent, ranked['Citra']!.woPointsConceded), (43, 6));
      expect((ranked['Maya']!.pointPercent, ranked['Kiki']!.pointPercent, ranked['Indra']!.pointPercent), (64, 46, 29));
    });

    test('golden set1 (Americano 24): default Point %', () {
      final ranked = _rank(set1.config.players, set1.matches, set1.config.format);
      final byName = {for (final s in ranked) s.player.name.split(' ').first: s};
      expect(
        [
          for (final n in ['Andi', 'Dewant', 'Gina', 'Citra', 'Hana', 'Joko', 'Eko', 'Budi', 'Indra', 'Fajar'])
            _firstName(byName[n]!),
        ],
        [
          'Andi 42/72 58 +12',
          'Dewant 42/72 58 +12',
          'Gina 27/48 56 +6',
          'Citra 26/48 54 +4',
          'Hana 36/72 50 0',
          'Joko 23/48 48 −2',
          'Eko 22/48 46 −4',
          'Budi 20/48 42 −8',
          'Indra 20/48 42 −8',
          'Fajar 30/72 42 −12',
        ],
      );
      expect(byName['Gilang']!.pointsPlayed, 0);
    });

    test('golden set2: R2 C2 WO Dewant·Gina kalah; Budi 14 dan Joko 13 → kalah 14', () {
      final a = set2();
      final ranked = _rank(a.config.players, a.matches, a.config.format);
      expect(
        [for (final s in ranked) _firstName(s)],
        [
          'Budi 42/62 68 +8',
          'Eko 43/72 60 +14',
          'Andi 41/72 57 +10',
          'Indra 25/48 52 +2',
          'Joko 30/61 49 −14',
          'Fajar 34/72 47 −4',
          'Hana 21/48 44 −6',
          'Citra 31/72 43 −10',
          'Dewant 25/62 40 +2',
          'Gina 23/62 37 −2',
        ],
      );
      final byName = {for (final s in ranked) s.player.name.split(' ').first: s};
      expect((byName['Dewant']!.woPointsConceded, byName['Gina']!.woPointsConceded), (14, 14));
    });
  });

  group('20.9 invariant (turnamen acak berseed, ±10% WO)', () {
    /// Match acak: pemain diacak per round, 2 vs 2; Fixed memakai pasangan tetap.
    ({List<Player> players, List<MatchGame> matches, ScoreFormat format}) build(int seed) {
      final r = Random(seed);
      final n = 4 + r.nextInt(9);
      final names = [for (var i = 0; i < n; i++) 'P$i'];
      final format = [americano21, americano20, raceTo6, const ScoreFormat(ScoringMethod.bestOf, 5)][seed % 4];
      final fixed = seed % 3 == 0;
      final matches = <MatchGame>[];
      final rounds = 3 + r.nextInt(5);
      for (var round = 1; round <= rounds; round++) {
        final order = [...names]..shuffle(r);
        for (var c = 0; c + 4 <= order.length && c < 8; c += 4) {
          final p = order.sublist(c, c + 4);
          final a = fixed ? ['P0', 'P1'] : p.take(2).toList();
          final b = fixed ? ['P2', 'P3'] : p.skip(2).toList();
          if (fixed && c > 0) break;
          final m = mixedMatch(round, a[0], a[1], b[0], b[1], 0, 0, number: c ~/ 4 + 1);
          if (r.nextInt(10) == 0) {
            matches.add(mixedMatch(round, a[0], a[1], b[0], b[1], null, null, number: c ~/ 4 + 1));
          } else {
            final total = format.method == ScoringMethod.americano ? format.target : 0;
            final s1 = format.method == ScoringMethod.americano ? r.nextInt(total + 1) : r.nextInt(7);
            final s2 = format.method == ScoringMethod.americano ? total - s1 : r.nextInt(7);
            matches.add(
              MatchGame(
                id: m.id,
                roundNumber: round,
                matchNumberInRound: m.matchNumberInRound,
                courtId: m.courtId,
                pair1: m.pair1,
                pair2: m.pair2,
              ).withScore([SetScore(side1: s1, side2: s2)]),
            );
          }
        }
      }
      return (players: playersOf(names), matches: matches, format: format);
    }

    for (var seed = 1; seed <= 40; seed++) {
      test('seed $seed', () {
        final t = build(seed);
        final all = {for (final s in _rank(t.players, t.matches, t.format)) s.player.id: s};

        // 1. Rentang, bulat, tanpa NaN; main → dimainkan ≥ 1 (kecuali match 0–0).
        for (final s in all.values) {
          expect(s.pointPercent, inInclusiveRange(0, 100));
          if (s.pointsPlayed == 0) expect(s.pointPercent, 0);
        }

        // 2. Σ didapat = Σ skor × 2 pemain + Σ nilai WO pemenang; Σ kalah WO = woPairValue × 2 per match WO.
        final played = <String, ({int games, int count})>{};
        var expectedGot = 0;
        for (final m in t.matches.where((m) => m.status == MatchStatus.done)) {
          expectedGot += 2 * (m.pair1TotalGames + m.pair2TotalGames);
          for (final (pair, g) in [(m.pair1, m.pair1TotalGames), (m.pair2, m.pair2TotalGames)]) {
            for (final id in pair.playerIds) {
              final c = played[id];
              played[id] = (games: (c?.games ?? 0) + g, count: (c?.count ?? 0) + 1);
            }
          }
        }
        int value(String id) =>
            t.format.woWinnerScore(played[id] == null ? null : played[id]!.games / played[id]!.count);
        var expectedConceded = 0;
        for (final m in t.matches.where((m) => m.status == MatchStatus.wo)) {
          final winner = m.pair1.id == m.winnerPairId ? m.pair1 : m.pair2;
          expectedGot += value(winner.player1Id) + value(winner.player2Id);
          expectedConceded += 2 * RankingCalculator.woPairValue(value(winner.player1Id), value(winner.player2Id));
        }
        expect(all.values.fold(0, (sum, s) => sum + s.totalPoint), expectedGot);
        expect(all.values.fold(0, (sum, s) => sum + s.woPointsConceded), expectedConceded);

        // 3. Tidak tergantung daftar pemain yang dioper (subset = semua) dan tidak tergantung metode.
        final r = Random(seed);
        final subset = [
          for (final p in t.players)
            if (r.nextBool()) p,
        ];
        for (final method in RankingMethod.values) {
          for (final s in _rank(subset, t.matches, t.format, method)) {
            final full = all[s.player.id]!;
            expect(
              (s.pointPercent, s.totalPoint, s.pointsPlayed),
              (full.pointPercent, full.totalPoint, full.pointsPlayed),
            );
          }
        }

        // 4. WO tidak mengubah selisih siapa pun.
        final noWo = {
          for (final s in _rank(t.players, [
            for (final m in t.matches)
              if (m.status != MatchStatus.wo) m,
          ], t.format))
            s.player.id: s,
        };
        for (final s in all.values) {
          expect(s.gameDiff, noWo[s.player.id]!.gameDiff);
          expect(s.totalPoint - s.woPoints, noWo[s.player.id]!.totalPoint);
        }
      });
    }
  });
}
