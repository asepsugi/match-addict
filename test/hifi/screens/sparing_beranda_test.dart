import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/home/app_install.dart';
import 'package:match_addict/features/home/home_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';

/// Golden Beranda sparing, frame 14x–14y. Data = `sparingAfterR5` (R6 berjalan, 6 – 4, 10 dari 12 match).
void main() {
  Widget screen(ActiveTournament active) {
    final store = TournamentStore.memory();
    store.saveActive(active);
    return hifiScreen(
      const HomeScreen(),
      overrides: [
        tournamentStoreProvider.overrideWithValue(store),
        lastFinishedProvider.overrideWith((ref) => null),
        appInstallModeProvider.overrideWithValue(ValueNotifier(AppInstallMode.none) as ValueListenable<AppInstallMode>),
      ],
    );
  }

  Future<void> golden(
    WidgetTester tester,
    String frame,
    Widget screen, {
    Future<void> Function(WidgetTester)? act,
  }) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath, SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen, frame, act: act);
  }

  testWidgets('14x turnamen sparing berjalan', (tester) async {
    await golden(tester, '14x', screen(sparingAfterR5()));
    // Teks kecil lolos toleransi 2% walau salah: cek terpisah.
    expect(find.text('PB Garuda'), findsOneWidget);
    expect(find.text('6 – 4'), findsOneWidget);
    expect(find.text('Matcha Club'), findsOneWidget);
    expect(find.text('Round 6'), findsOneWidget);
    expect(find.text('10 dari 12 match'), findsOneWidget);
  });

  testWidgets('14y dialog mulai turnamen baru saat sparing berjalan', (tester) async {
    await golden(
      tester,
      '14y',
      screen(sparingAfterR5()),
      act: (tester) => tester.tap(find.text('Mulai turnamen Padel')),
    );
    expect(find.text('Turnamen yang berjalan akan dihapus:\nPB Garuda vs Matcha Club, Round 6'), findsOneWidget);
  });

  testWidgets('skor klub "0 – 0" sebelum ada hasil', (tester) async {
    await tester.pumpWidget(screen(sparingSchedule()));
    await tester.pump();
    expect(find.text('0 – 0'), findsOneWidget);
  });

  testWidgets('skor klub seri tampil setengah angka', (tester) async {
    final base = sparingAfterR5();
    // Satu match yang sudah selesai dibuat seri: klub pertama dan kedua masing-masing dapat ½.
    final matches = [...base.matches];
    final i = matches.lastIndexWhere((m) => m.status == MatchStatus.done);
    matches[i] = matches[i].withScore(const [SetScore(side1: 10, side2: 10)]);
    await tester.pumpWidget(screen(base.copyWith(tournament: base.tournament.copyWith(matches: matches))));
    await tester.pump();
    expect(find.textContaining('½'), findsOneWidget);
  });
}
