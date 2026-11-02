import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';

List<Player> _players(List<String> names) =>
    [for (final n in names) Player(id: n, name: n)];

Pair _pair(String a, String b) => Pair(id: '$a+$b', player1Id: a, player2Id: b);

MatchGame _match({
  required Pair p1,
  required Pair p2,
  List<SetScore> sets = const [],
  MatchStatus status = MatchStatus.done,
  String? woLoser,
  int round = 1,
}) =>
    MatchGame(
      id: 'm${p1.id}-${p2.id}-$round',
      roundNumber: round,
      matchNumberInRound: 1,
      courtId: 'c1',
      pair1: p1,
      pair2: p2,
      sets: sets,
      status: status,
      woLoserPairId: woLoser,
    );

void main() {
  group('standingEntries', () {
    final players = _players(['Andi', 'Budi', 'Citra', 'Dewi']);
    final ab = _pair('Andi', 'Budi');
    final cd = _pair('Citra', 'Dewi');
    final ranked = RankingCalculator.rank(
      players: players,
      matches: [
        _match(
          p1: ab,
          p2: cd,
          sets: const [SetScore(side1: 6, side2: 4), SetScore(side1: 6, side2: 3)],
        ),
      ],
      method: RankingMethod.totalGames,
      format: ScoreFormat.standard,
    );

    test('mode Mixed: satu baris per pemain, urutan tidak berubah', () {
      final entries = standingEntries(standings: ranked, method: RankingMethod.totalGames);

      expect(entries, hasLength(ranked.length));
      expect(
        entries.map((e) => e.label).toList(),
        ranked.map((s) => s.player.name).toList(),
      );
    });

    test('mode Fixed: dua anggota pasangan jadi satu baris', () {
      final entries = standingEntries(standings: ranked, method: RankingMethod.totalGames, fixedPairs: [ab, cd]);

      expect(entries, hasLength(2));
      expect(entries.first.label, 'Andi + Budi');
      expect(entries.last.label, 'Citra + Dewi');
      // Statistik barisnya tetap statistik pasangan itu.
      expect(entries.first.standing.wins, 1);
      expect(entries.last.standing.losses, 1);
    });

    test('mode Fixed: pasangan mengambil posisi anggota terbaiknya', () {
      final entries = standingEntries(standings: ranked, method: RankingMethod.totalGames, fixedPairs: [ab, cd]);
      final bestName = ranked.first.player.name;

      expect(entries.first.hasPlayer(bestName), isTrue);
    });

    test('pemain sisa tanpa pasangan tetap tampil sendiri', () {
      final withOdd = [...players, const Player(id: 'Eka', name: 'Eka')];
      final rankedOdd = RankingCalculator.rank(
        players: withOdd,
        matches: [
          _match(
            p1: ab,
            p2: cd,
            sets: const [SetScore(side1: 6, side2: 4), SetScore(side1: 6, side2: 3)],
          ),
        ],
        method: RankingMethod.totalGames,
        format: ScoreFormat.standard,
      );

      final entries = standingEntries(standings: rankedOdd, method: RankingMethod.totalGames, fixedPairs: [ab, cd]);

      expect(entries, hasLength(3));
      expect(entries.map((e) => e.label), contains('Eka'));
      expect(entries.every((e) => e.players.length <= 2), isTrue);
    });
  });

  group('RankingCalculator', () {
    final players = _players(['Andi', 'Budi', 'Citra', 'Dewi']);
    final ab = _pair('Andi', 'Budi');
    final cd = _pair('Citra', 'Dewi');

    test('counts wins, losses and games from finished matches', () {
      final standings = RankingCalculator.rank(
        players: players,
        matches: [
          _match(p1: ab, p2: cd, sets: const [SetScore(side1: 6, side2: 4), SetScore(side1: 6, side2: 3)]),
        ],
        method: RankingMethod.winPercent,
        format: ScoreFormat.standard,
      );

      final andi = standings.firstWhere((s) => s.player.id == 'Andi');
      expect(andi.wins, 1);
      expect(andi.losses, 0);
      expect(andi.gamesWon, 12);
      expect(andi.gamesLost, 7);
      expect(andi.gameDiff, 5);
      expect(andi.winPercent, 100);

      final citra = standings.firstWhere((s) => s.player.id == 'Citra');
      expect(citra.losses, 1);
      expect(citra.gamesWon, 7);
    });

    test('walkover: menang/kalah dihitung, game tidak (kredit WO terpisah di woPoints)', () {
      final standings = RankingCalculator.rank(
        players: players,
        matches: [_match(p1: ab, p2: cd, status: MatchStatus.wo, woLoser: ab.id)],
        method: RankingMethod.winPercent,
        format: ScoreFormat.standard,
      );

      final andi = standings.firstWhere((s) => s.player.id == 'Andi');
      expect(andi.losses, 1);
      expect(andi.woLosses, 1);
      expect(andi.gamesWon, 0);
      expect(andi.gamesLost, 0);

      final citra = standings.firstWhere((s) => s.player.id == 'Citra');
      expect(citra.wins, 1);
      expect(citra.gamesWon, 0);
    });

    test('cancelled and pending matches are ignored entirely', () {
      final standings = RankingCalculator.rank(
        players: players,
        matches: [
          _match(p1: ab, p2: cd, status: MatchStatus.cancelled),
          _match(p1: ab, p2: cd, status: MatchStatus.pending, round: 2),
        ],
        method: RankingMethod.winPercent,
        format: ScoreFormat.standard,
      );
      for (final s in standings) {
        expect(s.matchesPlayed, 0);
        expect(s.winPercent, 0);
      }
    });

    test('win% ranks a player with fewer matches fairly', () {
      // Andi 1 dari 1 (100%), Citra 1 dari 2 (50%).
      final ac = _pair('Andi', 'Citra');
      final bd = _pair('Budi', 'Dewi');
      final standings = RankingCalculator.rank(
        players: players,
        matches: [
          _match(p1: ac, p2: bd, sets: const [SetScore(side1: 6, side2: 1)]),
          _match(p1: cd, p2: ab, sets: const [SetScore(side1: 1, side2: 6)], round: 2),
        ],
        method: RankingMethod.winPercent,
        format: ScoreFormat.standard,
      );
      expect(standings.first.player.id, 'Andi');
      expect(standings.firstWhere((s) => s.player.id == 'Andi').winPercent, 100);
      expect(standings.firstWhere((s) => s.player.id == 'Citra').winPercent, 50);
    });

    test('total games method ranks by games won', () {
      final ac = _pair('Andi', 'Citra');
      final bd = _pair('Budi', 'Dewi');
      final standings = RankingCalculator.rank(
        players: players,
        matches: [
          _match(p1: ac, p2: bd, sets: const [SetScore(side1: 6, side2: 5)]),
        ],
        method: RankingMethod.totalGames,
        format: ScoreFormat.standard,
      );
      expect(standings.take(2).map((s) => s.player.id), containsAll(['Andi', 'Citra']));
      expect(standings.first.gamesWon, 6);
    });

    test('total point menjumlah game yang dimenangkan lintas match', () {
      // Contoh dari host: Andi menang 6-5, 6-2, 6-5 → 18 poin;
      // Dewi kalah 5-6, menang 6-4, 6-5 → 17 poin, jadi Andi di atas Dewi.
      final ab = _pair('Andi', 'Budi');
      final cd = _pair('Citra', 'Dewi');
      final ad = _pair('Andi', 'Dewi');
      final bc = _pair('Budi', 'Citra');
      final standings = RankingCalculator.rank(
        players: players,
        matches: [
          _match(p1: ab, p2: cd, sets: const [SetScore(side1: 6, side2: 5)]),
          _match(p1: ad, p2: bc, sets: const [SetScore(side1: 6, side2: 2)], round: 2),
          _match(p1: ad, p2: bc, sets: const [SetScore(side1: 6, side2: 5)], round: 3),
        ],
        method: RankingMethod.totalGames,
        format: ScoreFormat.standard,
      );

      expect(standings.firstWhere((s) => s.player.id == 'Andi').totalPoint, 18);
      expect(standings.firstWhere((s) => s.player.id == 'Dewi').totalPoint, 17);
      expect(standings.first.player.id, 'Andi');
    });

    test('poin sama dipisah selisih, bukan head-to-head', () {
      // Andi · Budi menang head-to-head atas Citra · Dewi, tapi poinnya sama (10) dan selisihnya kalah (0 vs +4).
      final six = _players(['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fina']);
      final ab2 = _pair('Andi', 'Budi');
      final cd2 = _pair('Citra', 'Dewi');
      final ef = _pair('Eko', 'Fina');
      final standings = RankingCalculator.rank(
        players: six,
        matches: [
          _match(p1: ab2, p2: cd2, sets: const [SetScore(side1: 6, side2: 4)]),
          _match(p1: cd2, p2: ef, sets: const [SetScore(side1: 6, side2: 0)], round: 2),
          _match(p1: ab2, p2: ef, sets: const [SetScore(side1: 4, side2: 6)], round: 3),
        ],
        method: RankingMethod.totalGames,
        format: ScoreFormat.standard,
      );
      final andi = standings.firstWhere((s) => s.player.id == 'Andi');
      final citra = standings.firstWhere((s) => s.player.id == 'Citra');
      expect((andi.totalPoint, andi.gameDiff, citra.totalPoint, citra.gameDiff), (10, 0, 10, 4));
      expect(standings.indexOf(citra), lessThan(standings.indexOf(andi)));
    });

    test('poin dan selisih sama → nomor sama, nomor berikutnya melanjutkan (1, 1, 2, 2, 3…)', () {
      final eight = _players(['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fina', 'Gani', 'Hadi']);
      final ranked = RankingCalculator.rank(
        players: eight,
        matches: [
          _match(p1: _pair('Andi', 'Budi'), p2: _pair('Citra', 'Dewi'), sets: const [SetScore(side1: 6, side2: 2)]),
          _match(p1: _pair('Eko', 'Fina'), p2: _pair('Gani', 'Hadi'), sets: const [SetScore(side1: 6, side2: 4)]),
          _match(p1: _pair('Andi', 'Eko'), p2: _pair('Citra', 'Gani'), sets: const [SetScore(side1: 6, side2: 3)], round: 2),
          _match(p1: _pair('Budi', 'Fina'), p2: _pair('Dewi', 'Hadi'), sets: const [SetScore(side1: 6, side2: 3)], round: 2),
        ],
        method: RankingMethod.totalGames,
        format: ScoreFormat.standard,
      );
      final entries = standingEntries(standings: ranked, method: RankingMethod.totalGames);
      expect([for (final e in entries) '${e.position} ${e.label} ${e.standing.totalPoint} ${e.standing.gameDiff}'], [
        '1 Andi 12 7',
        '1 Budi 12 7',
        '2 Eko 12 5',
        '2 Fina 12 5',
        '3 Gani 7 -5',
        '3 Hadi 7 -5',
        '4 Citra 5 -7',
        '4 Dewi 5 -7',
      ]);
    });
  });
}
