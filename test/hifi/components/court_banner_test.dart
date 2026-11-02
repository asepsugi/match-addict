import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/court_painter.dart';
import 'package:match_addict/features/home/widgets/court_banner.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';

/// Golden banner lapangan Beranda. Wilayahnya berhenti 40 pt di atas panel: bayangan panel
/// (`0 -12px 32px`) jatuh ke lapangan, dan panelnya sendiri bagian layar (langkah 5).
void main() {
  final theme = MabarTheme.light();

  for (final (frame, sport, live) in [
    ('01b', SportType.tennis, null),
    ('01c', SportType.padel, null),
    (
      '01e',
      SportType.padel,
      CourtBannerLive(subtitle: 'Padel · Mixed · 8 pemain', title: 'Round 4', progress: 0.75, matches: '6 dari 8 match', onContinue: () {}),
    ),
    (
      '01f',
      SportType.tennis,
      CourtBannerLive(subtitle: 'Tennis · Fixed · 10 pemain', title: 'Round 2', progress: 0.3, matches: '3 dari 10 match', onContinue: () {}),
    ),
  ]) {
    testWidgets('CourtBanner ${sport.label}${live == null ? '' : ' + turnamen berjalan'} ($frame)', (tester) async {
      final band = hifiRect(frame, 'court-band'), panel = hifiRect(frame, 'homepanel');
      await expectRegionMatchesHifi(
        tester,
        hifiStage(theme: theme, at: band, height: band.height, child: CourtBanner(sport: sport, live: live)),
        frame,
        Rect.fromLTRB(band.left, band.top, band.right, panel.top - 40),
        label: 'court-band',
      );
    });
  }

  group('transisi 01g', () {
    Widget banner(SportType sport, {bool reduced = false}) => MaterialApp(
      theme: theme,
      home: MediaQuery(
        data: MediaQueryData(disableAnimations: reduced),
        child: CourtBanner(sport: sport),
      ),
    );
    List<CourtPainter> painters(WidgetTester tester) => [
      for (final w in tester.widgetList<CustomPaint>(find.byType(CustomPaint)))
        if (w.painter case final CourtPainter p) p,
    ];

    testWidgets('450 ms easeInOutCubic, garis bergerak; dibalik di tengah jalan tidak melompat', (tester) async {
      await tester.pumpWidget(banner(SportType.tennis));
      expect(painters(tester).single.t, 0);
      await tester.pumpWidget(banner(SportType.padel));
      await tester.pump(const Duration(milliseconds: 225));
      // Kurva Flutter sedikit tidak simetris: di tengah waktu posisinya ±0,52.
      final mid = painters(tester).single.t;
      expect(mid, closeTo(0.5, 0.05));
      await tester.pumpWidget(banner(SportType.tennis));
      await tester.pump();
      expect(painters(tester).single.t, closeTo(mid, 0.02));
      await tester.pumpAndSettle();
      expect(painters(tester).single.t, 0);
    });

    testWidgets('reduce motion: crossfade 150 ms dua gambar diam', (tester) async {
      await tester.pumpWidget(banner(SportType.tennis, reduced: true));
      await tester.pumpWidget(banner(SportType.padel, reduced: true));
      await tester.pump(const Duration(milliseconds: 75));
      expect(painters(tester).map((p) => p.t), [0, 1]);
      await tester.pump(const Duration(milliseconds: 75));
      expect(painters(tester).single.t, 1);
    });
  });
}
