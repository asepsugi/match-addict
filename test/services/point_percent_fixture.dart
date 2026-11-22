import 'package:match_addict/models/models.dart';

/// Data Point % (logic.md §20.8). Id pemain = nama; id pasangan dari nama anggotanya.

List<Player> playersOf(Iterable<String> names) => [for (final n in names) Player(id: n, name: n)];

Pair pairOfNames(String a, String b) => Pair(id: '$a+$b', player1Id: a, player2Id: b);

/// Satu match Mixed: [a]·[b] lawan [c]·[d]; skor null = WO ([a]·[b] kalah, tanpa alasan).
MatchGame mixedMatch(int round, String a, String b, String c, String d, int? s1, int? s2, {int number = 1}) {
  final m = MatchGame(
    id: 'r$round-$number',
    roundNumber: round,
    matchNumberInRound: number,
    courtId: 'c$number',
    pair1: pairOfNames(a, b),
    pair2: pairOfNames(c, d),
  );
  return s1 == null ? m.asWalkover(loserPairId: m.pair1.id) : m.withScore([SetScore(side1: s1, side2: s2!)]);
}

const americano21 = ScoreFormat(ScoringMethod.americano, 21);
const americano20 = ScoreFormat(ScoringMethod.americano, 20);
const raceTo6 = ScoreFormat(ScoringMethod.raceTo, 6);

/// 18A: Mixed Americano 21, 5 pemain, 1 court.
const names18a = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko'];
final matches18a = [
  mixedMatch(1, 'Andi', 'Budi', 'Citra', 'Dewi', 12, 9),
  mixedMatch(2, 'Andi', 'Citra', 'Budi', 'Eko', 10, 11),
  mixedMatch(3, 'Andi', 'Eko', 'Budi', 'Dewi', 8, 13),
  mixedMatch(4, 'Andi', 'Dewi', 'Citra', 'Eko', 11, 10),
];

/// 18C: Mixed Americano 21, 8 pemain, 2 court; R3 Court 1 WO (Citra·Dewi kalah dari Andi·Budi).
const names18c = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'];
final matches18c = [
  mixedMatch(1, 'Andi', 'Eko', 'Citra', 'Fajar', 13, 8),
  mixedMatch(1, 'Budi', 'Gita', 'Dewi', 'Hadi', 16, 5, number: 2),
  mixedMatch(2, 'Andi', 'Fajar', 'Dewi', 'Gita', 15, 6),
  mixedMatch(2, 'Budi', 'Hadi', 'Citra', 'Eko', 18, 3, number: 2),
  mixedMatch(3, 'Citra', 'Dewi', 'Andi', 'Budi', null, null),
  mixedMatch(3, 'Eko', 'Gita', 'Fajar', 'Hadi', 11, 10, number: 2),
];

/// 18C-hapus: match WO kembali pending (Hapus WO).
final matches18cHapus = [
  for (final m in matches18c)
    if (m.status == MatchStatus.wo)
      MatchGame(
        id: m.id,
        roundNumber: m.roundNumber,
        matchNumberInRound: m.matchNumberInRound,
        courtId: m.courtId,
        pair1: m.pair1,
        pair2: m.pair2,
      )
    else
      m,
];

/// 18B: Fixed Race to 6, 4 pasangan (id pasangan 'AB', anggota 'A' dan 'B').
const names18b = ['A', 'B', 'C', 'D', 'E', 'F', 'G', 'H'];
final pairs18b = {
  'AB': pairOfNames('A', 'B'),
  'CD': pairOfNames('C', 'D'),
  'EF': pairOfNames('E', 'F'),
  'GH': pairOfNames('G', 'H'),
};
MatchGame _fixed(int i, String p1, String p2, int s1, int s2) => MatchGame(
  id: 'f$i',
  roundNumber: i ~/ 2 + 1,
  matchNumberInRound: i % 2 + 1,
  courtId: 'c${i % 2 + 1}',
  pair1: pairs18b[p1]!,
  pair2: pairs18b[p2]!,
).withScore([SetScore(side1: s1, side2: s2)]);

final matches18b = [
  _fixed(0, 'AB', 'CD', 5, 6),
  _fixed(1, 'EF', 'GH', 6, 2),
  _fixed(2, 'AB', 'EF', 5, 6),
  _fixed(3, 'CD', 'GH', 6, 5),
  _fixed(4, 'AB', 'GH', 6, 0),
  _fixed(5, 'CD', 'EF', 0, 6),
];
