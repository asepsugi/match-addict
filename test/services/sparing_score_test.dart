import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/club_score.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';

import 'sparing_score_fixture.dart';

String _row(StandingEntry e, {bool percent = false}) {
  final value = percent ? '${e.standing.winPercent.round()}%' : '${e.standing.totalPoint}';
  return '${e.position} ${e.label} $value ${e.standing.diffLabel}';
}

List<String> _table(ActiveTournament a, Club club, RankingMethod method) {
  final standings = RankingCalculator.rank(
    players: a.config.players,
    matches: a.matches,
    method: method,
    format: a.config.format,
  );
  final group = clubStandings(active: a, standings: standings, method: method).firstWhere((g) => g.club.id == club.id);
  return [for (final e in group.entries) _row(e, percent: method == RankingMethod.winPercent)];
}

void main() {
  group('Skor klub 13C (AC-S14)', () {
    test('akhir: 7 – 5, 56 – 49, +13 / −13, Garuda unggul', () {
      final s = ClubScore.of(fixedSparing(c13))!;
      expect(s.first.club.id, 'club-1');
      expect((s.first.halfWins, s.second.halfWins), (14, 10));
      expect((s.first.winsLabel, s.second.winsLabel), ('7', '5'));
      expect((s.first.totalPoint, s.second.totalPoint), (56, 49));
      expect((s.first.diffLabel, s.second.diffLabel), ('+13', '−13'));
      expect(s.lead, ClubLead.first);
      expect(s.unit, 'game');
    });

    test('setelah R5: 6 – 4, 45 – 43, +8 / −8', () {
      final s = ClubScore.of(fixedSparing(c13.sublist(0, 10)))!;
      expect((s.first.winsLabel, s.second.winsLabel), ('6', '4'));
      expect((s.first.totalPoint, s.second.totalPoint), (45, 43));
      expect((s.first.diffLabel, s.second.diffLabel), ('+8', '−8'));
    });

    test('match belum dimainkan dan dibatalkan tidak dihitung', () {
      final a = fixedSparing(c13.sublist(0, 3));
      final withCancelled = a.copyWith(
        tournament: a.tournament.copyWith(
          matches: [
            for (final m in a.matches)
              if (m.id == 'm3') m.copyWith(status: MatchStatus.cancelled) else m,
          ],
        ),
      );
      final s = ClubScore.of(withCancelled)!;
      expect((s.first.halfWins, s.second.halfWins), (2, 2));
      expect((s.first.totalPoint, s.second.totalPoint), (10, 9));
    });

    test('turnamen biasa: tanpa skor klub dan tanpa klasemen klub', () {
      final plain = ActiveTournament(
        tournament: Tournament(
          id: 'x',
          createdAt: DateTime(2026, 11, 8),
          config: TournamentConfig(
            sport: SportType.padel,
            mode: PartnerMode.mixed,
            matchDurationMinutes: 15,
            courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 60)],
            players: const [Player(id: 'a', name: 'A')],
          ),
        ),
      );
      expect(ClubScore.of(plain), isNull);
      expect(clubStandings(active: plain, standings: const [], method: RankingMethod.totalGames), isEmpty);
    });
  });

  group('Unggul dan Seri (AC-S16)', () {
    test('14s: 5 – 7, 56 – 60, −4 / +4, klub kedua unggul', () {
      final s = ClubScore.of(fixedSparing(s14s))!;
      expect((s.first.winsLabel, s.second.winsLabel), ('5', '7'));
      expect((s.first.totalPoint, s.second.totalPoint), (56, 60));
      expect((s.first.diffLabel, s.second.diffLabel), ('−4', '+4'));
      expect(s.lead, ClubLead.second);
    });

    test('14t: 6 – 6 dan 58 – 58 → Seri', () {
      final s = ClubScore.of(fixedSparing(s14t))!;
      expect((s.first.winsLabel, s.second.winsLabel), ('6', '6'));
      expect((s.first.totalPoint, s.second.totalPoint), (58, 58));
      expect(s.lead, ClubLead.draw);
    });

    test('14u Americano 20: 6½ – 5½, 122 – 118 poin, +4 / −4, Garuda unggul', () {
      final s = ClubScore.of(fixedSparing(s14u, format: const ScoreFormat(ScoringMethod.americano, 20)))!;
      expect((s.first.halfWins, s.second.halfWins), (13, 11));
      expect((s.first.winsLabel, s.second.winsLabel), ('6½', '5½'));
      expect((s.first.totalPoint, s.second.totalPoint), (122, 118));
      expect((s.first.diffLabel, s.second.diffLabel), ('+4', '−4'));
      expect(s.unit, 'poin');
      expect(s.lead, ClubLead.first);
    });

    test('menang sama, Total Point lebih besar unggul; semua sama → Seri', () {
      const a = ClubTally(club: garuda, halfWins: 12, totalPoint: 50, diff: 2);
      const b = ClubTally(club: matcha, halfWins: 12, totalPoint: 48, diff: -2);
      expect(const ClubScore(first: a, second: b, unit: 'game').lead, ClubLead.first);
      expect(const ClubScore(first: b, second: a, unit: 'game').lead, ClubLead.second);
      const c = ClubTally(club: matcha, halfWins: 12, totalPoint: 50, diff: 9);
      expect(const ClubScore(first: a, second: c, unit: 'game').lead, ClubLead.draw);
    });

    test('winsLabel: setengah poin ditulis ½, bukan ,5', () {
      String label(int h) => ClubTally(club: garuda, halfWins: h, totalPoint: 0, diff: 0).winsLabel;
      expect([label(0), label(1), label(2), label(13)], ['0', '½', '1', '6½']);
    });
  });

  group('Klasemen per klub (AC-S17)', () {
    final end = fixedSparing(c13);

    test('Total Point akhir 13o: nomor mulai #1 di tiap klub', () {
      expect(_table(end, garuda, RankingMethod.totalGames), [
        '1 Eko + Fajar 18 +11',
        '2 Andi + Budi 14 +1',
        '3 Gita + Hadi 14 −2',
        '4 Citra + Dewi 10 +3',
      ]);
      expect(_table(end, matcha, RankingMethod.totalGames), [
        '1 Maya + Nanda 23 +4',
        '2 Kiki + Lina 16 −3',
        '3 Indra + Joko 10 −14',
      ]);
    });

    test('Win % akhir 13p', () {
      expect(_table(end, garuda, RankingMethod.winPercent), [
        '1 Eko + Fajar 100% +11',
        '2 Andi + Budi 67% +1',
        '3 Citra + Dewi 33% +3',
        '4 Gita + Hadi 33% −2',
      ]);
      expect(_table(end, matcha, RankingMethod.winPercent), [
        '1 Maya + Nanda 75% +4',
        '2 Kiki + Lina 50% −3',
        '3 Indra + Joko 0% −14',
      ]);
    });

    test('setelah R5 (13n)', () {
      final r5 = fixedSparing(c13.sublist(0, 10));
      expect(_table(r5, garuda, RankingMethod.totalGames), [
        '1 Andi + Budi 14 +1',
        '2 Eko + Fajar 12 +5',
        '3 Citra + Dewi 10 +3',
        '4 Gita + Hadi 9 −1',
      ]);
      expect(_table(r5, matcha, RankingMethod.totalGames), [
        '1 Maya + Nanda 17 +3',
        '2 Kiki + Lina 16 +3',
        '3 Indra + Joko 10 −14',
      ]);
    });

    test('14s dan 14u (Americano)', () {
      final s = fixedSparing(s14s);
      expect(_table(s, matcha, RankingMethod.totalGames), [
        '1 Kiki + Lina 24 +9',
        '2 Indra + Joko 19 −3',
        '3 Maya + Nanda 17 −2',
      ]);
      expect(_table(s, garuda, RankingMethod.totalGames), [
        '1 Eko + Fajar 17 +4',
        '2 Citra + Dewi 15 +2',
        '3 Andi + Budi 15 −1',
        '4 Gita + Hadi 9 −9',
      ]);
      final u = fixedSparing(s14u, format: const ScoreFormat(ScoringMethod.americano, 20));
      expect(
        [
          for (final e in clubStandings(
            active: u,
            standings: RankingCalculator.rank(
              players: u.config.players,
              matches: u.matches,
              method: RankingMethod.totalGames,
              format: u.config.format,
            ),
            method: RankingMethod.totalGames,
          )[0].entries)
            e.standing.totalPoint,
        ],
        [38, 32, 29, 23],
      );
    });

    test('pasangan yang belum main ada di tabel klubnya tanpa nomor (14p)', () {
      final one = fixedSparing(c13.sublist(0, 1));
      final rows = _table(one, garuda, RankingMethod.totalGames);
      expect(rows.first, '1 Andi + Budi 6 +3');
      expect(rows.skip(1).every((r) => r.startsWith('null ')), isTrue);
      expect(rows, hasLength(4));
    });
  });

  group('Skor klub berjalan (AC-S15, 14h)', () {
    test('setelah R1–R2 + R3 Court 1: 4 – 1, 28 – 22, +6 / −6', () {
      final s = ClubScore.of(fixedSparing(c13.sublist(0, 5)))!;
      expect((s.first.winsLabel, s.second.winsLabel), ('4', '1'));
      expect((s.first.totalPoint, s.second.totalPoint), (28, 22));
      expect((s.first.diffLabel, s.second.diffLabel), ('+6', '−6'));
    });

    test('WO G2 di R3 Court 2: Matcha +1 menang dan +6 poin, selisih tetap', () {
      final before = fixedSparing(c13.sublist(0, 5));
      final after = fixedSparing(c13.sublist(0, 6));
      final s = ClubScore.of(after)!;
      expect((s.first.winsLabel, s.second.winsLabel), ('4', '2'));
      expect((s.first.totalPoint, s.second.totalPoint), (28, 28));
      expect((s.first.diffLabel, s.second.diffLabel), ('+6', '−6'));

      int mayaNanda(ActiveTournament a) => RankingCalculator.rank(
        players: a.config.players,
        matches: a.matches,
        method: RankingMethod.totalGames,
        format: a.config.format,
      ).firstWhere((p) => p.player.id == 'p-maya').totalPoint;
      expect(mayaNanda(after) - mayaNanda(before), 6);
    });
  });

  group('Status Sementara / Final (AC-S14)', () {
    final now = DateTime(2026, 11, 8, 20);

    test('12 dari 12 match → Final; 10 dari 12 → Sementara', () {
      expect(fixedSparing(c13).isFinal(now), isTrue);
      expect(fixedSparing(c13.sublist(0, 10)).isFinal(now), isFalse);
    });
  });

  test('match satu klub (bug pasangan) membuat debug/test gagal, bukan skor salah diam-diam', () {
    final a = fixedSparing(c13.sublist(0, 1));
    final bad = a.copyWith(
      tournament: a.tournament.copyWith(
        matches: [
          MatchGame(
            id: 'x',
            roundNumber: 1,
            matchNumberInRound: 1,
            courtId: 'c1',
            pair1: clubPairs['G1']!,
            pair2: clubPairs['G2']!,
            sets: const [SetScore(side1: 6, side2: 1)],
            status: MatchStatus.done,
          ),
        ],
      ),
    );
    expect(() => ClubScore.of(bad), throwsA(isA<AssertionError>()));
  });

  group('Nilai WO klub Mixed (K11, AC-S15a)', () {
    const americano21 = ScoreFormat(ScoringMethod.americano, 21);

    /// Dua pemenang WO bermain satu match dulu supaya rata-rata skor mereka = [va] dan [vb] (nilai WO 4.4).
    /// [secondWins]: pemenang dari klub kedua (Matcha, lina + maya), kalau tidak klub pertama (andi + budi).
    ActiveTournament mixed({required bool secondWins, required int va, required int vb}) {
      final players = [
        for (final n in ['andi', 'budi', 'citra', 'dewi']) Player(id: n, name: n, clubId: garuda.id),
        for (final n in ['lina', 'maya', 'oki', 'putri']) Player(id: n, name: n, clubId: matcha.id),
      ];
      final own = secondWins ? ['lina', 'maya', 'oki', 'putri'] : ['andi', 'budi', 'citra', 'dewi'];
      final other = secondWins ? ['andi', 'budi'] : ['lina', 'maya'];
      Pair pair(String id, String a, String b) => Pair(id: id, player1Id: a, player2Id: b);
      final opponents = pair('x0', other[0], other[1]);
      final winners = pair('x3', own[0], own[1]);
      MatchGame match(int n, Pair a, Pair b) =>
          MatchGame(id: 'm$n', roundNumber: n, matchNumberInRound: 1, courtId: 'c1', pair1: a, pair2: b);
      return ActiveTournament(
        tournament: Tournament(
          id: 'mixed',
          createdAt: DateTime(2026, 11, 8, 19),
          config: TournamentConfig(
            sport: SportType.padel,
            mode: PartnerMode.mixed,
            matchDurationMinutes: 15,
            courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120)],
            players: players,
            format: americano21,
            clubs: const [garuda, matcha],
          ),
          matches: [
            match(1, pair('x1', own[0], own[2]), opponents).withScore([SetScore(side1: va, side2: 3)]),
            match(2, pair('x2', own[1], own[3]), opponents).withScore([SetScore(side1: vb, side2: 3)]),
            // Pasangan lawan WO; klub pemenang selalu di sisi yang sesuai urutan klub.
            if (secondWins)
              match(3, opponents, winners).asWalkover(loserPairId: opponents.id)
            else
              match(3, winners, opponents).asWalkover(loserPairId: opponents.id),
          ],
        ),
      );
    }

    List<PlayerStanding> rank(ActiveTournament a) => RankingCalculator.rank(
      players: a.config.players,
      matches: a.matches,
      method: RankingMethod.totalGames,
      format: a.config.format,
    );

    test('Andi 14 + Budi 17 → klub (14 + 17 + 1) ÷ 2 = 16; pemain tetap 14 / 17, selisih tidak berubah', () {
      final a = mixed(secondWins: false, va: 14, vb: 17);
      final values = RankingCalculator.woWinnerValues(
        players: a.config.players,
        matches: a.matches,
        format: a.config.format,
      );
      expect((values['andi'], values['budi']), (14, 17));

      final s = ClubScore.of(a)!;
      expect(s.first.totalPoint, 14 + 17 + 16);
      expect(s.first.diff, (14 - 3) + (17 - 3));
      expect((s.first.halfWins, s.second.halfWins), (6, 0));

      // Klasemen pemain: tiap pemenang dapat nilainya sendiri (AC-S15a).
      final andi = rank(a).firstWhere((p) => p.player.id == 'andi');
      final budi = rank(a).firstWhere((p) => p.player.id == 'budi');
      expect((andi.totalPoint, budi.totalPoint), (14 + 14, 17 + 17));
      expect((andi.gameDiff, budi.gameDiff), (14 - 3, 17 - 3));
    });

    test('15r/15t: Lina rata-rata 7 → batas minimal 11, Maya 12 → klub +12; Lina 18, Maya 24', () {
      final a = mixed(secondWins: true, va: 7, vb: 12);
      final lina = rank(a).firstWhere((p) => p.player.id == 'lina');
      final maya = rank(a).firstWhere((p) => p.player.id == 'maya');
      expect((lina.totalPoint, maya.totalPoint), (7 + 11, 12 + 12));

      // (11 + 12 + 1) ÷ 2 = 12, klub kedua; selisih klub tidak berubah oleh WO.
      final s = ClubScore.of(a)!;
      expect(s.second.totalPoint, 7 + 12 + 12);
      expect(s.second.diff, (7 - 3) + (12 - 3));
      expect((s.first.halfWins, s.second.halfWins), (0, 6));
    });
  });
}
