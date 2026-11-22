import 'package:match_addict/models/models.dart';

import 'schedule_fixture.dart';

// Data Peringkat & Detail = `test/services/ranking_v2_test.dart` (logic.md §3–§4).

const americano24 = ScoreFormat(ScoringMethod.americano, 24);

/// Data set 1 (09a/09b, 10a, 10c): Americano 24, R1–R3, Gilang masuk belakangan dan belum main.
final set1 = mixedTournament(
  const [
    [('Andi', 'Hana', 'Budi', 'Eko', 14, 10), ('Dewant', 'Citra', 'Fajar', 'Joko', 15, 9)],
    [('Andi', 'Gina', 'Fajar', 'Indra', 15, 9), ('Dewant', 'Joko', 'Budi', 'Hana', 14, 10)],
    [('Andi', 'Dewant', 'Citra', 'Indra', 13, 11), ('Eko', 'Gina', 'Fajar', 'Hana', 12, 12)],
  ],
  roster: [...fixtureNames.take(10), 'Gilang S'],
  format: americano24,
);

/// Data set 2 (09d–09f): R1–R4, Dewant · Gina tidak main di R2 (Budi · Joko menang WO), satu seri.
ActiveTournament set2({bool finished = false}) => mixedTournament(
  const [
    [('Andi', 'Budi', 'Citra', 'Dewant', 16, 8), ('Eko', 'Fajar', 'Gina', 'Hana', 13, 11)],
    [('Andi', 'Citra', 'Eko', 'Indra', 11, 13), ('Budi', 'Joko', 'Dewant', 'Gina', null, null)],
    [('Andi', 'Fajar', 'Hana', 'Joko', 14, 10), ('Budi', 'Indra', 'Citra', 'Gina', 12, 12)],
    [('Dewant', 'Eko', 'Fajar', 'Joko', 17, 7), ('Andi', 'Hana', 'Budi', 'Gina', null, null)],
  ],
  format: americano24,
  finished: finished,
  adjust: (m) => m.id == 'r2c2' ? m.asWalkover(loserPairId: m.pair2.id) : m,
);

/// Fixed Tennis Race to 6, semua 10 match selesai. A Andi·Budi, B Citra·Dewant, C Eko·Fajar, D Gina·Hana,
/// E Indra·Joko. Jadwal sah (tiap pasangan istirahat sekali) dan cocok dengan riwayat Gina · Hana di 10b:
/// R1 D–E 6–3, R2 D menang WO atas B, R3 D–C 6–1, R4 istirahat, R5 D–A 5–6.
ActiveTournament fixedFinal() {
  final players = [for (var i = 0; i < 10; i++) Player(id: 'p$i', name: fixtureNames[i])];
  final pairs = [for (var i = 0; i < 5; i++) Pair(id: 'pair$i', player1Id: 'p${2 * i}', player2Id: 'p${2 * i + 1}')];
  // (round, pair1, pair2, skor1, skor2); skor null = WO, pair2 kalah.
  const results = [
    (1, 3, 4, 6, 3), (1, 0, 1, 6, 4), //
    (2, 3, 1, null, null), (2, 2, 4, 6, 2),
    (3, 3, 2, 6, 1), (3, 0, 4, 6, 1),
    (4, 0, 2, 6, 3), (4, 1, 4, 6, 2),
    (5, 3, 0, 5, 6), (5, 1, 2, 4, 6),
  ];
  final matches = [
    for (final (i, (r, a, b, s1, s2)) in results.indexed)
      () {
        final m = MatchGame(
          id: 'm$i',
          roundNumber: r,
          matchNumberInRound: i.isEven ? 1 : 2,
          courtId: 'c${i.isEven ? 1 : 2}',
          pair1: pairs[a],
          pair2: pairs[b],
        );
        return s1 == null ? m.asWalkover(loserPairId: pairs[b].id) : m.withScore([SetScore(side1: s1, side2: s2!)]);
      }(),
  ];
  return ActiveTournament(
    tournament: Tournament(
      id: 't-fixed',
      createdAt: fixtureStart,
      config: TournamentConfig(
        sport: SportType.tennis,
        mode: PartnerMode.fixed,
        matchDurationMinutes: 20,
        courts: const [
          Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
          Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
        ],
        players: players,
        fixedPairs: pairs,
      ),
      matches: matches,
    ),
    byePairIdByRound: {1: 'pair2', 2: 'pair0', 3: 'pair1', 4: 'pair3', 5: 'pair4'},
  );
}

/// 09j (data 18A, PRD §18.4): Padel Mixed Americano 21, 5 pemain, 1 court; Andi main 4, yang lain 3.
final data18a = mixedTournament(
  const [
    [('Andi', 'Budi', 'Citra', 'Dewi', 12, 9)],
    [('Andi', 'Citra', 'Budi', 'Eko', 10, 11)],
    [('Andi', 'Eko', 'Budi', 'Dewi', 8, 13)],
    [('Andi', 'Dewi', 'Citra', 'Eko', 11, 10)],
  ],
  roster: const ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko'],
  courtCount: 1,
);

/// 09k (data 18B, PRD §18.4): Fixed Race to 6, 4 pasangan (Andi·Budi, Citra·Dewi, Eko·Fajar, Gita·Hadi), 3 round.
ActiveTournament data18b() {
  const names = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'];
  final players = [for (var i = 0; i < 8; i++) Player(id: 'p$i', name: names[i])];
  final pairs = [for (var i = 0; i < 4; i++) Pair(id: 'pair$i', player1Id: 'p${2 * i}', player2Id: 'p${2 * i + 1}')];
  // (round, pair1, pair2, skor1, skor2)
  const results = [
    (1, 0, 1, 5, 6), (1, 2, 3, 6, 2), //
    (2, 0, 2, 5, 6), (2, 1, 3, 6, 5),
    (3, 0, 3, 6, 0), (3, 1, 2, 0, 6),
  ];
  final matches = [
    for (final (i, (r, a, b, s1, s2)) in results.indexed)
      MatchGame(
        id: 'm$i',
        roundNumber: r,
        matchNumberInRound: i.isEven ? 1 : 2,
        courtId: 'c${i.isEven ? 1 : 2}',
        pair1: pairs[a],
        pair2: pairs[b],
      ).withScore([SetScore(side1: s1, side2: s2)]),
  ];
  return ActiveTournament(
    tournament: Tournament(
      id: 't-18b',
      createdAt: fixtureStart,
      config: TournamentConfig(
        sport: SportType.tennis,
        mode: PartnerMode.fixed,
        matchDurationMinutes: 20,
        courts: const [
          Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
          Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
        ],
        players: players,
        fixedPairs: pairs,
      ),
      matches: matches,
    ),
  );
}

/// 09h (09-klasemen.md): Padel Mixed Americano 21, 30 pemain, 4 court, R1–R2 selesai; delapan nama tidak muat satu
/// baris di kolom 108 pt.
final data09h = mixedTournament(
  const [
    [
      ('Andi Pratama', 'Dewantoro Rahman', 'Budi Santoso', 'Christina Lestari', 14, 7),
      ('Eko Mulyadi', 'Fajar Kurniawan', 'Gina Rahmawati', 'Hana Tanjung', 11, 10),
      ('Indra Wijaya', 'Joko Susilo', 'Kiki Amelia', 'Lina Marlina', 9, 12),
      ('Maya Puspita', 'Nanda Rizaldi', 'Oki Setiawan', 'Putri Anggraini', 13, 8),
    ],
    [
      ('Muhammad Rizky H', 'Muhammad Rifqi A', 'Sari Dewi', 'Tono Budiman', 12, 9),
      ('Umar Faruq', 'Vina Kartika', 'Wulan Sari', 'Yoga Prasetyo', 6, 15),
      ('Zaki Maulana', 'Bayu Saputra', 'Dimas Aditya', 'Galih Permana', 10, 11),
      ('Rina Kusuma', 'Hendra Gunawan', 'Dewantoro Rahman', 'Gina Rahmawati', 8, 13),
    ],
  ],
  roster: const [
    'Andi Pratama', 'Budi Santoso', 'Christina Lestari', 'Dewantoro Rahman', 'Eko Mulyadi', 'Fajar Kurniawan',
    'Gina Rahmawati', 'Hana Tanjung', 'Indra Wijaya', 'Joko Susilo', 'Kiki Amelia', 'Lina Marlina', 'Maya Puspita',
    'Nanda Rizaldi', 'Oki Setiawan', 'Putri Anggraini', 'Muhammad Rizky H', 'Muhammad Rifqi A', 'Sari Dewi',
    'Tono Budiman', 'Umar Faruq', 'Vina Kartika', 'Wulan Sari', 'Yoga Prasetyo', 'Zaki Maulana', 'Bayu Saputra',
    'Dimas Aditya', 'Galih Permana', 'Rina Kusuma', 'Hendra Gunawan',
  ],
  courtCount: 4,
);
