import 'dart:math';

import '../../models/models.dart';

/// Hasil generate jadwal Fixed sparing.
class SparingFixedSchedule {
  final List<MatchGame> matches;

  /// Pasangan yang istirahat per round: bisa beberapa, dari kedua klub (klub pertama dulu, urut daftar).
  final Map<int, List<String>> restingPairIdsByRound;

  const SparingFixedSchedule({required this.matches, required this.restingPairIdsByRound});

  static const empty = SparingFixedSchedule(matches: [], restingPairIdsByRound: {});

  int get roundCount => matches.isEmpty ? 0 : matches.last.roundNumber;
}

/// Jadwal Fixed sparing (logic.md §13.2–13.4): tiap pasangan klub pertama lawan tiap pasangan klub kedua, tidak
/// pernah sesama klub. `pair1` selalu pasangan klub pertama.
///
/// Algoritma diagonal: slot match dinomori dalam blok K = 0, 1, 2, … berisi L = KPK(p1, p2) slot; slot s di blok K =
/// pasangan klub pertama ke-(s mod p1) lawan pasangan klub kedua ke-((s + K) mod p2). Blok K memuat tepat kombinasi
/// dengan j − i ≡ K (mod g), g = FPB(p1, p2), jadi g blok berturut-turut = semua kombinasi tepat sekali. Slot lalu
/// dipotong berurutan jadi round sebesar court aktif. Circle method (`RoundRobinGenerator`) tidak dipakai karena dua
/// klub dengan jumlah pasangan berbeda tidak punya putaran yang saling lepas.
class SparingFixedGenerator {
  /// Court aktif C': satu pasangan tidak bisa main di dua court bersamaan, jadi paling banyak min(p1, p2).
  static int activeCourts(int courts, int p1, int p2) => min(courts, min(p1, p2));

  /// Satu satuan round tambahan = satu blok = KPK(p1, p2) match; klub pertama +L÷p1, klub kedua +L÷p2 per pasangan.
  /// 0 kalau salah satu klub tanpa pasangan (sheet Atur pasangan bisa sementara mengosongkan satu klub; FPB 0).
  static int unitMatches(int p1, int p2) => p1 == 0 || p2 == 0 ? 0 : p1 ~/ p1.gcd(p2) * p2;

  /// Jadwal awal: p1 × p2 match di Court 1..C'; court bernomor terakhir yang tidak aktif.
  static SparingFixedSchedule generate({
    required List<Pair> club1,
    required List<Pair> club2,
    required List<Court> courts,
  }) {
    final p1 = club1.length, p2 = club2.length;
    if (p1 == 0 || p2 == 0 || courts.isEmpty) return SparingFixedSchedule.empty;
    final active = courts.take(activeCourts(courts.length, p1, p2)).toList();
    return _pack(club1, club2, _slots(p1, p2, firstBlock: 0, blocks: p1.gcd(p2)), 1, (_) => active);
  }

  /// Round tambahan setelah jadwal awal (K5, logic.md §13.3). Satuan ke-u (u = [unitsDone] + i) = blok K = g + u,
  /// jadi kombinasinya sama dengan blok u mod g jadwal awal dan g satuan berturut-turut = semua kombinasi sekali
  /// lagi. [unitsDone] = `ActiveTournament.extraPutaran` (jumlah satuan yang sudah dibuat).
  ///
  /// [roundsLeft] per court (urutan [courts]) sama dengan `RoundRobinGenerator.extend`: round ke-r memakai court yang
  /// masih muat r round, sesudah habis court terpanjang (lewat booking). Jumlah satuan = paling sedikit yang membuat
  /// jumlah round ≥ fit. Kosong kalau tidak ada court yang muat satu round.
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
    if (p1 == 0 || p2 == 0 || fit == 0) return (schedule: SparingFixedSchedule.empty, units: 0);
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

    // Round ke-fit sudah ada begitu slotnya melewati kapasitas round 1..fit−1.
    var before = 0;
    for (var r = 1; r < fit; r++) {
      before += courtsFor(r).length;
    }
    final units = before ~/ unitMatches(p1, p2) + 1;
    // Semua satuan dipotong menerus (tidak mulai round baru per satuan): aman karena court per round tidak pernah
    // naik di dalam satu kali tambah.
    final slots = _slots(p1, p2, firstBlock: p1.gcd(p2) + unitsDone, blocks: units);
    return (schedule: _pack(club1, club2, slots, firstRound, courtsFor), units: units);
  }

  /// Rencana round tambahan untuk sheet Tambah round, padanan `RoundRobinGenerator.extraRounds`. [club1]/[club2] =
  /// pasangan per klub (hasil Atur pasangan atau pasangan sekarang); [roundsLeft] dihitung sama persis.
  /// [perPair] = match tambahan tiap pasangan, per klub. [overMinutes] = menit lewat booking = (round tambahan −
  /// [fitRounds]) × durasi, 0 kalau muat.
  static ({
    SparingFixedSchedule schedule,
    int units,
    ({int club1, int club2}) perPair,
    int fitRounds,
    List<int> roundsLeft,
    int overMinutes,
  })
  extraRounds(
    ActiveTournament active,
    DateTime now, {
    required List<Pair> club1,
    required List<Pair> club2,
    Map<String, int> extraMinutes = const {},
  }) {
    final config = active.config;
    final roundsLeft = [
      for (final c in config.courts)
        (active.remainingBookingMinutes(c, now) + (extraMinutes[c.id] ?? 0)) ~/ config.matchDurationMinutes,
    ];
    final extra = extend(
      club1: club1,
      club2: club2,
      courts: config.courts,
      roundsLeft: roundsLeft,
      unitsDone: active.extraPutaran,
      firstRound: active.roundCount + 1,
    );
    final matches = extra.schedule.matches.length;
    final fit = roundsLeft.fold(0, max);
    final added = matches == 0 ? 0 : extra.schedule.roundCount - active.roundCount;
    return (
      schedule: extra.schedule,
      units: extra.units,
      perPair: (club1: club1.isEmpty ? 0 : matches ~/ club1.length, club2: club2.isEmpty ? 0 : matches ~/ club2.length),
      fitRounds: fit,
      roundsLeft: roundsLeft,
      overMinutes: max(0, added - fit) * config.matchDurationMinutes,
    );
  }

  /// Estimasi tombol Lanjut di Konfigurasi (K10, logic.md §13.4), dari jumlah pemain aktif per klub; sisa ganjil
  /// ditahan di Pasangan (K12) jadi pasangan = ⌊n ÷ 2⌋. [bookingMinutes] per court, urutan Court 1, 2, ….
  /// [overMinutes] = R × durasi − booking terpendek di antara Court 1..C', 0 kalau muat.
  static ({int rounds, int matches, int activeCourts, int overMinutes}) estimate({
    required int players1,
    required int players2,
    required List<int> bookingMinutes,
    required int matchDurationMinutes,
  }) {
    final p1 = players1 ~/ 2, p2 = players2 ~/ 2;
    if (p1 == 0 || p2 == 0 || bookingMinutes.isEmpty) return (rounds: 0, matches: 0, activeCourts: 0, overMinutes: 0);
    final active = activeCourts(bookingMinutes.length, p1, p2);
    final matches = p1 * p2;
    final rounds = (matches + active - 1) ~/ active;
    final shortest = bookingMinutes.take(active).reduce(min);
    return (
      rounds: rounds,
      matches: matches,
      activeCourts: active,
      overMinutes: max(0, rounds * matchDurationMinutes - shortest),
    );
  }

  /// Slot blok [firstBlock] .. [firstBlock] + [blocks] − 1: (indeks pasangan klub pertama, indeks klub kedua).
  ///
  /// Jebakan: K harus naik terus, jangan `K mod g`. Dengan mod, lompatan g−1 → 0 di batas blok bisa membuat pasangan
  /// klub kedua yang sama muncul di dua slot berurutan dalam satu round (4 / 6 pasangan, 3 court, sisa [3, 6, 13]).
  /// Tanpa mod indeks klub kedua hanya naik 1 di batas blok, jadi tidak pernah kembar.
  static List<(int, int)> _slots(int p1, int p2, {required int firstBlock, required int blocks}) {
    final l = unitMatches(p1, p2);
    return [
      for (var k = firstBlock; k < firstBlock + blocks; k++)
        for (var s = 0; s < l; s++) (s % p1, (s + k) % p2),
    ];
  }

  /// Memotong slot berurutan jadi round sebesar court di round itu ([courtsFor], r mulai 1); round terakhir boleh
  /// kurang.
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
    for (var r = 1; i < slots.length; r++) {
      final courts = courtsFor(r);
      final round = firstRound + r - 1;
      final playing = <String>{};
      for (var j = 0; j < courts.length && i < slots.length; j++, i++) {
        final pair1 = club1[slots[i].$1], pair2 = club2[slots[i].$2];
        playing.addAll([pair1.id, pair2.id]);
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
    return SparingFixedSchedule(matches: matches, restingPairIdsByRound: resting);
  }
}
