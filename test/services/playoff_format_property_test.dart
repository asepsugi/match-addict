import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';
import 'package:match_addict/services/schedule/playoff_format.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import 'group_knockout_fixture.dart';

/// Syarat security W2 (docs/security.md): 36 kombinasi AC-G26 (urutan juara 3! × grup asal WC1/WC2 3 × 2) dan bagan
/// dari `WildcardPick` × ubah format / Juara 3 di tengah gugur → `canEncode` true dan encode(decode(x)) == encode(x).

const _rounds = [
  KnockoutRound.quarterfinal,
  KnockoutRound.semifinal,
  KnockoutRound.thirdPlace,
  KnockoutRound.finalRound,
];
const _formats = [
  ScoreFormat(ScoringMethod.raceTo, 5),
  ScoreFormat(ScoringMethod.bestOf, 3),
  ScoreFormat(ScoringMethod.americano, 21),
];

List<List<int>> _permutations(List<int> xs) => xs.length <= 1
    ? [xs]
    : [
        for (final x in xs)
          for (final rest in _permutations([...xs]..remove(x))) [x, ...rest],
      ];

void _expectStored(ActiveTournament a, String reason) {
  expect(TournamentCodec.canEncode(a), isTrue, reason: reason);
  final raw = TournamentCodec.encode(a);
  final back = TournamentCodec.decode(raw);
  expect(back, isNotNull, reason: reason);
  expect(TournamentCodec.encode(back!), raw, reason: reason);
  expect(back.config.groupKnockout!.wildcards, a.config.groupKnockout!.wildcards, reason: reason);
}

/// Hasil gugur acak berseed + ubah format/Juara 3 di sela-selanya; tiap langkah harus tersimpan dan terbaca.
void _walk(ActiveTournament start, Random rng, String name) {
  var a = start;
  _expectStored(a, '$name awal');
  final order = ['PF1', 'PF2', 'PF3', 'PF4', 'SF1', 'SF2', 'J3', 'F'];
  for (final code in order) {
    // Ubah format satu babak acak (ditolak kalau terkunci: state tetap) dan Juara 3 bolak-balik selagi boleh.
    final round = _rounds[rng.nextInt(_rounds.length)];
    a = PlayoffFormat.withFormat(a, round, _formats[rng.nextInt(_formats.length)]) ?? a;
    _expectStored(a, '$name format ${round.name} sebelum $code');
    if (rng.nextBool()) {
      final flipped = PlayoffFormat.withThirdPlace(a, !a.config.groupKnockout!.thirdPlace);
      if (flipped != null) {
        _expectStored(flipped, '$name juara 3 → ${flipped.config.groupKnockout!.thirdPlace} sebelum $code');
        a = rng.nextBool()
            ? flipped
            : PlayoffFormat.withThirdPlace(flipped, !flipped.config.groupKnockout!.thirdPlace)!;
      }
    }
    final m = a.matches.where((x) => x.phase?.code == code).firstOrNull;
    if (m == null || m.pair1.isTbd || m.pair2.isTbd) continue;
    a = rng.nextBool() ? a.ko(code, 6, rng.nextInt(6)) : a.ko(code, rng.nextInt(6), 6);
    _expectStored(a, '$name $code');
  }
  _expectStored(a.finish(), '$name diakhiri');
}

void main() {
  group('W2 / AC-G26: 36 kombinasi × C 1–4 × ubah format/Juara 3', () {
    var seed = 0;
    for (final champions in _permutations([0, 1, 2])) {
      for (final wc1 in [0, 1, 2]) {
        for (final wc2 in [0, 1, 2]) {
          if (wc1 == wc2) continue;
          final name = 'J$champions WC1 ${GroupKnockout.letter(wc1)}3 WC2 ${GroupKnockout.letter(wc2)}3';
          test(name, () {
            for (var courts = 1; courts <= 4; courts++) {
              final seeding = Seeding(
                groupSlots: [
                  for (final g in g16G) [g[0], g[1]],
                ],
                champions: champions,
                wildcards: [g16G[wc1][2], g16G[wc2][2]],
              );
              final a = t16G(courts: courts, thirdPlace: courts.isEven).withBracket(seeding);
              _walk(a, Random(seed++), '$name C$courts');
            }
          });
        }
      }
    }
  });

  group('W2: bagan dari WildcardPick (16G-iii, seri tiga) × ubah format/Juara 3', () {
    final cases = <String, (ActiveTournament, List<List<String>>)>{
      '16G-iii': (
        groups16G(qoriUmar: 3),
        [
          ['Kiki'],
          ['Umar'],
        ],
      ),
      'seri tiga': (
        groups16G(qoriUmar: 3, andiEko: 1),
        [
          ['Eko', 'Kiki'],
          ['Eko', 'Umar'],
          ['Kiki', 'Umar'],
        ],
      ),
    };
    for (final MapEntry(key: name, value: (groups, choices)) in cases.entries) {
      for (final chosen in choices) {
        test('$name pilih $chosen', () {
          final perGroup = GroupKnockoutRanking.qualifierPlan(groups).withPicks(const {})!;
          final seeding = GroupKnockoutRanking.seedingPlan(groups, perGroup).withWildcardPick(chosen)!;
          _walk(groups.withBracket(seeding), Random(chosen.join().hashCode), '$name $chosen');
        });
      }
    }
  });
}
