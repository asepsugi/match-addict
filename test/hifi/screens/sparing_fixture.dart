import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/sparing_fixed_generator.dart';

/// Fixture bersama Fixed sparing (logic.md §13.11, frame 13A/13C, 14*): PB Garuda 8 (4 pasangan) vs Matcha Club 6
/// (3 pasangan), Padel, Race to 6, 15 mnt, 2 court × 2 jam. Jadwal selalu dari `SparingFixedGenerator` (bukan ditulis
/// tangan) supaya golden ikut generator; `sparing_fixed_flow_test.dart` memastikan hasilnya = tabel 13.11 dan sama
/// dengan jalur controller. Jam tidak dipakai di sini: test meng-override `clockProvider` dengan [sparingAt].
///
/// Task layar menambah varian di file test-nya sendiri; file ini jangan diubah per layar (docs/tasks.md).

const garuda = Club(id: 'club-1', name: 'PB Garuda');
const matcha = Club(id: 'club-2', name: 'Matcha Club');

const garudaNames = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'];
const matchaNames = ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda'];

/// Id pemain dari namanya ("Andi" → `p-andi`), sama dengan `sparing_codec_test.dart`.
Player sparingPlayer(String name, Club club) =>
    Player(id: 'p-${name.toLowerCase().replaceAll(' ', '-')}', name: name, clubId: club.id);

/// Pemain pengganti Atur pasangan (14c sisa ganjil, 14o/14p pengganti).
final gilang = sparingPlayer('Gilang', garuda);
final oki = sparingPlayer('Oki', matcha);

/// Pasangan Atur pasangan setelah R6 (14o/14p): Dewi pulang → Citra · Gilang di slot G2; Nanda pulang → Maya · Oki di
/// slot M3.
final citraGilang = Pair(id: 'pair-g2b', player1Id: 'p-citra', player2Id: gilang.id);
final mayaOki = Pair(id: 'pair-m3b', player1Id: 'p-maya', player2Id: oki.id);

/// Jam mulai turnamen; [sparingAt] = setelah [rounds] round × 15 mnt.
final sparingStart = DateTime(2026, 11, 4, 19);

/// 14h (R3 berjalan) = `sparingAt(2)`; 13k (R6 berjalan, hitung mundur 00:45) = `sparingAt(5)`; 13l/14n (semua
/// terisi, sisa 00:30) = `sparingAt(6)`.
DateTime sparingAt(int rounds) => sparingStart.add(Duration(minutes: 15 * rounds));

/// Config sparing. Pasangan = dua pemain berurutan di tiap klub (G1 Andi · Budi, …, M1 Indra · Joko, …), klub pertama
/// dulu = urutan generator; sisa ganjil tidak berpasangan. [paired] false → `fixedPairs` null (layar Pemain,
/// Konfigurasi, Pasangan sebelum dibuat).
TournamentConfig sparingConfig({
  List<String> garudaPlayers = garudaNames,
  List<String> matchaPlayers = matchaNames,
  int courts = 2,
  int bookingMinutes = 120,
  ScoreFormat format = ScoreFormat.standard,
  PartnerMode mode = PartnerMode.fixed,
  bool paired = true,
  String? name,
}) {
  final g = [for (final n in garudaPlayers) sparingPlayer(n, garuda)];
  final m = [for (final n in matchaPlayers) sparingPlayer(n, matcha)];
  List<Pair> pairsOf(List<Player> players, String prefix) => [
    for (var i = 0; i + 1 < players.length; i += 2)
      Pair(id: 'pair-$prefix${i ~/ 2 + 1}', player1Id: players[i].id, player2Id: players[i + 1].id),
  ];
  return TournamentConfig(
    sport: SportType.padel,
    mode: mode,
    matchDurationMinutes: 15,
    format: format,
    name: name,
    courts: [
      for (var i = 0; i < courts; i++)
        Court(id: 'c${i + 1}', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: bookingMinutes),
    ],
    players: [...g, ...m],
    fixedPairs: paired && mode == PartnerMode.fixed ? [...pairsOf(g, 'g'), ...pairsOf(m, 'm')] : null,
    clubs: const [garuda, matcha],
  );
}

/// Jadwal awal dari generator, belum ada skor (seperti `startIfNeeded`, dengan id tetap).
ActiveTournament sparingSchedule([TournamentConfig? config]) {
  final c = config ?? sparingConfig();
  final schedule = SparingFixedGenerator.generate(
    club1: c.pairsOfClub(garuda.id),
    club2: c.pairsOfClub(matcha.id),
    courts: c.courts,
  );
  return ActiveTournament(
    tournament: Tournament(id: 't-sparing', createdAt: sparingStart, config: c, matches: schedule.matches),
    restingPairIdsByRound: schedule.restingPairIdsByRound,
  );
}

/// Skor satu match: (pasangan klub pertama, klub kedua). [wo] = WO dengan pasangan klub pertama absen.
typedef SparingScore = (int, int);
const wo = (-1, -1);

/// Skor 13C urut R1 C1, R1 C2, …: R3 Court 2 WO (Citra · Dewi absen, Maya · Nanda menang).
const scores13c = <SparingScore>[
  (6, 3),
  (4, 6),
  (6, 5),
  (6, 4),
  (6, 4),
  wo,
  (6, 2),
  (3, 6),
  (2, 6),
  (6, 1),
  (6, 0),
  (5, 6),
];

/// 14s: Matcha Club unggul 7 – 5, 56 – 60.
const scores14s = <SparingScore>[
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
  (3, 6),
];

/// 14t: Seri 6 – 6, 58 – 58.
const scores14t = <SparingScore>[
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
  (5, 6),
];

/// 14u: Americano 20 ([americano20]), Gita · Hadi 10–10 Indra · Joko di R2 → 6½ – 5½, 122 – 118 poin.
const scores14u = <SparingScore>[
  (12, 8), (9, 11), (13, 7), (10, 10), (11, 9), (8, 12), (14, 6), (7, 13), (9, 11), (12, 8), (11, 9), (6, 14), //
];
const americano20 = ScoreFormat(ScoringMethod.americano, 20);

/// [base] dengan [filled] match pertama (urut round, court) diisi dari [scores]; sisanya belum diisi. [ended] =
/// diakhiri: match yang belum diisi "Tidak dimainkan" (seperti `finishNow`).
ActiveTournament sparingScored(ActiveTournament base, List<SparingScore> scores, {int? filled, bool ended = false}) {
  final n = filled ?? scores.length;
  return base.copyWith(
    tournament: base.tournament.copyWith(
      isFinished: ended,
      matches: [
        for (final (i, m) in base.matches.indexed)
          if (i < n && scores[i] == wo)
            m.asWalkover(loserPairId: m.pair1.id, reason: WoReason.absent)
          else if (i < n)
            m.withScore([SetScore(side1: scores[i].$1, side2: scores[i].$2)])
          else if (ended)
            m.copyWith(status: MatchStatus.cancelled)
          else
            m,
      ],
    ),
  );
}

/// 14h, 14r: R3 berjalan (R1–R2 + R3 Court 1 terisi), skor klub 4 – 1, 28 – 22.
ActiveTournament sparingR3() => sparingScored(sparingSchedule(), scores13c, filled: 5);

/// 13k, 13n, 14i, 14j, 14k, 14q, 14x: R6 berjalan (R1–R5 terisi), 6 – 4, 45 – 43.
ActiveTournament sparingAfterR5() => sparingScored(sparingSchedule(), scores13c, filled: 10);

/// 13l, 13o, 13p, 14n, 14v, 14w: semua 12 match terisi, 7 – 5, 56 – 49.
ActiveTournament sparingFull() => sparingScored(sparingSchedule(), scores13c);

/// 14l: diakhiri saat R6 berjalan; dua match R6 "Tidak dimainkan", Final 6 – 4 (5 round · 10 match).
ActiveTournament sparingEnded() => sparingScored(sparingSchedule(), scores13c, filled: 10, ended: true);

/// 14s / 14t: jadwal yang sama dengan skor lain, semua terisi.
ActiveTournament sparing14s() => sparingScored(sparingSchedule(), scores14s);
ActiveTournament sparing14t() => sparingScored(sparingSchedule(), scores14t);

/// 14u: Americano 20, semua terisi.
ActiveTournament sparing14u() => sparingScored(sparingSchedule(sparingConfig(format: americano20)), scores14u);

/// 14m (dan 14g): 8 / 4 pemain di 3 court → 4 / 2 pasangan, court aktif 2, 4 round, belum ada skor.
ActiveTournament sparingSmall() =>
    sparingSchedule(sparingConfig(matchaPlayers: matchaNames.take(4).toList(), courts: 3));

/// 14p: [sparingFull] lalu Atur pasangan (Citra · Gilang, Maya · Oki) + "Buat R7–R12" pada `sparingAt(6)` (sisa 2 round,
/// tanpa tambahan jam): 1 satuan = 12 match, R7–R12 belum diisi, `extraPutaran` 1. Sama dengan hasil
/// `TournamentController.addRounds` (dicek di `sparing_fixed_flow_test.dart`).
ActiveTournament sparingReplaced() {
  final full = sparingFull();
  final config = full.config;
  final pairs = [
    for (final p in config.fixedPairs!)
      p.id == 'pair-g2'
          ? citraGilang
          : p.id == 'pair-m3'
          ? mayaOki
          : p,
  ];
  final next = config.copyWith(players: [...config.players, gilang, oki], fixedPairs: pairs);
  final extra = SparingFixedGenerator.extend(
    club1: next.pairsOfClub(garuda.id),
    club2: next.pairsOfClub(matcha.id),
    courts: next.courts,
    roundsLeft: const [2, 2],
    unitsDone: 0,
    firstRound: 7,
  );
  return full.copyWith(
    tournament: full.tournament.copyWith(config: next, matches: [...full.matches, ...extra.schedule.matches]),
    restingPairs: {...full.restingPairIdsByRound, ...extra.schedule.restingPairIdsByRound},
    extraPutaran: extra.units,
  );
}
