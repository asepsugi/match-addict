import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/share/result_text_builder.dart';

import '../hifi/screens/grup_gugur_fixture.dart';
import 'point_percent_fixture.dart';

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
        method: RankingMethod.winPercent,
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
        method: RankingMethod.winPercent,
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
        method: RankingMethod.winPercent,
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
      final text = ResultTextBuilder.build(active: finished, standings: standings, format: ShareFormat.ringkas, now: DateTime(2026, 9, 14, 1), method: RankingMethod.winPercent);
      expect(text, contains('Klasemen Akhir'));
    });

    test('summary line omits WO when there is none', () {
      final clean = _tournament([
        _match(status: MatchStatus.done, sets: const [SetScore(side1: 6, side2: 0)]),
      ]);
      expect(ResultTextBuilder.summaryLine(ActiveTournament(tournament: clean)), '1 round · 1 match · 14 Sep 2026');
    });
  });

  // Keputusan 134: WhatsApp memotong caption gambar di 1024 karakter.
  group('ResultTextBuilder.forShare', () {
    final now = DateTime(2026, 9, 14, 1);
    final many = [
      for (var r = 1; r <= 40; r++) _match(status: MatchStatus.done, sets: const [SetScore(side1: 6, side2: 4)], round: r),
    ];
    final active = ActiveTournament(tournament: _tournament(many));
    final standings = standingEntries(
      standings: RankingCalculator.rank(
        players: _players,
        matches: many,
        method: RankingMethod.winPercent,
        format: active.config.format,
      ),
      method: RankingMethod.winPercent,
    );
    ShareCaption of(ShareFormat format, [List<StandingEntry>? rows]) => ResultTextBuilder.forShare(
      active: active,
      standings: rows ?? standings,
      format: format,
      now: now,
      method: RankingMethod.winPercent,
    );
    String build(ShareFormat format) => ResultTextBuilder.build(
      active: active,
      standings: standings,
      format: format,
      now: now,
      method: RankingMethod.winPercent,
    );

    test('muat 1024: caption apa adanya, tidak dipendekkan', () {
      final c = of(ShareFormat.ringkas);
      expect(c.shortened, isFalse);
      expect(c.attached, c.full);
      expect(c.full, build(ShareFormat.ringkas));
    });

    test('Lengkap > 1024: lampiran tanpa Hasil per Round, teks lengkap tetap utuh', () {
      final c = of(ShareFormat.lengkap);
      expect(c.full, build(ShareFormat.lengkap));
      expect(c.full.length, greaterThan(ResultTextBuilder.mediaCaptionLimit));
      expect(c.shortened, isTrue);
      expect(c.attached, build(ShareFormat.ringkas));
      expect(c.attached, isNot(contains('Hasil per Round')));
    });

    test('Klasemen saja > 1024: kepala + ringkasan', () {
      final rows = [
        for (var i = 0; i < 30; i++)
          () {
            final p = Player(id: 'x$i', name: 'Pemain Bernama Sangat Panjang $i');
            return StandingEntry(
              players: [p],
              standing: PlayerStanding(player: p, wins: 1, gamesWon: 10, gamesLost: 5),
              position: i + 1,
            );
          }(),
      ];
      final c = of(ShareFormat.ringkas, rows);
      expect(c.full.length, greaterThan(ResultTextBuilder.mediaCaptionLimit));
      expect(c.shortened, isTrue);
      expect(c.attached, '🏆 Match Addict · Padel\n14 September 2026\n\n40 round · 40 match · 14 Sep 2026');
    });
  });

  // Grup + Gugur (PRD 16E/16F): baris Hasil per Round berlabel babak; sisi belum diketahui = sumbernya (keputusan 106).
  group('Grup + Gugur', () {
    setUpAll(() => initializeDateFormatting('id'));

    String caption(ActiveTournament a) =>
        ResultTextBuilder.build(active: a, standings: const [], format: ShareFormat.lengkap, now: at21f, method: RankingMethod.winPercent);

    test('Hasil per Round berlabel Grup A · / Semifinal · / Final · / Juara 3 ·', () {
      final lines = caption(gg21i()).split('\n');
      final i = lines.indexOf('Hasil per Round');
      expect(lines[i + 1], '· Round 1');
      expect(lines[i + 2], '  Grup A · Andi+Budi vs Gita+Hadi → 4-6');
      expect(lines[i + 3], '  Grup B · Indra+Joko vs Oki+Putri → 6-1');
      expect(lines.sublist(lines.indexOf('· Round 7')), [
        '· Round 7',
        '  Semifinal · Andi+Budi vs Maya+Nanda → 6-4',
        '  Semifinal · Indra+Joko vs Citra+Dewi → 4-6',
        '· Round 8',
        '  Final · Andi+Budi vs Citra+Dewi → 7-9',
        '  Juara 3 · Maya+Nanda vs Indra+Joko → 4-2',
        '',
        '8 round · 16 match · 17 Nov 2026',
      ]);
    });

    test('K106: match gugur cancelled bersisi tbd menulis sumber ("Pemenang SF2")', () {
      final text = caption(gg21c().finish());
      expect(text, contains('  Semifinal · Indra+Joko vs Citra+Dewi → tidak dimainkan'));
      expect(text, contains('  Final · Andi+Budi vs Pemenang SF2 → tidak dimainkan'));
      expect(text, contains('  Juara 3 · Maya+Nanda vs Kalah SF2 → tidak dimainkan'));
      expect(text, isNot(contains('?')));
    });
  });

  group('ResultTextBuilder · Point % (U-RP3, 18A)', () {
    final players = playersOf(names18a);
    final active = ActiveTournament(
      tournament: Tournament(
        id: 't18a',
        createdAt: DateTime(2026, 11, 6),
        config: TournamentConfig(
          sport: SportType.padel,
          mode: PartnerMode.mixed,
          matchDurationMinutes: 15,
          courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120)],
          players: players,
          format: americano21,
          name: 'Mabar Jumat PB Garuda',
        ),
        matches: matches18a,
      ),
    );

    List<String> lines(RankingMethod method) {
      final standings = standingEntries(
        standings: RankingCalculator.rank(players: players, matches: matches18a, method: method, format: americano21),
        method: method,
      );
      final text = ResultTextBuilder.build(
        active: active,
        standings: standings,
        format: ShareFormat.ringkas,
        now: DateTime(2026, 11, 6, 23),
        method: method,
      );
      return text.split('\n').skip(4).toList();
    }

    test('Point %: baris pertama persis', () {
      expect(lines(RankingMethod.pointPercent).first, '1. Budi — 36 poin · 57% poin (3-0, +9 poin)');
    });

    test('Total Point dan Win % tetap bentuk lama (Win % satu desimal)', () {
      expect(lines(RankingMethod.totalGames).first, '1. Andi — 41 poin · 50.0% (2-2, -2 poin)');
      expect(lines(RankingMethod.winPercent).first, '1. Budi — 36 poin · 100.0% (3-0, +9 poin)');
    });
  });
}
