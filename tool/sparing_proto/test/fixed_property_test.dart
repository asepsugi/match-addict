import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:sparing_proto/sparing_fixed.dart';

List<Pair> pairsOf(String club, int n) => [
  for (var i = 1; i <= n; i++) Pair(id: '$club$i', player1Id: '$club${i}a', player2Id: '$club${i}b'),
];

List<Court> courtsOf(int n) => [
  for (var i = 1; i <= n; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: 120),
];

/// Cek invariant tiap round dan kembalikan jumlah main per pasangan (lanjut dari [counts]).
void checkRounds({
  required List<MatchGame> matches,
  required List<Pair> club1,
  required List<Pair> club2,
  required Map<String, int> counts,
  required Map<String, int> edges,
  required List<Court> Function(int round) expectedCourts,
  required String label,
}) {
  final ids1 = club1.map((p) => p.id).toSet();
  final ids2 = club2.map((p) => p.id).toSet();
  final rounds = matches.map((m) => m.roundNumber).toSet().toList()..sort();
  for (final r in rounds) {
    final ms = matches.where((m) => m.roundNumber == r).toList();
    final seen = <String>{};
    final courts = expectedCourts(r);
    expect(ms.length, lessThanOrEqualTo(courts.length), reason: '$label R$r terlalu banyak match');
    for (final (j, m) in ms.indexed) {
      expect(ids1.contains(m.pair1.id), isTrue, reason: '$label R$r pair1 bukan klub 1');
      expect(ids2.contains(m.pair2.id), isTrue, reason: '$label R$r pair2 bukan klub 2');
      expect(seen.add(m.pair1.id) && seen.add(m.pair2.id), isTrue, reason: '$label R$r pasangan dua kali');
      expect(m.courtId, courts[j].id, reason: '$label R$r court');
      counts[m.pair1.id] = (counts[m.pair1.id] ?? 0) + 1;
      counts[m.pair2.id] = (counts[m.pair2.id] ?? 0) + 1;
      final e = '${m.pair1.id}-${m.pair2.id}';
      edges[e] = (edges[e] ?? 0) + 1;
    }
    for (final club in [club1, club2]) {
      final c = club.map((p) => counts[p.id] ?? 0);
      expect(c.reduce(max) - c.reduce(min), lessThanOrEqualTo(1), reason: '$label selisih setelah R$r');
    }
  }
}

void main() {
  // 1–15 pasangan per klub (1 = klub 2–3 pemain, K6; 15 + 15 = 30 pemain), 1–10 court.
  test('jadwal awal: semua ukuran', () {
    var cases = 0;
    for (var p1 = 1; p1 <= 15; p1++) {
      for (var p2 = 1; p2 <= 15; p2++) {
        for (var c = 1; c <= 10; c++) {
          final club1 = pairsOf('G', p1), club2 = pairsOf('M', p2), courts = courtsOf(c);
          final s = SparingFixedGenerator.generate(club1: club1, club2: club2, courts: courts);
          final active = min(c, min(p1, p2));
          final m = p1 * p2;
          final label = '$p1/$p2 c$c';
          expect(s.matches.length, m, reason: label);
          expect(s.roundCount, max((m + active - 1) ~/ active, max(p1, p2)), reason: '$label R');
          // Semua round penuh kecuali yang terakhir.
          for (var r = 1; r < s.roundCount; r++) {
            expect(s.matches.where((x) => x.roundNumber == r).length, active, reason: '$label R$r penuh');
          }
          final counts = <String, int>{}, edges = <String, int>{};
          checkRounds(
            matches: s.matches,
            club1: club1,
            club2: club2,
            counts: counts,
            edges: edges,
            expectedCourts: (_) => courts.take(active).toList(),
            label: label,
          );
          expect(edges.length, m, reason: '$label tiap lawan');
          expect(edges.values.every((v) => v == 1), isTrue, reason: '$label tepat sekali');
          for (final p in club1) {
            expect(counts[p.id], p2);
          }
          for (final p in club2) {
            expect(counts[p.id], p1);
          }
          cases++;
        }
      }
    }
    expect(cases, 15 * 15 * 10);
  });

  // Round tambahan berantai: 8 kali Tambah round berturut-turut, sisa round per court beragam.
  test('extend: satuan berantai, court berhenti, semua ukuran', () {
    final rng = Random(7);
    var cases = 0;
    for (var p1 = 1; p1 <= 15; p1++) {
      for (var p2 = 1; p2 <= 15; p2++) {
        for (var c = 1; c <= 10; c++) {
          final club1 = pairsOf('G', p1), club2 = pairsOf('M', p2), courts = courtsOf(c);
          final label0 = '$p1/$p2 c$c';
          final base = SparingFixedGenerator.generate(club1: club1, club2: club2, courts: courts);
          final counts = <String, int>{}, edges = <String, int>{};
          checkRounds(
            matches: base.matches,
            club1: club1,
            club2: club2,
            counts: counts,
            edges: edges,
            expectedCourts: (_) => courts.take(min(c, min(p1, p2))).toList(),
            label: label0,
          );
          final g = gcd(p1, p2), l = lcm(p1, p2);
          var unitsDone = 0;
          var lastRound = base.roundCount;
          for (var step = 0; step < 8; step++) {
            // Pola: semua sama, menurun, acak (0..14 round per court, minimal satu court > 0).
            final roundsLeft = switch (step) {
              0 => List.filled(c, 1 + rng.nextInt(6)),
              1 => [for (var i = 0; i < c; i++) max(0, 8 - 2 * i)],
              _ => [for (var i = 0; i < c; i++) rng.nextInt(15)],
            };
            if (roundsLeft.every((x) => x == 0)) roundsLeft[0] = 3;
            final fit = roundsLeft.reduce(max);
            final ext = SparingFixedGenerator.extend(
              club1: club1,
              club2: club2,
              courts: courts,
              roundsLeft: roundsLeft,
              unitsDone: unitsDone,
              firstRound: lastRound + 1,
            );
            final label = '$label0 tambah#$step $roundsLeft';
            final rounds = ext.schedule.roundCount - lastRound;
            expect(ext.schedule.matches.length, ext.units * l, reason: label);
            expect(rounds, greaterThanOrEqualTo(fit), reason: '$label mengisi waktu');
            // Paling sedikit: satu satuan kurang tidak sampai round ke-fit.
            var before = 0;
            final longest = [
              for (var i = 0; i < c; i++)
                if (roundsLeft[i] == fit) courts[i],
            ];
            List<Court> expected(int r) {
              final rr = r - lastRound;
              final open = [
                for (var i = 0; i < c; i++)
                  if (roundsLeft[i] >= rr) courts[i],
              ];
              final use = open.isEmpty ? longest : open;
              return use.take(min(use.length, min(p1, p2))).toList();
            }

            for (var r = 1; r < fit; r++) {
              before += expected(lastRound + r).length;
            }
            expect((ext.units - 1) * l, lessThanOrEqualTo(before), reason: '$label minimal');
            checkRounds(
              matches: ext.schedule.matches,
              club1: club1,
              club2: club2,
              counts: counts,
              edges: edges,
              expectedCourts: expected,
              label: label,
            );
            // Semua round penuh (ukuran court aktif saat itu) kecuali yang terakhir.
            for (var r = lastRound + 1; r < ext.schedule.roundCount; r++) {
              expect(
                ext.schedule.matches.where((x) => x.roundNumber == r).length,
                expected(r).length,
                reason: '$label R$r penuh',
              );
            }
            unitsDone += ext.units;
            lastRound = ext.schedule.roundCount;
            // Di batas satuan: jumlah main per klub sama persis, dan lawan berulang merata
            // (tiap kombinasi 1 + ⌊u/g⌋ atau 1 + ⌈u/g⌉ kali — tidak ada pertemuan ketiga sebelum semua dua kali).
            for (final p in club1) {
              expect(counts[p.id], p2 + unitsDone * l ~/ p1, reason: '$label klub 1 sama');
            }
            for (final p in club2) {
              expect(counts[p.id], p1 + unitsDone * l ~/ p2, reason: '$label klub 2 sama');
            }
            final lo = 1 + unitsDone ~/ g, hi = 1 + (unitsDone + g - 1) ~/ g;
            for (final a in club1) {
              for (final b in club2) {
                final v = edges['${a.id}-${b.id}'] ?? 0;
                expect(v >= lo && v <= hi, isTrue, reason: '$label lawan ${a.id}-${b.id} = $v');
              }
            }
          }
          cases++;
        }
      }
    }
    expect(cases, 15 * 15 * 10);
  });
}
