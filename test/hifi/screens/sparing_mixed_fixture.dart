import 'dart:math';

import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';

import 'sparing_fixture.dart' show SparingScore, garuda, garudaNames, matcha, matchaNames, sparingScored, wo;

export 'sparing_fixture.dart' show SparingScore, garuda, garudaNames, matcha, matchaNames, wo;

/// Fixture bersama Mixed sparing (frame 13m, 15a–15y; contoh 13B logic.md §13.11): PB Garuda 8 vs Matcha Club 6,
/// Padel, Race to 6, 15 mnt, 2 court × 2 jam (19.00–21.00). Semua susunan pasangan, yang istirahat, dan prioritas dari
/// generator produksi (`EndlessRoundGenerator.generateSparingRound`, `courtUse`/`courtMatch`) dengan `Random` frame
/// dari pembuka `15-sparing-mixed.md`; tidak ada match yang ditulis tangan. `sparing_mixed_fixture_test.dart`
/// mencocokkan tiap keadaan dengan catatan frame.
///
/// Tiap keadaan = turnamen + jam `clockProvider` ([MixedSparingState]); test meng-override keduanya. Task layar
/// menambah varian di file test-nya sendiri; file ini jangan diubah per layar (docs/tasks.md).

/// Turnamen dan jam layar satu keadaan frame.
typedef MixedSparingState = ({ActiveTournament active, DateTime now});

/// Id turnamen yang `drawSeed`-nya (FNV-1a) = [mixedSparingSeed]: designer mengundi frame dengan seed itu langsung,
/// sedangkan layar (daftar Prioritas, Buat) memakai `drawSeed` dari id. Ditemukan dengan membalik FNV-1a
/// (meet-in-the-middle 3 + 3 karakter setelah awalan `t-sparing-mixed-`).
const mixedSparingId = 't-sparing-mixed-s5n7bi';
const mixedSparingSeed = 0x5eed;

/// Jam mulai (19.00); [mixedSparingAt] = [minutes] menit setelahnya.
final mixedSparingStart = DateTime(2026, 11, 7, 19);
DateTime mixedSparingAt(int minutes) => mixedSparingStart.add(Duration(minutes: minutes));

const mixedSparingAmericano21 = ScoreFormat(ScoringMethod.americano, 21);

/// 15d (30 pemain): nama dan urutan 14e, 16 + 14; Oki tetap m07.
const garuda16Names = [
  ...['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'],
  ...['Gilang', 'Hendra', 'Iwan', 'Jaka', 'Rizky', 'Sari', 'Tono', 'Umar'],
];
const matcha14Names = [
  ...['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda'],
  ...['Oki', 'Putri', 'Rina', 'Tari', 'Vina', 'Wulan', 'Yoga', 'Zaki'],
];

/// Id pemain fixture designer: Garuda g01, g02, …; Matcha m01, m02, … urut daftar.
List<Player> mixedClubPlayers(String tag, Club club, List<String> names) => [
  for (final (i, n) in names.indexed) Player(id: '$tag${(i + 1).toString().padLeft(2, '0')}', name: n, clubId: club.id),
];

/// Pemain telat 15l/15n: Oki masuk Matcha Club setelah R3.
final mixedOki = Player(id: 'm07', name: 'Oki', clubId: matcha.id);

TournamentConfig mixedSparingConfig({
  List<String> garudaPlayers = garudaNames,
  List<String> matchaPlayers = matchaNames,
  int courts = 2,
  ScoreFormat format = ScoreFormat.standard,
  String? name,
}) => TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.mixed,
  matchDurationMinutes: 15,
  format: format,
  name: name,
  courts: [
    for (var i = 1; i <= courts; i++)
      Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: 120),
  ],
  players: [...mixedClubPlayers('g', garuda, garudaPlayers), ...mixedClubPlayers('m', matcha, matchaPlayers)],
  clubs: const [garuda, matcha],
);

/// Turnamen tanpa round (sebelum R1 dibuat).
ActiveTournament mixedSparingEmpty([TournamentConfig? config]) => ActiveTournament(
  tournament: Tournament(id: mixedSparingId, createdAt: mixedSparingStart, config: config ?? mixedSparingConfig()),
);

/// Buat [count] round seperti `TournamentController.generateNextRound`: pemain aktif per klub, seed `drawSeed`,
/// `latePlayerIds` dari model, yang istirahat dicatat urut hasil generator. [random] bersambung antar round. Court =
/// semua court (di frame semuanya masih muat saat round dibuat).
ActiveTournament mixedSparingRounds(ActiveTournament active, int count, Random random) {
  assert(active.drawSeed == mixedSparingSeed, 'id turnamen harus [mixedSparingId]');
  var next = active;
  for (var i = 0; i < count; i++) {
    final n = next.roundCount + 1;
    final (club1, club2) = next.activePlayersByClub;
    final round = EndlessRoundGenerator.generateSparingRound(
      club1: club1,
      club2: club2,
      courts: next.config.courts,
      history: next.matches,
      roundNumber: n,
      seed: next.drawSeed,
      latePlayerIds: next.latePlayerIds,
      random: random,
    )!;
    next = next.copyWith(
      tournament: next.tournament.copyWith(matches: [...next.matches, ...round.matches]),
      resting: {...next.restingPlayerIdsByRound, n: round.resting.map((p) => p.id).toList()},
    );
  }
  return next;
}

/// Skor 13B (13m, 15a, 15f), skor klub pertama dulu, urut R1 C1, R1 C2, …. R1–R3 dari catatan 13m/15a; R4, R6 C2,
/// R7 C1, R8 dari Detail 15u/15v dan Jadwal 15f; R5, R6 C1, R7 C2 satu-satunya skor Race to 6 yang membuat tabel 15s
/// cocok (Kiki 0–5 → Gita/Fajar 6 di R5 C1 dan Gita/Citra 6 di R7 C2; Maya 20 → Dewi · Budi 6 di R6 C1; Indra 23 → 5;
/// Joko 26 (+5) → R5 C2 2–6).
const mixedScores13B = <SparingScore>[
  (6, 4), (3, 6), // R1
  (6, 2), (6, 5), // R2
  (6, 4), (5, 6), // R3
  (4, 6), (6, 3), // R4
  (6, 1), (2, 6), // R5
  (6, 5), (4, 6), // R6
  (6, 3), (6, 4), // R7
  (5, 6), (6, 2), // R8
];

/// 15d: R3 C1 6–5 dari frame; R1–R2 contoh, tidak tampil di frame mana pun selain jumlahnya (4 – 1, 28 – 20).
const mixedScores30 = <SparingScore>[(6, 2), (4, 6), (6, 3), (6, 4), (6, 5)];

/// 15e: R1 Gita · Fajar 6–3 Kiki · Joko.
const mixedScores8v3 = <SparingScore>[(6, 3)];

/// 15r/15t (Americano 21): R1 13–8, 9–12 · R2 14–7, 11–10 · R3 12–9 · R3 C2 WO (Citra · Gita absen).
const mixedScoresAmericano = <SparingScore>[(13, 8), (9, 12), (14, 7), (11, 10), (12, 9), wo];

/// 13B dengan [rounds] round dari `Random(1)` bersambung dan [filled] match pertama terisi [scores].
ActiveTournament _garudaMatcha(
  int rounds,
  int filled, {
  TournamentConfig? config,
  List<SparingScore> scores = mixedScores13B,
  bool ended = false,
}) => sparingScored(
  mixedSparingRounds(mixedSparingEmpty(config), rounds, Random(1)),
  scores,
  filled: filled,
  ended: ended,
);

/// 15k (sheet Cara kerja) dan latarnya: R1 baru dibuat, 19.00.
MixedSparingState mixedSparing15k() => (active: _garudaMatcha(1, 0), now: mixedSparingAt(0));

/// 13m (juga latar 15l, 15q): R3 berjalan, Court 2 belum diisi, 19.40 (sisa 01:20). Skor klub 4 – 1, 27 – 21.
MixedSparingState mixedSparing13m() => (active: _garudaMatcha(3, 5), now: mixedSparingAt(40));

/// 15a: R3 lengkap, 19.45 (sisa 01:15). Skor klub 4 – 2, 32 – 27.
MixedSparingState mixedSparing15a() => (active: _garudaMatcha(3, 6), now: mixedSparingAt(45));

/// 15b (juga latar 15c, 15g, 15h, 15o): R4 baru, 19.47 (sisa 01:13).
MixedSparingState mixedSparing15b() => (active: _garudaMatcha(4, 6), now: mixedSparingAt(47));

/// 15d: 16 + 14 pemain, R3 berjalan (Court 2 belum), 19.40. Skor klub 4 – 1, 28 – 20.
MixedSparingState mixedSparing15d() => (
  active: sparingScored(
    mixedSparingRounds(
      mixedSparingEmpty(mixedSparingConfig(garudaPlayers: garuda16Names, matchaPlayers: matcha14Names)),
      3,
      Random(1),
    ),
    mixedScores30,
  ),
  now: mixedSparingAt(40),
);

/// 15e (13j, 8 / 3): R1 terisi, R2 baru, 19.15 (sisa 01:45). Hanya Court 1 yang dipakai.
MixedSparingState mixedSparing15e() => (
  active: sparingScored(
    mixedSparingRounds(
      mixedSparingEmpty(mixedSparingConfig(matchaPlayers: matchaNames.take(3).toList())),
      2,
      Random(1),
    ),
    mixedScores8v3,
  ),
  now: mixedSparingAt(15),
);

/// 15f (juga latar 15j, 15s, 15u, 15v, 15x): R8 lengkap, waktu habis 21.00. Skor klub 10 – 6, 83 – 69.
MixedSparingState mixedSparing15f() => (active: _garudaMatcha(8, 16), now: mixedSparingAt(120));

/// 15i: diakhiri saat R4 (15b), dua match R4 "Tidak dimainkan" (seperti `finishNow`).
MixedSparingState mixedSparing15i() => (active: _garudaMatcha(4, 6, ended: true), now: mixedSparingAt(47));

/// Oki ditambah ke Matcha Club seperti `addPlayer` (di akhir daftar pemain).
ActiveTournament _withOki(ActiveTournament active) => active.copyWith(
  tournament: active.tournament.copyWith(config: active.config.copyWith(players: [...active.config.players, mixedOki])),
);

/// 15l setelah Tambah: 13m + Oki di Matcha Club (belum main), 19.40.
MixedSparingState mixedSparing15lOki() => (active: _withOki(_garudaMatcha(3, 5)), now: mixedSparingAt(40));

/// 15n: 15a + Oki, lalu Buat R4 dengan `Random(3)` (pembuka 15-sparing-mixed.md); Oki · Nanda main, 19.47.
/// [rounds] > 1 = `Random(3)` yang sama bersambung ke R5, R6, … (tanpa skor; untuk mengecek jeda Oki k = 2).
MixedSparingState mixedSparing15n({int rounds = 1}) =>
    (active: mixedSparingRounds(_withOki(_garudaMatcha(3, 6)), rounds, Random(3)), now: mixedSparingAt(47));

/// 15m: 15e dengan Kiki keluar (Matcha Club tinggal Indra dan Joko).
MixedSparingState mixedSparing15m() {
  final base = mixedSparing15e();
  return (active: base.active.copyWith(withdrawn: {'m03'}), now: base.now);
}

/// 15p: 15b + Court 3 (2 jam) ditambah 19.47, langsung main di R4 seperti `TournamentController.addCourt`: pemain dari
/// `courtUse`, susunan `courtMatch(…, Random(2))`, yang main dihapus dari istirahat R4.
MixedSparingState mixedSparing15p() {
  final base = mixedSparing15b();
  final now = base.now;
  final court = base.active.newCourt(id: 'c3', name: '', colorIndex: 2, bookingMinutes: 120, now: now);
  final next = base.active.withCourt(court);
  final use = EndlessRoundGenerator.courtUse(next, court.id, now);
  assert(use.use == CourtUse.now);
  final match = EndlessRoundGenerator.courtMatch(next, court.id, use.players, random: Random(2));
  final playing = {for (final p in use.players) p.id};
  final n = next.roundCount;
  return (
    active: next.copyWith(
      tournament: next.tournament.copyWith(matches: [...next.matches, match]),
      resting: {
        ...next.restingPlayerIdsByRound,
        n: [
          for (final id in next.restingPlayerIdsByRound[n]!)
            if (!playing.contains(id)) id,
        ],
      },
    ),
    now: now,
  );
}

/// 15r: Americano 21, susunan sama, R3 Court 2 belum diisi (sheet WO dibuka), 19.40.
MixedSparingState mixedSparing15r() => (
  active: _garudaMatcha(
    3,
    5,
    config: mixedSparingConfig(format: mixedSparingAmericano21),
    scores: mixedScoresAmericano,
  ),
  now: mixedSparingAt(40),
);

/// 15t: 15r setelah WO disimpan (Citra · Gita absen, Lina · Maya menang). Skor klub 4 – 2, 59 – 58.
MixedSparingState mixedSparing15t() => (
  active: _garudaMatcha(
    3,
    6,
    config: mixedSparingConfig(format: mixedSparingAmericano21),
    scores: mixedScoresAmericano,
  ),
  now: mixedSparingAt(40),
);

/// Nama turnamen 15w/15y.
const mixedSparingName = 'Sparing Bulanan November';

/// 15w (juga latar 15y): 15b dengan nama turnamen, Round 4, 4 – 2, 6 dari 8 match.
MixedSparingState mixedSparing15w() =>
    (active: _garudaMatcha(4, 6, config: mixedSparingConfig(name: mixedSparingName)), now: mixedSparingAt(47));
