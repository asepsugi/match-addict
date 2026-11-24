import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/group_stage.dart';

/// Invariant I1–I6 fase grup (logic.md §18.4, §21.2): P 8–16 × G ∈ groupCountsFor(P) (turnamen baru) ditambah P 6–15 ×
/// aturan 3.8.x–3.9.x (data lama tetap dijadwalkan sama, AC-G29) = P 6–16 × G ∈ decodableGroupCounts(P), × C 1–10; isi
/// grup = urutan acak berseed (urutan masuk layar Grup).

/// Rumus PRD 16.3 dihitung ulang di sini, terpisah dari implementasi: g pasangan, k court → r × ⌈m ÷ k⌉.
int _rounds(int g, int k) => (g.isEven ? g - 1 : g) * ((g ~/ 2 + k - 1) ~/ k);

void main() {
  for (var p = 6; p <= 16; p++) {
    for (final g in GroupStage.decodableGroupCounts(p)) {
      for (var c = 1; c <= 10; c++) {
        test('P $p · G $g · C $c', () {
          final rng = Random(p * 100 + g * 10 + c);
          final pairs = [for (var i = 0; i < p; i++) Pair(id: 'p$i', player1Id: 'a$i', player2Id: 'b$i')]..shuffle(rng);
          final sizes = GroupStage.sizes(p, g);
          final groups = <List<Pair>>[];
          var at = 0;
          for (final s in sizes) {
            groups.add(pairs.sublist(at, at += s));
          }
          final courts = [
            for (var i = 0; i < c; i++)
              Court(id: 'c$i', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: 120),
          ];
          final matches = GroupStage.schedule(groups: groups, courts: courts);
          final owned = GroupStage.courtsOfGroups(sizes, c);
          int groupOf(String id) => groups.indexWhere((gr) => gr.any((x) => x.id == id));
          int courtIndex(String id) => courts.indexWhere((x) => x.id == id);

          // I1 tiap pasangan di tepat satu grup; ukuran = sizes(P, G).
          expect([for (final gr in groups) gr.length], sizes);
          expect(sizes.fold<int>(0, (a, b) => a + b), p);
          expect({for (final gr in groups) ...gr.map((x) => x.id)}, hasLength(p));

          // I2 hanya antara pasangan satu grup; tiap dua pasangan satu grup bertemu tepat sekali.
          final met = <String>{};
          for (final m in matches) {
            final gi = groupOf(m.pair1.id);
            expect(groupOf(m.pair2.id), gi);
            expect(m.phase, GroupPhase(gi));
            expect(met.add(([m.pair1.id, m.pair2.id]..sort()).join('|')), isTrue, reason: 'bertemu dua kali');
          }
          expect(met, hasLength(sizes.fold<int>(0, (a, s) => a + s * (s - 1) ~/ 2)));

          // I3 semua match satu grup di court miliknya; C ≥ G tiap court ≤ 1 grup, C < G tiap grup 1 court.
          for (final m in matches) {
            expect(owned[(m.phase! as GroupPhase).group], contains(courtIndex(m.courtId)));
          }
          final allOwned = [for (final o in owned) ...o];
          if (c >= g) {
            expect(allOwned.toSet(), hasLength(allOwned.length));
            for (final o in owned) {
              expect(o, isNotEmpty);
            }
          } else {
            for (final o in owned) {
              expect(o, hasLength(1));
            }
          }

          // I4 tidak ada pasangan di dua match pada round yang sama.
          // I5 per round satu match per court, matchNumberInRound 1..n urut indeks court.
          final byRound = <int, List<MatchGame>>{};
          for (final m in matches) {
            (byRound[m.roundNumber] ??= []).add(m);
          }
          for (final MapEntry(key: r, value: ms) in byRound.entries) {
            final ids = [
              for (final m in ms) ...[m.pair1.id, m.pair2.id],
            ];
            expect(ids.toSet(), hasLength(ids.length), reason: 'R$r');
            final idx = [for (final m in ms) courtIndex(m.courtId)];
            expect(idx, [...idx.toSet()]..sort(), reason: 'R$r');
            expect([for (final m in ms) m.matchNumberInRound], [for (var i = 1; i <= ms.length; i++) i]);
            expect([for (final m in ms) m.id], [for (final m in ms) 'm-r$r-${m.matchNumberInRound}']);
          }
          expect(byRound.keys.toList(), [for (var r = 1; r <= byRound.length; r++) r], reason: 'round tanpa lubang');

          // I6 jumlah round fase grup = maks per court = rumus 18.3.
          final lastPerCourt = <int, int>{};
          for (final m in matches) {
            lastPerCourt[courtIndex(m.courtId)] = m.roundNumber;
          }
          final expected = c >= g
              ? [for (final (i, s) in sizes.indexed) _rounds(s, owned[i].length)].reduce(max)
              : [
                  for (var ci = 0; ci < c; ci++)
                    [
                      for (final (i, s) in sizes.indexed)
                        if (owned[i].single == ci) s * (s - 1) ~/ 2,
                    ].fold<int>(0, (a, b) => a + b),
                ].reduce(max);
          expect(matches.last.roundNumber, lastPerCourt.values.reduce(max));
          expect(matches.last.roundNumber, expected);
          expect(GroupStage.groupPhaseRounds(sizes, c), expected);
        });
      }
    }
  }
}
