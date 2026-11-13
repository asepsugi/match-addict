import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/share/podium_theme.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/share_exports.dart';
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/share/lengkap.dart';

/// Turnamen dengan [count] pemain, satu round; seluruh match-nya selesai, atau belum ada skor ([played] false).
ActiveTournament _active(int count, {String? name, bool played = true}) {
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
        sets: played ? const [SetScore(side1: 6, side2: 3)] : const [],
        status: played ? MatchStatus.done : MatchStatus.pending,
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

    test('Lengkap: semua yang bernomor, kepala dan fakta = podium; Win % "100%" + selisih tanpa satuan', () {
      final active = _active(8);
      final entries = _standings(active);
      final data = sharePosterData(active: active, entries: entries, method: RankingMethod.winPercent, isFinal: false);
      final podium = podiumPosterData(
        active: active,
        entries: entries,
        method: RankingMethod.winPercent,
        isFinal: false,
      );
      expect(data.rows, hasLength(8));
      expect(data.clubs, isNull);
      expect(data.endless, isTrue);
      expect((data.title, data.subtitle, data.facts), (podium.title, podium.subtitle, podium.facts));
      expect(
        [for (final b in data.blocks) (b.level, b.face, b.balls)],
        [for (final b in podium.blocks) (b.level, b.face, b.balls)],
      );
      expect((data.rows.first.value, data.rows.first.detail, data.rows.first.diff), ('100%', null, '+3'));
    });

    test('11m Feed K85: lebih dari empat di #1 → satu blok lebar, 12 baris, 6 bernomor #1', () {
      final active = _active(12, name: 'Mabar Jumat PB Garuda');
      final data = sharePosterData(
        active: active,
        entries: _standings(active),
        method: RankingMethod.winPercent,
        isFinal: false,
      );
      expect(data.wide, isTrue);
      expect([for (final b in data.blocks) (b.level, b.face, b.balls)], [(1, '1', 0)]);
      expect(data.rows, hasLength(12));
      expect(data.rows.where((r) => r.position == 1), hasLength(6));
      expect(data.title, 'Mabar Jumat PB Garuda');
      expect(data.subtitle, 'Klasemen sementara · 16 Sep 2026');
      expect(data.facts, 'Padel · 12 pemain · R1 · 3 dari 3 match');
    });

    test('11m Story K87: belum ada match → blok kosong, baris kosong, fakta "0 dari 3 match"', () {
      final active = _active(12, name: 'Mabar Jumat PB Garuda', played: false);
      final data = sharePosterData(
        active: active,
        entries: _standings(active),
        method: RankingMethod.winPercent,
        isFinal: false,
      );
      expect(data.blocks, isEmpty);
      expect(data.rows, isEmpty);
      expect(data.clubs, isNull);
      expect(data.facts, 'Padel · 12 pemain · R1 · 0 dari 3 match');
      expect(lengkapGrid(story: true, endless: true, rowCounts: data.rowCounts, pairs: false).units, 0);
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
    // lengkapImages: Feed 360 × 360 dan Story 360 × 640 ×3 (§17.9), bukan kanvas Story lama 202,5 × 360.
    final active = _active(20);
    final images = lengkapImages(
      sharePosterData(active: active, entries: _standings(active), method: RankingMethod.totalGames, isFinal: false),
      PodiumTheme.court(SportType.padel),
    );

    test('Feed dan Story: ukuran, rasio, nama berkas', () {
      expect(
        [for (final i in images) (i.size, i.pixelRatio, i.fileName)],
        [
          (const Size(360, 360), 3.0, 'match-addict-feed-1080x1080.png'),
          (const Size(360, 640), 3.0, 'match-addict-story-1080x1920.png'),
        ],
      );
      expect(
        [for (final i in images) (i.poster as SharePoster).target],
        [PodiumPosterTarget.feed, PodiumPosterTarget.story],
      );
    });

    for (final (image, size) in [(0, const Size(1080, 1080)), (1, const Size(1080, 1920))]) {
      testWidgets('${size.width.round()} × ${size.height.round()} px', (tester) async {
        final shot = images[image];
        await tester.binding.setSurfaceSize(shot.size);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final key = GlobalKey();
        await tester.pumpWidget(
          MediaQuery(
            data: const MediaQueryData(),
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: Center(
                child: RepaintBoundary(key: key, child: shot.poster),
              ),
            ),
          ),
        );
        // 20 baris tetap muat: kalau meluber, pump melempar overflow.
        expect(tester.takeException(), isNull);

        // Jalur yang sama dipakai ScreenshotController saat share.
        final boundary = key.currentContext!.findRenderObject()! as RenderRepaintBoundary;
        late ui.Image rendered;
        await tester.runAsync(() async {
          rendered = await boundary.toImage(pixelRatio: shot.pixelRatio);
        });
        addTearDown(rendered.dispose);
        expect((rendered.width, rendered.height), (size.width.round(), size.height.round()));
      });
    }
  });
}
