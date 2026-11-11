import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/sparing_fixed_generator.dart';

List<Pair> _pairs(String club, int n) => [
  for (var i = 1; i <= n; i++) Pair(id: '$club$i', player1Id: '$club${i}a', player2Id: '$club${i}b'),
];

List<Court> _courts(int n, [int minutes = 120]) => [
  for (var i = 1; i <= n; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: minutes),
];

// Pasangan 13A (logic.md §13.11): Garuda G1–G4, Matcha M1–M3.
final _garuda = _pairs('G', 4);
final _matcha = _pairs('M', 3);

/// Satu baris per round: "G1–M1 G2–M2 | G3 G4 M3" (court berurutan, lalu yang istirahat).
List<String> _table(SparingFixedSchedule s) => [
  for (final r in s.matches.map((m) => m.roundNumber).toSet())
    '${s.matches.where((m) => m.roundNumber == r).map((m) => '${m.pair1.id}–${m.pair2.id}').join(' ')}'
        ' | ${s.restingPairIdsByRound[r]!.join(' ')}',
];

Map<String, int> _played(Iterable<MatchGame> ms) {
  final count = <String, int>{};
  for (final m in ms) {
    for (final id in [m.pair1.id, m.pair2.id]) {
      count[id] = (count[id] ?? 0) + 1;
    }
  }
  return count;
}

/// Invariant per round (logic.md §13.12) sambil menghitung jumlah main ([counts]) dan pertemuan ([edges]) menerus.
void _checkRounds({
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
      expect(ids1.contains(m.pair1.id), isTrue, reason: '$label R$r pair1 bukan klub pertama');
      expect(ids2.contains(m.pair2.id), isTrue, reason: '$label R$r pair2 bukan klub kedua');
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

void _expectNoPairTwicePerRound(List<MatchGame> ms, String label) {
  for (final r in ms.map((m) => m.roundNumber).toSet()) {
    final ids = [
      for (final m in ms.where((m) => m.roundNumber == r)) ...[m.pair1.id, m.pair2.id],
    ];
    expect(ids.toSet(), hasLength(ids.length), reason: '$label R$r');
  }
}

void main() {
  group('Jadwal awal Fixed sparing (logic.md §13.2)', () {
    test('AC-S5 13A: 4 / 3 pasangan, 2 court → tabel 13.11 persis', () {
      final s = SparingFixedGenerator.generate(club1: _garuda, club2: _matcha, courts: _courts(2));
      expect(s.matches, hasLength(12));
      expect(s.roundCount, 6);
      expect(_table(s), [
        'G1–M1 G2–M2 | G3 G4 M3',
        'G3–M3 G4–M1 | G1 G2 M2',
        'G1–M2 G2–M3 | G3 G4 M1',
        'G3–M1 G4–M2 | G1 G2 M3',
        'G1–M3 G2–M1 | G3 G4 M2',
        'G3–M2 G4–M3 | G1 G2 M1',
      ]);
      expect(s.matches.every((m) => m.courtId == 'c${m.matchNumberInRound}'), isTrue);
      expect(s.matches.first.id, 'm-r1-1');

      // Jumlah main per round (13.11): Garuda dan Matcha, urut daftar.
      final garuda = <String>[], matcha = <String>[];
      for (var r = 1; r <= 6; r++) {
        final c = _played(s.matches.where((m) => m.roundNumber <= r));
        garuda.add(_garuda.map((p) => c[p.id] ?? 0).join('·'));
        matcha.add(_matcha.map((p) => c[p.id] ?? 0).join('·'));
      }
      expect(garuda, ['1·1·0·0', '1·1·1·1', '2·2·1·1', '2·2·2·2', '3·3·2·2', '3·3·3·3']);
      expect(matcha, ['1·1·0', '2·1·1', '2·2·2', '3·3·2', '4·3·3', '4·4·4']);

      // Tiap pasangan Garuda bertemu tiap pasangan Matcha tepat sekali, nol sesama klub.
      final edges = s.matches.map((m) => '${m.pair1.id}-${m.pair2.id}').toList();
      expect(edges.toSet(), hasLength(12));
      expect(s.matches.every((m) => m.pair1.id.startsWith('G') && m.pair2.id.startsWith('M')), isTrue);
    });

    test('AC-S6 14m: 8 / 4 pemain (4 / 2 pasangan), 3 court → 2 court aktif, Court 3 tanpa match', () {
      final s = SparingFixedGenerator.generate(club1: _garuda, club2: _pairs('M', 2), courts: _courts(3));
      expect(SparingFixedGenerator.activeCourts(3, 4, 2), 2);
      expect(_table(s), ['G1–M1 G2–M2 | G3 G4', 'G3–M1 G4–M2 | G1 G2', 'G1–M2 G2–M1 | G3 G4', 'G3–M2 G4–M1 | G1 G2']);
      expect(s.matches.any((m) => m.courtId == 'c3'), isFalse);
    });

    test('AC-S6 ukuran lain: 2 / 2 di 1 court, 14 / 1 di 2 court, 8 / 7 di 4 court, 3 / 3 di 2 court', () {
      for (final (p1, p2, c, matches, rounds) in [
        (2, 2, 1, 4, 4),
        (14, 1, 2, 14, 14),
        (8, 7, 4, 56, 14),
        (3, 3, 2, 9, 5),
      ]) {
        final s = SparingFixedGenerator.generate(club1: _pairs('G', p1), club2: _pairs('M', p2), courts: _courts(c));
        expect((s.matches.length, s.roundCount), (matches, rounds), reason: '$p1/$p2 c$c');
        if (p2 == 1) expect(s.matches.any((m) => m.courtId == 'c2'), isFalse, reason: 'Court 2 kosong');
      }
    });

    test('tanpa pasangan atau tanpa court → kosong', () {
      expect(SparingFixedGenerator.generate(club1: _garuda, club2: const [], courts: _courts(2)).matches, isEmpty);
      expect(SparingFixedGenerator.generate(club1: _garuda, club2: _matcha, courts: const []).matches, isEmpty);
    });
  });

  group('Round tambahan Fixed sparing (logic.md §13.3)', () {
    test('AC-S18 14n: 13A setelah R6, sisa 30 menit → 1 satuan, R7–R12 persis, Garuda +3, Matcha +4', () {
      final ext = SparingFixedGenerator.extend(
        club1: _garuda,
        club2: _matcha,
        courts: _courts(2),
        roundsLeft: [2, 2],
        unitsDone: 0,
        firstRound: 7,
      );
      expect(ext.units, 1);
      expect(ext.schedule.matches, hasLength(12));
      expect(ext.schedule.matches.first.roundNumber, 7);
      expect(ext.schedule.roundCount, 12);
      expect(ext.schedule.matches.first.id, 'm-r7-1');
      expect(
        [for (final row in _table(ext.schedule)) row.split(' | ').first],
        ['G1–M2 G2–M3', 'G3–M1 G4–M2', 'G1–M3 G2–M1', 'G3–M2 G4–M3', 'G1–M1 G2–M2', 'G3–M3 G4–M1'],
      );
      final c = _played(ext.schedule.matches);
      expect([for (final p in _garuda) c[p.id]], everyElement(3));
      expect([for (final p in _matcha) c[p.id]], everyElement(4));
    });

    test('AC-S18 satuan: 4 / 2 pasangan = 4 match, 3 / 3 = 3 match', () {
      expect(SparingFixedGenerator.unitMatches(4, 3), 12);
      expect(SparingFixedGenerator.unitMatches(4, 2), 4);
      expect(SparingFixedGenerator.unitMatches(3, 3), 3);
      // Satu klub kosong sementara di Atur pasangan: tidak melempar pembagian nol.
      expect(SparingFixedGenerator.unitMatches(0, 0), 0);
      expect(SparingFixedGenerator.unitMatches(4, 0), 0);
      final e42 = SparingFixedGenerator.extend(
        club1: _garuda,
        club2: _pairs('M', 2),
        courts: _courts(3),
        roundsLeft: [1, 1, 1],
        unitsDone: 0,
        firstRound: 5,
      );
      expect((e42.units, e42.schedule.matches.length), (1, 4));
      final e33 = SparingFixedGenerator.extend(
        club1: _pairs('G', 3),
        club2: _matcha,
        courts: _courts(2),
        roundsLeft: [1, 1],
        unitsDone: 0,
        firstRound: 6,
      );
      expect((e33.units, e33.schedule.matches.length), (1, 3));
    });

    test('tidak ada court yang muat satu round → tidak ada yang dibuat', () {
      final ext = SparingFixedGenerator.extend(
        club1: _garuda,
        club2: _matcha,
        courts: _courts(2),
        roundsLeft: [0, 0],
        unitsDone: 0,
        firstRound: 7,
      );
      expect(ext.units, 0);
      expect(ext.schedule.matches, isEmpty);
    });

    // Regresi jebakan §13.2: geser blok `(s + K mod g)` membuat M1 main dua kali di round yang melintasi batas
    // satuan ganjil → genap. K harus naik terus.
    test('regresi K mod g: 4 / 6 pasangan, 3 court, sisa [3, 6, 13] setelah satuan ganjil', () {
      final club1 = _pairs('G', 4), club2 = _pairs('M', 6), courts = _courts(3);
      for (final done in [1, 3, 5]) {
        final ext = SparingFixedGenerator.extend(
          club1: club1,
          club2: club2,
          courts: courts,
          roundsLeft: [3, 6, 13],
          unitsDone: done,
          firstRound: 20,
        );
        expect(ext.units, 2);
        _expectNoPairTwicePerRound(ext.schedule.matches, 'unitsDone $done');
      }
    });

    group('extraRounds: court di sheet = C\' (4 / 2 pasangan, 3 court)', () {
      final start = DateTime(2026, 11, 4, 19);
      final club1 = _pairs('G', 4), club2 = _pairs('M', 2);
      ActiveTournament active(List<int> bookings) {
        final courts = [
          for (final (i, b) in bookings.indexed)
            Court(id: 'c${i + 1}', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: b),
        ];
        final base = SparingFixedGenerator.generate(club1: club1, club2: club2, courts: courts);
        return ActiveTournament(
          tournament: Tournament(
            id: 't-c',
            createdAt: start,
            config: TournamentConfig(
              sport: SportType.padel,
              mode: PartnerMode.fixed,
              matchDurationMinutes: 15,
              courts: courts,
              players: const [],
              fixedPairs: [...club1, ...club2],
            ),
            matches: base.matches,
          ),
        );
      }

      test('3 court muat, C\' = 2: "2 court", tanpa berkurang', () {
        final a = active([180, 180, 180]);
        final plan = SparingFixedGenerator.extraRounds(a, start.add(const Duration(minutes: 60)), club1: club1, club2: club2);
        expect(plan.roundsLeft, [8, 8, 8]);
        expect(plan.courts, 2);
        expect(plan.fewerCourtsFrom, isNull);
      });

      test('Court 1 habis duluan tapi masih 2 court lain: tetap 2 court; tinggal 1 court → berkurang', () {
        final a = active([90, 120, 180]);
        final plan = SparingFixedGenerator.extraRounds(a, start.add(const Duration(minutes: 60)), club1: club1, club2: club2);
        expect(plan.roundsLeft, [2, 4, 8]);
        expect(plan.courts, 2);
        // R+3 tinggal Court 2 dan 3 (tetap C' = 2); R+5 tinggal Court 3.
        expect(plan.rounds, 8);
        expect(plan.fewerCourtsFrom, 5);
      });
    });

    group('extraRounds dari turnamen berjalan', () {
      final start = DateTime(2026, 11, 4, 19);
      final base = SparingFixedGenerator.generate(club1: _garuda, club2: _matcha, courts: _courts(2));
      final active = ActiveTournament(
        tournament: Tournament(
          id: 't13a',
          createdAt: start,
          config: TournamentConfig(
            sport: SportType.padel,
            mode: PartnerMode.fixed,
            matchDurationMinutes: 15,
            courts: _courts(2),
            players: const [],
            fixedPairs: [..._garuda, ..._matcha],
          ),
          matches: base.matches,
        ),
      );

      test('AC-S18 14n: sisa 30 menit → fit 2, R7–R12, lewat booking 01:00, perPair Garuda 3 · Matcha 4', () {
        final plan = SparingFixedGenerator.extraRounds(
          active,
          start.add(const Duration(minutes: 90)),
          club1: _garuda,
          club2: _matcha,
        );
        expect(plan.roundsLeft, [2, 2]);
        expect(plan.fitRounds, 2);
        expect(plan.units, 1);
        expect(plan.perPair, (club1: 3, club2: 4));
        expect(plan.schedule.matches.first.roundNumber, 7);
        expect(plan.schedule.roundCount, 12);
        expect(plan.overMinutes, 60);
      });

      test('kedua court +1 jam → tetap 1 satuan, tanpa lewat booking', () {
        final plan = SparingFixedGenerator.extraRounds(
          active,
          start.add(const Duration(minutes: 90)),
          club1: _garuda,
          club2: _matcha,
          extraMinutes: const {'c1': 60, 'c2': 60},
        );
        expect(plan.fitRounds, 6);
        expect(plan.units, 1);
        expect(plan.schedule.roundCount - active.roundCount, 6);
        expect(plan.overMinutes, 0);
      });

      test('satuan berikutnya melanjutkan extraPutaran: satuan kedua = blok K = g + 1', () {
        final second = SparingFixedGenerator.extraRounds(
          ActiveTournament(tournament: active.tournament, extraPutaran: 1),
          start.add(const Duration(minutes: 90)),
          club1: _garuda,
          club2: _matcha,
        );
        // g = 1, K = 2: slot pertama G1 lawan M((0 + 2) mod 3) = M3.
        expect('${second.schedule.matches.first.pair1.id}–${second.schedule.matches.first.pair2.id}', 'G1–M3');
      });
    });
  });

  group('Estimasi Konfigurasi Fixed sparing (logic.md §13.4)', () {
    ({int rounds, int matches, int activeCourts, int overMinutes}) est(int n1, int n2, int courts) =>
        SparingFixedGenerator.estimate(
          players1: n1,
          players2: n2,
          bookingMinutes: List.filled(courts, 120),
          matchDurationMinutes: 15,
        );

    test('AC-S7a 13h: 8 / 6 di 2 court → 6 round · 12 match, muat', () {
      expect(est(8, 6, 2), (rounds: 6, matches: 12, activeCourts: 2, overMinutes: 0));
    });

    test('AC-S7a 14f: 16 / 14 di 4 court → 14 round, lewat booking 90 menit', () {
      expect(est(16, 14, 4), (rounds: 14, matches: 56, activeCourts: 4, overMinutes: 90));
    });

    test('AC-S7a 14g: 8 / 4 di 3 court → 4 round · 8 match · 2 court aktif', () {
      expect(est(8, 4, 3), (rounds: 4, matches: 8, activeCourts: 2, overMinutes: 0));
    });

    test('28 / 2 di 2 court → 14 round, lewat 90 menit; 9 / 6 = 8 / 6 (sisa ganjil ditahan)', () {
      expect(est(28, 2, 2), (rounds: 14, matches: 14, activeCourts: 1, overMinutes: 90));
      expect(est(9, 6, 2), est(8, 6, 2));
    });

    test('lewat booking dihitung dari booking terpendek di antara court aktif saja', () {
      final e = SparingFixedGenerator.estimate(
        players1: 8,
        players2: 4,
        bookingMinutes: [120, 60, 30],
        matchDurationMinutes: 15,
      );
      expect((e.activeCourts, e.overMinutes), (2, 0));
    });
  });

  // Test properti §13.12 Fixed (prototipe ±8 detik untuk kedua sweep).
  group('Test properti Fixed sparing (logic.md §13.12)', () {
    test('jadwal awal: 1–15 pasangan per klub × 1–10 court', () {
      var cases = 0;
      for (var p1 = 1; p1 <= 15; p1++) {
        for (var p2 = 1; p2 <= 15; p2++) {
          for (var c = 1; c <= 10; c++) {
            final club1 = _pairs('G', p1), club2 = _pairs('M', p2), courts = _courts(c);
            final s = SparingFixedGenerator.generate(club1: club1, club2: club2, courts: courts);
            final active = min(c, min(p1, p2));
            final m = p1 * p2;
            final label = '$p1/$p2 c$c';
            expect(s.matches.length, m, reason: label);
            expect(s.roundCount, (m + active - 1) ~/ active, reason: '$label R');
            for (var r = 1; r < s.roundCount; r++) {
              expect(s.matches.where((x) => x.roundNumber == r).length, active, reason: '$label R$r penuh');
            }
            final counts = <String, int>{}, edges = <String, int>{};
            _checkRounds(
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
              expect(counts[p.id], p2, reason: label);
            }
            for (final p in club2) {
              expect(counts[p.id], p1, reason: label);
            }
            cases++;
          }
        }
      }
      expect(cases, 15 * 15 * 10);
    });

    test('round tambahan: ukuran sama × 8 tambahan berantai (sisa sama, menurun, acak 0–14)', () {
      final rng = Random(7);
      var cases = 0;
      for (var p1 = 1; p1 <= 15; p1++) {
        for (var p2 = 1; p2 <= 15; p2++) {
          for (var c = 1; c <= 10; c++) {
            final club1 = _pairs('G', p1), club2 = _pairs('M', p2), courts = _courts(c);
            final label0 = '$p1/$p2 c$c';
            final base = SparingFixedGenerator.generate(club1: club1, club2: club2, courts: courts);
            final counts = <String, int>{}, edges = <String, int>{};
            _checkRounds(
              matches: base.matches,
              club1: club1,
              club2: club2,
              counts: counts,
              edges: edges,
              expectedCourts: (_) => courts.take(min(c, min(p1, p2))).toList(),
              label: label0,
            );
            final g = p1.gcd(p2), l = SparingFixedGenerator.unitMatches(p1, p2);
            var unitsDone = 0;
            var lastRound = base.roundCount;
            for (var step = 0; step < 8; step++) {
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
              expect(ext.schedule.matches.length, ext.units * l, reason: label);
              expect(ext.schedule.roundCount - lastRound, greaterThanOrEqualTo(fit), reason: '$label mengisi waktu');
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

              // Satuan minimal: satu satuan kurang tidak sampai round ke-fit.
              var before = 0;
              for (var r = 1; r < fit; r++) {
                before += expected(lastRound + r).length;
              }
              expect((ext.units - 1) * l, lessThanOrEqualTo(before), reason: '$label minimal');
              _checkRounds(
                matches: ext.schedule.matches,
                club1: club1,
                club2: club2,
                counts: counts,
                edges: edges,
                expectedCourts: expected,
                label: label,
              );
              for (var r = lastRound + 1; r < ext.schedule.roundCount; r++) {
                expect(
                  ext.schedule.matches.where((x) => x.roundNumber == r).length,
                  expected(r).length,
                  reason: '$label R$r penuh',
                );
              }
              unitsDone += ext.units;
              lastRound = ext.schedule.roundCount;
              // Di batas satuan jumlah main satu klub sama persis; tiap kombinasi 1 + ⌊u/g⌋ atau 1 + ⌈u/g⌉ kali.
              for (final p in club1) {
                expect(counts[p.id], p2 + unitsDone * l ~/ p1, reason: '$label klub pertama sama');
              }
              for (final p in club2) {
                expect(counts[p.id], p1 + unitsDone * l ~/ p2, reason: '$label klub kedua sama');
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
  });
}
