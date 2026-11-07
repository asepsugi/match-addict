import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:sparing_proto/sparing_mixed.dart';

List<Player> club(String tag, int n) => [
  for (var i = 0; i < n; i++) Player(id: '$tag${i.toString().padLeft(2, '0')}', name: '$tag$i'),
];
List<Court> courtsOf(int n) => [
  for (var i = 1; i <= n; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: 0, bookingDurationMinutes: 600),
];

int played(List<MatchGame> h, String id) => h.where((m) => m.pair1.contains(id) || m.pair2.contains(id)).length;

void check(List<MatchGame> h, List<Player> c1, List<Player> c2, Iterable<String> fair1, Iterable<String> fair2, String label) {
  for (final (ids, tag) in [(fair1, 'klub 1'), (fair2, 'klub 2')]) {
    if (ids.isEmpty) continue;
    final c = ids.map((id) => played(h, id));
    expect(c.reduce(max) - c.reduce(min), lessThanOrEqualTo(1), reason: '$label $tag');
  }
}

void main() {
  test('Mixed sparing: semua ukuran 2–28 per klub (total ≤ 30), court 1/2/3/4/7/10, 30 round', () {
    var cases = 0;
    for (var n1 = 2; n1 <= 28; n1++) {
      for (var n2 = 2; n1 + n2 <= 30; n2++) {
        for (final c in [1, 2, 3, 4, 7, 10]) {
          final c1 = club('g', n1), c2 = club('m', n2), courts = courtsOf(c);
          final h = <MatchGame>[];
          final rng = Random(n1 * 1000 + n2 * 10 + c);
          final active = SparingMixed.activeCourts(c, n1, n2);
          for (var r = 1; r <= 30; r++) {
            final round = SparingMixed.generateRound(
              club1: c1, club2: c2, courts: courts, history: h, roundNumber: r, seed: 99, random: rng)!;
            expect(round.matches.length, active);
            final seen = <String>{};
            for (final m in round.matches) {
              expect(m.pair1.playerIds.every((id) => id.startsWith('g')), isTrue);
              expect(m.pair2.playerIds.every((id) => id.startsWith('m')), isTrue);
              for (final id in [...m.pair1.playerIds, ...m.pair2.playerIds]) {
                expect(seen.add(id), isTrue);
              }
            }
            h.addAll(round.matches);
            check(h, c1, c2, c1.map((p) => p.id), c2.map((p) => p.id), '$n1/$n2 c$c R$r');
          }
          cases++;
        }
      }
    }
    // ignore: avoid_print
    print('Mixed: $cases ukuran × 30 round lolos');
  });

  test('Mixed sparing AC-S9 + pemain telat/keluar per klub', () {
    for (final (n1, n2, c) in [(8, 6, 2), (7, 6, 2), (8, 3, 2), (15, 15, 4), (2, 2, 1)]) {
      var c1 = club('g', n1), c2 = club('m', n2);
      final orig1 = c1.map((p) => p.id).toSet(), orig2 = c2.map((p) => p.id).toSet();
      final late = <String>{};
      final h = <MatchGame>[];
      final rng = Random(5);
      for (var r = 1; r <= 30; r++) {
        // R4: satu pemain telat masuk klub 2; R7: satu pemain klub 1 keluar (kalau tersisa > 2).
        if (r == 4 && n1 + n2 < 30) {
          c2 = [...c2, const Player(id: 'm99', name: 'telat')];
          late.add('m99');
        }
        if (r == 7 && c1.length > 2) c1 = c1.sublist(1);
        final round = SparingMixed.generateRound(
          club1: c1, club2: c2, courts: courtsOf(c), history: h, roundNumber: r, seed: 7, late: late, random: rng)!;
        h.addAll(round.matches);
        check(
          h,
          c1,
          c2,
          c1.map((p) => p.id).where(orig1.contains),
          c2.map((p) => p.id).where(orig2.contains),
          '$n1/$n2 c$c R$r',
        );
      }
    }
  });
}
