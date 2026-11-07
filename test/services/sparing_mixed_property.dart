import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';

/// Test properti Mixed sparing (logic.md §13.12), dipakai versi ringkas di `sparing_mixed_test.dart` dan sweep penuh
/// bertag `slow` di `sparing_mixed_sweep_test.dart`.

/// [n] pemain klub [club], id `<tag>00…` (urut daftar).
List<Player> sizedClub(String tag, Club club, int n) => [
  for (var i = 0; i < n; i++) Player(id: '$tag${i.toString().padLeft(2, '0')}', name: '$tag$i', clubId: club.id),
];

const _club1 = Club(id: 'club-1', name: 'Klub 1');
const _club2 = Club(id: 'club-2', name: 'Klub 2');

List<Court> _courts(int n) => [
  for (var i = 1; i <= n; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: 0, bookingDurationMinutes: 600),
];

int _played(List<MatchGame> h, String id) => h.where((m) => m.pair1.contains(id) || m.pair2.contains(id)).length;

void _expectFair(List<MatchGame> h, Iterable<String> ids, String label) {
  if (ids.isEmpty) return;
  final counts = ids.map((id) => _played(h, id));
  expect(counts.reduce(max) - counts.reduce(min), lessThanOrEqualTo(1), reason: label);
}

/// Satu round: C' match di Court 1..C', partner sesama klub, pair1 klub pertama, tiap pemain paling banyak sekali.
void _expectRound(List<MatchGame> round, List<Player> c1, List<Player> c2, int courts, String label) {
  final active = ActiveTournament.sparingActiveCourts(courts: courts, club1: c1.length, club2: c2.length);
  expect(round.length, active, reason: label);
  expect([for (final m in round) m.courtId], [for (var i = 1; i <= active; i++) 'c$i'], reason: label);
  final ids1 = {for (final p in c1) p.id}, ids2 = {for (final p in c2) p.id};
  final seen = <String>{};
  for (final m in round) {
    expect(m.pair1.playerIds.every(ids1.contains), isTrue, reason: '$label pair1 klub pertama');
    expect(m.pair2.playerIds.every(ids2.contains), isTrue, reason: '$label pair2 klub kedua');
    for (final id in [...m.pair1.playerIds, ...m.pair2.playerIds]) {
      expect(seen.add(id), isTrue, reason: '$label $id dua kali');
    }
  }
}

/// [n1] / [n2] pemain, [courts] court, 30 round: bentuk round + selisih main satu klub ≤ 1 setelah setiap round.
void checkSize(int n1, int n2, int courts) {
  final c1 = sizedClub('g', _club1, n1), c2 = sizedClub('m', _club2, n2);
  final rng = Random(n1 * 1000 + n2 * 10 + courts);
  final h = <MatchGame>[];
  for (var r = 1; r <= 30; r++) {
    final label = '$n1/$n2 c$courts R$r';
    final round = EndlessRoundGenerator.generateSparingRound(
      club1: c1,
      club2: c2,
      courts: _courts(courts),
      history: h,
      roundNumber: r,
      seed: 99,
      random: rng,
    )!.matches;
    _expectRound(round, c1, c2, courts, label);
    h.addAll(round);
    _expectFair(h, c1.map((p) => p.id), '$label klub 1');
    _expectFair(h, c2.map((p) => p.id), '$label klub 2');
  }
}

/// Ukuran AC-S9 + satu pemain telat masuk klub kedua di R4 (kalau total < 30) dan satu pemain klub pertama keluar di
/// R7 (kalau sisa > 2): selisih ≤ 1 di antara yang hadir sejak awal.
void checkLateAndWithdrawn(int n1, int n2, int courts) {
  var c1 = sizedClub('g', _club1, n1), c2 = sizedClub('m', _club2, n2);
  final orig1 = {for (final p in c1) p.id}, orig2 = {for (final p in c2) p.id};
  final late = <String>{};
  final rng = Random(5);
  final h = <MatchGame>[];
  for (var r = 1; r <= 30; r++) {
    final label = '$n1/$n2 c$courts R$r (telat/keluar)';
    if (r == 4 && n1 + n2 < 30) {
      c2 = [...c2, Player(id: 'm99', name: 'telat', clubId: _club2.id)];
      late.add('m99');
    }
    if (r == 7 && c1.length > 2) c1 = c1.sublist(1);
    final round = EndlessRoundGenerator.generateSparingRound(
      club1: c1,
      club2: c2,
      courts: _courts(courts),
      history: h,
      roundNumber: r,
      seed: 7,
      latePlayerIds: late,
      random: rng,
    )!.matches;
    _expectRound(round, c1, c2, courts, label);
    h.addAll(round);
    _expectFair(h, c1.map((p) => p.id).where(orig1.contains), '$label klub 1');
    _expectFair(h, c2.map((p) => p.id).where(orig2.contains), '$label klub 2');
  }
}
