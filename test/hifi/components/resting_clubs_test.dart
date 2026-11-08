import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/schedule/widgets/resting_list.dart';

import '../hifi_golden.dart';

/// `RestingList.clubs` (Mixed sparing 13m, 15d, 15e, 15o): judul sama dengan daftar biasa, dua kolom klub, kolom
/// kosong "–" (docs/tasks.md SP-18a).
void main() {
  final theme = MabarTheme.light();

  Widget stage(Widget child) => hifiStage(theme: theme, at: const Rect.fromLTWH(16, 0, 358, 400), child: child);

  testWidgets('judul: Istirahat, Prioritas main di R4, Istirahat lagi di R4, judul lain', (tester) async {
    const clubs = [
      RestingClub(club: 'PB Garuda', names: ['Andi']),
      RestingClub(club: 'Matcha Club', names: []),
    ];
    await tester.pumpWidget(
      stage(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestingList.clubs(clubs: clubs),
            RestingList.clubs(clubs: clubs, priorityRound: 4),
            RestingList.clubs(clubs: clubs, priorityRound: 4, later: true),
            RestingList.clubs(clubs: clubs, title: 'Langsung main di R4'),
          ],
        ),
      ),
    );
    expect(find.text('Istirahat', findRichText: true), findsOneWidget);
    expect(find.text('Istirahat · Prioritas main di R4', findRichText: true), findsOneWidget);
    expect(find.text('Istirahat lagi di R4'), findsOneWidget);
    expect(find.text('Langsung main di R4'), findsOneWidget);
    expect(find.text('PB Garuda'), findsNWidgets(4));
    expect(find.text('Matcha Club'), findsNWidgets(4));
    expect(find.text('–'), findsNWidgets(4));
  });

  testWidgets('klub kedua di kolom kanan; Istirahat lagi pudar', (tester) async {
    await tester.pumpWidget(
      stage(
        Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestingList.clubs(
              clubs: const [
                RestingClub(club: 'PB Garuda', names: ['Eko']),
                RestingClub(club: 'Matcha Club', names: ['Joko']),
              ],
              priorityRound: 3,
            ),
            RestingList.clubs(
              clubs: const [
                RestingClub(club: 'PB Garuda', names: ['Budi']),
                RestingClub(club: 'Matcha Club', names: []),
              ],
              priorityRound: 3,
              later: true,
            ),
          ],
        ),
      ),
    );
    expect(tester.getTopLeft(find.text('Joko')).dx, greaterThan(tester.getTopLeft(find.text('Eko')).dx));
    expect(tester.getTopLeft(find.text('Matcha Club').first).dx, tester.getTopLeft(find.text('Joko')).dx);
    expect(tester.widget<Text>(find.text('Budi')).style?.color, MabarColors.ink3);
    expect(tester.widget<Text>(find.text('Eko')).style?.color, MabarColors.ink2);
  });

  testWidgets('tepat dua klub (assert)', (tester) async {
    expect(
      () => RestingList.clubs(
        clubs: const [RestingClub(club: 'PB Garuda', names: [])],
      ),
      throwsA(isA<AssertionError>()),
    );
    expect(() => RestingList.clubs(clubs: const [], later: true), throwsA(isA<AssertionError>()));
  });

  testWidgets('golden 15e: Prioritas main di R3 + Istirahat lagi di R3, kolom Matcha "–"', (tester) async {
    final first = hifiRect('15e', 'rest'), second = hifiRect('15e', 'rest', index: 1);
    final region = first.expandToInclude(second);
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: region,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            RestingList.clubs(
              clubs: const [
                RestingClub(club: 'PB Garuda', names: ['Eko', 'Hadi']),
                RestingClub(club: 'Matcha Club', names: ['Joko']),
              ],
              priorityRound: 3,
            ),
            const SizedBox(height: 16),
            RestingList.clubs(
              clubs: const [
                RestingClub(club: 'PB Garuda', names: ['Budi', 'Dewi', 'Fajar', 'Gita']),
                RestingClub(club: 'Matcha Club', names: []),
              ],
              priorityRound: 3,
              later: true,
            ),
          ],
        ),
      ),
      '15e',
      region,
      label: 'rest',
    );
  });

  testWidgets('golden 13m: Istirahat · Prioritas main di R4 per klub', (tester) async {
    final at = hifiRect('13m', 'rest');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: RestingList.clubs(
          clubs: const [
            RestingClub(club: 'PB Garuda', names: ['Andi', 'Budi', 'Dewi', 'Hadi']),
            RestingClub(club: 'Matcha Club', names: ['Kiki', 'Nanda']),
          ],
          priorityRound: 4,
        ),
      ),
      '13m',
      at,
      label: 'rest',
    );
  });
}
