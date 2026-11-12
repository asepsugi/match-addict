import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/features/share/share_theme.dart';

/// Turnamen dengan [count] pemain, satu round yang seluruh match-nya selesai.
ActiveTournament _active(int count, {String? name}) {
  final players = [
    for (var i = 0; i < count; i++)
      Player(id: 'p$i', name: 'Pemain Nomor ${i + 1}'),
  ];
  final matches = <MatchGame>[
    for (var i = 0; i + 3 < count; i += 4)
      MatchGame(
        id: 'm$i',
        roundNumber: 1,
        matchNumberInRound: i ~/ 4 + 1,
        courtId: 'c1',
        pair1: Pair(id: 'x$i', player1Id: 'p$i', player2Id: 'p${i + 1}'),
        pair2: Pair(id: 'y$i', player1Id: 'p${i + 2}', player2Id: 'p${i + 3}'),
        sets: const [SetScore(side1: 6, side2: 3)],
        status: MatchStatus.done,
      ),
  ];

  return ActiveTournament(
    tournament: Tournament(
      id: 't1',
      createdAt: DateTime(2026, 9, 16),
      config: TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.mixed,
        matchDurationMinutes: 15,
        courts: const [
          Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
        ],
        players: players,
        name: name,
      ),
      matches: matches,
    ),
  );
}

List<StandingEntry> _standings(ActiveTournament active) => standingEntries(
      standings: RankingCalculator.rank(
        players: active.config.players,
        matches: active.matches,
        method: RankingMethod.winPercent,
        format: active.config.format,
      ),
      method: RankingMethod.winPercent,
    );

List<StandingEntry> _fixedStandings(ActiveTournament active, List<Pair> pairs) => standingEntries(
      standings: RankingCalculator.rank(
        players: active.config.players,
        matches: active.matches,
        method: RankingMethod.totalGames,
        format: active.config.format,
      ),
      method: RankingMethod.totalGames,
      fixedPairs: pairs,
    );

void main() {
  group('sharePosterData', () {
    test('Ringkas = podium: kepala, nilai Total Point + satuan + selisih, fakta tanpa tanggal', () {
      final active = _active(8);
      final entries = _standings(active);
      final data = podiumPosterData(
        active: active,
        entries: entries,
        method: RankingMethod.totalGames,
        isFinal: false,
      );
      expect(data.title, 'Klasemen sementara');
      expect(data.subtitle, 'Padel · Mixed · 16 Sep 2026');
      // Empat pemenang 6–3 senomor #1: empat blok emas, satu bola tiap blok.
      expect(data.rows, hasLength(4));
      expect([for (final b in data.blocks) (b.level, b.face, b.balls)], List.filled(4, (1, '1', 1)));
      final top = data.rows.first;
      expect((top.badge, top.gold, top.value), ('1', true, '6'));
      expect(top.detail, 'game · ${entries.first.standing.diffLabel}');
      expect(data.facts, startsWith('8 pemain · R'));
      expect(data.facts, isNot(contains('16 Sep')));
    });

    test('Turnamen bernama: nama jadi judul, tanggal di baris kecil, olahraga di fakta', () {
      final active = _active(8, name: 'PB Garuda x Matcha Club');
      final data = podiumPosterData(
        active: active,
        entries: _standings(active),
        method: RankingMethod.winPercent,
        isFinal: true,
      );
      expect(data.title, 'PB Garuda x Matcha Club');
      expect(data.subtitle, 'Klasemen akhir · 16 Sep 2026');
      expect(data.facts, 'Padel · 8 pemain · 1 round · 2 match');
      expect(data.rows.first.value, '100%');
      expect(data.rows.first.detail, '· +3');
    });

    test('Lengkap: semua yang bernomor, tanpa "+n"; Win % "100%" + selisih', () {
      final active = _active(8);
      final data = sharePosterData(
        active: active,
        entries: _standings(active),
        method: RankingMethod.winPercent,
        isFinal: false,
      );
      expect(data.rows, hasLength(8));
      expect(data.more, isNull);
      expect(data.complete, isTrue);
      expect((data.rows.first.value, data.rows.first.detail, data.rows.first.diff), ('100%', null, '+3'));
    });

    test('Fixed: ukuran pasangan, dua nama per baris, fakta menghitung pasangan', () {
      final base = _active(12);
      final pairs = [
        for (var i = 0; i < 12; i += 2) Pair(id: 'pair$i', player1Id: 'p$i', player2Id: 'p${i + 1}'),
      ];
      final active = ActiveTournament(
        tournament: base.tournament.copyWith(
          config: TournamentConfig(
            sport: SportType.tennis,
            mode: PartnerMode.fixed,
            matchDurationMinutes: 20,
            courts: base.config.courts,
            players: base.config.players,
            fixedPairs: pairs,
          ),
        ),
      );
      final data = podiumPosterData(
        active: active,
        entries: _fixedStandings(active, pairs),
        method: RankingMethod.totalGames,
        isFinal: false,
      );
      expect(data.pairSize, isTrue);
      expect(data.rows.first.names, hasLength(2));
      expect(data.rows.first.detail, startsWith('game · '));
      expect(data.facts, contains('6 pasangan'));
    });
  });

  group('gambar ekspor', () {
    for (final target in [SharePosterTarget.feed, SharePosterTarget.story]) {
      testWidgets('${target.name} lebarnya 1080 px', (tester) async {
        final size = target.designSize;
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final active = _active(20);
        final key = GlobalKey();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: RepaintBoundary(
                  key: key,
                  child: SizedBox.fromSize(
                    size: size,
                    child: SharePoster(
                      data: sharePosterData(
                        active: active,
                        entries: _standings(active),
                        method: RankingMethod.totalGames,
                                        isFinal: false,
                      ),
                      theme: ShareTheme.hijau,
                      target: target,
                    ),
                  ),
                ),
              ),
            ),
          ),
        );
        // 20 baris tetap muat: kalau meluber, pump melempar overflow.
        expect(tester.takeException(), isNull);

        // Jalur yang sama dipakai ScreenshotController saat share.
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        late ui.Image image;
        await tester.runAsync(() async {
          image = await boundary.toImage(pixelRatio: target.exportPixelRatio);
        });
        addTearDown(image.dispose);
        expect(image.width, 1080);
        expect(image.height, (size.height * target.exportPixelRatio).round());
      });
    }
  });
}
