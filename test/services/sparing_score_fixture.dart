import 'package:match_addict/models/models.dart';

/// Fixture bersama test skor klub (services) dan provider sparing (features): jadwal Fixed 13A, 8 / 6 pemain,
/// data logic.md §13.11.
const garuda = Club(id: 'club-1', name: 'PB Garuda');
const matcha = Club(id: 'club-2', name: 'Matcha Club');

Player _p(String name, Club club) => Player(id: 'p-${name.toLowerCase()}', name: name, clubId: club.id);

final clubPlayers = [
  for (final n in ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi']) _p(n, garuda),
  for (final n in ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda']) _p(n, matcha),
];

Pair _pair(String id, String a, String b) => Pair(id: id, player1Id: 'p-$a', player2Id: 'p-$b');

final clubPairs = {
  'G1': _pair('G1', 'andi', 'budi'),
  'G2': _pair('G2', 'citra', 'dewi'),
  'G3': _pair('G3', 'eko', 'fajar'),
  'G4': _pair('G4', 'gita', 'hadi'),
  'M1': _pair('M1', 'indra', 'joko'),
  'M2': _pair('M2', 'kiki', 'lina'),
  'M3': _pair('M3', 'maya', 'nanda'),
};

/// Urutan R1 Court 1, R1 Court 2, R2 Court 1, … = urutan skor di logic.md §13.11.
const c13Layout = [
  ('G1', 'M1'), ('G2', 'M2'), //
  ('G3', 'M3'), ('G4', 'M1'),
  ('G1', 'M2'), ('G2', 'M3'),
  ('G3', 'M1'), ('G4', 'M2'),
  ('G1', 'M3'), ('G2', 'M1'),
  ('G3', 'M2'), ('G4', 'M3'),
];

TournamentConfig sparingConfig(ScoreFormat format) => TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.fixed,
  matchDurationMinutes: 15,
  courts: const [
    Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
    Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
  ],
  players: clubPlayers,
  fixedPairs: clubPairs.values.toList(),
  format: format,
  clubs: const [garuda, matcha],
);

/// [scores] satu per match urut `c13Layout`; null = WO (pasangan pertama absen, seperti G2 di R3 13C). Match setelah
/// akhir daftar belum dimainkan.
ActiveTournament fixedSparing(List<(int, int)?> scores, {ScoreFormat format = ScoreFormat.standard}) {
  final matches = <MatchGame>[];
  for (var i = 0; i < c13Layout.length; i++) {
    final (a, b) = c13Layout[i];
    final base = MatchGame(
      id: 'm${i + 1}',
      roundNumber: i ~/ 2 + 1,
      matchNumberInRound: i % 2 + 1,
      courtId: i.isEven ? 'c1' : 'c2',
      pair1: clubPairs[a]!,
      pair2: clubPairs[b]!,
    );
    if (i >= scores.length) {
      matches.add(base);
    } else if (scores[i] == null) {
      matches.add(base.asWalkover(loserPairId: clubPairs[a]!.id));
    } else {
      matches.add(base.withScore([SetScore(side1: scores[i]!.$1, side2: scores[i]!.$2)]));
    }
  }
  return ActiveTournament(
    tournament: Tournament(
      id: 't',
      createdAt: DateTime(2026, 11, 8, 19),
      config: sparingConfig(format),
      matches: matches,
    ),
  );
}

const c13 = <(int, int)?>[
  (6, 3),
  (4, 6),
  (6, 5),
  (6, 4),
  (6, 4),
  null,
  (6, 2),
  (3, 6),
  (2, 6),
  (6, 1),
  (6, 0),
  (5, 6), //
];
const s14s = <(int, int)?>[
  (6, 4),
  (3, 6),
  (6, 2),
  (4, 6),
  (5, 6),
  (6, 3),
  (6, 5),
  (2, 6),
  (4, 6),
  (6, 4),
  (5, 6),
  (3, 6), //
];
const s14t = <(int, int)?>[
  (6, 4),
  (6, 5),
  (3, 6),
  (6, 2),
  (5, 6),
  (2, 6),
  (6, 3),
  (4, 6),
  (6, 4),
  (3, 6),
  (6, 4),
  (5, 6), //
];
const s14u = <(int, int)?>[
  (12, 8),
  (9, 11),
  (13, 7),
  (10, 10),
  (11, 9),
  (8, 12),
  (14, 6),
  (7, 13),
  (9, 11),
  (12, 8),
  (11, 9),
  (6, 14), //
];
