import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/club_score.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import 'sparing_mixed_fixture.dart';

/// Fixture Mixed sparing = catatan frame 13m, 15a–15y (docs/tasks.md SP-18a): susunan, istirahat, prioritas per klub,
/// skor klub, klasemen 15s, riwayat 15u/15v, dan simpanan tiap keadaan.
void main() {
  String pair(ActiveTournament a, Pair p) => '${a.playerName(p.player1Id)} · ${a.playerName(p.player2Id)}';
  String match(ActiveTournament a, MatchGame m) {
    final s = m.sets.isEmpty ? ' vs ' : ' ${m.sets.single.side1}–${m.sets.single.side2} ';
    return '${pair(a, m.pair1)}$s${pair(a, m.pair2)}';
  }

  List<String> round(ActiveTournament a, int r) => [for (final m in a.matchesOfRound(r)) match(a, m)];
  List<String> names(Iterable<Player> ps) => [for (final p in ps) p.name];

  /// Daftar Istirahat round terakhir per klub seperti layar: (Prioritas, Istirahat lagi) klub pertama lalu kedua.
  List<List<List<String>>> resting(MixedSparingState s) => [
    for (final c in EndlessRoundGenerator.restingByClubAfterLastRound(s.active, s.now))
      [names(c.priority), names(c.later)],
  ];

  String clubScore(ActiveTournament a) {
    final r = ClubResult.of(a)!;
    return '${r.scoreLabel} · ${r.first.totalPoint} – ${r.second.totalPoint}';
  }

  int played(ActiveTournament a, String id) => a.matches
      .where((m) => m.status != MatchStatus.cancelled && (m.pair1.contains(id) || m.pair2.contains(id)))
      .length;

  /// AC-S11: Prioritas per klub = yang istirahat lalu main di hasil Buat R(n+1); Istirahat lagi tidak main.
  void expectPriorityIsNextRound(MixedSparingState s) {
    final split = EndlessRoundGenerator.restingByClubAfterLastRound(s.active, s.now);
    final next = mixedSparingRounds(s.active, 1, Random(7));
    final playing = {
      for (final m in next.matchesOfRound(next.roundCount)) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
    };
    for (final c in split) {
      expect(c.priority.every((p) => playing.contains(p.id)), isTrue, reason: c.club.name);
      expect(c.later.any((p) => playing.contains(p.id)), isFalse, reason: c.club.name);
    }
  }

  final states = <String, MixedSparingState Function()>{
    '15k': mixedSparing15k,
    '13m': mixedSparing13m,
    '15a': mixedSparing15a,
    '15b': mixedSparing15b,
    '15d': mixedSparing15d,
    '15e': mixedSparing15e,
    '15f': mixedSparing15f,
    '15i': mixedSparing15i,
    '15l+Oki': mixedSparing15lOki,
    '15m': mixedSparing15m,
    '15n': mixedSparing15n,
    '15p': mixedSparing15p,
    '15r': mixedSparing15r,
    '15t': mixedSparing15t,
    '15w': mixedSparing15w,
  };

  test('id turnamen menghasilkan drawSeed 0x5eed di semua keadaan', () {
    expect(mixedSparingEmpty().drawSeed, 0x5eed);
    for (final MapEntry(:key, :value) in states.entries) {
      expect(value().active.drawSeed, mixedSparingSeed, reason: key);
    }
  });

  test('AC-S20 simpanan tiap keadaan terbaca', () {
    for (final MapEntry(:key, :value) in states.entries) {
      final active = value().active;
      expect(TournamentCodec.decode(TournamentCodec.encode(active)), isNotNull, reason: key);
    }
  });

  test('15k: R1 baru, Prioritas R2 Andi, Budi, Dewi, Hadi · Indra, Lina', () {
    final s = mixedSparing15k();
    expect(round(s.active, 1), ['Eko · Gita vs Nanda · Kiki', 'Citra · Fajar vs Maya · Joko']);
    expect(resting(s), [
      [['Andi', 'Budi', 'Dewi', 'Hadi'], <String>[]],
      [['Indra', 'Lina'], <String>[]],
    ]);
    expect(clubScore(s.active), '0 – 0 · 0 – 0');
  });

  test('13m: R1–R3, R3 Court 2 belum; skor klub 4 – 1 · 27 – 21; AC-S11 Prioritas R4', () {
    final s = mixedSparing13m();
    expect(round(s.active, 1), ['Eko · Gita 6–4 Nanda · Kiki', 'Citra · Fajar 3–6 Maya · Joko']);
    expect(round(s.active, 2), ['Budi · Andi 6–2 Lina · Kiki', 'Dewi · Hadi 6–5 Nanda · Indra']);
    expect(round(s.active, 3), ['Fajar · Eko 6–4 Joko · Indra', 'Citra · Gita vs Lina · Maya']);
    expect(clubScore(s.active), '4 – 1 · 27 – 21');
    expect(resting(s), [
      [['Andi', 'Budi', 'Dewi', 'Hadi'], <String>[]],
      [['Kiki', 'Nanda'], <String>[]],
    ]);
    expectPriorityIsNextRound(s);
    // Fairness per klub setelah R3 (R3 berjalan dihitung): Garuda 2·2·2·2·1·1·1·1, Matcha 2 semua.
    expect(
      [for (final p in s.active.config.players) played(s.active, p.id)],
      [1, 1, 2, 1, 2, 2, 2, 1, ...List.filled(6, 2)],
    );
  });

  test('15a: R3 lengkap 5–6, skor klub 4 – 2 · 32 – 27; Prioritas R4 sama dengan 13m (AC-S11)', () {
    final s = mixedSparing15a();
    expect(round(s.active, 3), ['Fajar · Eko 6–4 Joko · Indra', 'Citra · Gita 5–6 Lina · Maya']);
    expect(clubScore(s.active), '4 – 2 · 32 – 27');
    expect(resting(s), [
      [['Andi', 'Budi', 'Dewi', 'Hadi'], <String>[]],
      [['Kiki', 'Nanda'], <String>[]],
    ]);
    expectPriorityIsNextRound(s);
    // Hasil Buat R4 (15b) = daftar Prioritas 15a.
    expect(round(mixedSparing15b().active, 4), ['Budi · Hadi vs Lina · Nanda', 'Andi · Dewi vs Indra · Kiki']);
  });

  test('15b: R4 baru, Prioritas R5 Citra, Eko, Fajar, Gita · Joko, Maya; bisa dibatalkan', () {
    final s = mixedSparing15b();
    expect(round(s.active, 4), ['Budi · Hadi vs Lina · Nanda', 'Andi · Dewi vs Indra · Kiki']);
    expect(clubScore(s.active), '4 – 2 · 32 – 27');
    expect(resting(s), [
      [['Citra', 'Eko', 'Fajar', 'Gita'], <String>[]],
      [['Joko', 'Maya'], <String>[]],
    ]);
    expect(s.active.canCancelLastRound, isTrue);
    expectPriorityIsNextRound(s);
  });

  test('15d: 16 + 14, R3 = frame, Prioritas + Istirahat lagi per klub, 4 – 1 · 28 – 20', () {
    final s = mixedSparing15d();
    expect(s.active.config.players.length, 30);
    expect(s.active.config.playerById('m07')?.name, 'Oki');
    expect(round(s.active, 3), ['Hadi · Dewi 6–5 Joko · Putri', 'Iwan · Budi vs Vina · Lina']);
    expect(clubScore(s.active), '4 – 1 · 28 – 20');
    expect(resting(s), [
      [['Gilang', 'Jaka', 'Rizky', 'Tono'], ['Andi', 'Citra', 'Eko', 'Fajar', 'Gita', 'Hendra', 'Sari', 'Umar']],
      [['Maya', 'Oki', 'Rina', 'Yoga'], ['Indra', 'Kiki', 'Nanda', 'Tari', 'Wulan', 'Zaki']],
    ]);
    expectPriorityIsNextRound(s);
  });

  test('15e (8 / 3): hanya Court 1 (AC-S10), R1 6–3, R2 Citra · Andi vs Indra · Kiki, Matcha istirahat lagi "–"', () {
    final s = mixedSparing15e();
    expect(round(s.active, 1), ['Gita · Fajar 6–3 Kiki · Joko']);
    expect(round(s.active, 2), ['Citra · Andi vs Indra · Kiki']);
    expect({for (final m in s.active.matches) m.courtId}, {'c1'});
    expect(clubScore(s.active), '1 – 0 · 6 – 3');
    expect(resting(s), [
      [['Eko', 'Hadi'], ['Budi', 'Dewi', 'Fajar', 'Gita']],
      [['Joko'], <String>[]],
    ]);
    expect(s.active.sparingLimitingClub, matcha);
    expectPriorityIsNextRound(s);
  });

  test('15f: R8 lengkap, waktu habis; 10 – 6 · 83 – 69; AC-S8 jumlah main; Prioritas R9', () {
    final s = mixedSparing15f();
    final a = s.active;
    expect(a.roundCount, 8);
    expect(round(a, 8), ['Budi · Hadi 5–6 Lina · Indra', 'Andi · Dewi 6–2 Maya · Nanda']);
    expect(clubScore(a), '10 – 6 · 83 – 69');
    expect(ClubResult.of(a)!.first.diff, 14);
    expect(a.courtsAvailableAt(s.now), isEmpty);
    expect(a.isFinal(s.now), isTrue);
    expect({for (final p in a.config.players.take(8)) played(a, p.id)}, {4});
    expect(
      {for (final p in a.config.players.skip(8)) p.name: played(a, p.id)},
      {'Indra': 5, 'Joko': 5, 'Kiki': 5, 'Lina': 6, 'Maya': 5, 'Nanda': 6},
    );
    expect(resting(s), [
      [['Citra', 'Eko', 'Fajar', 'Gita'], <String>[]],
      [['Joko', 'Kiki'], <String>[]],
    ]);
    // 15j: Matcha Club membatasi (⌊6 ÷ 2⌋ = 3 < ⌊8 ÷ 2⌋ = 4).
    expect(a.sparingLimitingClub, matcha);
  });

  test('15s: Klasemen Final Total Point per klub = frame (game, +/−, W–L, main, nomor)', () {
    final a = mixedSparing15f().active;
    final standings = RankingCalculator.rank(
      players: a.config.players,
      matches: a.matches,
      method: RankingMethod.totalGames,
      format: a.config.format,
    );
    final groups = clubStandings(active: a, standings: standings, method: RankingMethod.totalGames);
    String row(StandingEntry e) {
      final s = e.standing;
      return '${e.position} ${e.label} ${s.matchesPlayed} ${s.wins}–${s.losses} ${s.diffLabel} ${s.totalPoint}';
    }

    expect([for (final g in groups) g.club], [garuda, matcha]);
    expect(
      [for (final e in groups[0].entries) row(e)],
      [
        '1 Dewi 4 4–0 +9 24',
        '2 Gita 4 3–1 +8 23',
        '3 Andi 4 3–1 +9 22',
        '4 Fajar 4 3–1 +7 21',
        '5 Budi 4 2–2 +2 21',
        '6 Eko 4 3–1 +3 20',
        '7 Hadi 4 1–3 −4 19',
        '8 Citra 4 1–3 −6 16',
      ],
    );
    expect(
      [for (final e in groups[1].entries) row(e)],
      [
        '1 Lina 6 4–2 −1 29',
        '2 Joko 5 3–2 +5 26',
        '3 Nanda 6 2–4 −4 26',
        '4 Indra 5 1–4 −6 23',
        '5 Maya 5 2–3 −6 20',
        '6 Kiki 5 0–5 −16 14',
      ],
    );
  });

  test('15u/15v: riwayat Andi dan Lina = frame (tim sendiri dulu)', () {
    final a = mixedSparing15f().active;
    List<String> history(String id) => [
      for (final m in a.matches.reversed)
        if (m.pair1.contains(id) || m.pair2.contains(id))
          () {
            final own = m.pair1.contains(id) ? m.pair1 : m.pair2;
            final other = identical(own, m.pair1) ? m.pair2 : m.pair1;
            final set = m.sets.single;
            final (mine, theirs) = identical(own, m.pair1) ? (set.side1, set.side2) : (set.side2, set.side1);
            final partner = own.player1Id == id ? own.player2Id : own.player1Id;
            return 'R${m.roundNumber} ${a.playerName(id)} · ${a.playerName(partner)} $mine–$theirs ${pair(a, other)}';
          }(),
    ];
    expect(history('g01'), [
      'R8 Andi · Dewi 6–2 Maya · Nanda',
      'R6 Andi · Hadi 4–6 Joko · Lina',
      'R4 Andi · Dewi 6–3 Indra · Kiki',
      'R2 Andi · Budi 6–2 Lina · Kiki',
    ]);
    expect(history('m04'), [
      'R8 Lina · Indra 6–5 Budi · Hadi',
      'R7 Lina · Nanda 3–6 Fajar · Eko',
      'R6 Lina · Joko 6–4 Hadi · Andi',
      'R4 Lina · Nanda 6–4 Budi · Hadi',
      'R3 Lina · Maya 6–5 Citra · Gita',
      'R2 Lina · Kiki 2–6 Budi · Andi',
    ]);
  });

  test('15i: diakhiri saat R4, R4 tidak dimainkan, skor klub akhir 4 – 2', () {
    final s = mixedSparing15i();
    expect(s.active.tournament.isFinished, isTrue);
    expect({for (final m in s.active.matchesOfRound(4)) m.status}, {MatchStatus.cancelled});
    expect(clubScore(s.active), '4 – 2 · 32 – 27');
    expect(s.active.canResume(s.now), isTrue);
  });

  test('15l: Oki ditambah ke Matcha Club, belum main; Matcha 7 aktif', () {
    final s = mixedSparing15lOki();
    expect(s.active.config.players.last, mixedOki);
    expect(s.active.activePlayersOfClub(matcha.id).length, 7);
    expect(played(s.active, 'm07'), 0);
  });

  test(
    '15n: Oki telat, R4 Oki · Nanda dan Garuda sama dengan 15b; Prioritas R5 Citra, Eko, Fajar, Gita · Joko, Lina, Maya',
    () {
      final s = mixedSparing15n();
      expect(s.active.latePlayerIds, {'m07'});
      expect([for (final m in s.active.matchesOfRound(4)) pair(s.active, m.pair1)], ['Budi · Hadi', 'Andi · Dewi']);
      expect([for (final m in s.active.matchesOfRound(4)) pair(s.active, m.pair2)], contains('Oki · Nanda'));
      expect(s.active.activePlayers.length, 15);
      expect(resting(s), [
        [['Citra', 'Eko', 'Fajar', 'Gita'], <String>[]],
        [['Joko', 'Lina', 'Maya'], <String>[]],
      ]);
    },
  );

  test('15m: Kiki keluar, Matcha tinggal Indra dan Joko: Keluarkan mati di Matcha, Garuda tetap bisa', () {
    final s = mixedSparing15m();
    expect(names(s.active.activePlayersOfClub(matcha.id)), ['Indra', 'Joko']);
    expect(s.active.canWithdraw('m01'), isFalse);
    expect(s.active.canWithdraw('g01'), isTrue);
  });

  test('15o/15p AC-S13: Court 3 19.47 langsung main Gita · Fajar vs Maya · Joko; Prioritas R5 Citra, Eko · –', () {
    final b = mixedSparing15b();
    final court = b.active.newCourt(id: 'c3', name: '', colorIndex: 2, bookingMinutes: 120, now: b.now);
    final use = EndlessRoundGenerator.courtUse(b.active.withCourt(court), 'c3', b.now);
    expect(use.use, CourtUse.now);
    // Urut prioritas tiap klub (klub pertama dulu); kolom layar diurut daftar pemain.
    expect(names(use.players), ['Gita', 'Fajar', 'Maya', 'Joko']);

    final s = mixedSparing15p();
    final r4 = s.active.matchesOfRound(4);
    expect(r4.length, 3);
    expect((r4.last.courtId, r4.last.matchNumberInRound), ('c3', 3));
    expect(match(s.active, r4.last), 'Gita · Fajar vs Maya · Joko');
    expect(s.active.config.courts.last.name, 'Court 3');
    expect(s.active.remainingBookingMinutes(s.active.config.courts.last, s.now), 120);
    expect(resting(s), [
      [['Citra', 'Eko'], <String>[]],
      [<String>[], <String>[]],
    ]);
    expect(names([for (final id in s.active.restingPlayerIdsByRound[4]!) s.active.config.playerById(id)!])..sort(), [
      'Citra',
      'Eko',
    ]);
  });

  test('15r/15t K11: Americano 21, WO R3 Court 2 → 4 – 2, 59 – 58 (Matcha 46 + 12)', () {
    final r = mixedSparing15r();
    expect(round(r.active, 3), ['Fajar · Eko 12–9 Joko · Indra', 'Citra · Gita vs Lina · Maya']);
    expect(clubScore(r.active), '4 – 1 · 59 – 46');

    final t = mixedSparing15t();
    final wo = t.active.matchesOfRound(3).last;
    expect((wo.status, wo.winnerPairId), (MatchStatus.wo, wo.pair2.id));
    expect(clubScore(t.active), '4 – 2 · 59 – 58');
    final standings = {
      for (final s in RankingCalculator.rank(
        players: t.active.config.players,
        matches: t.active.matches,
        method: RankingMethod.totalGames,
        format: t.active.config.format,
      ))
        s.player.name: s.totalPoint,
    };
    expect((standings['Maya'], standings['Lina']), (24, 18));
  });

  test('15w: sparing bernama, Round 4, 4 – 2', () {
    final s = mixedSparing15w();
    expect(s.active.config.name, mixedSparingName);
    expect(s.active.roundCount, 4);
    expect(s.active.playedMatchCount, 6);
    expect(ClubResult.of(s.active)!.scoreLabel, '4 – 2');
    expect(round(s.active, 4), round(mixedSparing15b().active, 4));
  });
}
