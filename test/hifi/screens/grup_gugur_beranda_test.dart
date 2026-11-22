import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/home/app_install.dart';
import 'package:match_addict/features/home/home_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'screen_harness.dart';

/// Golden Beranda Grup + Gugur, frame 22s–22u (KS-7e C-4, keputusan 127/128 #6): baris kecil banner = nama format
/// ("Group - Playoff"), judul = nama babak yang berjalan ("Semifinal"), bukan "Round 7".
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

  Future<void> golden(WidgetTester tester, String frame, ActiveTournament active, {bool dialog = false}) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath, SportType.padel.assetPath]);
    await expectMatchesHifi(
      tester,
      screen(active),
      frame,
      act: dialog ? (t) => t.tap(find.text('Mulai turnamen Padel')) : null,
    );
  }

  testWidgets('22s fase grup: "Padel · Group - Playoff · 16 pemain", Round 3', (tester) async {
    await golden(tester, '22s', gg20b());
    expect(find.text('Padel · Group - Playoff · 16 pemain'), findsOneWidget);
    expect(find.text('Round 3'), findsOneWidget);
    expect(find.text('5 dari 12 match'), findsOneWidget);
  });

  testWidgets('22t Semifinal: judul nama babak, 12 dari 16 match', (tester) async {
    await golden(tester, '22t', gg21a());
    expect(find.text('Semifinal'), findsOneWidget);
    expect(find.text('12 dari 16 match'), findsOneWidget);
  });

  testWidgets('22u dialog mulai baru: "Padel · Group - Playoff, Semifinal"', (tester) async {
    await golden(tester, '22u', gg21a(), dialog: true);
    expect(find.textContaining('Padel · Group - Playoff, Semifinal'), findsOneWidget);
  });
}
