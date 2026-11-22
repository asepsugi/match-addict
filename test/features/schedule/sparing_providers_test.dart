import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../../services/sparing_score_fixture.dart';

void main() {
  group('Provider', () {
    Future<ProviderContainer> seed(ActiveTournament a) async {
      final store = TournamentStore.memory();
      await store.saveActive(a);
      return ProviderContainer(overrides: [tournamentStoreProvider.overrideWithValue(store)]);
    }

    test('clubScoreProvider dan clubStandingEntriesProvider membaca turnamen aktif', () async {
      final c = await seed(fixedSparing(c13));
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
      final c = await seed(fixedSparing(c13));
      addTearDown(c.dispose);
      c.read(rankingMethodProvider.notifier).state = RankingMethod.totalGames;
      final maya = c.read(playerClubPositionProvider('p-maya'))!;
      expect((maya.club.id, maya.position), ('club-2', 1));
      final citra = c.read(playerClubPositionProvider('p-citra'))!;
      expect((citra.club.id, citra.position), ('club-1', 4));
      expect(c.read(playerClubPositionProvider('tidak-ada')), isNull);
    });

    test('metode awal ikut format skor; pilihan host bertahan sampai turnamen berganti (PRD 4.2)', () async {
      final raceTo = fixedSparing(c13);
      final c = await seed(raceTo);
      addTearDown(c.dispose);
      expect(raceTo.config.format.method, ScoringMethod.raceTo);
      expect(c.read(rankingMethodProvider), RankingMethod.winPercent);

      c.read(rankingMethodProvider.notifier).state = RankingMethod.totalGames;
      c.read(tournamentProvider); // turnamen yang sama: pilihan tidak direset
      expect(c.read(rankingMethodProvider), RankingMethod.totalGames);

      c.read(tournamentProvider.notifier).state = null;
      expect(c.read(rankingMethodProvider), RankingMethod.totalGames, reason: 'tanpa turnamen');
      c.read(tournamentProvider.notifier).state = raceTo;
      expect(c.read(rankingMethodProvider), RankingMethod.winPercent, reason: 'turnamen dimuat lagi → default');
    });

    test('AC-RP2: default per format; Americano → Point %, ganti tab bertahan, ganti turnamen → default', () async {
      final americano = fixedSparing(c13, format: const ScoreFormat(ScoringMethod.americano, 21));
      final c = await seed(americano);
      addTearDown(c.dispose);
      expect(c.read(rankingMethodProvider), RankingMethod.pointPercent);

      c.read(rankingMethodProvider.notifier).state = RankingMethod.totalGames;
      c.read(tournamentProvider);
      expect(c.read(rankingMethodProvider), RankingMethod.totalGames);

      c.read(tournamentProvider.notifier).state = fixedSparing(c13);
      expect(
        c.read(rankingMethodProvider),
        RankingMethod.winPercent,
        reason: 'turnamen berganti → default format baru',
      );
    });

    test('AC-RP14: penonton memakai default yang sama dengan host (tanpa metode di payload)', () {
      final americano = fixedSparing(c13, format: const ScoreFormat(ScoringMethod.americano, 21));
      final viewer = ProviderContainer(
        overrides: [
          liveViewProvider.overrideWith(() => _Watching(LiveView(LiveViewStatus.live, americano))),
          tournamentProvider.overrideWith(LiveTournamentController.new),
        ],
      );
      addTearDown(viewer.dispose);
      expect(viewer.read(rankingMethodProvider), RankingMethod.pointPercent);
    });

    test('tanpa turnamen: kosong', () {
      final c = ProviderContainer(overrides: [tournamentStoreProvider.overrideWithValue(TournamentStore.memory())]);
      addTearDown(c.dispose);
      expect(c.read(clubScoreProvider), isNull);
      expect(c.read(clubStandingEntriesProvider), isEmpty);
    });
  });
}

/// Penonton dengan hasil relay yang sudah ada (pola test/hifi/screens/live_test.dart).
class _Watching extends LiveViewController {
  final LiveView view;
  _Watching(this.view);

  @override
  LiveView? build() => view;
}
