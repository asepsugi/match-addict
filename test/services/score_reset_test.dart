import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/score_input/knockout_text.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/club_score.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';
import 'package:match_addict/services/schedule/player_swap.dart';
import 'package:match_addict/services/scoring/score_reset.dart';
import 'package:match_addict/services/share/result_text_builder.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi/screens/schedule_fixture.dart' show LoadedTournament, fixedTournament;
import 'group_knockout_fixture.dart';
import 'score_reset_fixture.dart';
import 'sparing_score_fixture.dart';

/// Kosongkan skor / Hapus WO (KS-7a, design/spec/logic.md §19.2, 19.6, 19.9). Nama test = ID PRD §17.

const _clear = ResetAction.clearScore;
const _removeWo = ResetAction.removeWalkover;
final _sparingNow = DateTime(2026, 11, 8, 20);

ResetAllowed _allowed(ActiveTournament a, String id, ResetAction action) {
  final c = ScoreReset.check(a, id, action);
  expect(c, isA<ResetAllowed>(), reason: '$id ${action.name}');
  return c as ResetAllowed;
}

ActiveTournament _apply(ActiveTournament a, String id, ResetAction action) {
  final next = ScoreReset.apply(a, id, action);
  expect(next, isNotNull, reason: '$id ${action.name}');
  return next!;
}

/// Mutasi lewat controller (cancelLastRound, resume, createBracket, submitScore, finishNow) atas [a].
ActiveTournament _via(ActiveTournament a, void Function(TournamentController c) act, {DateTime? now}) {
  final container = ProviderContainer(
    overrides: [
      tournamentStoreProvider.overrideWithValue(TournamentStore.memory()),
      clockProvider.overrideWithValue(() => now ?? resetNow),
      tournamentProvider.overrideWith(() => LoadedTournament(a)),
    ],
  );
  addTearDown(container.dispose);
  act(container.read(tournamentProvider.notifier));
  return container.read(tournamentProvider)!;
}

List<PlayerStanding> _rank(ActiveTournament a, RankingMethod method) =>
    RankingCalculator.rank(players: a.config.players, matches: a.matches, method: method, format: a.config.format);

PlayerStanding _standing(ActiveTournament a, String id) =>
    _rank(a, RankingMethod.totalGames).firstWhere((s) => s.player.id == id);

/// "1 Eko + Fajar 18 +11" per baris klasemen klub (Total Point).
List<String> _clubTable(ActiveTournament a, Club club) {
  const method = RankingMethod.totalGames;
  final group = clubStandings(
    active: a,
    standings: _rank(a, method),
    method: method,
  ).firstWhere((g) => g.club.id == club.id);
  return [for (final e in group.entries) '${e.position} ${e.label} ${e.standing.totalPoint} ${e.standing.diffLabel}'];
}

String _caption(ActiveTournament a) {
  const method = RankingMethod.totalGames;
  final standings = _rank(a, method);
  return ResultTextBuilder.build(
    active: a,
    standings: standingEntries(standings: standings, method: method),
    format: ShareFormat.ringkas,
    now: _sparingNow,
    clubStandings: clubStandings(active: a, standings: standings, method: method),
  );
}

/// "#1 Citra Final" per baris peringkat akhir.
List<String> _final(ActiveTournament a) => [
  for (final e in GroupKnockoutRanking.finalEntries(a)) '#${e.position ?? '-'} ${e.players.first.name} ${e.stage}',
];

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  group('17A Sparing Fixed 13C', () {
    test('AC-K4 17A-i clearScore m12: skor klub, klasemen, caption, Sementara', () {
      final a = fixedSparing(c13);
      expect(_allowed(a, 'm12', _clear).outcome, ResetOutcome.pending);
      final b = _apply(a, 'm12', _clear);
      final club = ClubResult.of(b)!;
      expect(club.scoreLabel, '7 – 4');
      expect((club.detailLabel(club.first), club.detailLabel(club.second)), ('51 game · +14', '43 game · −14'));
      expect(b.playedMatchCount, 11);
      // Kepala poster "Klasemen sementara" diturunkan dari isFinal (share_content.dart).
      expect(b.isFinal(_sparingNow), isFalse);
      expect(b.canAddRounds, isFalse);
      // AC-K10: m12 diisi lagi (skor lama) → Tambah round kembali.
      final refilled = b.copyWith(
        tournament: b.tournament.copyWith(matches: [for (final m in b.matches) m.id == 'm12' ? a.matchById('m12')! : m]),
      );
      expect(refilled.canAddRounds, isTrue);
      expect(_clubTable(b, garuda), [
        '1 Eko + Fajar 18 +11',
        '2 Andi + Budi 14 +1',
        '3 Citra + Dewi 10 +3',
        '4 Gita + Hadi 9 −1',
      ]);
      expect(_clubTable(b, matcha), ['1 Maya + Nanda 17 +3', '2 Kiki + Lina 16 −3', '3 Indra + Joko 10 −14']);
      expect(_caption(b), contains('🏆 PB Garuda 7–4 Matcha Club · Padel'));
    });

    test('AC-K5 17A-ii removeWalkover m6: round lama Belum, R4–R6 terkunci oleh R3, Maya', () {
      final a = fixedSparing(c13);
      expect(_allowed(a, 'm6', _removeWo).outcome, ResetOutcome.pending);
      final b = _apply(a, 'm6', _removeWo);
      final club = ClubResult.of(b)!;
      expect(club.scoreLabel, '7 – 4');
      expect((club.detailLabel(club.first), club.detailLabel(club.second)), ('56 game · +13', '43 game · −13'));
      expect(b.currentRound, 3);
      expect(b.canOpenScore(b.matchById('m7')!), isFalse);
      expect([b.lockedBy(4), b.lockedBy(5), b.lockedBy(6)], [3, 3, 3]);
      final maya = PlayerProfile.of(playerId: 'p-maya', matches: b.matches);
      final totals = coverageTotals(b.config, 'p-maya', partnerCount: maya.partnerIds.length);
      expect(maya.playedMatches, hasLength(3));
      expect(_standing(b, 'p-maya').totalPoint, 17);
      expect('${maya.opponentIds.length} / ${totals.opponents}', '6 / 8');
      expectRoundtrip(b, reason: '17A-ii');
    });

    test('AC-P5 13C (B-21): Maya Beda lawan 8 / 8, Main 4, Total Point 23', () {
      final a = fixedSparing(c13);
      final maya = PlayerProfile.of(playerId: 'p-maya', matches: a.matches);
      final totals = coverageTotals(a.config, 'p-maya', partnerCount: maya.partnerIds.length);
      expect('${maya.opponentIds.length} / ${totals.opponents}', '8 / 8');
      expect(maya.playedMatches, hasLength(4));
      expect(_standing(a, 'p-maya').totalPoint, 23);
    });

    test('AC-K11 17A-iii diakhiri lalu clearScore m12 → Tidak dimainkan, tetap Final, tidak bisa diisi lagi', () {
      final a = _via(fixedSparing(c13), (c) => c.finishNow());
      expect(_allowed(a, 'm12', _clear).outcome, ResetOutcome.cancelled);
      final b = _apply(a, 'm12', _clear);
      final m12 = b.matchById('m12')!;
      expect(m12.status, MatchStatus.cancelled);
      expect(b.isFinal(_sparingNow), isTrue);
      expect(ClubResult.of(b)!.scoreLabel, '7 – 4');
      expect(m12.isScorable, isFalse);
      expect(ScoreReset.check(b, 'm12', _clear), isA<ResetUnavailable>());
      expectRoundtrip(b, reason: '17A-iii');
    });

    test('AC-K3 07v Hapus WO dengan skor lama → Selesai 6–4, WO dan alasan hilang', () {
      final base = fixedTournament({'r1c1': (6, 3), 'r1c2': (4, 6), 'r2c1': (6, 4), 'r2c2': (6, 4)});
      final m = base.matchById('r2c2')!;
      final a = base.copyWith(
        tournament: base.tournament.copyWith(
          matches: [
            for (final x in base.matches)
              x.id == m.id ? x.asWalkover(loserPairId: m.pair2.id, reason: WoReason.injury) : x,
          ],
        ),
      );
      final check = _allowed(a, 'r2c2', _removeWo);
      expect(check.outcome, ResetOutcome.oldScore);
      expect(check.preview, isEmpty);
      final r = _apply(a, 'r2c2', _removeWo).matchById('r2c2')!;
      expect((r.status, r.sets.single.side1, r.sets.single.side2), (MatchStatus.done, 6, 4));
      expect((r.woLoserPairId, r.woReason), (null, null));
      expect(ScoreReset.check(a, 'r2c2', _clear), isA<ResetUnavailable>(), reason: 'K3: WO tanpa Kosongkan');
    });
  });

  group('17B Mixed', () {
    test('AC-K6 17B clearScore R3 Court 2: tunggu 1, Total Point dan selisih, Tukar boleh', () {
      final a = mixed17b();
      final id = matchAt(a, 3, 2).id;
      expect(_allowed(a, id, _clear).outcome, ResetOutcome.pending);
      final b = _apply(a, id, _clear);
      expect(b.matchesOfRound(3).where((m) => m.status == MatchStatus.pending), hasLength(1));
      expect(b.canGenerateNextRound(resetNow), isFalse);
      expect(b.canCancelLastRound, isFalse);
      for (final (p, tp, diff) in [('Citra', -11, -1), ('Gita', -11, -1), ('Dewi', -10, 1), ('Hadi', -10, 1)]) {
        expect(_standing(b, p).totalPoint - _standing(a, p).totalPoint, tp, reason: p);
        expect(_standing(b, p).gameDiff - _standing(a, p).gameDiff, diff, reason: p);
      }
      expect(PlayerSwap.isSwappable(b, b.matchById(id)!), isTrue);

      final mex = mixed17b(mode: PartnerMode.mexicano);
      final mexAfter = _apply(mex, id, _clear);
      expect(PlayerSwap.isSwappable(mexAfter, mexAfter.matchById(id)!), isFalse, reason: 'Mexicano tanpa tukar');
    });

    test('17B R4 dibuat: R3 tidak tersedia; Batalkan R4 → tersedia lagi; R4 berskor → tetap tidak', () {
      final a = mixed17b(matches: [...mixed17bRounds(), ...mixed17bR4()]);
      final r3c2 = matchAt(a, 3, 2);
      expect(ScoreReset.check(a, r3c2.id, _clear), isA<ResetUnavailable>());
      final wo = a.copyWith(
        tournament: a.tournament.copyWith(
          matches: [for (final x in a.matches) x.id == r3c2.id ? x.asWalkover(loserPairId: x.pair2.id) : x],
        ),
      );
      expect(ScoreReset.check(wo, r3c2.id, _removeWo), isA<ResetUnavailable>());
      expect(ScoreReset.apply(a, r3c2.id, _clear), isNull);

      final cancelled = _via(a, (c) => c.cancelLastRound());
      expect(cancelled.roundCount, 3);
      expect(ScoreReset.check(cancelled, r3c2.id, _clear), isA<ResetAllowed>());

      final r4scored = _via(a, (c) => c.submitScore(matchAt(a, 4, 1).id, const [SetScore(side1: 13, side2: 8)]));
      expect(ScoreReset.check(r4scored, r3c2.id, _clear), isA<ResetUnavailable>());
    });

    test('AC-K7 semua match R3 dikosongkan → Batalkan R3 tersedia; R1 satu-satunya round → tidak', () {
      var a = mixed17b();
      for (final m in a.matchesOfRound(3)) {
        a = _apply(a, m.id, _clear);
      }
      expect(a.canCancelLastRound, isTrue);

      var only = mixed17b(matches: mixed17bRounds().where((m) => m.roundNumber == 1).toList());
      for (final m in only.matchesOfRound(1)) {
        only = _apply(only, m.id, _clear);
      }
      expect(only.canCancelLastRound, isFalse);
    });

    test('AC-K11 Mixed diakhiri lalu clearScore R3 Court 2 → Tidak dimainkan; Lanjutkan → Belum', () {
      final a = _via(mixed17b(), (c) => c.finishNow());
      final id = matchAt(a, 3, 2).id;
      expect(_allowed(a, id, _clear).outcome, ResetOutcome.cancelled);
      final b = _apply(a, id, _clear);
      expect(b.matchById(id)!.status, MatchStatus.cancelled);
      expect(ScoreReset.check(b, matchAt(b, 2, 1).id, _clear), isA<ResetUnavailable>(), reason: 'round lama');
      final resumed = _via(b, (c) => c.resume(const {}));
      expect(resumed.matchById(id)!.status, MatchStatus.pending);
    });

    test('Sparing Mixed (U-2): round lama tidak; round terakhir boleh dan skor klub ikut', () {
      final a = sparingMixed();
      expect(ClubResult.of(a)!.scoreLabel, '3 – 1');
      expect(ScoreReset.check(a, matchAt(a, 1, 1).id, _clear), isA<ResetUnavailable>());
      final b = _apply(a, matchAt(a, 2, 2).id, _clear);
      expect(ClubResult.of(b)!.scoreLabel, '3 – 0');
      expectRoundtrip(b, reason: 'Sparing Mixed');
    });
  });

  group('17C Mexicano 14A', () {
    test('R2 Court 2 boleh; setelah R3 dibuat tidak; Batalkan R3 → boleh lagi, round tidak dibuat ulang', () {
      final a = mexicano14a();
      final r2c2 = matchAt(a, 2, 2);
      expect((r2c2.sets.single.side1, r2c2.sets.single.side2), (8, 13));
      expect(ScoreReset.check(a, r2c2.id, _clear), isA<ResetAllowed>());

      final withR3 = mexicano14a(matches: [...mexicano14aRounds(), ...mexicano14aR3()]);
      expect(ScoreReset.check(withR3, r2c2.id, _clear), isA<ResetUnavailable>());
      final cancelled = _via(withR3, (c) => c.cancelLastRound());
      expect(ScoreReset.check(cancelled, r2c2.id, _clear), isA<ResetAllowed>());

      final b = _apply(a, r2c2.id, _clear);
      expect([for (final m in b.matches) m.id], [for (final m in a.matches) m.id], reason: 'tanpa generator');
      expect(b.roundCount, 2);
    });
  });

  group('17D Grup + Gugur fase grup (16A / 20b)', () {
    test('AC-K8 clearScore R1 Court 1 → tunggu 8, R1 berjalan, R3 Court 1 tetap dihitung', () {
      final a = gk20b();
      expect(a.pendingGroupMatches, 7);
      expect(a.waitsForBracket, isTrue);
      final r1c1 = matchAt(a, 1, 1);
      expect((r1c1.pair1.id, r1c1.pair2.id), ('Andi', 'Gita'));
      final b = _apply(a, r1c1.id, _clear);
      expect(b.pendingGroupMatches, 8);
      expect(b.currentRound, 1);
      expect(b.lockedBy(2), 1);
      final r3c1 = matchAt(b, 3, 1);
      expect((r3c1.status, r3c1.sets.single.side1, r3c1.sets.single.side2), (MatchStatus.done, 6, 3));
      final andi = GroupKnockoutRanking.groupTables(b)[0].entries.firstWhere((e) => e.players.first.id == 'Andi');
      expect((andi.standing.wins, andi.standing.losses), (1, 0), reason: 'R3 Court 1 Andi 6–3 Eko tetap dihitung');
    });

    test('AC-K8 12 terisi → Buat bagan; clearScore R6 Court 2 → tunggu 1; setelah bagan grup terkunci', () {
      final full = groups16E();
      expect((full.canCreateBracket, full.waitsForBracket, full.pendingGroupMatches), (true, false, 0));
      final b = _apply(full, matchAt(full, 6, 2).id, _clear);
      expect((b.pendingGroupMatches, b.waitsForBracket, b.canCreateBracket), (1, true, false));

      final built = _via(full, (c) => c.createBracket());
      expect(built.hasBracket, isTrue);
      expect(built.waitsForBracket, isFalse);
      for (final m in built.matches.where((m) => m.phase is GroupPhase)) {
        expect(ScoreReset.check(built, m.id, _clear), isA<ResetUnavailable>(), reason: m.id);
        expect(ScoreReset.check(built, m.id, _removeWo), isA<ResetUnavailable>(), reason: m.id);
      }
    });

    test('diakhiri di fase grup → match grup boleh, hasil Tidak dimainkan, tanpa tunggu', () {
      final a = gk20b().finish();
      expect(a.waitsForBracket, isFalse);
      final id = matchAt(a, 1, 1).id;
      expect(_allowed(a, id, _clear).outcome, ResetOutcome.cancelled);
      final b = _apply(a, id, _clear);
      expect(b.matchById(id)!.status, MatchStatus.cancelled);
      expect(b.waitsForBracket, isFalse);
      expect(b.lockedBy(4), isNull, reason: 'diakhiri: tanpa catatan kunci');
    });
  });

  group('17E gugur 16E', () {
    ActiveTournament sf() => groups16E().bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6);

    test('AC-K9 07w R8 Belum: clearScore SF1 → pratinjau tbd, peringkat', () {
      final a = sf();
      final check = _allowed(a, a.byCode('SF1').id, _clear);
      expect(check.outcome, ResetOutcome.pending);
      expect(
        knockoutFlipMessage(a, check.preview),
        'Final: Pemenang SF1 vs Citra · Dewi\nJuara 3: Kalah SF1 vs Indra · Joko',
      );
      final b = _apply(a, a.byCode('SF1').id, _clear);
      expect((b.sides('F'), b.sides('J3')), ('?–Citra', '?–Indra'));
      expect(b.currentRound, 7);
      expect(_final(b), [
        '#1 Citra Final',
        '#2 Andi Semifinal',
        '#2 Maya Semifinal',
        '#3 Indra Perebutan juara 3',
        '#4 Eko Grup A · 3',
        '#4 Kiki Grup B · 3',
        '#5 Gita Grup A · 4',
        '#5 Oki Grup B · 4',
      ]);
      expectRoundtrip(b, reason: '17E SF1 dikosongkan');
    });

    test('AC-K9 07x Final + Juara 3 berskor → ResetBlocked; hanya Final → "Final sudah ada skor"', () {
      final both = sf().ko('F', 7, 9).ko('J3', 4, 2);
      final sf1 = both.byCode('SF1');
      final blocked = ScoreReset.check(both, sf1.id, _clear) as ResetBlocked;
      expect(blocked.flip.rounds, [KnockoutRound.finalRound, KnockoutRound.thirdPlace]);
      expect(
        knockoutBlockedMessage(blocked.flip, sf1.phase! as KnockoutPhase, 'Andi & Budi'),
        'Final dan Juara 3 sudah ada skor · pemenang SF1 tetap Andi & Budi',
      );
      expect(ScoreReset.apply(both, sf1.id, _clear), isNull);

      final onlyF = sf().ko('F', 7, 9);
      final b2 = ScoreReset.check(onlyF, sf1.id, _clear) as ResetBlocked;
      expect(
        knockoutBlockedMessage(b2.flip, sf1.phase! as KnockoutPhase, 'Andi & Budi'),
        'Final sudah ada skor · pemenang SF1 tetap Andi & Budi',
      );
    });

    test('urutan 17E: clearScore F, lalu J3, lalu SF1 4–6 → susunan Maya–Citra / Andi–Indra', () {
      var a = sf().ko('F', 7, 9).ko('J3', 4, 2);
      final checkF = _allowed(a, a.byCode('F').id, _clear);
      expect(checkF.preview, isEmpty);
      a = _apply(a, a.byCode('F').id, _clear);
      expect(a.isFinal(DateTime(2026, 11, 17, 20)), isFalse);
      expect(_final(a), [
        '#1 Andi Final',
        '#1 Citra Final',
        '#2 Maya Juara 3',
        '#3 Indra Semifinal',
        '#4 Eko Grup A · 3',
        '#4 Kiki Grup B · 3',
        '#5 Gita Grup A · 4',
        '#5 Oki Grup B · 4',
      ]);
      a = _apply(a, a.byCode('J3').id, _clear);
      expect(_final(a), [
        '#1 Andi Final',
        '#1 Citra Final',
        '#2 Indra Perebutan juara 3',
        '#2 Maya Perebutan juara 3',
        '#3 Eko Grup A · 3',
        '#3 Kiki Grup B · 3',
        '#4 Gita Grup A · 4',
        '#4 Oki Grup B · 4',
      ]);
      final sf1 = a.byCode('SF1').id;
      expect(KnockoutBracket.flipCheck(a, sf1, 'Maya'), isA<FlipAllowed>());
      a = _via(a, (c) => c.submitScore(sf1, const [SetScore(side1: 4, side2: 6)]));
      expect((a.sides('F'), a.sides('J3')), ('Maya–Citra', 'Andi–Indra'));
    });

    test('Hapus WO SF2 tanpa skor lama → Belum + pratinjau tbd', () {
      final a = groups16E().bracket(q16E).ko('SF1', 6, 4).koWo('SF2', 'Indra');
      final check = _allowed(a, a.byCode('SF2').id, _removeWo);
      expect(check.outcome, ResetOutcome.pending);
      expect(
        knockoutFlipMessage(a, check.preview),
        'Final: Andi · Budi vs Pemenang SF2\nJuara 3: Maya · Nanda vs Kalah SF2',
      );
      final b = _apply(a, a.byCode('SF2').id, _removeWo);
      expect((b.sides('F'), b.sides('J3')), ('Andi–?', 'Maya–?'));
    });

    test('Hapus WO SF2 ke skor lama 4–6 membalik pemenang → pratinjau Citra; Final berskor → ResetBlocked', () {
      final a = sf().koWo('SF2', 'Citra');
      expect(a.sides('F'), 'Andi–Indra');
      final check = _allowed(a, a.byCode('SF2').id, _removeWo);
      expect(check.outcome, ResetOutcome.oldScore);
      expect(
        knockoutFlipMessage(a, check.preview),
        'Final: Andi · Budi vs Citra · Dewi\nJuara 3: Maya · Nanda vs Indra · Joko',
      );
      final b = _apply(a, a.byCode('SF2').id, _removeWo);
      expect((b.byCode('SF2').winnerPairId, b.sides('F'), b.sides('J3')), ('Citra', 'Andi–Citra', 'Maya–Indra'));

      final scored = a.ko('F', 9, 7);
      expect(ScoreReset.check(scored, scored.byCode('SF2').id, _removeWo), isA<ResetBlocked>());
    });

    test('diakhiri setelah R7 (F, J3 Tidak dimainkan) → clearScore SF1 boleh, sisi F/J3 kembali tbd', () {
      final a = sf().finish();
      final check = _allowed(a, a.byCode('SF1').id, _clear);
      expect(check.outcome, ResetOutcome.cancelled);
      final b = _apply(a, a.byCode('SF1').id, _clear);
      expect(b.byCode('SF1').status, MatchStatus.cancelled);
      expect((b.sides('F'), b.sides('J3')), ('?–Citra', '?–Indra'));
      expectRoundtrip(b, reason: '17E diakhiri');
    });

    test('I9 pengaman: gugur Hapus WO ke skor lama seri (simpanan rusak) → tidak tersedia', () {
      final base = sf();
      final sf2 = base.byCode('SF2');
      final broken = base.withMatches([
        for (final x in base.matches)
          x.id == sf2.id ? x.withScore(const [SetScore(side1: 5, side2: 5)]).asWalkover(loserPairId: 'Indra') : x,
      ]);
      expect(ScoreReset.check(broken, sf2.id, _removeWo), isA<ResetUnavailable>());
    });
  });

  group('Ketersediaan per mode × diakhiri × status', () {
    List<(String, ActiveTournament)> tournaments() => [
      ('Fixed', fixedTournament({'r1c1': (6, 3), 'r1c2': (4, 6), 'r2c1': (6, 4)})),
      ('Sparing Fixed', fixedSparing(c13.sublist(0, 7))),
      ('Mixed', mixed17b()),
      ('Mexicano', mexicano14a()),
      ('Grup + Gugur', gk20b()),
    ];

    for (final finished in [false, true]) {
      test(
        'status pending/cancelled tidak punya keduanya; done hanya Kosongkan; wo hanya Hapus WO (diakhiri $finished)',
        () {
          for (final (name, base) in tournaments()) {
            final t = finished ? base.finish() : base;
            // Satu match WO di round yang terbuka untuk aksi (Mixed/Mexicano: round terakhir).
            final open = t.matches.lastWhere((m) => m.status == MatchStatus.done);
            final withWo = t.withMatches([
              for (final x in t.matches) x.id == open.id ? x.asWalkover(loserPairId: x.pair1.id) : x,
            ]);
            for (final m in withWo.matches) {
              final clear = ScoreReset.check(withWo, m.id, _clear);
              final remove = ScoreReset.check(withWo, m.id, _removeWo);
              final where = '$name ${m.id} ${m.status.name}';
              if (m.status == MatchStatus.pending || m.status == MatchStatus.cancelled) {
                expect(clear, isA<ResetUnavailable>(), reason: where);
                expect(remove, isA<ResetUnavailable>(), reason: where);
              }
              if (m.status == MatchStatus.done) expect(remove, isA<ResetUnavailable>(), reason: where);
              if (m.status == MatchStatus.wo) {
                expect(clear, isA<ResetUnavailable>(), reason: where);
                expect(remove, isA<ResetAllowed>(), reason: where);
              }
              if (finished) expect(t.matches.any((x) => x.status == MatchStatus.pending), isFalse);
            }
            expect(ScoreReset.check(withWo, 'tidak-ada', _clear), isA<ResetUnavailable>());
          }
        },
      );
    }

    test('Fixed: round terkunci tidak; setelah diakhiri semua round terbuka', () {
      final a = fixedSparing(c13);
      final b = _apply(a, 'm6', _removeWo); // R3 kembali Belum → R4–R6 terkunci
      expect(ScoreReset.check(b, 'm12', _clear), isA<ResetUnavailable>());
      expect(ScoreReset.check(b, 'm1', _clear), isA<ResetAllowed>());
      final ended = b.finish();
      expect(ScoreReset.check(ended, 'm12', _clear), isA<ResetAllowed>());
    });

    test('match bersisi tbd → tidak tersedia', () {
      final a = groups16E().bracket(q16E);
      final f = a.byCode('F');
      expect(f.pair1.isTbd, isTrue);
      // Simpanan rusak: Final bersisi tbd tapi Selesai.
      final broken = a.withMatches([
        for (final x in a.matches) x.id == f.id ? x.withScore(const [SetScore(side1: 9, side2: 7)]) : x,
      ]);
      expect(ScoreReset.check(broken, f.id, _clear), isA<ResetUnavailable>());
    });
  });

  group('Model', () {
    test('cleared/withoutWalkover membawa phase, id, sisi; WO dan alasan null', () {
      final a = sf16E();
      final sf1 = a.byCode('SF1');
      for (final r in [
        sf1.cleared(finished: false),
        sf1.cleared(finished: true),
        sf1.asWalkover(loserPairId: sf1.pair2.id, reason: WoReason.absent).withoutWalkover(finished: false),
      ]) {
        expect(r.phase, sf1.phase);
        expect(
          (r.id, r.roundNumber, r.matchNumberInRound, r.courtId),
          (sf1.id, 7, sf1.matchNumberInRound, sf1.courtId),
        );
        expect((r.pair1.id, r.pair2.id), (sf1.pair1.id, sf1.pair2.id));
        expect((r.woLoserPairId, r.woReason), (null, null));
      }
      expect(sf1.cleared(finished: false).status, MatchStatus.pending);
      expect(sf1.cleared(finished: true).status, MatchStatus.cancelled);
      expect(sf1.cleared(finished: false).sets, isEmpty);
      final restored = sf1.asWalkover(loserPairId: sf1.pair1.id).withoutWalkover(finished: true);
      expect((restored.status, restored.sets.single.side1), (MatchStatus.done, 6));
      final noOld = a.byCode('F').asWalkover(loserPairId: 'x').withoutWalkover(finished: true);
      expect((noOld.status, noOld.sets.length), (MatchStatus.cancelled, 0));
    });

    test('lockedBy: tanpa yang dikosongkan = round − 1; round berjalan/sebelumnya null', () {
      final a = fixedTournament({'r1c1': (6, 3), 'r1c2': (4, 6), 'r2c1': (6, 4)});
      expect(a.currentRound, 2);
      expect([a.lockedBy(1), a.lockedBy(2), a.lockedBy(3), a.lockedBy(5)], [null, null, 2, 4]);
      expect(fixedTournament({}, finished: true).lockedBy(3), isNull);
    });
  });
}

/// SF1 dan SF2 berskor (17E).
ActiveTournament sf16E() => groups16E().bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6);
