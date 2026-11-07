// T2: contoh PRD 13A, 13C, 13B lewat prototipe + kalkulator yang ada. Mencetak angka supaya bisa dibandingkan.
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:sparing_proto/sparing_fixed.dart';
import 'package:sparing_proto/sparing_mixed.dart';

final garudaNames = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'];
final matchaNames = ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda'];
List<Player> playersOf(String club, List<String> names) => [
  for (final (i, n) in names.indexed) Player(id: '$club${(i + 1).toString().padLeft(2, '0')}', name: n),
];
final garuda = playersOf('g', garudaNames);
final matcha = playersOf('m', matchaNames);

List<Pair> pairsOf(String tag, List<Player> ps) => [
  for (var i = 0; i < ps.length ~/ 2; i++)
    Pair(id: '$tag${i + 1}', player1Id: ps[2 * i].id, player2Id: ps[2 * i + 1].id),
];
final g = pairsOf('G', garuda);
final mp = pairsOf('M', matcha);

List<Court> courtsOf(int n, [int minutes = 120]) => [
  for (var i = 1; i <= n; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: minutes),
];

/// Skor klub (13.5): menang 1, seri ½, WO = menang lawan; Total Point = game sisi klub + nilai WO; selisih tanpa WO.
({double w1, double w2, int tp1, int tp2, int d1}) clubScore(
  List<MatchGame> ms,
  ScoreFormat f,
  Map<String, int> woValue,
) {
  var w1 = 0.0, w2 = 0.0;
  var tp1 = 0, tp2 = 0, d1 = 0;
  for (final m in ms) {
    if (m.status == MatchStatus.done) {
      final a = m.pair1TotalGames, b = m.pair2TotalGames;
      tp1 += a;
      tp2 += b;
      d1 += a - b;
      if (a > b) w1 += 1;
      if (b > a) w2 += 1;
      if (a == b) {
        w1 += .5;
        w2 += .5;
      }
    } else if (m.status == MatchStatus.wo) {
      final winner = m.winnerPairId!;
      if (winner == m.pair1.id) {
        w1 += 1;
        tp1 += woValue[winner]!;
      } else {
        w2 += 1;
        tp2 += woValue[winner]!;
      }
    }
  }
  return (w1: w1, w2: w2, tp1: tp1, tp2: tp2, d1: d1);
}

String pairLabel(Pair p, List<Player> all) =>
    p.playerIds.map((id) => all.firstWhere((x) => x.id == id).name).join(' · ');

void main() {
  final all = [...garuda, ...matcha];

  test('13A jadwal Fixed 4/3 pasangan, 2 court', () {
    final s = SparingFixedGenerator.generate(club1: g, club2: mp, courts: courtsOf(2));
    expect(s.roundCount, 6);
    final cG = {for (final p in g) p.id: 0}, cM = {for (final p in mp) p.id: 0};
    for (var r = 1; r <= s.roundCount; r++) {
      final ms = s.matches.where((m) => m.roundNumber == r).toList();
      for (final m in ms) {
        cG[m.pair1.id] = cG[m.pair1.id]! + 1;
        cM[m.pair2.id] = cM[m.pair2.id]! + 1;
      }
      // ignore: avoid_print
      print(
        'R$r | ${ms.map((m) => '${m.pair1.id} vs ${m.pair2.id}').join(' | ')} | istirahat '
        '${s.restingPairIdsByRound[r]!.join(', ')} | G ${cG.values.join('·')} | M ${cM.values.join('·')}',
      );
    }
    // Round tambahan setelah R6, sisa 30 menit = 2 round di kedua court.
    final ext = SparingFixedGenerator.extend(
      club1: g,
      club2: mp,
      courts: courtsOf(2),
      roundsLeft: [2, 2],
      unitsDone: 0,
      firstRound: 7,
    );
    // ignore: avoid_print
    print('13A tambah: ${ext.units} satuan, ${ext.schedule.matches.length} match, R7–R${ext.schedule.roundCount}, '
        'lewat booking ${(ext.schedule.roundCount - 6 - 2) * 15} menit');
    expect(ext.schedule.matches.length, 12);
    expect(ext.schedule.roundCount, 12);
    // 4/2 pasangan dan 3/3.
    final e42 = SparingFixedGenerator.extend(
      club1: g,
      club2: mp.take(2).toList(),
      courts: courtsOf(3),
      roundsLeft: [1, 1, 1],
      unitsDone: 0,
      firstRound: 5,
    );
    expect(e42.schedule.matches.length, 4);
    final e33 = SparingFixedGenerator.extend(
      club1: g.take(3).toList(),
      club2: mp,
      courts: courtsOf(2),
      roundsLeft: [1, 1],
      unitsDone: 0,
      firstRound: 6,
    );
    expect(e33.schedule.matches.length, 3);
    // Tabel ukuran lain 13.3.
    for (final (p1, p2, c, matches, rounds) in [
      (4, 3, 2, 12, 6),
      (3, 3, 2, 9, 5),
      (4, 2, 3, 8, 4),
      (2, 2, 1, 4, 4),
      (8, 7, 4, 56, 14),
      (14, 1, 2, 14, 14),
    ]) {
      final x = SparingFixedGenerator.generate(
        club1: [for (var i = 0; i < p1; i++) Pair(id: 'a$i', player1Id: 'a${i}x', player2Id: 'a${i}y')],
        club2: [for (var i = 0; i < p2; i++) Pair(id: 'b$i', player1Id: 'b${i}x', player2Id: 'b${i}y')],
        courts: courtsOf(c),
      );
      expect((x.matches.length, x.roundCount), (matches, rounds), reason: '$p1/$p2 c$c');
      if (p1 == 4 && p2 == 2) {
        // ignore: avoid_print
        print('8/4 c3: ${[for (var r = 1; r <= 4; r++) 'R$r ${x.matches.where((m) => m.roundNumber == r).map((m) => '${m.pair1.id}-${m.pair2.id}@${m.courtId}').join(', ')}'].join(' · ')}');
      }
    }
  });

  test('13C skor klub + klasemen per klub (skor PRD dipetakan per lawan ke jadwal generator)', () {
    final s = SparingFixedGenerator.generate(club1: g, club2: mp, courts: courtsOf(2));
    // Skor 13C per lawan (Garuda–Matcha). null = WO, Citra · Dewi (G2) absen.
    final scores = <String, (int, int)?>{
      'G1-M1': (6, 3), 'G2-M2': (4, 6), 'G3-M1': (6, 2), 'G4-M3': (5, 6), 'G1-M2': (6, 4), 'G3-M3': (6, 5),
      'G2-M1': (6, 1), 'G4-M2': (3, 6), 'G1-M3': (2, 6), 'G4-M1': (6, 4), 'G2-M3': null, 'G3-M2': (6, 0),
    };
    final played = [
      for (final m in s.matches)
        switch (scores['${m.pair1.id}-${m.pair2.id}']) {
          final (int, int) sc => m.withScore([SetScore(side1: sc.$1, side2: sc.$2)]),
          null => m.asWalkover(loserPairId: m.pair1.id, reason: WoReason.absent),
        },
    ];
    for (var r = 1; r <= 6; r++) {
      // ignore: avoid_print
      print('13C R$r: ${played.where((m) => m.roundNumber == r).map((m) => m.status == MatchStatus.wo ? '${m.pair1.id} WO→${m.pair2.id}' : '${m.pair1.id} ${m.pair1TotalGames}–${m.pair2TotalGames} ${m.pair2.id}').join(' | ')}');
    }
    const f = ScoreFormat(ScoringMethod.raceTo, 6);
    final cs = clubScore(played, f, {'M3': f.woWinnerScore(null)});
    // ignore: avoid_print
    print('13C klub ${cs.w1}–${cs.w2}, TP ${cs.tp1}–${cs.tp2}, selisih ${cs.d1}');
    expect((cs.w1, cs.w2, cs.tp1, cs.tp2, cs.d1), (7.0, 5.0, 56, 49, 13));
    final beforeR6 = clubScore(played.where((m) => m.roundNumber < 6).toList(), f, {'M3': 6});
    // ignore: avoid_print
    print('13C sebelum R6: ${beforeR6.w1}–${beforeR6.w2}');

    for (final method in RankingMethod.values) {
      final st = RankingCalculator.rank(players: all, matches: played, method: method, format: f);
      // Total Point klub = jumlah Total Point pasangan (satu anggota per pasangan) — harus sama dengan per match.
      for (final (club, pairs) in [('Garuda', g), ('Matcha', mp)]) {
        final ids = {for (final p in pairs) ...p.playerIds};
        final rows = standingEntries(
          standings: st.where((x) => ids.contains(x.player.id)).toList(),
          method: method,
          fixedPairs: pairs,
        );
        // ignore: avoid_print
        print('${method.label} $club: ${rows.map((e) => '#${e.position} ${e.players.map((p) => p.name).join(' · ')} '
            '${method == RankingMethod.totalGames ? e.standing.totalPoint : '${e.standing.winPercent.round()}%'} (${e.standing.diffLabel}) '
            'W${e.standing.wins}/${e.standing.matchesPlayed}').join(' · ')}');
        if (method == RankingMethod.totalGames) {
          final sum = rows.fold(0, (t, e) => t + e.standing.totalPoint);
          // ignore: avoid_print
          print('  Σ Total Point pasangan $club = $sum; Σ semua pemain = ${st.where((x) => ids.contains(x.player.id)).fold(0, (t, x) => t + x.totalPoint)}');
        }
      }
    }
    // Seri Americano 20: satu 10–10, enam menang Garuda, lima menang Matcha.
    const am = ScoreFormat(ScoringMethod.americano, 20);
    final drawn = [
      for (final (i, m) in s.matches.indexed)
        m.withScore([
          i == 0
              ? const SetScore(side1: 10, side2: 10)
              : i <= 6
              ? const SetScore(side1: 12, side2: 8)
              : const SetScore(side1: 8, side2: 12),
        ]),
    ];
    final ds = clubScore(drawn, am, {});
    expect((ds.w1, ds.w2), (6.5, 5.5));
  });

  group('13B Mixed 8/6, 2 court × 2 jam, 15 menit', () {
    const seed = 0x5eed;
    List<MatchGame> run(int rounds, {List<Player>? c1, List<Player>? c2, int courts = 2, Random? rng, List<MatchGame>? start, int from = 1}) {
      final h = [...?start];
      final r = rng ?? Random(1);
      for (var n = from; n < from + rounds; n++) {
        final round = SparingMixed.generateRound(
          club1: c1 ?? garuda,
          club2: c2 ?? matcha,
          courts: courtsOf(courts),
          history: h,
          roundNumber: n,
          seed: seed,
          random: r,
        )!;
        h.addAll(round.matches);
      }
      return h;
    }

    Map<String, int> counts(List<MatchGame> h, List<Player> ps) => {
      for (final p in ps) p.name: h.where((m) => m.pair1.contains(p.id) || m.pair2.contains(p.id)).length,
    };

    test('jumlah main R6/R8, court aktif, pasangan sesama klub', () {
      expect(SparingMixed.activeCourts(2, 8, 6), 2);
      final h = run(8);
      for (final m in h) {
        expect(m.pair1.playerIds.every((id) => id.startsWith('g')), isTrue);
        expect(m.pair2.playerIds.every((id) => id.startsWith('m')), isTrue);
      }
      final r6 = h.where((m) => m.roundNumber <= 6).toList();
      // ignore: avoid_print
      print('13B R6: ${counts(r6, garuda)} ${counts(r6, matcha)}');
      // ignore: avoid_print
      print('13B R8: ${counts(h, garuda)} ${counts(h, matcha)}');
      expect(counts(r6, garuda).values.toSet(), {3});
      expect(counts(r6, matcha).values.toSet(), {4});
      expect(counts(h, garuda).values.toSet(), {4});
      final m8 = counts(h, matcha).values.toList()..sort();
      expect(m8, [5, 5, 5, 5, 6, 6]);
    });

    test('Kelola court: Court 3 saat R4 berjalan', () {
      final h = run(4);
      final use = SparingMixed.courtUseNow(club1: garuda, club2: matcha, history: h, n: 4, seed: seed, nextCourts: 3)!;
      // ignore: avoid_print
      print('13B Court 3 di R4: ${use.$1.map((p) => p.name)} vs ${use.$2.map((p) => p.name)}');
      final arr = SparingMixed.bestArrangement(use.$1, use.$2, h, Random(2)).single;
      h.add(MatchGame(id: 'm-r4-3', roundNumber: 4, matchNumberInRound: 3, courtId: 'c3', pair1: arr.$1, pair2: arr.$2));
      final h5 = run(1, courts: 3, start: h, from: 5);
      final r5 = h5.where((m) => m.roundNumber == 5).toList();
      final matchaInR5 = {for (final m in r5) ...m.pair2.playerIds};
      // ignore: avoid_print
      print('13B R5: ${r5.length} match, Matcha main ${matchaInR5.length}; setelah R5 ${counts(h5, garuda)} ${counts(h5, matcha)}');
      expect(r5.length, 3);
      expect(matchaInR5.length, 6);
    });

    test('Pemain telat: Oki masuk Matcha setelah R3', () {
      final h = run(3);
      const oki = Player(id: 'm07', name: 'Oki');
      final matcha7 = [...matcha, oki];
      final r = Random(3);
      for (var n = 4; n <= 8; n++) {
        final round = SparingMixed.generateRound(
          club1: garuda,
          club2: matcha7,
          courts: courtsOf(2),
          history: h,
          roundNumber: n,
          seed: seed,
          late: {oki.id},
          random: r,
        )!;
        h.addAll(round.matches);
        final okiPlays = round.matches.any((m) => m.pair2.contains(oki.id));
        // ignore: avoid_print
        print('13B Oki R$n: ${okiPlays ? 'main' : 'istirahat'} · Matcha ${counts(h, matcha7)} · Garuda ${counts(h, garuda).values.toSet()}');
      }
    });

    test('Nanda keluar setelah R3', () {
      final h = run(3);
      final matcha5 = matcha.where((p) => p.name != 'Nanda').toList();
      expect(SparingMixed.activeCourts(2, 8, 5), 2);
      final h2 = run(5, c2: matcha5, start: h, from: 4);
      final playing = {for (final m in h2.where((m) => m.roundNumber == 4)) ...m.pair2.playerIds};
      expect(playing.length, 4);
      // ignore: avoid_print
      print('13B Nanda keluar: setelah R8 Matcha ${counts(h2, matcha)}');
    });
  });
}
