import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:sparing_proto/sparing_mixed.dart';

void main() {
  // Tabel 13.4 "Ukuran lain, 8 round": (n1, n2, court) → court aktif, match, min–max main per klub.
  test('13.4 tabel 8 round', () {
    for (final (n1, n2, c) in [(8, 6, 2), (7, 6, 2), (8, 3, 2), (15, 15, 4), (2, 2, 1)]) {
      final c1 = [for (var i = 0; i < n1; i++) Player(id: 'g$i', name: 'g$i')];
      final c2 = [for (var i = 0; i < n2; i++) Player(id: 'm$i', name: 'm$i')];
      final courts = [for (var i = 1; i <= c; i++) Court(id: 'c$i', name: 'C$i', colorIndex: 0, bookingDurationMinutes: 120)];
      final h = <MatchGame>[];
      final rng = Random(1);
      for (var r = 1; r <= 8; r++) {
        h.addAll(SparingMixed.generateRound(club1: c1, club2: c2, courts: courts, history: h, roundNumber: r, seed: 3, random: rng)!.matches);
      }
      String span(List<Player> ps) {
        final x = ps.map((p) => h.where((m) => m.pair1.contains(p.id) || m.pair2.contains(p.id)).length);
        final lo = x.reduce(min), hi = x.reduce(max);
        return lo == hi ? '$lo' : '$lo–$hi';
      }
      final used = h.map((m) => m.courtId).toSet();
      // ignore: avoid_print
      print('$n1/$n2 c$c: aktif ${SparingMixed.activeCourts(c, n1, n2)}, ${h.length} match, ${span(c1)} / ${span(c2)}, court dipakai $used');
    }
  });
}
