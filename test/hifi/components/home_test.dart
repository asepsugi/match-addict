import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_group.dart';
import 'package:match_addict/features/home/widgets/home_panel.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';

/// Golden panel Beranda dan langkah pasang di iPhone. Sudut atas panel (radius 24) menampilkan lapangan
/// di belakangnya — itu bagian painter (langkah 4), jadi wilayahnya dimulai di bawah radius.
void main() {
  final theme = MabarTheme.light();

  Rect belowRadius(Rect panel) => Rect.fromLTRB(panel.left, panel.top + MabarRadius.homePanel, panel.right, panel.bottom);

  testWidgets('HomePanel: Padel terpilih + turnamen terakhir + pasang di HP (01a)', (tester) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath, SportType.padel.assetPath]);
    final at = hifiRect('01a', 'homepanel');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: HomePanel(
          sport: SportType.padel,
          onSport: (_) {},
          onStart: () {},
          rows: [
            MabarRow(
              padded: true,
              leading: const MabarRowIcon(MabarIcons.clockCounterClockwise),
              title: 'Padel · Mixed · 8 pemain',
              subtitle: 'Selesai di R6 · tambah jam untuk lanjut',
              chevron: true,
              onTap: () {},
            ),
            MabarRow(
              padded: true,
              leading: const MabarRowIcon(MabarIcons.deviceMobile),
              title: 'Pasang Match Addict di HP',
              subtitle: 'Buka dari layar utama, tanpa browser',
              chevron: true,
              onTap: () {},
            ),
          ],
        ),
      ),
      '01a',
      belowRadius(at),
      label: 'homepanel',
    );
  });

  testWidgets('HomePanel: Tennis terpilih, tanpa baris tambahan (01d)', (tester) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath, SportType.padel.assetPath]);
    final at = hifiRect('01d', 'homepanel');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(theme: theme, at: at, child: HomePanel(sport: SportType.tennis, onSport: (_) {}, onStart: () {})),
      '01d',
      belowRadius(at),
      label: 'homepanel',
    );
  });

  testWidgets('InstallStep ×3 dalam grup sheet (01i)', (tester) async {
    final at = hifiRect('01i', 'group', text: 'Ketuk Bagikan');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        background: MabarColors.card,
        at: at,
        child: MabarGroup(
          color: MabarColors.paper,
          children: [
            MabarRow(
              padded: true,
              titleWidget: InstallStep(
                number: 1,
                text: [const TextSpan(text: 'Ketuk '), InstallStep.bold('Bagikan'), const TextSpan(text: ' '), InstallStep.icon(MabarIcons.export)],
                sub: 'Kalau tidak kelihatan, ada di dalam menu ···',
              ),
            ),
            MabarRow(
              padded: true,
              titleWidget: InstallStep(
                number: 2,
                text: [
                  const TextSpan(text: 'Pilih '),
                  InstallStep.bold('Tambah ke Layar Utama'),
                  const TextSpan(text: ' '),
                  InstallStep.icon(MabarIcons.plusSquare),
                ],
                sub: 'Add to Home Screen · geser ke bawah kalau belum kelihatan',
              ),
            ),
            MabarRow(
              padded: true,
              titleWidget: InstallStep(
                number: 3,
                text: [const TextSpan(text: 'Ketuk '), InstallStep.bold('Tambah'), const TextSpan(text: ' di kanan atas')],
                sub: 'Match Addict muncul di layar utama seperti app biasa',
              ),
            ),
          ],
        ),
      ),
      '01i',
      at,
      label: 'install',
    );
  });
}
