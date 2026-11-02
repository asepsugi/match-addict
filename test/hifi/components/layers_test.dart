import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_group.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/core/widgets/mabar_layers.dart';

import '../hifi_golden.dart';

/// Golden per komponen lapisan: sheet, dialog, menu ⋯, toast. Sudut membulat menampilkan layar di
/// belakangnya, jadi wilayah sheet dimulai di bawah radiusnya; sudut dialog/menu/toast < 1% wilayah.
void main() {
  final theme = MabarTheme.light();
  const screen = Rect.fromLTWH(0, 0, 390, 844);

  testWidgets('showMabarSheet: WO — opsi, chip alasan, footer aksi bahaya (07j)', (tester) async {
    final sheet = hifiRect('07j', 'sheet');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: sheet,
        background: MabarColors.card,
        child: MabarSheet(
          title: 'Walkover',
          subtitle: 'Round 3 · Court 2',
          footer: Row(
            children: [
              Expanded(child: MabarButton(label: 'Batal', variant: MabarButtonVariant.secondary, onPressed: () {})),
              const SizedBox(width: 10),
              Expanded(
                flex: 2,
                child: MabarButton(label: 'Simpan WO', variant: MabarButtonVariant.danger, onPressed: () {}),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const MabarGroupLabel('Siapa yang tidak main?'),
              const SizedBox(height: 8),
              MabarOption(label: 'Eko M · Budi S', sublabel: 'Kalah WO', selected: true, onTap: () {}),
              const SizedBox(height: 16),
              MabarOption(label: 'Hana T · Gina R', onTap: () {}),
              const SizedBox(height: 16),
              const MabarGroupNote('Hana T & Gina R menang WO dan dapat poin rata-rata mereka, minimal 11.'),
              const SizedBox(height: 16),
              const MabarGroupLabel('Alasan'),
              const SizedBox(height: 8),
              MabarChipWrap(
                children: [
                  for (final (label, on) in [('Absen', true), ('Cedera', false), ('Waktu habis', false), ('Lainnya', false)])
                    MabarChip(label: label, selected: on, onTap: () {}),
                ],
              ),
            ],
          ),
        ),
      ),
      '07j',
      Rect.fromLTRB(sheet.left, sheet.top + MabarRadius.sheet, sheet.right, sheet.bottom),
      label: 'sheet',
    );
  });

  testWidgets('showMabarConfirm: varian bahaya (06e)', (tester) async {
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: screen,
        height: screen.height,
        background: const Color(0xFF878E94),
        child: MabarConfirmDialog(
          title: 'Akhiri turnamen?',
          message: 'Match yang belum main tidak dihitung.',
          confirmLabel: 'Akhiri',
          destructive: true,
          onCancel: () {},
          onConfirm: () {},
        ),
      ),
      '06e',
      hifiRect('06e', 'dialog'),
      label: 'dialog',
    );
  });

  testWidgets('MabarMenu: Mixed (06i)', (tester) async {
    final at = hifiRect('06i', 'menu');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: MabarMenu<int>(
          items: const [
            MabarMenuItem(icon: MabarIcons.broadcast, label: 'Live score', value: 3),
            MabarMenuItem(icon: MabarIcons.squareSplitHorizontal, label: 'Kelola court', value: 2),
            MabarMenuItem(icon: MabarIcons.info, label: 'Cara kerja Mixed', value: 0),
            MabarMenuItem(icon: MabarIcons.flag, label: 'Akhiri turnamen', value: 1, danger: true, dividerBefore: true),
          ],
          onSelected: (_) {},
        ),
      ),
      '06i',
      at,
      label: 'menu',
    );
  });

  testWidgets('MabarToast (11c)', (tester) async {
    final at = hifiRect('11c', 'toast');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(theme: theme, at: at, child: const MabarToast(message: 'Hasil disalin')),
      '11c',
      at,
      label: 'toast',
    );
  });
}
