import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/schedule/player_swap.dart';
import 'package:match_addict/services/share/result_text_builder.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import '../hifi/screens/mexicano_fixture.dart';
import '../hifi/screens/schedule_fixture.dart' show LoadedTournament, fixedTournament;
import '../hifi/screens/sparing_mixed_fixture.dart';
import 'player_swap_fixture.dart';

/// Tukar pemain Mixed (logic.md §15, PRD §15): data 15A/15B/15C dan tabel AC-T.
void main() {
  late ProviderContainer container;
  late DateTime now;
  ActiveTournament read() => container.read(tournamentProvider)!;
  TournamentController load(ActiveTournament active, [DateTime? at]) {
    now = at ?? swapNow;
    container = ProviderContainer(
      overrides: [
        tournamentProvider.overrideWith(() => LoadedTournament(active)),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container.read(tournamentProvider.notifier);
  }

  Set<String> restingOf(ActiveTournament a, int round) => {...?a.restingPlayerIdsByRound[round]};
  List<String> names(Iterable<Player> players) => [for (final p in players) p.name];
  Set<String> nameSet(Iterable<Player> players) => names(players).toSet();
  MatchGame match(ActiveTournament a, String id) => a.matchById(id)!;
  int played(ActiveTournament a, String id) => a.matches.where((m) => swapPlayersOf(m).contains(id)).length;

  /// Isi skor semua match yang belum ada skornya di round terakhir (skor tidak memengaruhi siapa main di Mixed).
  void fillLastRound(TournamentController c) {
    for (final m in read().matchesOfRound(read().roundCount)) {
      if (m.status == MatchStatus.pending) c.submitScore(m.id, const [SetScore(side1: 12, side2: 9)]);
    }
  }

  group('AC-T2 / T3 / T5: 15A (17a)', () {
    test('AC-T2 Dewi → Budi di C2: slot sama, id pasangan dihitung ulang, C1 tidak berubah', () {
      final c = load(swap15A());
      final before = read();
      expect(c.swapPlayer(matchId: 'm-r3-2', outId: 'Dewi', inId: 'Budi'), isTrue);
      final after = read();
      final m = match(after, 'm-r3-2');
      expect([m.pair1.player1Id, m.pair1.player2Id], ['Budi', 'Eko'], reason: 'Budi di slot Dewi = player1Id');
      expect([m.pair2.player1Id, m.pair2.player2Id], ['Fajar', 'Gita']);
      expect(m.pair1.id, EndlessRoundGenerator.pairId('Budi', 'Eko'));
      expect((m.id, m.courtId, m.matchNumberInRound, m.roundNumber), ('m-r3-2', 'c2', 2, 3));
      expect(identical(m.pair2, match(before, 'm-r3-2').pair2), isTrue, reason: 'pasangan lawan objek yang sama');
      expect(identical(match(after, 'm-r3-1'), match(before, 'm-r3-1')), isTrue);
      expect(PlayerSwap.isSwappable(after, match(after, 'm-r3-1')), isFalse, reason: 'C1 sudah ada skor');
      expectSwapInvariants(before, after, matchId: 'm-r3-2', outId: 'Dewi', inId: 'Budi');
    });

    test('AC-T3 daftar istirahat, jumlah main, dan Buat R4', () {
      final c = load(swap15A());
      c.swapPlayer(matchId: 'm-r3-2', outId: 'Dewi', inId: 'Budi');
      final after = read();
      expect(after.restingPlayerIdsByRound[3], ['Andi', 'Dewi'], reason: 'Dewi menggantikan Budi di indeksnya');
      final list = EndlessRoundGenerator.restingAfterLastRound(after, now);
      expect(names(list.priority), ['Andi', 'Dewi']);
      expect(list.later, isEmpty);
      expect([played(after, 'Andi'), played(after, 'Budi'), played(after, 'Dewi')], [2, 3, 2]);
      expectSwapListMatchesCreate(after, now);

      fillLastRound(c);
      c.generateNextRound();
      final r4 = read();
      expect(r4.roundCount, 4);
      expect(restingOf(r4, 4), {'Eko', 'Budi'});
      final playing = {for (final m in r4.matchesOfRound(4)) ...swapPlayersOf(m)};
      expect(playing, containsAll(['Andi', 'Dewi']));
    });

    test('AC-T5 tukar balik: encode byte-sama; Buat R4 → istirahat {Eko, Dewi}', () {
      final c = load(swap15A());
      final first = TournamentCodec.encode(read());
      c.swapPlayer(matchId: 'm-r3-2', outId: 'Dewi', inId: 'Budi');
      final swappedOnce = read();
      expect(c.swapPlayer(matchId: 'm-r3-2', outId: 'Budi', inId: 'Dewi'), isTrue);
      expect(TournamentCodec.encode(read()), first);
      expectSwapInvariants(swappedOnce, read(), matchId: 'm-r3-2', outId: 'Budi', inId: 'Dewi');
      fillLastRound(c);
      c.generateNextRound();
      expect(restingOf(read(), 4), {'Eko', 'Dewi'});
    });

    test('AC-T9 Batalkan R3 setelah tukar, lalu Buat R3: Andi dan Budi istirahat lagi (himpunan, bukan pasangan)', () {
      // 15B (R3 tanpa skor): Batalkan hanya untuk round tanpa skor.
      final c = load(swap15B());
      c.swapPlayer(matchId: 'm-r3-2', outId: 'Dewi', inId: 'Budi');
      c.cancelLastRound();
      expect(read().roundCount, 2);
      c.generateNextRound();
      final r3 = read();
      expect(r3.roundCount, 3);
      expect(restingOf(r3, 3), {'Andi', 'Budi'});
      expect(r3.latePlayerIds, isEmpty);
    });
  });

  group('AC-T7: 15B (17f)', () {
    test('Citra → Budi di C1, lalu R4–R6: istirahat R4 {Budi, Dewi}, selisih main 2 / 2 / 1', () {
      final c = load(swap15B());
      expect(c.swapPlayer(matchId: 'm-r3-1', outId: 'Citra', inId: 'Budi'), isTrue);
      final after = read();
      final m = match(after, 'm-r3-1');
      expect([m.pair1.player1Id, m.pair1.player2Id], ['Budi', 'Indra'], reason: 'pernah partner di R2, tetap sah');
      expect(restingOf(after, 3), {'Andi', 'Citra'});
      expect(names(EndlessRoundGenerator.restingAfterLastRound(after, now).priority), ['Andi', 'Citra']);
      expect(after.latePlayerIds, isEmpty);
      expect(
        {for (final p in swapNames) p: played(after, p)},
        {
          'Citra': 1,
          'Andi': 2, 'Hadi': 2, 'Indra': 2, 'Joko': 2, //
          'Budi': 3, 'Dewi': 3, 'Eko': 3, 'Fajar': 3, 'Gita': 3,
        },
      );

      List<int> spread() {
        final counts = [for (final p in swapNames) played(read(), p)];
        final (lo, hi) = (counts.reduce(min), counts.reduce(max));
        return [lo, hi, hi - lo];
      }

      fillLastRound(c);
      c.generateNextRound();
      expect(restingOf(read(), 4), {'Budi', 'Dewi'});
      expect(spread(), [2, 4, 2]);
      fillLastRound(c);
      c.generateNextRound();
      expect(spread(), [3, 5, 2]);
      fillLastRound(c);
      c.generateNextRound();
      expect(spread(), [4, 5, 1]);
    });
  });

  group('AC-T6 / T12: pemain telat', () {
    test('AC-T6 15A dan 15B setelah tukar: latePlayerIds kosong', () {
      for (final (active, id, outId, inId) in [
        (swap15A(), 'm-r3-2', 'Dewi', 'Budi'),
        (swap15B(), 'm-r3-1', 'Citra', 'Budi'),
      ]) {
        final c = load(active);
        c.swapPlayer(matchId: id, outId: outId, inId: inId);
        expect(read().latePlayerIds, isEmpty);
      }
    });

    test('AC-T6 10 pemain R1, tukar Andi → Indra, Buat R2: Andi main dan tidak pernah telat', () {
      final c = load(
        swapActive([
          swapMatch(1, 1, ('Andi', 'Citra'), ('Budi', 'Dewi')),
          swapMatch(1, 2, ('Eko', 'Gita'), ('Fajar', 'Hadi')),
        ]),
      );
      expect(restingOf(read(), 1), {'Indra', 'Joko'});
      expect(c.swapPlayer(matchId: 'm-r1-1', outId: 'Andi', inId: 'Indra'), isTrue);
      expect(read().latePlayerIds, isEmpty);
      fillLastRound(c);
      c.generateNextRound();
      expect({for (final m in read().matchesOfRound(2)) ...swapPlayersOf(m)}, contains('Andi'));
      expect(read().latePlayerIds, isEmpty);
    });

    test('AC-T12 pemain baru setelah R1 dibuat: tukar pemain aktif → dia main, keluar dari daftar telat', () {
      final base = swapActive([
        swapMatch(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewi'), (12, 9)),
        swapMatch(1, 2, ('Eko', 'Fajar'), ('Gita', 'Hadi')),
      ], config: swapConfig(names: swapNames.take(9).toList()));
      final c = load(base);
      expect(c.addPlayer('Joko'), isNull);
      final joko = read().config.players.last.id;
      expect(read().latePlayerIds, {joko});
      expect(c.swapPlayer(matchId: 'm-r1-2', outId: 'Hadi', inId: joko), isTrue);
      final after = read();
      expect(after.latePlayerIds, isEmpty);
      expect(restingOf(after, 1), {'Indra', 'Hadi'});
      expect(names(EndlessRoundGenerator.restingAfterLastRound(after, now).priority), ['Hadi', 'Indra']);
      c.submitScore('m-r1-2', const [SetScore(side1: 12, side2: 9)]);
      c.generateNextRound();
      final r2 = {for (final m in read().matchesOfRound(2)) ...swapPlayersOf(m)};
      expect(r2, containsAll(['Hadi', 'Indra']));
    });
  });

  group('invariant #4 dua arah (n > 1)', () {
    test('Hadi dikembalikan setelah hanya R2 dibuat tanpa dia, lalu ditukar masuk → keluar dari telat', () {
      final base = swapActive(
        [
          swapMatch(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewi'), (12, 9)),
          swapMatch(1, 2, ('Eko', 'Fajar'), ('Gita', 'Hadi'), (11, 10)),
          swapMatch(2, 1, ('Andi', 'Budi'), ('Citra', 'Dewi')),
          swapMatch(2, 2, ('Eko', 'Fajar'), ('Gita', 'Indra')),
        ],
        config: swapConfig(names: swapNames.take(9).toList()),
        withdrawn: {'Hadi'},
      );
      final c = load(base);
      expect(c.reinstatePlayer('Hadi'), isNull);
      final before = read();
      expect(before.latePlayerIds, {'Hadi'}, reason: 'absen di R2 saja');
      expect(c.swapPlayer(matchId: 'm-r2-1', outId: 'Andi', inId: 'Hadi'), isTrue);
      expect(read().latePlayerIds, isEmpty);
      expectSwapInvariants(before, read(), matchId: 'm-r2-1', outId: 'Andi', inId: 'Hadi');
    });

    test('Hadi telat di R1 dan R2: ditukar masuk di R2 → tetap telat (R1 masih dilewatkan)', () {
      final full = swapActive([
        swapMatch(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewi'), (12, 9)),
        swapMatch(1, 2, ('Eko', 'Fajar'), ('Gita', 'Indra'), (11, 10)),
        swapMatch(2, 1, ('Andi', 'Budi'), ('Citra', 'Dewi')),
        swapMatch(2, 2, ('Eko', 'Fajar'), ('Gita', 'Indra')),
      ], config: swapConfig(names: swapNames.take(9).toList()));
      // Hadi baru bergabung: tidak tercatat istirahat di round mana pun (seperti pemain telat sungguhan).
      final base = full.copyWith(
        resting: {
          for (final e in full.restingPlayerIdsByRound.entries)
            e.key: [
              for (final id in e.value)
                if (id != 'Hadi') id,
            ],
        },
      );
      final c = load(base);
      final before = read();
      expect(before.latePlayerIds, {'Hadi'});
      expect(c.swapPlayer(matchId: 'm-r2-1', outId: 'Andi', inId: 'Hadi'), isTrue);
      expect(read().latePlayerIds, {'Hadi'});
      expectSwapInvariants(before, read(), matchId: 'm-r2-1', outId: 'Andi', inId: 'Hadi');
    });
  });

  group('AC-T8: Sparing (15C)', () {
    test('kandidat sesama klub; Citra (Garuda) bukan kandidat tim Matcha', () {
      final state = mixedSparing15b();
      final active = state.active;
      final c2 = active.matchesOfRound(4).firstWhere((m) => m.courtId == 'c2');
      expect(c2.pair1.playerIds.map(active.playerName), ['Andi', 'Dewi']);
      final kiki = c2.pair2;
      expect(active.matchesOfRound(4).firstWhere((m) => m.courtId == 'c1').pair1.playerIds.map(active.playerName), [
        'Budi',
        'Hadi',
      ]);
      Set<String> union(Pair team) {
        final c = PlayerSwap.candidates(active, c2, team, state.now);
        return nameSet([...c.priority, ...c.later]);
      }

      expect(union(kiki), {'Joko', 'Maya'});
      expect(union(c2.pair1), {'Citra', 'Eko', 'Fajar', 'Gita'});
      final citra = active.config.players.firstWhere((p) => p.name == 'Citra').id;
      expect(PlayerSwap.isCandidate(active, kiki, citra), isFalse);
      final kikiId = kiki.playerIds.firstWhere((id) => active.playerName(id) == 'Kiki');
      expect(PlayerSwap.apply(active, matchId: c2.id, outId: kikiId, inId: citra), isNull);
      expectSwapListMatchesCreate(active, state.now);
    });

    test('Kiki → Maya: C2 Andi·Dewi vs Indra·Maya, Matcha istirahat {Joko, Kiki}, Garuda tetap, simpanan sah', () {
      final state = mixedSparing15b();
      final active = state.active;
      final c2 = active.matchesOfRound(4).firstWhere((m) => m.courtId == 'c2');
      String id(String name) => active.config.players.firstWhere((p) => p.name == name).id;
      final after = PlayerSwap.apply(active, matchId: c2.id, outId: id('Kiki'), inId: id('Maya'))!;
      final m = match(after, c2.id);
      expect([for (final p in m.pair2.playerIds) after.playerName(p)], ['Indra', 'Maya']);
      expect([for (final p in m.pair1.playerIds) after.playerName(p)], ['Andi', 'Dewi']);
      Set<String> club(ActiveTournament a, String clubName) {
        final e = EndlessRoundGenerator.restingByClubAfterLastRound(
          a,
          state.now,
        ).firstWhere((e) => e.club.name == clubName);
        return nameSet([...e.priority, ...e.later]);
      }

      expect(club(active, 'Matcha Club'), {'Joko', 'Maya'});
      expect(club(after, 'Matcha Club'), {'Joko', 'Kiki'});
      expect(club(after, garuda.name), club(active, garuda.name));
      expectSwapInvariants(active, after, matchId: c2.id, outId: id('Kiki'), inId: id('Maya'));
      expectSwapListMatchesCreate(after, state.now);
      expect(TournamentCodec.decode(TournamentCodec.encode(after)), isNotNull, reason: 'S2/S4 lolos _isValidSparing');
    });

    test('17n Garuda 4 / Matcha 6, R1: tim Garuda tanpa ikon, tim Matcha berikon dengan 2 kandidat', () {
      final active = mixedSparingRounds(
        mixedSparingEmpty(mixedSparingConfig(garudaPlayers: garudaNames.take(4).toList())),
        1,
        Random(1),
      );
      final at = mixedSparingAt(0);
      for (final m in active.matchesOfRound(1)) {
        for (final team in [m.pair1, m.pair2]) {
          final club = active.config.clubOfPair(team)!;
          final candidates = PlayerSwap.candidates(active, m, team, at);
          expect(PlayerSwap.canSwapTeam(active, m, team), club.id == matcha.id);
          expect(candidates.priority.length + candidates.later.length, club.id == matcha.id ? 2 : 0);
        }
      }
      expectSwapListMatchesCreate(active, at);
    });
  });

  group('AC-T1 / invariant #8: tidak sah = tidak berubah', () {
    void expectRejected(ActiveTournament active, String matchId, String outId, String inId, {DateTime? at}) {
      final c = load(active, at);
      final before = read();
      expect(PlayerSwap.apply(before, matchId: matchId, outId: outId, inId: inId), isNull);
      expect(c.swapPlayer(matchId: matchId, outId: outId, inId: inId), isFalse);
      expect(identical(read(), before), isTrue);
    }

    test('match sudah ada skor', () => expectRejected(swap15A(), 'm-r3-1', 'Citra', 'Andi'));

    test('match WO', () {
      final a = swap15A();
      final wo = a.copyWith(
        tournament: a.tournament.copyWith(
          matches: [
            for (final m in a.matches)
              if (m.id == 'm-r3-2') m.asWalkover(loserPairId: m.pair2.id, reason: WoReason.absent) else m,
          ],
        ),
      );
      final m = match(wo, 'm-r3-2');
      expect(PlayerSwap.canSwapTeam(wo, m, m.pair1), isFalse);
      expectRejected(wo, 'm-r3-2', 'Dewi', 'Andi');
    });

    test('round sebelum round terakhir (tab R2)', () {
      final a = swapActive([
        ...swapRounds12().take(2),
        ...swapRounds12().skip(2),
        swapMatch(3, 1, ('Citra', 'Indra'), ('Hadi', 'Joko')),
        swapMatch(3, 2, ('Dewi', 'Eko'), ('Fajar', 'Gita')),
      ]);
      // R2 sudah berskor; ubah jadi pending supaya satu-satunya alasan tolak adalah "bukan round terakhir".
      final pendingR2 = a.copyWith(
        tournament: a.tournament.copyWith(
          matches: [
            for (final m in a.matches)
              if (m.id == 'm-r2-2') swapMatch(2, 2, ('Budi', 'Indra'), ('Dewi', 'Joko')) else m,
          ],
        ),
      );
      final m = match(pendingR2, 'm-r2-2');
      expect(PlayerSwap.isSwappable(pendingR2, m), isFalse);
      expect(PlayerSwap.canSwapTeam(pendingR2, m, m.pair1), isFalse);
      expectRejected(pendingR2, 'm-r2-2', 'Budi', 'Citra');
    });

    test('turnamen diakhiri (finishNow); resume menghidupkan lagi (AC-T13)', () {
      final c = load(swap15A());
      c.swapPlayer(matchId: 'm-r3-2', outId: 'Dewi', inId: 'Budi');
      c.finishNow();
      final m = match(read(), 'm-r3-2');
      expect(m.status, MatchStatus.cancelled);
      expect(PlayerSwap.isSwappable(read(), m), isFalse);
      expect(PlayerSwap.canSwapTeam(read(), m, m.pair1), isFalse);
      final ended = read();
      expect(c.swapPlayer(matchId: 'm-r3-2', outId: 'Budi', inId: 'Dewi'), isFalse);
      expect(identical(read(), ended), isTrue);
      c.resume(const {}, from: ended);
      final back = match(read(), 'm-r3-2');
      expect(back.status, MatchStatus.pending);
      expect(PlayerSwap.canSwapTeam(read(), back, back.pair1), isTrue);
    });

    test('mode Fixed', () {
      final fixed = fixedTournament(const {});
      final m = fixed.matches.last;
      expect(PlayerSwap.isSwappable(fixed, m), isFalse);
      expect(PlayerSwap.canSwapTeam(fixed, m, m.pair1), isFalse);
      expectRejected(fixed, m.id, m.pair1.player1Id, 'p0');
    });

    test('mode Mexicano (14B R2): dikunci walau isEndless', () {
      final mex = mexicanoTournament(2);
      expect(mex.config.mode.isEndless, isTrue);
      final m = mex.matchesOfRound(2).first;
      expect(PlayerSwap.isSwappable(mex, m), isFalse);
      expect(PlayerSwap.canSwapTeam(mex, m, m.pair1), isFalse);
      expectRejected(mex, m.id, m.pair1.player1Id, mex.config.players.first.id);
    });

    test('8 pemain / 2 court R2: semua main, tidak ada kandidat → tanpa ikon', () {
      final a = swapActive([
        swapMatch(1, 1, ('Andi', 'Citra'), ('Budi', 'Dewi'), (12, 9)),
        swapMatch(1, 2, ('Eko', 'Gita'), ('Fajar', 'Hadi'), (11, 10)),
        swapMatch(2, 1, ('Andi', 'Gita'), ('Fajar', 'Eko')),
        swapMatch(2, 2, ('Budi', 'Hadi'), ('Dewi', 'Citra')),
      ], config: swapConfig(names: swapNames.take(8).toList()));
      final m = match(a, 'm-r2-1');
      expect(PlayerSwap.canSwapTeam(a, m, m.pair1), isFalse);
      expect(PlayerSwap.candidates(a, m, m.pair1, swapNow).priority, isEmpty);
      expectRejected(a, 'm-r2-1', 'Andi', 'Budi');
    });

    test('alasan tolak per argumen: Q main, Q dikeluarkan, P bukan di match, P == Q, id tak dikenal', () {
      final a = swap15A();
      expectRejected(a, 'm-r3-2', 'Dewi', 'Fajar'); // Q main di round n (match yang sama)
      expectRejected(a, 'm-r3-2', 'Dewi', 'Citra'); // Q main di match lain
      expectRejected(a, 'm-r3-2', 'Andi', 'Budi'); // P bukan pemain match itu
      expectRejected(a, 'm-r3-2', 'Dewi', 'Dewi'); // P == Q
      expectRejected(a, 'm-r3-2', 'Dewi', 'Orang Asing'); // Q tidak dikenal
      expectRejected(a, 'm-tidak-ada', 'Dewi', 'Andi'); // match tidak ada
      final out = a.copyWith(withdrawn: {'Andi'});
      expectRejected(out, 'm-r3-2', 'Dewi', 'Andi'); // Q dikeluarkan
    });

    test('sparing: Q klub lain', () {
      final state = mixedSparing15b();
      final a = state.active;
      final c2 = a.matchesOfRound(4).firstWhere((m) => m.courtId == 'c2');
      final citra = a.config.players.firstWhere((p) => p.name == 'Citra').id;
      final kiki = c2.pair2.playerIds.firstWhere((id) => a.playerName(id) == 'Kiki');
      expectRejected(a, c2.id, kiki, citra, at: state.now);
    });
  });

  group('AC-T10: Kelola court sesudah tukar', () {
    TournamentController loadAt(ActiveTournament a) => load(a, swapAt(10));

    test('(a) tambah Court 3: match baru = 4 yang istirahat termasuk P; resting[2] kosong', () {
      final names12 = [...swapNames, 'Kiki', 'Lina'];
      final a = swapActive([
        swapMatch(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewi'), (12, 9)),
        swapMatch(1, 2, ('Eko', 'Fajar'), ('Gita', 'Hadi'), (11, 10)),
        swapMatch(2, 1, ('Indra', 'Joko'), ('Kiki', 'Lina')),
        swapMatch(2, 2, ('Andi', 'Eko'), ('Budi', 'Fajar')),
      ], config: swapConfig(names: names12));
      final c = loadAt(a);
      expect(restingOf(read(), 2), {'Citra', 'Dewi', 'Gita', 'Hadi'});
      expect(c.swapPlayer(matchId: 'm-r2-2', outId: 'Andi', inId: 'Citra'), isTrue);
      c.addCourt(name: '', colorIndex: 2, bookingMinutes: 120);
      final after = read();
      final added = after.matchesOfRound(2).last;
      expect(added.courtId, isNot(anyOf('c1', 'c2')));
      expect(swapPlayersOf(added), {'Andi', 'Dewi', 'Gita', 'Hadi'});
      expect(after.restingPlayerIdsByRound[2], isEmpty);
    });

    test('(b) Court 3 dihapus: Q dan tiga lainnya kembali ke resting[2], P tetap, tanpa duplikat', () {
      final names14 = [...swapNames, 'Kiki', 'Lina', 'Maya', 'Nanda'];
      final a = swapActive([
        swapMatch(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewi'), (12, 9)),
        swapMatch(1, 2, ('Eko', 'Fajar'), ('Gita', 'Hadi'), (11, 10)),
        swapMatch(2, 1, ('Indra', 'Joko'), ('Kiki', 'Lina')),
        swapMatch(2, 2, ('Maya', 'Nanda'), ('Andi', 'Eko')),
      ], config: swapConfig(names: names14));
      final c = loadAt(a);
      expect(restingOf(read(), 2).length, 6);
      c.addCourt(name: '', colorIndex: 2, bookingMinutes: 120);
      final court3 = read().config.courts.last.id;
      final added = read().matchesOfRound(2).last;
      expect(added.courtId, court3);
      expect(read().restingPlayerIdsByRound[2]!.length, 2);
      final q = read().restingPlayerIdsByRound[2]!.first;
      final p = added.pair1.player1Id;
      final others = swapPlayersOf(added).difference({p});
      expect(c.swapPlayer(matchId: added.id, outId: p, inId: q), isTrue);
      expect(c.removeCourt(court3), isTrue);
      final after = read();
      final resting = after.restingPlayerIdsByRound[2]!;
      expect(resting.length, 6);
      expect(resting.toSet().length, 6, reason: 'tanpa duplikat');
      expect(resting, containsAll([p, q, ...others]));
      expect(after.matchesOfRound(2).length, 2);
    });
  });

  group('AC-T11: pemain yang dikeluarkan sebagai P', () {
    test('Hadi dikeluarkan lalu ditukar dengan Indra; Kembalikan sebelum R2 → tidak telat', () {
      final base = swapActive([
        swapMatch(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewi'), (12, 9)),
        swapMatch(1, 2, ('Eko', 'Fajar'), ('Gita', 'Hadi')),
      ], config: swapConfig(names: swapNames.take(9).toList()));
      final c = load(base);
      expect(c.withdrawPlayer('Hadi'), isTrue);
      expect(c.swapPlayer(matchId: 'm-r1-2', outId: 'Hadi', inId: 'Indra'), isTrue);
      final after = read();
      expect(swapPlayersOf(match(after, 'm-r1-2')), contains('Indra'));
      expect(restingOf(after, 1), {'Hadi'}, reason: 'P yang dikeluarkan tetap dicatat (TU1)');
      expect(names(EndlessRoundGenerator.restingAfterLastRound(after, now).priority), isEmpty);
      expect(EndlessRoundGenerator.restingAfterLastRound(after, now).later, isEmpty);
      expect(after.latePlayerIds, isEmpty);
      expect(c.reinstatePlayer('Hadi'), isNull);
      expect(read().latePlayerIds, isEmpty);
      final list = EndlessRoundGenerator.restingAfterLastRound(read(), now);
      expect(nameSet([...list.priority, ...list.later]), {'Hadi'});
    });
  });

  group('AC-T13 / T15 / T16', () {
    test('AC-T13 encode → decode setelah tukar: match + resting sama, Buat R4 = {Eko, Budi}', () {
      final c = load(swap15A());
      c.swapPlayer(matchId: 'm-r3-2', outId: 'Dewi', inId: 'Budi');
      final encoded = TournamentCodec.encode(read());
      final back = TournamentCodec.decode(encoded)!;
      expect(TournamentCodec.encode(back), encoded);
      expect(back.restingPlayerIdsByRound[3], ['Andi', 'Dewi']);
      final c2 = load(back);
      fillLastRound(c2);
      c2.generateNextRound();
      expect(restingOf(read(), 4), {'Eko', 'Budi'});
    });

    test('AC-T15 ranking menghitung pemain yang main; teks share tanpa kata "tukar"', () async {
      await initializeDateFormatting('id');
      final c = load(swap15A());
      c.swapPlayer(matchId: 'm-r3-2', outId: 'Dewi', inId: 'Budi');
      final before = RankingCalculator.rank(
        players: read().config.players,
        matches: read().matches,
        method: RankingMethod.totalGames,
        format: read().config.format,
      );
      c.submitScore('m-r3-2', const [SetScore(side1: 15, side2: 6)]);
      final a = read();
      final ranked = RankingCalculator.rank(
        players: a.config.players,
        matches: a.matches,
        method: RankingMethod.totalGames,
        format: a.config.format,
      );
      PlayerStanding of(List<PlayerStanding> list, String id) => list.firstWhere((s) => s.player.id == id);
      final budi = of(ranked, 'Budi'), dewi = of(ranked, 'Dewi');
      expect(budi.matchesPlayed, 3);
      expect(dewi.matchesPlayed, 2);
      expect(budi.totalPoint - of(before, 'Budi').totalPoint, 15);
      expect(dewi.totalPoint, of(before, 'Dewi').totalPoint);
      for (final format in ShareFormat.values) {
        final text = ResultTextBuilder.build(
          active: a,
          standings: standingEntries(standings: ranked, method: RankingMethod.totalGames),
          format: format,
          now: now,
        );
        expect(text.toLowerCase(), isNot(contains('tukar')));
      }
    });
  });
}
