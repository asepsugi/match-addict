import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';

import '../hifi_golden.dart';

/// Golden per komponen: tombol, app bar, action bar (hi-fi → Komponen; wilayah dari design/spec/rects.json).
void main() {
  final theme = MabarTheme.light();

  testWidgets('MabarButton primary + meta (03a)', (tester) async {
    final at = hifiRect('03a', 'btn');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(theme: theme, at: at, child: MabarButton(label: 'Lanjut', meta: '· ±6 round · 12 match', onPressed: () {})),
      '03a',
      at,
      label: 'button',
    );
  });

  testWidgets('MabarAppBar (03a)', (tester) async {
    final at = hifiRect('03a', 'appbar');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(theme: theme, at: at, child: MabarAppBar(title: 'Atur turnamen', subtitle: 'Tennis · 8 pemain', onBack: () {})),
      '03a',
      at,
      label: 'appbar',
    );
  });

  testWidgets('MabarActionBar: ikon solid + angka, tombol tunggu (06f)', (tester) async {
    final at = hifiRect('06f', 'actionbar');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: MabarActionBar(
          children: [
            MabarIconButton(icon: MabarIcons.ranking, semanticLabel: 'Klasemen', solid: true, onPressed: () {}),
            MabarIconButton(icon: MabarIcons.users, semanticLabel: 'Pemain', solid: true, count: 10, onPressed: () {}),
            const Expanded(child: MabarButton(label: 'Buat R4', meta: '· tunggu 1 match', variant: MabarButtonVariant.wait)),
          ],
        ),
      ),
      '06f',
      at,
      label: 'actionbar',
    );
  });

  testWidgets('MabarTextButton danger di app bar (07a)', (tester) async {
    final at = hifiRect('07a', 'appbar');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: MabarAppBar(
          title: 'Court 2',
          subtitle: 'Round 2 · Race to 6',
          onBack: () {},
          actions: [MabarTextButton(label: 'WO', tone: MabarTextTone.danger, onPressed: () {})],
        ),
      ),
      '07a',
      at,
      label: 'appbar',
    );
  });
}
