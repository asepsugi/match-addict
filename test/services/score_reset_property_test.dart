import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';
import 'package:match_addict/services/scoring/score_reset.dart';

import '../hifi/screens/schedule_fixture.dart' show fixedTournament;
import 'group_knockout_fixture.dart';
import 'score_reset_fixture.dart';
import 'sparing_score_fixture.dart';

/// Invariant Kosongkan skor / Hapus WO (logic.md §19.3 R1–R7, §18.8 I7–I9): turnamen berseed, isi/WO acak lewat aturan
/// yang sama dengan controller, lalu Kosongkan/Hapus WO acak. Tiap langkah: `check` ⇔ `apply`, dan bila diterapkan
/// R1–R5 + R7.

const _names = ['Andi', 'Citra', 'Eko', 'Gita', 'Indra', 'Kiki', 'Maya', 'Oki', 'Rudi', 'Tono', 'Qori', 'Vina'];

ActiveTournament _replace(ActiveTournament a, List<MatchGame> matches) =>
    a.copyWith(tournament: a.tournament.copyWith(matches: matches));

/// Match yang boleh diisi seperti Input Skor: Mixed/Mexicano `isScorable`, Fixed `canOpenScore` dan bukan grup terkunci.
bool _fillable(ActiveTournament a, MatchGame m) =>
    a.config.mode.isEndless ? m.isScorable : a.canOpenScore(m) && !a.isGroupKnockoutLocked(m);

/// Isi skor atau WO acak (jalur controller: gugur dicek `flipCheck`, lalu `resolve`). null = ditolak.
ActiveTournament? _fill(ActiveTournament a, MatchGame m, Random rng) {
  final format = a.config.formatFor(m);
  final firstWins = rng.nextBool();
  final MatchGame changed;
  if (rng.nextInt(4) == 0) {
    // WO atas match yang sudah berskor menyimpan skor lama (Hapus WO → oldScore).
    changed = m.asWalkover(loserPairId: firstWins ? m.pair2.id : m.pair1.id, reason: WoReason.values[rng.nextInt(4)]);
  } else {
    final high = format.method == ScoringMethod.raceTo ? format.target : format.minWinningScore;
    final low = rng.nextInt(format.method == ScoringMethod.raceTo ? format.target : format.target - high + 1);
    changed = m.withScore([firstWins ? SetScore(side1: high, side2: low) : SetScore(side1: low, side2: high)]);
  }
  if (m.phase is KnockoutPhase && KnockoutBracket.flipCheck(a, m.id, changed.winnerPairId!) is FlipBlocked) {
    return null;
  }
  return _replace(a, KnockoutBracket.resolve(a.config, [for (final x in a.matches) x.id == m.id ? changed : x]));
}

ActiveTournament _finish(ActiveTournament a) => a.copyWith(
  tournament: a.tournament.copyWith(
    isFinished: true,
    matches: [
      for (final m in a.matches) m.status == MatchStatus.pending ? m.copyWith(status: MatchStatus.cancelled) : m,
    ],
  ),
);

/// I7–I9 (sama dengan knockout_bracket_property_test, tanpa syarat round untuk Kosongkan yang mundur).
void _checkKnockout(ActiveTournament a, String at) {
  for (final m in a.matches.where((m) => m.phase is KnockoutPhase)) {
    if (m.pair1.isTbd || m.pair2.isTbd) {
      expect(m.status, anyOf(MatchStatus.pending, MatchStatus.cancelled), reason: '$at I7 ${m.phase!.code}');
      expect(m.roundNumber > a.currentRound || a.tournament.isFinished, isTrue, reason: '$at I7 round ${m.id}');
    }
    if (m.status == MatchStatus.done || m.status == MatchStatus.wo) {
      expect(m.winnerPairId, isNotNull, reason: '$at I9 ${m.phase!.code}');
    }
  }
  expect(KnockoutBracket.isResolved(a.config, a.matches), isTrue, reason: '$at I8');
}

void _checkReset(ActiveTournament a, ActiveTournament b, MatchGame m, ResetAction action, ResetAllowed c, String at) {
  final r = b.matchById(m.id)!;
  // R2
  expect(
    (r.id, r.roundNumber, r.matchNumberInRound, r.courtId, r.pair1.id, r.pair2.id, r.phase),
    (m.id, m.roundNumber, m.matchNumberInRound, m.courtId, m.pair1.id, m.pair2.id, m.phase),
    reason: '$at R2',
  );
  expect(matchSig(r), matchSig(c.result), reason: '$at result');
  // R3
  expect((r.woLoserPairId, r.woReason), (null, null), reason: '$at R3 WO');
  final finished = a.tournament.isFinished;
  final blank = finished ? MatchStatus.cancelled : MatchStatus.pending;
  if (action == ResetAction.clearScore) {
    expect((r.sets.length, r.status), (0, blank), reason: '$at R3 clear');
  } else {
    String score(MatchGame x) => x.sets.map((s) => '${s.side1}-${s.side2}').join(',');
    expect(score(r), score(m), reason: '$at R3 skor lama apa adanya');
    expect(r.status, m.sets.isEmpty ? blank : MatchStatus.done, reason: '$at R3 status');
  }
  // R1: hanya match itu; sisi lanjutan gugur ikut resolve, selain sisi semuanya identik.
  final expected = KnockoutBracket.resolve(a.config, [for (final x in a.matches) x.id == m.id ? c.result : x]);
  expect([for (final x in b.matches) matchSig(x)], [for (final x in expected) matchSig(x)], reason: '$at R1');
  for (final (i, x) in a.matches.indexed) {
    if (x.id == m.id) continue;
    final y = b.matches[i];
    final sameSides = x.pair1.id == y.pair1.id && x.pair2.id == y.pair2.id;
    expect(sameSides || x.phase is KnockoutPhase, isTrue, reason: '$at R1 sisi ${x.id}');
    expect(
      (y.id, y.sets.length, y.status, y.woLoserPairId, y.woReason),
      (x.id, x.sets.length, x.status, x.woLoserPairId, x.woReason),
      reason: '$at R1 ${x.id}',
    );
  }
  // R4
  if (finished) expect(b.matches.any((x) => x.status == MatchStatus.pending), isFalse, reason: '$at R4');
  expect(b.tournament.isFinished, finished);
  expect(identical(b.config, a.config), isTrue, reason: '$at R4 config');
  expect(identical(b.byePairIdByRound, a.byePairIdByRound), isTrue);
  expect(identical(b.restingPlayerIdsByRound, a.restingPlayerIdsByRound), isTrue);
  expect(identical(b.withdrawnPlayerIds, a.withdrawnPlayerIds), isTrue);
  expect(b.extraPutaran, a.extraPutaran);
  expect(identical(b.restingPairIdsByRound, a.restingPairIdsByRound), isTrue);
  // R5
  _checkKnockout(b, at);
  // R7
  expectRoundtrip(b, reason: at);
}

/// Jalan acak [steps] langkah atas [start].
void _walk(ActiveTournament start, Random rng, {int steps = 80, bool groupKnockout = false}) {
  var a = start;
  var applied = 0;
  for (var step = 0; step < steps; step++) {
    final at = 'langkah $step';
    // Diakhiri di paruh kedua saja, supaya sebelum diakhiri ada cukup langkah.
    if (!a.tournament.isFinished && step > steps ~/ 2 && rng.nextInt(40) == 0) {
      a = _finish(a);
      continue;
    }
    if (groupKnockout && a.canCreateBracket && rng.nextInt(3) == 0) {
      final plan = GroupKnockoutRanking.qualifierPlan(a);
      final picks = <int, List<String>>{
        for (final p in plan.picks) p.group: ([...p.candidates]..shuffle(rng)).sublist(0, p.taps),
      };
      a = a.bracket(plan.withPicks(picks)!);
      continue;
    }
    MatchGame pick(Iterable<MatchGame> from) {
      final list = from.toList();
      return list.isEmpty ? a.matches[rng.nextInt(a.matches.length)] : list[rng.nextInt(list.length)];
    }

    if (rng.nextInt(5) < 3) {
      final fillable = a.matches.where((m) => _fillable(a, m));
      if (!a.tournament.isFinished && fillable.isNotEmpty) a = _fill(a, pick(fillable), rng) ?? a;
      continue;
    }
    // Sebagian besar match berhasil (yang mungkin tersedia), sisanya match sembarang supaya jalur tolak ikut teruji.
    final m = rng.nextInt(4) == 0
        ? a.matches[rng.nextInt(a.matches.length)]
        : pick(a.matches.where((x) => x.status == MatchStatus.done || x.status == MatchStatus.wo));
    final action = m.status == MatchStatus.wo && rng.nextInt(4) > 0
        ? ResetAction.removeWalkover
        : m.status == MatchStatus.done && rng.nextInt(4) > 0
        ? ResetAction.clearScore
        : ResetAction.values[rng.nextInt(2)];
    final c = ScoreReset.check(a, m.id, action);
    final b = ScoreReset.apply(a, m.id, action);
    // R6
    expect(c is ResetAllowed, b != null, reason: '$at R6 ${m.id} ${action.name}');
    if (c is ResetBlocked) expect(c.flip.rounds, isNotEmpty);
    if (c is ResetAllowed && b != null) {
      _checkReset(a, b, m, action, c, '$at ${m.id} ${action.name}');
      // Pratinjau = susunan sesudahnya.
      for (final p in c.preview) {
        final now = b.matches.firstWhere((x) => x.phase == p.phase);
        expect('${now.pair1.id}|${now.pair2.id}', '${p.pair1.id}|${p.pair2.id}', reason: '$at pratinjau');
      }
      a = b;
      applied++;
    }
  }
  expect(applied, greaterThan(0), reason: 'tidak ada Kosongkan/Hapus WO yang diterapkan');
}

void main() {
  for (var seed = 0; seed < 6; seed++) {
    test('Fixed · seed $seed', () {
      final rng = Random(seed);
      _walk(fixedTournament({}), rng);
    });

    test('Sparing Fixed · seed $seed', () {
      final rng = Random(100 + seed);
      _walk(fixedSparing(const []), rng);
    });

    test('Mixed 4 round · seed $seed', () {
      final rng = Random(200 + seed);
      _walk(mixed17b(matches: [...mixed17bRounds(), ...mixed17bR4()]), rng);
    });

    test('Mexicano · seed $seed', () {
      final rng = Random(300 + seed);
      _walk(mexicano14a(matches: [...mexicano14aRounds(), ...mexicano14aR3()]), rng);
    });
  }

  for (final groupCount in [2, 4]) {
    for (var courts = 1; courts <= 4; courts++) {
      for (final thirdPlace in [true, false]) {
        for (var seed = 0; seed < 2; seed++) {
          test('Grup + Gugur G $groupCount · C $courts · juara 3 $thirdPlace · seed $seed', () {
            final rng = Random(groupCount * 1000 + courts * 100 + (thirdPlace ? 10 : 0) + seed);
            final names = [..._names]..shuffle(rng);
            final total = groupCount == 4 ? 12 : 6 + rng.nextInt(5);
            final groups = groupCount == 4
                ? [for (var g = 0; g < 4; g++) names.sublist(g * 3, g * 3 + 3)]
                : [names.sublist(0, (total + 1) ~/ 2), names.sublist((total + 1) ~/ 2, total)];
            _walk(
              gkTournament(groups: groups, courts: courts, thirdPlace: thirdPlace),
              rng,
              steps: 250,
              groupKnockout: true,
            );
          });
        }
      }
    }
  }
}
