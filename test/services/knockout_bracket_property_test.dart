import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import 'group_knockout_fixture.dart';

/// Invariant I7–I12 bagan (logic.md §18.8, §21.6): 2/3/4 grup × C 1–4 × juara 3 × beberapa seed. Skor grup acak,
/// pilihan host acak, lalu langkah gugur acak (skor atau WO, termasuk ubah skor yang membalik pemenang); langkah yang
/// ditolak [KnockoutBracket.flipCheck] tidak diterapkan. 3 grup: `Seeding` acak (juara, slot, wildcard) sebagai input,
/// bukan dari `seedingPlan` (GP-3) — bagan tidak bergantung pada cara seeding dihitung. Plus AC-G26 36 kombinasi.

/// Buat bagan seperti controller: match baru + config (wildcards) sekaligus.
ActiveTournament _seeded(ActiveTournament a, Seeding seeding) {
  final built = KnockoutBracket.build(a, seeding);
  return ActiveTournament(
    tournament: a.tournament.copyWith(config: built.config, matches: [...a.matches, ...built.matches]),
  );
}

/// AC-G26: tidak ada QF segrup; slot 1 dan 2 tiap grup di paruh berbeda (QF1–QF2 vs QF3–QF4); J1 tidak bertemu juara
/// lain sebelum Final.
void _checkAcG26(List<(String, String)> qf, List<List<String>> groups, Seeding s, String at) {
  int groupOf(String id) => groups.indexWhere((g) => g.contains(id));
  for (final (i, (a, b)) in qf.indexed) {
    expect(groupOf(a), isNot(groupOf(b)), reason: '$at QF${i + 1} segrup');
  }
  int half(String id) => qf.indexWhere((m) => m.$1 == id || m.$2 == id) ~/ 2;
  for (final slots in s.groupSlots) {
    expect(half(slots[0]), isNot(half(slots[1])), reason: '$at ${slots.join('/')} paruh sama');
  }
  final champions = [for (final g in s.champions) s.groupSlots[g][0]];
  expect(half(champions[0]), 0, reason: at);
  expect(half(champions[1]), 1, reason: at);
  expect(half(champions[2]), 1, reason: at);
  // Paruh bawah: J2 dan J3 di QF berbeda (baru bisa bertemu di SF2).
  expect(qf.indexWhere((m) => m.$1 == champions[1]), isNot(qf.indexWhere((m) => m.$1 == champions[2])));
}

const _names = ['Andi', 'Citra', 'Eko', 'Gita', 'Indra', 'Kiki', 'Maya', 'Oki', 'Rudi', 'Tono', 'Qori', 'Vina'];

ActiveTournament _playGroups(ActiveTournament a, Random rng) {
  var t = a;
  for (final m in a.matches) {
    final loser = rng.nextInt(6);
    final r = rng.nextInt(10);
    t = r == 0
        ? t.withMatches([for (final x in t.matches) x.id == m.id ? x.asWalkover(loserPairId: x.pair2.id) : x])
        : t.withMatches([
            for (final x in t.matches)
              x.id == m.id
                  ? x.withScore([r.isEven ? SetScore(side1: 6, side2: loser) : SetScore(side1: loser, side2: 6)])
                  : x,
          ]);
  }
  return t;
}

void _checkStep(ActiveTournament a, String at) {
  final ko = a.matches.where((m) => m.phase is KnockoutPhase);
  for (final m in ko) {
    final tbd = m.pair1.isTbd || m.pair2.isTbd;
    // I7
    if (tbd) {
      expect(m.status, anyOf(MatchStatus.pending, MatchStatus.cancelled), reason: '$at I7 ${m.phase!.code}');
      expect(m.roundNumber > a.currentRound || a.tournament.isFinished, isTrue, reason: '$at I7 round ${m.id}');
    }
    // I9
    if (m.status == MatchStatus.done || m.status == MatchStatus.wo) {
      expect(m.winnerPairId, isNotNull, reason: '$at I9 ${m.phase!.code}');
    }
  }
  // I8
  final again = KnockoutBracket.resolve(a.config, a.matches);
  expect(
    [for (final m in again) '${m.pair1.id}|${m.pair2.id}'],
    [for (final m in a.matches) '${m.pair1.id}|${m.pair2.id}'],
  );
  expect(KnockoutBracket.isResolved(a.config, a.matches), isTrue, reason: '$at I8');
  // W2 (docs/security.md): validator GR19 dan build satu sumber, jadi tiap keadaan bagan tetap tersimpan dan terbaca.
  expect(TournamentCodec.canEncode(a), isTrue, reason: '$at canEncode');
  final raw = TournamentCodec.encode(a);
  expect(TournamentCodec.encode(TournamentCodec.decode(raw)!), raw, reason: '$at round trip');
}

void main() {
  group('AC-G26 3 grup: 36 kombinasi (urutan juara 3! × grup WC1/WC2 3 × 2)', () {
    const groups = [
      ['Andi', 'Citra', 'Eko', 'Gita'],
      ['Indra', 'Kiki', 'Maya', 'Oki'],
      ['Qori', 'Sari', 'Umar', 'Wawan'],
    ];
    const perms = [
      [0, 1, 2],
      [0, 2, 1],
      [1, 0, 2],
      [1, 2, 0],
      [2, 0, 1],
      [2, 1, 0],
    ];
    var combos = 0;
    for (final champions in perms) {
      for (var w1 = 0; w1 < 3; w1++) {
        for (var w2 = 0; w2 < 3; w2++) {
          if (w1 == w2) continue;
          combos++;
          test('AC-G26 juara $champions · WC1 ${GroupKnockout.letter(w1)}3 · WC2 ${GroupKnockout.letter(w2)}3', () {
            final seeding = Seeding(
              groupSlots: [for (final g in groups) g.sublist(0, 2)],
              champions: champions,
              wildcards: [groups[w1][2], groups[w2][2]],
            );
            final at = 'juara $champions WC $w1/$w2';
            final qf = KnockoutBracket.threeGroupQuarterfinals(seeding, groups)!;
            _checkAcG26(qf, groups, seeding, at);
            // build memakai fungsi yang sama (W2) dan menulis wildcards urutan WC1, WC2.
            final a = _seeded(gkTournament(groups: groups), seeding);
            expect([
              for (final m in a.matches)
                if (m.phase case KnockoutPhase(round: KnockoutRound.quarterfinal)) (m.pair1.id, m.pair2.id),
            ], qf);
            expect(a.config.groupKnockout!.wildcards, seeding.wildcards);
            expect(KnockoutBracket.seedCode(a, groups[w1][2]), 'WC1');
            expect(KnockoutBracket.seedCode(a, groups[w2][2]), 'WC2');
            _checkStep(a, at);
          });
        }
      }
    }
    test('jumlah kombinasi = 36', () => expect(combos, 36));
  });

  for (final groupCount in [2, 3, 4]) {
    for (var courts = 1; courts <= 4; courts++) {
      for (final thirdPlace in [true, false]) {
        for (var seed = 0; seed < 3; seed++) {
          test('G $groupCount · C $courts · juara 3 $thirdPlace · seed $seed', () {
            final rng = Random(groupCount * 1000 + courts * 100 + (thirdPlace ? 10 : 0) + seed);
            final names = [..._names]..shuffle(rng);
            final total = groupCount == 4 ? 12 : 6 + rng.nextInt(5);
            final groups = switch (groupCount) {
              4 => [for (var g = 0; g < 4; g++) names.sublist(g * 3, g * 3 + 3)],
              3 => [for (var g = 0; g < 3; g++) names.sublist(g * 4, g * 4 + 4)],
              _ => [names.sublist(0, (total + 1) ~/ 2), names.sublist((total + 1) ~/ 2, total)],
            };
            var a = _playGroups(gkTournament(groups: groups, courts: courts, thirdPlace: thirdPlace), rng);
            expect(a.canCreateBracket, isTrue);

            final Seeding seeding;
            if (groupCount == 3) {
              final order = [
                for (final g in groups) [...g]..shuffle(rng),
              ];
              final wcGroups = [0, 1, 2]..shuffle(rng);
              seeding = Seeding(
                groupSlots: [for (final o in order) o.sublist(0, 2)],
                champions: [0, 1, 2]..shuffle(rng),
                wildcards: [order[wcGroups[0]][2], order[wcGroups[1]][2]],
              );
              _checkAcG26(KnockoutBracket.threeGroupQuarterfinals(seeding, groups)!, groups, seeding, 'acak');
            } else {
              final plan = GroupKnockoutRanking.qualifierPlan(a);
              final picks = <int, List<String>>{
                for (final p in plan.picks) p.group: ([...p.candidates]..shuffle(rng)).sublist(0, p.taps),
              };
              seeding = Seeding(groupSlots: plan.withPicks(picks)!);
            }
            final qualifiers = [...seeding.groupSlots, seeding.wildcards];
            final groupBefore = [
              for (final m in a.matches)
                '${m.id} ${m.pair1.id} ${m.pair2.id} ${m.status} ${m.sets.map((s) => s.side1)}',
            ];
            final lastGroupRound = a.roundCount;
            a = _seeded(a, seeding);
            expect(a.config.groupKnockout!.wildcards, seeding.wildcards, reason: 'W3');
            _checkStep(a, 'build');

            final ko = [
              for (final m in a.matches)
                if (m.phase is KnockoutPhase) m,
            ];
            // I11 round gugur > round grup; babak berikutnya di round sesudahnya; Final di round terakhir.
            expect(ko.every((m) => m.roundNumber > lastGroupRound), isTrue);
            int lastOf(KnockoutRound r) =>
                ko.where((m) => (m.phase! as KnockoutPhase).round == r).map((m) => m.roundNumber).reduce(max);
            int firstOf(KnockoutRound r) =>
                ko.where((m) => (m.phase! as KnockoutPhase).round == r).map((m) => m.roundNumber).reduce(min);
            if (groupCount >= 3) {
              expect(firstOf(KnockoutRound.semifinal), greaterThan(lastOf(KnockoutRound.quarterfinal)));
            }
            expect(firstOf(KnockoutRound.finalRound), greaterThan(lastOf(KnockoutRound.semifinal)));
            expect(firstOf(KnockoutRound.finalRound), a.roundCount);
            if (thirdPlace) {
              expect(firstOf(KnockoutRound.thirdPlace), greaterThan(lastOf(KnockoutRound.semifinal)));
            }
            // I12 tiap pasangan lolos tepat sekali di babak pertama; yang tidak lolos tidak pernah di gugur.
            final firstRound = groupCount >= 3 ? KnockoutRound.quarterfinal : KnockoutRound.semifinal;
            final firstSides = [
              for (final m in ko)
                if ((m.phase! as KnockoutPhase).round == firstRound) ...[m.pair1.id, m.pair2.id],
            ];
            expect(firstSides..sort(), [for (final q in qualifiers) ...q]..sort());

            // Langkah gugur acak.
            for (var step = 0; step < 40; step++) {
              final open = [
                for (final m in a.matches)
                  if (m.phase is KnockoutPhase &&
                      !m.pair1.isTbd &&
                      !m.pair2.isTbd &&
                      (m.status != MatchStatus.pending || m.roundNumber <= a.currentRound))
                    m,
              ];
              if (open.isEmpty) break;
              final m = open[rng.nextInt(open.length)];
              final winnerFirst = rng.nextBool();
              final winner = winnerFirst ? m.pair1.id : m.pair2.id;
              final check = KnockoutBracket.flipCheck(a, m.id, winner);
              if (check is FlipBlocked) {
                expect(check.rounds, isNotEmpty);
                continue;
              }
              final low = rng.nextInt(a.config.formatFor(m).target);
              final high = a.config.formatFor(m).target;
              final changed = rng.nextInt(6) == 0
                  ? m.asWalkover(loserPairId: winnerFirst ? m.pair2.id : m.pair1.id)
                  : m.withScore([winnerFirst ? SetScore(side1: high, side2: low) : SetScore(side1: low, side2: high)]);
              a = a.withMatches(
                KnockoutBracket.resolve(a.config, [for (final x in a.matches) x.id == m.id ? changed : x]),
              );
              _checkStep(a, 'step $step');
              if (check is FlipAllowed) {
                for (final p in check.preview) {
                  final now = a.matches.firstWhere((x) => x.phase == p.phase);
                  expect('${now.pair1.id}|${now.pair2.id}', '${p.pair1.id}|${p.pair2.id}', reason: 'pratinjau = hasil');
                }
              }
            }

            // I10 match grup identik dengan sebelum bagan.
            final groupAfter = [
              for (final m in a.matches)
                if (m.phase is GroupPhase)
                  '${m.id} ${m.pair1.id} ${m.pair2.id} ${m.status} ${m.sets.map((s) => s.side1)}',
            ];
            expect(groupAfter, groupBefore);
            // I12 sisi gugur hanya pasangan lolos.
            final lolos = {for (final q in qualifiers) ...q};
            for (final m in a.matches.where((m) => m.phase is KnockoutPhase)) {
              for (final side in [m.pair1, m.pair2]) {
                expect(side.isTbd || lolos.contains(side.id), isTrue);
              }
            }
            final done = a.matches.every((m) => m.status != MatchStatus.pending);
            expect(a.isFinal(DateTime(2026, 11, 17)), done);
            // Peringkat akhir: tiap pasangan tepat sekali, bernomor; diakhiri → I7 tetap.
            final entries = GroupKnockoutRanking.finalEntries(a);
            expect(entries, hasLength(a.config.fixedPairs!.length));
            expect(entries.every((e) => e.position != null && e.stage != null), isTrue);
            _checkStep(a.finish(), 'finish');
          });
        }
      }
    }
  }
}
