import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';

/// Peringkat desain v2 (design/spec/logic.md §3–§4): nilai menang WO per format, nomor sama kalau
/// semua tie-break seri (nomor rapat 1, 2, 2, 3), "Belum main", status Final. Data = frame 09a–09f, 10a, 10b.

const _americano24 = ScoreFormat(ScoringMethod.americano, 24);

Player _p(String name) => Player(id: name, name: name);

Pair _pair(String a, String b) => Pair(id: '$a+$b', player1Id: a, player2Id: b);

MatchGame _m(int round, int no, (String, String) t1, (String, String) t2, {int? s1, int? s2, String? status}) {
  final p1 = _pair(t1.$1, t1.$2), p2 = _pair(t2.$1, t2.$2);
  return MatchGame(
    id: 'r$round-$no',
    roundNumber: round,
    matchNumberInRound: no,
    courtId: 'c$no',
    pair1: p1,
    pair2: p2,
    sets: s1 == null ? const [] : [SetScore(side1: s1, side2: s2!)],
    status: switch (status) {
      'wo2' => MatchStatus.wo,
      'pending' => MatchStatus.pending,
      'cancelled' => MatchStatus.cancelled,
      _ => MatchStatus.done,
    },
    woLoserPairId: status == 'wo2' ? p2.id : null,
  );
}

/// Data set 1 — 09a/09b, 10a, 11a: Americano 24, R1–R3, Gilang masuk belakangan dan belum main.
final _players1 = [
  for (final n in ['Andi', 'Budi', 'Citra', 'Dewant', 'Eko', 'Fajar', 'Gina', 'Hana', 'Indra', 'Joko', 'Gilang']) _p(n),
];
final _set1 = [
  _m(1, 1, ('Andi', 'Hana'), ('Budi', 'Eko'), s1: 14, s2: 10),
  _m(1, 2, ('Dewant', 'Citra'), ('Fajar', 'Joko'), s1: 15, s2: 9),
  _m(2, 1, ('Andi', 'Gina'), ('Fajar', 'Indra'), s1: 15, s2: 9),
  _m(2, 2, ('Dewant', 'Joko'), ('Budi', 'Hana'), s1: 14, s2: 10),
  _m(3, 1, ('Andi', 'Dewant'), ('Citra', 'Indra'), s1: 13, s2: 11),
  _m(3, 2, ('Eko', 'Gina'), ('Fajar', 'Hana'), s1: 12, s2: 12),
];

/// Data set 2 — 09d/09e/09f: R1–R4, 7 dari 8 match, satu WO (Dewant · Gina tidak main), satu seri.
final _players2 = _players1.take(10).toList();
List<MatchGame> _set2({String lastMatch = 'pending'}) => [
  _m(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewant'), s1: 16, s2: 8),
  _m(1, 2, ('Eko', 'Fajar'), ('Gina', 'Hana'), s1: 13, s2: 11),
  _m(2, 1, ('Andi', 'Citra'), ('Eko', 'Indra'), s1: 11, s2: 13),
  _m(2, 2, ('Budi', 'Joko'), ('Dewant', 'Gina'), status: 'wo2'),
  _m(3, 1, ('Andi', 'Fajar'), ('Hana', 'Joko'), s1: 14, s2: 10),
  _m(3, 2, ('Budi', 'Indra'), ('Citra', 'Gina'), s1: 12, s2: 12),
  _m(4, 1, ('Dewant', 'Eko'), ('Fajar', 'Joko'), s1: 17, s2: 7),
  _m(4, 2, ('Andi', 'Hana'), ('Budi', 'Gina'), status: lastMatch),
];

List<StandingEntry> _entries(List<Player> players, List<MatchGame> matches, RankingMethod method,
        {ScoreFormat format = _americano24, List<Pair>? fixedPairs}) =>
    standingEntries(
      standings: RankingCalculator.rank(players: players, matches: matches, method: method, format: format),
      method: method,
      fixedPairs: fixedPairs,
    );

/// "1 Andi 42 +12" — nomor, nama, nilai metode, selisih (kolom +/− di Klasemen).
List<String> _table(List<StandingEntry> entries, RankingMethod method) => [
  for (final e in entries)
    '${e.position ?? '–'} ${e.label} '
        '${method == RankingMethod.totalGames ? e.standing.totalPoint : '${e.standing.winPercent.round()} ${e.standing.totalPoint}'} '
        '${e.standing.gameDiff > 0 ? '+' : ''}${e.standing.gameDiff}',
];

void main() {
  group('data set 1 (09a, 09b, 10a)', () {
    test('Total Point: poin dan selisih sama → nomor sama, berikutnya melanjutkan; belum main di belakang', () {
      expect(_table(_entries(_players1, _set1, RankingMethod.totalGames), RankingMethod.totalGames), [
        '1 Andi 42 +12',
        '1 Dewant 42 +12',
        '2 Hana 36 0',
        '3 Fajar 30 -12',
        '4 Gina 27 +6',
        '5 Citra 26 +4',
        '6 Joko 23 -2',
        '7 Eko 22 -4',
        '8 Budi 20 -8',
        '8 Indra 20 -8',
        '– Gilang 0 0',
      ]);
    });

    test('Win %: urutan berubah, Win % sama dipisah selisih', () {
      expect(_table(_entries(_players1, _set1, RankingMethod.winPercent), RankingMethod.winPercent), [
        '1 Andi 100 42 +12',
        '1 Dewant 100 42 +12',
        '2 Gina 75 27 +6',
        '3 Citra 50 26 +4',
        '4 Hana 50 36 0',
        '5 Joko 50 23 -2',
        '6 Eko 25 22 -4',
        '7 Fajar 17 30 -12',
        '8 Budi 0 20 -8',
        '8 Indra 0 20 -8',
        '– Gilang 0 0 0',
      ]);
    });

    test('W–L–D Hana 1–1–1 dan Fajar 0–2–1', () {
      final byName = {for (final e in _entries(_players1, _set1, RankingMethod.totalGames)) e.label: e.standing};
      expect((byName['Hana']!.wins, byName['Hana']!.losses, byName['Hana']!.draws), (1, 1, 1));
      expect((byName['Fajar']!.wins, byName['Fajar']!.losses, byName['Fajar']!.draws), (0, 2, 1));
    });

    test('Detail Andi: 42 poin · 100% · 3–0–0 · +12, beda partner 3/10, beda lawan 5/10', () {
      final andi = _entries(_players1, _set1, RankingMethod.totalGames).first.standing;
      expect((andi.totalPoint, andi.winPercent, andi.wins, andi.losses, andi.draws, andi.gameDiff), (42, 100, 3, 0, 0, 12));
      final profile = PlayerProfile.of(playerId: 'Andi', matches: _set1);
      expect((profile.partnerIds.length, profile.opponentIds.length), (3, 5));
    });
  });

  group('data set 2 (09d, 09e)', () {
    test('menang WO = rata-rata sendiri, minimal skor menang terkecil: Budi +14, Joko +13', () {
      final byName = {for (final e in _entries(_players2, _set2(), RankingMethod.totalGames)) e.label: e.standing};
      // Budi (16 + 12) ÷ 2 = 14; Joko (10 + 7) ÷ 2 = 8,5 → 9, di bawah 13 (Americano 24) → 13.
      expect((byName['Budi']!.woPoints, byName['Budi']!.totalPoint), (14, 42));
      expect((byName['Joko']!.woPoints, byName['Joko']!.totalPoint), (13, 30));
      // Yang kalah WO dapat 0, selisih kedua tim tidak berubah.
      expect((byName['Dewant']!.woPoints, byName['Dewant']!.woLosses, byName['Dewant']!.gameDiff), (0, 1, 2));
      expect(byName['Budi']!.gameDiff, 8);
      // Menang/kalah WO tetap masuk W–L–D.
      expect((byName['Budi']!.wins, byName['Budi']!.losses, byName['Budi']!.draws), (2, 0, 1));
    });

    test('Total Point 09d: hanya Eko di peringkat 1; Dewant dan Indra berbagi 7 (poin dan selisih sama)', () {
      expect(_table(_entries(_players2, _set2(), RankingMethod.totalGames), RankingMethod.totalGames), [
        '1 Eko 43 +14',
        '2 Budi 42 +8',
        '3 Andi 41 +10',
        '4 Fajar 34 -4',
        '5 Citra 31 -10',
        '6 Joko 30 -14',
        '7 Dewant 25 +2',
        '7 Indra 25 +2',
        '8 Gina 23 -2',
        '9 Hana 21 -6',
      ]);
    });

    test('Win % 09e: Win % sama dipisah selisih', () {
      expect(_table(_entries(_players2, _set2(), RankingMethod.winPercent), RankingMethod.winPercent), [
        '1 Eko 100 43 +14',
        '2 Budi 83 42 +8',
        '3 Indra 75 25 +2',
        '4 Andi 67 41 +10',
        '5 Fajar 67 34 -4',
        '6 Dewant 33 25 +2',
        '7 Joko 33 30 -14',
        '8 Gina 17 23 -2',
        '9 Citra 17 31 -10',
        '10 Hana 0 21 -6',
      ]);
    });

    test('match tidak dimainkan (09f) tidak mengubah apa pun', () {
      expect(
        _table(_entries(_players2, _set2(lastMatch: 'cancelled'), RankingMethod.totalGames), RankingMethod.totalGames),
        _table(_entries(_players2, _set2(), RankingMethod.totalGames), RankingMethod.totalGames),
      );
    });

    test('rata-rata WO dihitung ulang setiap kali pemain main lagi', () {
      // Budi menang 20–4 di R4: rata-rata (16 + 12 + 20) ÷ 3 = 16.
      final matches = [
        for (final m in _set2()) m.id == 'r4-2' ? m.withScore(const [SetScore(side1: 4, side2: 20)]) : m,
      ];
      final budi = _entries(_players2, matches, RankingMethod.totalGames).firstWhere((e) => e.label == 'Budi').standing;
      expect(budi.woPoints, 16);
    });

    test('belum pernah main saat menang WO → skor menang terkecil', () {
      final wo = [_m(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewant'), status: 'wo2')];
      final andi = _entries(_players2, wo, RankingMethod.totalGames).first.standing;
      expect(andi.totalPoint, 13);
      const bestOf6 = ScoreFormat(ScoringMethod.bestOf, 6);
      expect(_entries(_players2, wo, RankingMethod.totalGames, format: bestOf6).first.standing.totalPoint, 4);
    });
  });

  test('Fixed Race to 6 (09c, 10b): pemenang WO dapat 6 game — Gina · Hana 17 → 23, selisih tetap +7', () {
    final gh = _pair('Gina', 'Hana'), cd = _pair('Citra', 'Dewant');
    final matches = [
      _m(1, 1, ('Gina', 'Hana'), ('Indra', 'Joko'), s1: 6, s2: 3),
      _m(2, 1, ('Gina', 'Hana'), ('Citra', 'Dewant'), status: 'wo2'),
      _m(3, 1, ('Gina', 'Hana'), ('Eko', 'Fajar'), s1: 6, s2: 1),
      _m(5, 1, ('Gina', 'Hana'), ('Andi', 'Budi'), s1: 5, s2: 6),
    ];
    final entries = _entries(
      _players2,
      matches,
      RankingMethod.totalGames,
      format: ScoreFormat.standard,
      fixedPairs: [gh, cd, _pair('Indra', 'Joko'), _pair('Eko', 'Fajar'), _pair('Andi', 'Budi')],
    );
    final ginaHana = entries.firstWhere((e) => e.label == 'Gina + Hana').standing;
    expect((ginaHana.totalPoint, ginaHana.gameDiff, ginaHana.wins, ginaHana.losses, ginaHana.winPercent), (23, 7, 3, 1, 75));
    final citraDewant = entries.firstWhere((e) => e.label == 'Citra + Dewant').standing;
    expect((citraDewant.totalPoint, citraDewant.woLosses), (0, 1));
  });

  group('status & hitungan', () {
    ActiveTournament mixed(List<MatchGame> matches, {int booking = 120, bool finished = false}) => ActiveTournament(
      tournament: Tournament(
        id: 't1',
        createdAt: DateTime(2026, 10, 21),
        isFinished: finished,
        config: TournamentConfig(
          sport: SportType.padel,
          mode: PartnerMode.mixed,
          matchDurationMinutes: 15,
          courts: [
            Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: booking),
            Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: booking),
          ],
          players: _players2,
          format: _americano24,
        ),
        matches: matches,
      ),
    );

    // Waktu sungguhan sejak mulai; durasi match 15 menit.
    DateTime at(int minutes) => DateTime(2026, 10, 21).add(Duration(minutes: minutes));

    test('Mixed tidak Final hanya karena round lengkap; Final setelah diakhiri', () {
      final complete = _set2().where((m) => m.roundNumber < 4).toList();
      expect(mixed(complete).isFinal(at(45)), isFalse, reason: 'masih bisa buat R4');
      expect(mixed(_set2(lastMatch: 'cancelled'), finished: true).isFinal(at(45)), isTrue);
    });

    test('Mixed Final kalau waktu habis dan round terakhir lengkap; belum lengkap tetap Sementara', () {
      // Sudah 60 menit dari booking 60: R5 tidak muat.
      expect(mixed(_set2(), booking: 60).isFinal(at(60)), isFalse, reason: 'R4 M2 belum diisi');
      final r4Done = [
        for (final m in _set2()) m.id == 'r4-2' ? m.withScore(const [SetScore(side1: 12, side2: 12)]) : m,
      ];
      expect(mixed(r4Done, booking: 60).isFinal(at(60)), isTrue);
      expect(mixed(r4Done).isFinal(at(60)), isFalse, reason: 'booking 2 jam: R5 masih muat');
      expect(mixed(r4Done, booking: 60).isFinal(at(45)), isFalse, reason: 'round selesai cepat: R5 masih muat');
    });

    test('Fixed Final kalau semua match terisi', () {
      ActiveTournament fixed(List<MatchGame> matches) => ActiveTournament(
        tournament: mixed(matches).tournament.copyWith(
          config: TournamentConfig(
            sport: SportType.tennis,
            mode: PartnerMode.fixed,
            matchDurationMinutes: 20,
            courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120)],
            players: _players2,
          ),
        ),
      );
      expect(fixed(_set2()).isFinal(at(0)), isFalse);
      expect(fixed(_set2(lastMatch: 'cancelled')).isFinal(at(0)), isTrue);
    });

    test('round & match yang dimainkan: "3 round · 6 match" (set 1), "4 round · 7 match" (09f)', () {
      expect((mixed(_set1).playedRoundCount, mixed(_set1).playedMatchCount), (3, 6));
      final finished = mixed(_set2(lastMatch: 'cancelled'), finished: true);
      expect((finished.playedRoundCount, finished.playedMatchCount), (4, 7));
    });
  });
}
