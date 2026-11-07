import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/club_score.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

/// Skor klub + klasemen per klub (logic.md §13.7, §13.8, data §13.11): jadwal Fixed 13A, 8 / 6 pemain.
const _garuda = Club(id: 'club-1', name: 'PB Garuda');
const _matcha = Club(id: 'club-2', name: 'Matcha Club');

Player _p(String name, Club club) => Player(id: 'p-${name.toLowerCase()}', name: name, clubId: club.id);

final _players = [
  for (final n in ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi']) _p(n, _garuda),
  for (final n in ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda']) _p(n, _matcha),
];

Pair _pair(String id, String a, String b) => Pair(id: id, player1Id: 'p-$a', player2Id: 'p-$b');

final _pairs = {
  'G1': _pair('G1', 'andi', 'budi'),
  'G2': _pair('G2', 'citra', 'dewi'),
  'G3': _pair('G3', 'eko', 'fajar'),
  'G4': _pair('G4', 'gita', 'hadi'),
  'M1': _pair('M1', 'indra', 'joko'),
  'M2': _pair('M2', 'kiki', 'lina'),
  'M3': _pair('M3', 'maya', 'nanda'),
};

/// Urutan R1 Court 1, R1 Court 2, R2 Court 1, … = urutan skor di logic.md §13.11.
const _layout = [
  ('G1', 'M1'), ('G2', 'M2'), //
  ('G3', 'M3'), ('G4', 'M1'),
  ('G1', 'M2'), ('G2', 'M3'),
  ('G3', 'M1'), ('G4', 'M2'),
  ('G1', 'M3'), ('G2', 'M1'),
  ('G3', 'M2'), ('G4', 'M3'),
];

TournamentConfig _config(ScoreFormat format) => TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.fixed,
  matchDurationMinutes: 15,
  courts: const [
    Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
    Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
  ],
  players: _players,
  fixedPairs: _pairs.values.toList(),
  format: format,
  clubs: const [_garuda, _matcha],
);

/// [scores] satu per match urut `_layout`; null = WO (pasangan pertama absen, seperti G2 di R3 13C). Match setelah
/// akhir daftar belum dimainkan.
ActiveTournament _fixed(List<(int, int)?> scores, {ScoreFormat format = ScoreFormat.standard, bool finished = false}) {
  final matches = <MatchGame>[];
  for (var i = 0; i < _layout.length; i++) {
    final (a, b) = _layout[i];
    final base = MatchGame(
      id: 'm${i + 1}',
      roundNumber: i ~/ 2 + 1,
      matchNumberInRound: i % 2 + 1,
      courtId: i.isEven ? 'c1' : 'c2',
      pair1: _pairs[a]!,
      pair2: _pairs[b]!,
    );
    if (i >= scores.length) {
      matches.add(base);
    } else if (scores[i] == null) {
      matches.add(base.asWalkover(loserPairId: _pairs[a]!.id));
    } else {
      matches.add(base.withScore([SetScore(side1: scores[i]!.$1, side2: scores[i]!.$2)]));
    }
  }
  return ActiveTournament(
    tournament: Tournament(
      id: 't',
      createdAt: DateTime(2026, 11, 8, 19),
      config: _config(format),
      matches: matches,
      isFinished: finished,
    ),
  );
}

const _c13 = <(int, int)?>[
  (6, 3),
  (4, 6),
  (6, 5),
  (6, 4),
  (6, 4),
  null,
  (6, 2),
  (3, 6),
  (2, 6),
  (6, 1),
  (6, 0),
  (5, 6), //
];
const _s14s = <(int, int)?>[
  (6, 4),
  (3, 6),
  (6, 2),
  (4, 6),
  (5, 6),
  (6, 3),
  (6, 5),
  (2, 6),
  (4, 6),
  (6, 4),
  (5, 6),
  (3, 6), //
];
const _s14t = <(int, int)?>[
  (6, 4),
  (6, 5),
  (3, 6),
  (6, 2),
  (5, 6),
  (2, 6),
  (6, 3),
  (4, 6),
  (6, 4),
  (3, 6),
  (6, 4),
  (5, 6), //
];
const _s14u = <(int, int)?>[
  (12, 8),
  (9, 11),
  (13, 7),
  (10, 10),
  (11, 9),
  (8, 12),
  (14, 6),
  (7, 13),
  (9, 11),
  (12, 8),
  (11, 9),
  (6, 14), //
];

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
      final s = ClubScore.of(_fixed(_c13))!;
      expect(s.first.club.id, 'club-1');
      expect((s.first.halfWins, s.second.halfWins), (14, 10));
      expect((s.first.winsLabel, s.second.winsLabel), ('7', '5'));
      expect((s.first.totalPoint, s.second.totalPoint), (56, 49));
      expect((s.first.diffLabel, s.second.diffLabel), ('+13', '−13'));
      expect(s.lead, ClubLead.first);
      expect(s.unit, 'game');
    });

    test('setelah R5: 6 – 4, 45 – 43, +8 / −8', () {
      final s = ClubScore.of(_fixed(_c13.sublist(0, 10)))!;
      expect((s.first.winsLabel, s.second.winsLabel), ('6', '4'));
      expect((s.first.totalPoint, s.second.totalPoint), (45, 43));
      expect((s.first.diffLabel, s.second.diffLabel), ('+8', '−8'));
    });

    test('match belum dimainkan dan dibatalkan tidak dihitung', () {
      final a = _fixed(_c13.sublist(0, 3));
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
      final s = ClubScore.of(_fixed(_s14s))!;
      expect((s.first.winsLabel, s.second.winsLabel), ('5', '7'));
      expect((s.first.totalPoint, s.second.totalPoint), (56, 60));
      expect((s.first.diffLabel, s.second.diffLabel), ('−4', '+4'));
      expect(s.lead, ClubLead.second);
    });

    test('14t: 6 – 6 dan 58 – 58 → Seri', () {
      final s = ClubScore.of(_fixed(_s14t))!;
      expect((s.first.winsLabel, s.second.winsLabel), ('6', '6'));
      expect((s.first.totalPoint, s.second.totalPoint), (58, 58));
      expect(s.lead, ClubLead.draw);
    });

    test('14u Americano 20: 6½ – 5½, 122 – 118 poin, +4 / −4, Garuda unggul', () {
      final s = ClubScore.of(_fixed(_s14u, format: const ScoreFormat(ScoringMethod.americano, 20)))!;
      expect((s.first.halfWins, s.second.halfWins), (13, 11));
      expect((s.first.winsLabel, s.second.winsLabel), ('6½', '5½'));
      expect((s.first.totalPoint, s.second.totalPoint), (122, 118));
      expect((s.first.diffLabel, s.second.diffLabel), ('+4', '−4'));
      expect(s.unit, 'poin');
      expect(s.lead, ClubLead.first);
    });

    test('menang sama, Total Point lebih besar unggul; semua sama → Seri', () {
      const a = ClubTally(club: _garuda, halfWins: 12, totalPoint: 50, diff: 2);
      const b = ClubTally(club: _matcha, halfWins: 12, totalPoint: 48, diff: -2);
      expect(const ClubScore(first: a, second: b, unit: 'game').lead, ClubLead.first);
      expect(const ClubScore(first: b, second: a, unit: 'game').lead, ClubLead.second);
      const c = ClubTally(club: _matcha, halfWins: 12, totalPoint: 50, diff: 9);
      expect(const ClubScore(first: a, second: c, unit: 'game').lead, ClubLead.draw);
    });

    test('winsLabel: setengah poin ditulis ½, bukan ,5', () {
      String label(int h) => ClubTally(club: _garuda, halfWins: h, totalPoint: 0, diff: 0).winsLabel;
      expect([label(0), label(1), label(2), label(13)], ['0', '½', '1', '6½']);
    });
  });

  group('Klasemen per klub (AC-S17)', () {
    final end = _fixed(_c13);

    test('Total Point akhir 13o: nomor mulai #1 di tiap klub', () {
      expect(_table(end, _garuda, RankingMethod.totalGames), [
        '1 Eko + Fajar 18 +11',
        '2 Andi + Budi 14 +1',
        '3 Gita + Hadi 14 −2',
        '4 Citra + Dewi 10 +3',
      ]);
      expect(_table(end, _matcha, RankingMethod.totalGames), [
        '1 Maya + Nanda 23 +4',
        '2 Kiki + Lina 16 −3',
        '3 Indra + Joko 10 −14',
      ]);
    });

    test('Win % akhir 13p', () {
      expect(_table(end, _garuda, RankingMethod.winPercent), [
        '1 Eko + Fajar 100% +11',
        '2 Andi + Budi 67% +1',
        '3 Citra + Dewi 33% +3',
        '4 Gita + Hadi 33% −2',
      ]);
      expect(_table(end, _matcha, RankingMethod.winPercent), [
        '1 Maya + Nanda 75% +4',
        '2 Kiki + Lina 50% −3',
        '3 Indra + Joko 0% −14',
      ]);
    });

    test('setelah R5 (13n)', () {
      final r5 = _fixed(_c13.sublist(0, 10));
      expect(_table(r5, _garuda, RankingMethod.totalGames), [
        '1 Andi + Budi 14 +1',
        '2 Eko + Fajar 12 +5',
        '3 Citra + Dewi 10 +3',
        '4 Gita + Hadi 9 −1',
      ]);
      expect(_table(r5, _matcha, RankingMethod.totalGames), [
        '1 Maya + Nanda 17 +3',
        '2 Kiki + Lina 16 +3',
        '3 Indra + Joko 10 −14',
      ]);
    });

    test('14s dan 14u (Americano)', () {
      final s = _fixed(_s14s);
      expect(_table(s, _matcha, RankingMethod.totalGames), [
        '1 Kiki + Lina 24 +9',
        '2 Indra + Joko 19 −3',
        '3 Maya + Nanda 17 −2',
      ]);
      expect(_table(s, _garuda, RankingMethod.totalGames), [
        '1 Eko + Fajar 17 +4',
        '2 Citra + Dewi 15 +2',
        '3 Andi + Budi 15 −1',
        '4 Gita + Hadi 9 −9',
      ]);
      final u = _fixed(_s14u, format: const ScoreFormat(ScoringMethod.americano, 20));
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
      final one = _fixed(_c13.sublist(0, 1));
      final garuda = _table(one, _garuda, RankingMethod.totalGames);
      expect(garuda.first, '1 Andi + Budi 6 +3');
      expect(garuda.skip(1).every((r) => r.startsWith('null ')), isTrue);
      expect(garuda, hasLength(4));
    });
  });

  group('Nilai WO klub Mixed (K11, AC-S15a)', () {
    const americano21 = ScoreFormat(ScoringMethod.americano, 21);

    /// Dua pemenang WO bermain satu match dulu supaya rata-rata skor mereka = nilai WO masing-masing.
    ActiveTournament mixed(int winnerA, int winnerB) {
      final players = [
        Player(id: 'a', name: 'Andi', clubId: _garuda.id),
        Player(id: 'b', name: 'Budi', clubId: _garuda.id),
        Player(id: 'c', name: 'Citra', clubId: _garuda.id),
        Player(id: 'd', name: 'Dewi', clubId: _garuda.id),
        Player(id: 'm', name: 'Maya', clubId: _matcha.id),
        Player(id: 'n', name: 'Nanda', clubId: _matcha.id),
        Player(id: 'o', name: 'Oki', clubId: _matcha.id),
        Player(id: 'q', name: 'Putri', clubId: _matcha.id),
      ];
      Pair pair(String id, String a, String b) => Pair(id: id, player1Id: a, player2Id: b);
      MatchGame match(int n, Pair a, Pair b) =>
          MatchGame(id: 'm$n', roundNumber: n, matchNumberInRound: 1, courtId: 'c1', pair1: a, pair2: b);
      final wo = pair('x5', 'm', 'n');
      final winners = pair('x3', 'a', 'b');
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
            clubs: const [_garuda, _matcha],
          ),
          matches: [
            // Andi main 1 match dengan skor winnerA, Budi dengan skor winnerB; lawan mendapat sisanya.
            match(1, pair('x1', 'a', 'c'), pair('x2', 'o', 'q')).withScore([SetScore(side1: winnerA, side2: 3)]),
            match(2, pair('x4', 'b', 'd'), pair('x6', 'o', 'q')).withScore([SetScore(side1: winnerB, side2: 3)]),
            match(3, winners, wo).asWalkover(loserPairId: wo.id),
          ],
        ),
      );
    }

    test('Andi 14 + Budi 17 → (14 + 17 + 1) ÷ 2 = 16 ke klub; pemain tetap 14 / 17', () {
      final a = mixed(14, 17);
      final values = RankingCalculator.woWinnerValues(
        players: a.config.players,
        matches: a.matches,
        format: a.config.format,
      );
      expect((values['a'], values['b']), (14, 17));
      final s = ClubScore.of(a)!;
      // Garuda: 14 + 17 dari dua match + 16 WO. Selisih tidak berubah oleh WO.
      expect(s.first.totalPoint, 14 + 17 + 16);
      expect(s.first.diff, (14 - 3) + (17 - 3));
      expect(s.first.halfWins, 6);
      expect(s.second.halfWins, 0);
    });

    test('nilai 11 dan 12 → klub +12, pembulatan ,5 ke atas (15r/15t)', () {
      final a = mixed(11, 12);
      // (11 + 12 + 1) ÷ 2 = 12; klub tidak memengaruhi rumusnya (Lina 11 + Maya 12 di frame 15r).
      final s = ClubScore.of(a)!;
      expect(s.first.totalPoint, 11 + 12 + 12);
    });
  });

  group('Provider', () {
    Future<ProviderContainer> seed(ActiveTournament a) async {
      final store = TournamentStore.memory();
      await store.saveActive(a);
      return ProviderContainer(overrides: [tournamentStoreProvider.overrideWithValue(store)]);
    }

    test('clubScoreProvider dan clubStandingEntriesProvider membaca turnamen aktif', () async {
      final c = await seed(_fixed(_c13));
      addTearDown(c.dispose);
      final s = c.read(clubScoreProvider)!;
      expect((s.first.winsLabel, s.second.winsLabel), ('7', '5'));

      final groups = c.read(clubStandingEntriesProvider);
      expect([for (final g in groups) g.club.id], ['club-1', 'club-2']);
      expect([for (final e in groups[1].entries) e.position], [1, 2, 3]);

      c.read(rankingMethodProvider.notifier).state = RankingMethod.winPercent;
      expect(c.read(clubStandingEntriesProvider)[0].entries.map((e) => e.label).first, 'Eko + Fajar');
    });

    test('playerClubPositionProvider: nomor di dalam klubnya, bukan lintas klub', () async {
      final c = await seed(_fixed(_c13));
      addTearDown(c.dispose);
      final maya = c.read(playerClubPositionProvider('p-maya'))!;
      expect((maya.club.id, maya.position), ('club-2', 1));
      final citra = c.read(playerClubPositionProvider('p-citra'))!;
      expect((citra.club.id, citra.position), ('club-1', 4));
      expect(c.read(playerClubPositionProvider('tidak-ada')), isNull);
    });

    test('tanpa turnamen: kosong', () {
      final c = ProviderContainer(overrides: [tournamentStoreProvider.overrideWithValue(TournamentStore.memory())]);
      addTearDown(c.dispose);
      expect(c.read(clubScoreProvider), isNull);
      expect(c.read(clubStandingEntriesProvider), isEmpty);
    });
  });
}
