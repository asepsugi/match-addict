import 'dart:math';

import '../../models/models.dart';

/// Hasil generate jadwal mode Fixed.
class FixedSchedule {
  final List<MatchGame> matches;

  /// Pair yang bye, per nomor round. Kosong kalau jumlah pair genap.
  final Map<int, String> byePairIdByRound;

  const FixedSchedule({required this.matches, required this.byePairIdByRound});

  int get roundCount => matches.isEmpty ? 0 : matches.last.roundNumber;
}

/// Round-robin mode Fixed dengan circle method.
///
/// Circle method menghasilkan "putaran" berisi `pairs/2` pertandingan yang
/// semuanya bisa jalan bersamaan. Karena jumlah court biasanya lebih sedikit,
/// tiap putaran dipotong lagi menjadi beberapa round jadwal sebesar jumlah
/// court — sesuai definisi round di PRD: satu batch yang memakai semua court
/// sekali. Pemotongan tidak pernah menggabungkan dua putaran, jadi satu pair
/// tidak mungkin dijadwalkan di dua lapangan pada round yang sama.
class RoundRobinGenerator {
  static FixedSchedule generate({required List<Pair> pairs, required List<Court> courts}) {
    if (pairs.length < 2 || courts.isEmpty) {
      return const FixedSchedule(matches: [], byePairIdByRound: {});
    }
    final schedule = _Packer(firstRound: 1, courtsFor: (_) => courts);
    for (final circleRound in _circleRounds(pairs)) {
      schedule.add(circleRound);
    }
    return schedule.result;
  }

  /// Match per putaran tambahan: genap tiap pasangan +1, ganjil +2 (lihat [extend]).
  static int matchesPerPutaran(int pairs) => pairs.isEven ? pairs ~/ 2 : pairs;

  /// Round tambahan setelah round-robin selesai (sheet Tambah round, logic.md §12).
  ///
  /// Satu putaran = tiap pasangan main sekali lagi. Pasangan ganjil +2: satu pasangan selalu istirahat per putaran
  /// circle, jadi +1 untuk semua tidak mungkin. Lawan: genap mengulang circle round dari awal (putaran tambahan
  /// pertama = lawan R1); ganjil memakai siklus Hamilton (Walecki), sehingga round-robin kedua tidak pernah
  /// mempertemukan dua pasangan untuk ketiga kalinya sebelum semua bertemu dua kali. [putaranDone] = putaran
  /// tambahan yang sudah dibuat, supaya tambahan berikutnya melanjutkan urutan itu.
  ///
  /// [roundsLeft] = per court (urutan [courts]), berapa round lagi yang muat di sisa booking-nya. Round tambahan ke-r
  /// memakai court yang masih muat r round; sesudah semua habis, court yang paling lama tetap dipakai (round melewati
  /// booking, host yang memutuskan kapan berhenti). Jumlah putaran = paling sedikit yang mengisi semua sisa waktu,
  /// jadi dibulatkan ke atas supaya tiap pasangan dapat jumlah match yang sama. Kosong kalau tidak ada court yang
  /// muat satu round.
  static ({FixedSchedule schedule, int putaran}) extend({
    required List<Pair> pairs,
    required List<Court> courts,
    required List<int> roundsLeft,
    required int putaranDone,
    required int firstRound,
  }) {
    final fit = roundsLeft.fold(0, max);
    if (pairs.length < 2 || fit == 0) {
      return (schedule: const FixedSchedule(matches: [], byePairIdByRound: {}), putaran: 0);
    }
    final longest = [
      for (final (i, c) in courts.indexed)
        if (roundsLeft[i] == fit) c,
    ];
    final schedule = _Packer(
      firstRound: firstRound,
      courtsFor: (r) {
        final open = [
          for (final (i, c) in courts.indexed)
            if (roundsLeft[i] >= r) c,
        ];
        return open.isEmpty ? longest : open;
      },
    );

    final circle = pairs.length.isEven ? _circleRounds(pairs).toList() : const <_CircleRound>[];
    var putaran = 0;
    while (schedule.rounds < fit) {
      final k = putaranDone + putaran;
      final groups = pairs.length.isEven ? [circle[k % circle.length]] : _hamiltonCycle(pairs, k);
      groups.forEach(schedule.add);
      putaran++;
    }
    return (schedule: schedule.result, putaran: putaran);
  }

  /// Rencana round tambahan [active] kalau tiap court ditambah [extraMinutes] (per court id), untuk sheet Tambah round
  /// (06w–06z) dan `TournamentController.addRounds`. [pairs] = hasil Atur pasangan (04f), default pasangan sekarang.
  /// Round yang muat di tiap court ([roundsLeft], urutan `config.courts`) = ⌊(sisa + tambahan) ÷ durasi⌋, sama dengan
  /// `capacityAhead`; [fitRounds] = yang terbesar. [perPair] = match tambahan tiap pasangan.
  static ({FixedSchedule schedule, int putaran, int perPair, int fitRounds, List<int> roundsLeft}) extraRounds(
    ActiveTournament active,
    DateTime now, {
    Map<String, int> extraMinutes = const {},
    List<Pair>? pairs,
  }) {
    final config = active.config;
    pairs ??= config.fixedPairs ?? const <Pair>[];
    final roundsLeft = [
      for (final c in config.courts)
        (active.remainingBookingMinutes(c, now) + (extraMinutes[c.id] ?? 0)) ~/ config.matchDurationMinutes,
    ];
    final extra = extend(
      pairs: pairs,
      courts: config.courts,
      roundsLeft: roundsLeft,
      putaranDone: active.extraPutaran,
      firstRound: active.roundCount + 1,
    );
    return (
      schedule: extra.schedule,
      putaran: extra.putaran,
      perPair: extra.putaran * (pairs.length.isEven ? 1 : 2),
      fitRounds: roundsLeft.fold(0, max),
      roundsLeft: roundsLeft,
    );
  }

  /// Putaran circle method: tiap putaran berisi pertandingan yang saling lepas.
  static Iterable<_CircleRound> _circleRounds(List<Pair> pairs) sync* {
    // Pair dummy (null) dipakai kalau jumlahnya ganjil — lawannya berarti bye.
    final slots = <Pair?>[...pairs];
    if (slots.length.isOdd) slots.add(null);
    final n = slots.length;

    var arrangement = [...slots];
    for (var round = 0; round < n - 1; round++) {
      final games = <(Pair, Pair)>[];
      Pair? bye;

      for (var i = 0; i < n ~/ 2; i++) {
        final a = arrangement[i];
        final b = arrangement[n - 1 - i];
        if (a == null || b == null) {
          bye = a ?? b;
          continue;
        }
        games.add((a, b));
      }
      yield _CircleRound(games, bye);

      // Putar semua kecuali elemen pertama.
      arrangement = [arrangement.first, arrangement.last, ...arrangement.sublist(1, n - 1)];
    }
  }

  /// Pasangan ganjil n = 2m + 1: siklus Hamilton ke-(k mod m) dari dekomposisi Walecki. Pasangan terakhir = pusat,
  /// sisanya di lingkaran; jalur zig-zag i, i+1, i−1, i+2, …, i+m dibagi jadi dua putaran yang masing-masing
  /// mengistirahatkan satu pasangan (pusat, lalu ujung jalur), ditutup satu match antara keduanya. Tiap pasangan
  /// main dua kali, dan m siklus berturut-turut memuat setiap lawan tepat sekali.
  static List<_CircleRound> _hamiltonCycle(List<Pair> pairs, int k) {
    final hub = pairs.last;
    final m = (pairs.length - 1) ~/ 2;
    final ring = 2 * m;
    final i = k % m;
    Pair at(int x) => pairs[(x % ring + ring) % ring];
    final path = [
      at(i),
      for (var j = 1; j < m; j++) ...[at(i + j), at(i - j)],
      at(i + m),
    ];
    return [
      _CircleRound([for (var t = 0; t < ring - 1; t += 2) (path[t], path[t + 1])], hub),
      _CircleRound([for (var t = 1; t < ring - 1; t += 2) (path[t], path[t + 1]), (hub, path.first)], path.last),
      _CircleRound([(hub, path.last)], null),
    ];
  }
}

class _CircleRound {
  final List<(Pair, Pair)> games;
  final Pair? bye;
  const _CircleRound(this.games, this.bye);
}

/// Memotong putaran jadi round sebesar court yang tersedia di round itu ([courtsFor], r mulai 1). Tiap putaran
/// mulai di round baru.
class _Packer {
  final int firstRound;
  final List<Court> Function(int r) courtsFor;
  final _matches = <MatchGame>[];
  final _byes = <int, String>{};
  int rounds = 0;

  _Packer({required this.firstRound, required this.courtsFor});

  void add(_CircleRound group) {
    for (var i = 0; i < group.games.length;) {
      rounds++;
      final courts = courtsFor(rounds);
      final slice = group.games.skip(i).take(courts.length).toList();
      i += slice.length;
      final round = firstRound + rounds - 1;
      if (group.bye != null) _byes[round] = group.bye!.id;
      for (final (j, game) in slice.indexed) {
        _matches.add(
          MatchGame(
            id: 'm-r$round-${j + 1}',
            roundNumber: round,
            matchNumberInRound: j + 1,
            courtId: courts[j].id,
            pair1: game.$1,
            pair2: game.$2,
          ),
        );
      }
    }
  }

  FixedSchedule get result => FixedSchedule(matches: _matches, byePairIdByRound: _byes);
}
