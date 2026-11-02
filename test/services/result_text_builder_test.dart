import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/share/result_text_builder.dart';

const _players = [
  Player(id: 'a', name: 'Andi P'),
  Player(id: 'b', name: 'Budi S'),
  Player(id: 'c', name: 'Citra L'),
  Player(id: 'd', name: 'Dewi R'),
];

const _ab = Pair(id: 'ab', player1Id: 'a', player2Id: 'b');
const _cd = Pair(id: 'cd', player1Id: 'c', player2Id: 'd');

Tournament _tournament(List<MatchGame> matches, {String? name}) => Tournament(
      id: 't1',
      createdAt: DateTime(2026, 9, 14),
      config: TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.fixed,
        matchDurationMinutes: 15,
        courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120)],
        players: _players,
        fixedPairs: const [_ab, _cd],
        name: name,
      ),
      matches: matches,
    );

MatchGame _match({
  required MatchStatus status,
  List<SetScore> sets = const [],
  String? woLoser,
  int round = 1,
}) =>
    MatchGame(
      id: 'm$round',
      roundNumber: round,
      matchNumberInRound: 1,
      courtId: 'c1',
      pair1: _ab,
      pair2: _cd,
      sets: sets,
      status: status,
      woLoserPairId: woLoser,
    );

void main() {
  setUpAll(() => initializeDateFormatting('id'));

  group('ResultTextBuilder', () {
    final matches = [
      _match(status: MatchStatus.done, sets: const [SetScore(side1: 6, side2: 4)]),
      _match(status: MatchStatus.wo, woLoser: 'cd', round: 2),
      _match(status: MatchStatus.pending, round: 3),
    ];
    final tournament = _tournament(matches);
    final active = ActiveTournament(tournament: tournament);
    final standings = standingEntries(
      standings: RankingCalculator.rank(
        players: _players,
        matches: matches,
        method: RankingMethod.winPercent,
        format: tournament.config.format,
      ),
      method: RankingMethod.winPercent,
    );

    test('ringkas lists every player once, without per-round detail', () {
      final text = ResultTextBuilder.build(
        active: active,
        standings: standings,
        format: ShareFormat.ringkas,
        now: DateTime(2026, 9, 14, 1),
      );

      expect(text, contains('🏆 Match Addict · Padel'));
      // R3 belum dimainkan dan turnamen belum diakhiri.
      expect(text, contains('Klasemen Sementara'));
      for (final p in _players) {
        expect(text, contains(p.name));
      }
      expect(text, isNot(contains('Hasil per Round')));
      // Total point ikut dibagikan, bukan cuma win%.
      // Race to 6: satuannya game. Pemenang WO dapat 6 game (PRD 4.4): 6 + 6 = 12. Statistik Andi dan
      // Budi identik, jadi nomornya sama; nomor berikutnya melanjutkan (2, bukan 3).
      expect(text, contains('1. Andi P — 12 game'));
      expect(text, contains('1. Budi S — 12 game'));
      expect(text, contains('2. Citra L — 4 game'));
    });

    test('turnamen bernama: baris pertama "🏆 nama · olahraga"', () {
      final text = ResultTextBuilder.build(
        active: ActiveTournament(tournament: _tournament(matches, name: 'PB Garuda x Matcha Club')),
        standings: standings,
        format: ShareFormat.ringkas,
        now: DateTime(2026, 9, 14, 1),
      );
      expect(text.split('\n').first, '🏆 PB Garuda x Matcha Club · Padel');
      expect(text, isNot(contains('Match Addict')));
    });

    test('lengkap adds per-round results and skips unplayed matches', () {
      final text = ResultTextBuilder.build(
        active: active,
        standings: standings,
        format: ShareFormat.lengkap,
        now: DateTime(2026, 9, 14, 1),
      );

      expect(text, contains('Hasil per Round'));
      expect(text, contains('· Round 1'));
      expect(text, contains('6-4'));
      expect(text, contains('WO'));
      expect(text, isNot(contains('· Round 3')));
    });

    test('summary line counts played rounds, played matches and WO', () {
      expect(
        ResultTextBuilder.summaryLine(active),
        '2 round · 2 match · 1 WO · 14 Sep 2026',
      );
    });

    test('klasemen akhir kalau turnamen sudah diakhiri', () {
      final finished = ActiveTournament(tournament: tournament.copyWith(isFinished: true));
      final text = ResultTextBuilder.build(active: finished, standings: standings, format: ShareFormat.ringkas, now: DateTime(2026, 9, 14, 1));
      expect(text, contains('Klasemen Akhir'));
    });

    test('summary line omits WO when there is none', () {
      final clean = _tournament([
        _match(status: MatchStatus.done, sets: const [SetScore(side1: 6, side2: 0)]),
      ]);
      expect(ResultTextBuilder.summaryLine(ActiveTournament(tournament: clean)), '1 round · 1 match · 14 Sep 2026');
    });
  });
}
