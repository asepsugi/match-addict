// Prototipe jadwal Fixed sparing (PRD 13.3, T1). Bukan kode produksi.
//
// Algoritma "diagonal": slot match diberi nomor s = 0, 1, 2, … dan dibagi ke blok berisi L = KPK(p1, p2) slot.
// Blok ke-K (K = 0, 1, 2, … tanpa mod; g = FPB(p1, p2)) berisi slot s = 0..L−1 dengan
//   pasangan klub 1 = s mod p1, pasangan klub 2 = (s + K) mod p2.
// Blok K memuat tepat kombinasi (i, j) dengan j − i ≡ K (mod g), jadi g blok berturut-turut memuat setiap kombinasi
// tepat sekali (CRT). K harus naik 1 per blok (bukan K mod g): lompatan g−1 → 0 membuat pasangan klub 2 yang sama
// muncul dua kali di round yang melintasi batas blok. Slot lalu dipotong
// berurutan jadi round sebesar court aktif.
import 'dart:math';

import 'package:match_addict/models/models.dart';

int gcd(int a, int b) => b == 0 ? a : gcd(b, a % b);
int lcm(int a, int b) => a ~/ gcd(a, b) * b;

class SparingFixedSchedule {
  final List<MatchGame> matches;

  /// Pasangan yang istirahat per round (bisa beberapa, dari kedua klub).
  final Map<int, List<String>> restingPairIdsByRound;

  const SparingFixedSchedule(this.matches, this.restingPairIdsByRound);

  int get roundCount => matches.isEmpty ? 0 : matches.map((m) => m.roundNumber).reduce(max);
}

class SparingFixedGenerator {
  /// Court aktif: satu pasangan tidak bisa main di dua court bersamaan.
  static int activeCourts(int courts, int p1, int p2) => min(courts, min(p1, p2));

  /// Satuan round tambahan: L = KPK(p1, p2) match.
  static int unitMatches(int p1, int p2) => lcm(p1, p2);

  /// Slot ke-s di blok dengan geser [shift]: (indeks pasangan klub 1, indeks pasangan klub 2).
  static (int, int) slot(int s, int shift, int p1, int p2) => (s % p1, (s + shift) % p2);

  /// Jadwal awal: p1 × p2 match.
  static SparingFixedSchedule generate({
    required List<Pair> club1,
    required List<Pair> club2,
    required List<Court> courts,
  }) {
    final p1 = club1.length, p2 = club2.length;
    if (p1 == 0 || p2 == 0 || courts.isEmpty) return const SparingFixedSchedule([], {});
    final g = gcd(p1, p2), l = lcm(p1, p2);
    final c = activeCourts(courts.length, p1, p2);
    final slots = [
      for (var k = 0; k < g; k++)
        for (var s = 0; s < l; s++) slot(s, k, p1, p2),
    ];
    return _pack(club1, club2, slots, 1, (_) => courts.take(c).toList());
  }

  /// Round tambahan (PRD 13.7, K5): jumlah satuan = paling sedikit yang mengisi semua round yang muat di court
  /// terpanjang; satuan ke-u (u = [unitsDone] + i) = blok K = g + u, jadi kombinasinya sama dengan blok u mod g
  /// jadwal awal, dan g satuan berturut-turut = semua kombinasi sekali lagi.
  /// Round ke-r memakai court dengan [roundsLeft] ≥ r; sesudah habis, court terpanjang (lewat booking).
  static ({SparingFixedSchedule schedule, int units}) extend({
    required List<Pair> club1,
    required List<Pair> club2,
    required List<Court> courts,
    required List<int> roundsLeft,
    required int unitsDone,
    required int firstRound,
  }) {
    final p1 = club1.length, p2 = club2.length;
    final fit = roundsLeft.fold(0, max);
    if (p1 == 0 || p2 == 0 || fit == 0) return (schedule: const SparingFixedSchedule([], {}), units: 0);
    final longest = [
      for (final (i, c) in courts.indexed)
        if (roundsLeft[i] == fit) c,
    ];
    List<Court> courtsFor(int r) {
      final open = [
        for (final (i, c) in courts.indexed)
          if (roundsLeft[i] >= r) c,
      ];
      final use = open.isEmpty ? longest : open;
      return use.take(activeCourts(use.length, p1, p2)).toList();
    }

    final g = gcd(p1, p2), l = lcm(p1, p2);
    // Sama dengan RoundRobinGenerator.extend: satuan ditambah sampai jumlah round ≥ fit. Round ke-fit sudah ada
    // begitu slotnya melewati kapasitas round 1..fit−1.
    var before = 0;
    for (var r = 1; r < fit; r++) {
      before += courtsFor(r).length;
    }
    final units = before ~/ l + 1;
    final slots = [
      for (var u = 0; u < units; u++)
        for (var s = 0; s < l; s++) slot(s, g + unitsDone + u, p1, p2),
    ];
    return (schedule: _pack(club1, club2, slots, firstRound, courtsFor), units: units);
  }

  static SparingFixedSchedule _pack(
    List<Pair> club1,
    List<Pair> club2,
    List<(int, int)> slots,
    int firstRound,
    List<Court> Function(int r) courtsFor,
  ) {
    final matches = <MatchGame>[];
    final resting = <int, List<String>>{};
    var i = 0;
    var r = 0;
    while (i < slots.length) {
      r++;
      final courts = courtsFor(r);
      final round = firstRound + r - 1;
      final playing = <String>{};
      for (var j = 0; j < courts.length && i < slots.length; j++, i++) {
        final (a, b) = slots[i];
        final pair1 = club1[a], pair2 = club2[b];
        playing..add(pair1.id)..add(pair2.id);
        matches.add(
          MatchGame(
            id: 'm-r$round-${j + 1}',
            roundNumber: round,
            matchNumberInRound: j + 1,
            courtId: courts[j].id,
            pair1: pair1,
            pair2: pair2,
          ),
        );
      }
      resting[round] = [
        for (final p in [...club1, ...club2])
          if (!playing.contains(p.id)) p.id,
      ];
    }
    return SparingFixedSchedule(matches, resting);
  }
}
