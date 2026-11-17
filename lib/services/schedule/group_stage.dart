import 'dart:math';

import '../../models/models.dart';
import 'round_robin_generator.dart';

/// Fase grup Grup + Gugur (PRD §16.3, logic.md §18.2–18.5): ukuran grup, court per grup, jadwal, dan estimasi
/// Konfigurasi. Urutan match per grup = circle method round-robin ([RoundRobinGenerator.circleRounds]).
class GroupStage {
  /// Ukuran tiap grup: ⌊P ÷ G⌋, grup awal (huruf lebih dulu) mendapat sisa satu per grup. 7/2 → [4, 3].
  static List<int> sizes(int pairs, int groups) => [
    for (var g = 0; g < groups; g++) pairs ~/ groups + (g < pairs % groups ? 1 : 0),
  ];

  /// Jumlah grup yang ditawarkan untuk P pasangan: tiap grup minimal 3 pasangan (G1, G2).
  static List<int> groupCountsFor(int pairs) => switch (pairs) {
    < 6 => const [],
    < 12 => const [2],
    _ => const [2, 4],
  };

  /// Round satu grup g pasangan dengan k court: putaran circle r dipotong per k court, dua putaran tidak digabung.
  static int _rounds(int g, int k) {
    final r = g.isEven ? g - 1 : g;
    final m = g ~/ 2;
    return k <= 0 ? 0 : r * ((m + k - 1) ~/ k);
  }

  static int _matches(int g) => g * (g - 1) ~/ 2;

  /// Indeks court (urut `config.courts`) per grup (GU3, GU4). C ≥ G: court i → grup i, court sisa ke grup yang
  /// roundnya paling banyak **dan** berkurang (seri → huruf awal), tidak ada → court itu tidak dipakai. C < G: tiap grup
  /// ke court dengan match grup paling sedikit sejauh ini (seri → court terkecil).
  static List<List<int>> courtsOfGroups(List<int> sizes, int courtCount) {
    final g = sizes.length;
    if (courtCount <= 0) return [for (var i = 0; i < g; i++) <int>[]];
    if (courtCount >= g) {
      final owned = [
        for (var i = 0; i < g; i++) [i],
      ];
      for (var c = g; c < courtCount; c++) {
        int? best;
        for (var i = 0; i < g; i++) {
          final k = owned[i].length;
          final now = _rounds(sizes[i], k);
          if (_rounds(sizes[i], k + 1) >= now) continue;
          if (best == null || now > _rounds(sizes[best], owned[best].length)) best = i;
        }
        if (best != null) owned[best].add(c);
      }
      return owned;
    }
    final load = List.filled(courtCount, 0);
    final owned = <List<int>>[];
    for (final size in sizes) {
      var c = 0;
      for (var i = 1; i < courtCount; i++) {
        if (load[i] < load[c]) c = i;
      }
      load[c] += _matches(size);
      owned.add([c]);
    }
    return owned;
  }

  /// Round fase grup = round terbanyak di antara court (tabel logic.md §18.3).
  static int groupPhaseRounds(List<int> sizes, int courtCount) {
    if (courtCount <= 0) return 0;
    final owned = courtsOfGroups(sizes, courtCount);
    if (courtCount >= sizes.length) {
      return [for (final (i, size) in sizes.indexed) _rounds(size, owned[i].length)].fold(0, max);
    }
    final perCourt = List.filled(courtCount, 0);
    for (final (i, size) in sizes.indexed) {
      perCourt[owned[i].single] += _matches(size);
    }
    return perCourt.fold(0, max);
  }

  /// Jadwal fase grup (G5, GU4, GU5), urut (round, court). Grup dengan court sendiri memakai pemotong round-robin;
  /// court yang dipakai beberapa grup bergantian satu match per round urut huruf, grup yang habis dilewati. Bye tidak
  /// dicatat: beberapa grup bisa bye di round yang sama, dan Jadwal Grup + Gugur tidak punya baris Istirahat (GU5).
  static List<MatchGame> schedule({required List<List<Pair>> groups, required List<Court> courts}) {
    if (courts.isEmpty) return const [];
    final owned = courtsOfGroups([for (final g in groups) g.length], courts.length);
    final placed = <({int round, int court, int group, (Pair, Pair) game})>[];
    if (courts.length >= groups.length) {
      for (final (g, pairs) in groups.indexed) {
        final mine = owned[g];
        final packer = RoundPacker(firstRound: 1, courtsFor: (_) => [for (final c in mine) courts[c]]);
        RoundRobinGenerator.circleRounds(pairs).forEach(packer.add);
        for (final m in packer.result.matches) {
          // Pemotong menaruh match ke-j round itu di court ke-j grup ini.
          placed.add((round: m.roundNumber, court: mine[m.matchNumberInRound - 1], group: g, game: (m.pair1, m.pair2)));
        }
      }
    } else {
      final games = [
        for (final pairs in groups) [for (final r in RoundRobinGenerator.circleRounds(pairs)) ...r.games],
      ];
      for (var c = 0; c < courts.length; c++) {
        final sharing = [
          for (var g = 0; g < groups.length; g++)
            if (owned[g].single == c) g,
        ];
        var round = 0;
        for (var i = 0; sharing.any((g) => i < games[g].length); i++) {
          for (final g in sharing) {
            if (i < games[g].length) placed.add((round: ++round, court: c, group: g, game: games[g][i]));
          }
        }
      }
    }
    placed.sort((a, b) => a.round != b.round ? a.round - b.round : a.court - b.court);
    final matches = <MatchGame>[];
    var number = 0;
    for (final p in placed) {
      number = matches.isNotEmpty && matches.last.roundNumber == p.round ? number + 1 : 1;
      matches.add(
        MatchGame(
          id: 'm-r${p.round}-$number',
          roundNumber: p.round,
          matchNumberInRound: number,
          courtId: courts[p.court].id,
          pair1: p.game.$1,
          pair2: p.game.$2,
          phase: GroupPhase(p.group),
        ),
      );
    }
    return matches;
  }

  /// Round gugur (GU10): Perempat final (4 grup) dan Semifinal dipotong per court; Final + Perebutan juara 3 satu
  /// round kecuali hanya 1 court. Dari semua court, walau ada yang kosong di fase grup (§18.12 #11).
  static int _knockoutRounds({required int groups, required int courtCount, required bool thirdPlace}) {
    if (courtCount <= 0) return 0;
    int perCourt(int matches) => (matches + courtCount - 1) ~/ courtCount;
    return (groups == 4 ? perCourt(4) : 0) + perCourt(2) + (thirdPlace && courtCount == 1 ? 2 : 1);
  }

  /// Estimasi tombol Lanjut di Konfigurasi (logic.md §18.5), pasti seperti Fixed sparing. P = ⌊[players] ÷ 2⌋ (sisa
  /// ganjil ditahan di Pasangan); tidak bergantung pada isi grup. [bookingMinutes] per court, urutan Court 1, 2, ….
  /// [overMinutes] = (round − round yang muat di booking terpendek) × durasi, 0 kalau muat. Semua 0 kalau [groups]
  /// tidak ditawarkan untuk P ini.
  static ({int rounds, int matches, int overMinutes}) estimate({
    required int players,
    required int groups,
    required List<int> bookingMinutes,
    required int matchDurationMinutes,
    required bool thirdPlace,
  }) {
    final pairs = players ~/ 2;
    if (!groupCountsFor(pairs).contains(groups) || bookingMinutes.isEmpty || matchDurationMinutes <= 0) {
      return (rounds: 0, matches: 0, overMinutes: 0);
    }
    final s = sizes(pairs, groups);
    final c = bookingMinutes.length;
    final rounds = groupPhaseRounds(s, c) + _knockoutRounds(groups: groups, courtCount: c, thirdPlace: thirdPlace);
    final matches = s.map(_matches).fold(0, (a, b) => a + b) + (groups == 4 ? 4 : 0) + 2 + 1 + (thirdPlace ? 1 : 0);
    // Sama dengan `TournamentConfig.maxRounds`: booking terpendek ÷ durasi.
    final fit = bookingMinutes.reduce(min) ~/ matchDurationMinutes;
    return (rounds: rounds, matches: matches, overMinutes: max(0, rounds - fit) * matchDurationMinutes);
  }
}
