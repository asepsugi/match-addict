import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/club_score.dart';

import '../hifi_golden.dart';

/// Golden `.clubscore` (SP-6). Widget hanya menerima nilai jadi, jadi data tiap frame ditulis persis seperti
/// di hi-fi. Angka kecil lolos toleransi 2% walau salah, maka dicek juga dengan `find.text`.
void main() {
  final theme = MabarTheme.light();

  ClubScoreRow row(
    String name,
    String detail,
    String score, {
    bool lead = false,
  }) => ClubScoreRow(name: name, detail: detail, score: score, lead: lead);

  for (final (frame, label, first, second) in [
    (
      '13k',
      'klub pertama unggul',
      row('PB Garuda', '45 game · +8', '6', lead: true),
      row('Matcha Club', '43 game · −8', '4'),
    ),
    (
      '14s',
      'klub kedua unggul',
      row('PB Garuda', '56 game · −4', '5'),
      row('Matcha Club', '60 game · +4', '7', lead: true),
    ),
    (
      '14t',
      'Seri, bola dua',
      row('PB Garuda', '58 game · 0', '6', lead: true),
      row('Matcha Club', '58 game · 0', '6', lead: true),
    ),
    (
      '14u',
      'match seri, poin',
      row('PB Garuda', '122 poin · +4', '6½', lead: true),
      row('Matcha Club', '118 poin · −4', '5½'),
    ),
    (
      '14m',
      '0 – 0 tanpa bola',
      row('PB Garuda', '0 game · 0', '0'),
      row('Matcha Club', '0 game · 0', '0'),
    ),
  ]) {
    testWidgets('ClubScore $label ($frame)', (tester) async {
      final at = hifiRect(frame, 'clubscore');
      await expectRegionMatchesHifi(
        tester,
        hifiStage(
          theme: theme,
          at: at,
          background: MabarColors.paper,
          child: ClubScore(first: first, second: second),
        ),
        frame,
        at,
        label: 'clubscore',
      );
      expect(find.text(first.name), findsOneWidget);
      expect(find.text(second.name), findsOneWidget);
      final sameDetail = first.detail == second.detail;
      expect(
        find.text(first.detail),
        sameDetail ? findsNWidgets(2) : findsOneWidget,
      );
      expect(
        find.text(second.detail),
        sameDetail ? findsNWidgets(2) : findsOneWidget,
      );
      // Detail/skor yang sama di kedua baris (Seri, 0 – 0) muncul dua kali.
      final same = first.score == second.score;
      expect(find.text(first.score), same ? findsNWidgets(2) : findsOneWidget);
      expect(find.text(second.score), same ? findsNWidgets(2) : findsOneWidget);
    });
  }
}
