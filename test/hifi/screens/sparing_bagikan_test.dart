import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/share/share_content.dart';
import 'package:match_addict/features/share/share_result_screen.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/share/result_text_builder.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';

/// Golden Bagikan sparing Fixed, frame 13q–13t (docs/tasks.md SP-15): data 13C Final ([sparingFull]), tema biru,
/// tanpa nama. 13r/13t = lembar gambar Feed 360×360 di x 0 dan Story 203×360 di x 374, seperti 11d.
void main() {
  setUpAll(() => initializeDateFormatting('id'));

  final now = sparingAt(6);
  List<Override> overrides(ActiveTournament active) => [
    tournamentProvider.overrideWith(() => LoadedTournament(active)),
    clockProvider.overrideWithValue(() => now),
  ];

  Widget screen(ActiveTournament active) => hifiScreen(const ShareResultScreen(), overrides: overrides(active));
  Future<void> lengkap(WidgetTester tester) => tester.tap(find.text('Lengkap'));

  /// Isi poster lewat provider yang sama dengan layar (nomor per klub = Klasemen).
  SharePosterData posterOf(ActiveTournament active, ShareFormat format) {
    final container = ProviderContainer(overrides: overrides(active));
    addTearDown(container.dispose);
    return sharePosterData(
      active: active,
      entries: container.read(standingEntriesProvider),
      method: container.read(rankingMethodProvider),
      format: format,
      isFinal: active.isFinal(now),
      clubResult: container.read(clubScoreProvider),
      clubEntries: container.read(clubStandingEntriesProvider),
    );
  }

  // Teks kecil lolos toleransi golden walau salah, jadi dicek juga lewat teks.
  void expectClubScore() {
    expect(find.text('PB Garuda'), findsOneWidget);
    expect(find.text('Matcha Club'), findsOneWidget);
    expect(find.text('56 game · +13'), findsOneWidget);
    expect(find.text('49 game · −13'), findsOneWidget);
    expect(find.text('7'), findsOneWidget);
    expect(find.text('5'), findsOneWidget);
    expect(find.text('PB GARUDA'), findsOneWidget);
    expect(find.text('MATCHA CLUB'), findsOneWidget);
    expect(find.text('6 round · 12 match · 1 WO'), findsOneWidget);
  }

  testWidgets('13q Ringkas: skor klub, 3 teratas tiap klub, +1 di label Garuda (K7)', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen(sparingFull()), '13q');
    expectClubScore();
    expect(find.text('+1 pasangan lainnya'), findsOneWidget);
    expect(find.text('Citra + Dewi'), findsNothing);
    expect(find.text('3 teratas tiap klub · gambar Feed 1:1 & Story 9:16'), findsOneWidget);
  });

  testWidgets('13s Lengkap: semua 7 pasangan, label tanpa +n, ×8/9', (tester) async {
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen(sparingFull()), '13s', act: lengkap);
    expectClubScore();
    expect(find.text('+1 pasangan lainnya'), findsNothing);
    expect(find.text('Citra + Dewi'), findsOneWidget);
    expect(find.text('Semua 7 pasangan · gambar Feed 1:1 & Story 9:16'), findsOneWidget);
  });

  testWidgets('AC-S17 nomor poster = Klasemen per klub (Garuda #1–#4, Matcha #1–#3)', (tester) async {
    final data = posterOf(sparingFull(), ShareFormat.lengkap);
    expect(
      [
        for (final c in data.clubs!) [for (final r in c.rows) '${r.position} ${r.names.join(' + ')} ${r.value} ${r.diff}'],
      ],
      [
        ['1 Eko + Fajar 18 +11', '2 Andi + Budi 14 +1', '3 Gita + Hadi 14 −2', '4 Citra + Dewi 10 +3'],
        ['1 Maya + Nanda 23 +4', '2 Kiki + Lina 16 −3', '3 Indra + Joko 10 −14'],
      ],
    );
    expect(data.more, isNull);
    final ringkas = posterOf(sparingFull(), ShareFormat.ringkas);
    expect([for (final c in ringkas.clubs!) c.more], ['+1 pasangan lainnya', null]);
    expect([for (final c in ringkas.clubs!) c.rows.length], [3, 3]);
  });

  const feedAt = Rect.fromLTWH(0, 0, 360, 360), storyAt = Rect.fromLTWH(374, 0, 203, 360);
  for (final (frame, format) in [('13r', ShareFormat.ringkas), ('13t', ShareFormat.lengkap)]) {
    for (final (target, at) in [(SharePosterTarget.feed, feedAt), (SharePosterTarget.story, storyAt)]) {
      testWidgets('$frame gambar ${format.label} ${target.name}', (tester) async {
        await precacheHifiAssets(tester, [SportType.padel.assetPath]);
        await expectRegionMatchesHifi(
          tester,
          hifiStage(
            theme: MabarTheme.light(),
            at: at,
            height: at.height,
            child: ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: SharePoster(data: posterOf(sparingFull(), format), theme: ShareTheme.biru, target: target),
            ),
          ),
          frame,
          at,
          label: target.name,
        );
        expect(find.text('56 game · +13'), findsOneWidget);
        expect(find.text('PB GARUDA'), findsOneWidget);
        // Kaki gambar hanya ringkasan; "+1 pasangan lainnya" di label klub (13r).
        expect(find.text('6 round · 12 match · 1 WO'), findsOneWidget);
        expect(find.text('+1 pasangan lainnya'), format == ShareFormat.ringkas ? findsOneWidget : findsNothing);
      });
    }
  }

  testWidgets('13q caption = teks frame persis (nomor per klub dari provider)', (tester) async {
    String? copied;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, (call) async {
      if (call.method == 'Clipboard.setData') copied = (call.arguments as Map)['text'] as String;
      return null;
    });
    addTearDown(() => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(SystemChannels.platform, null));
    await precacheHifiAssets(tester, [SportType.padel.assetPath]);
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(sparingFull()));
    await tester.pumpAndSettle();

    // Share sheet tidak ada di test: share gagal dan caption disalin.
    await tester.tap(find.text('Bagikan hasil').last);
    await tester.pump();
    for (var i = 0; i < 30 && copied == null; i++) {
      await tester.runAsync(() => Future<void>.delayed(const Duration(milliseconds: 100)));
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(
      copied,
      '🏆 PB Garuda 7–5 Matcha Club · Padel\n'
      '4 November 2026\n'
      '\n'
      'Klasemen Akhir · PB Garuda\n'
      '1. Eko + Fajar — 18 game · 100.0% (3-0, +11 game)\n'
      '2. Andi + Budi — 14 game · 66.7% (2-1, +1 game)\n'
      '3. Gita + Hadi — 14 game · 33.3% (1-2, -2 game)\n'
      '4. Citra + Dewi — 10 game · 33.3% (1-2, +3 game)\n'
      '\n'
      'Klasemen Akhir · Matcha Club\n'
      '1. Maya + Nanda — 23 game · 75.0% (3-1, +4 game)\n'
      '2. Kiki + Lina — 16 game · 50.0% (2-2, -3 game)\n'
      '3. Indra + Joko — 10 game · 0.0% (0-4, -14 game)\n'
      '\n'
      '6 round · 12 match · 1 WO · 4 Nov 2026',
    );
    await tester.pump(const Duration(seconds: 3)); // toast hilang sendiri
  });
}
