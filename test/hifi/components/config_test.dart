import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_group.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/features/konfigurasi/widgets/config_pickers.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';

/// Golden ModePicker dan warna court (Konfigurasi).
void main() {
  final theme = MabarTheme.light();

  testWidgets('ModePicker: Fixed terpilih (03a); kartu Mexicano menyusul di KF-1 bagian 2', (tester) async {
    final at = hifiRect('03a', 'modes');
    // Dibandingkan hanya sampai tepi kanan kartu Mixed: kolom ketiga (Mexicano) belum ada sampai bagian 2.
    final mixed = hifiRect('03a', 'mode', text: 'Mixed');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: ModePicker(selected: PartnerMode.fixed, onChanged: (_) {}),
      ),
      '03a',
      Rect.fromLTRB(at.left, at.top, mixed.right, at.bottom),
      label: 'modes',
    );
  });

  testWidgets('Baris court di sheet: swatch bernomor + isian sebaris + stepper (03i, grup Court)', (tester) async {
    final region = hifiRect('03i', 'group', text: 'Jumlah court');
    MabarRow court(int i, int hours, {String? name}) => MabarRow(
      leading: CourtSwatch(color: MabarColors.courtPalette[i], number: i + 1, onTap: () {}),
      titleWidget: MabarField.inline(
        controller: TextEditingController(text: name),
        hint: 'Court ${i + 1}',
      ),
      trailing: MabarStepper(value: hours, min: 1, max: 12, unit: 'jam', onChanged: (_) {}),
    );
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        background: MabarColors.card,
        at: region,
        child: MabarGroup(
          color: MabarColors.paper,
          children: [
            MabarRow(
              title: 'Jumlah court',
              trailing: MabarStepper(value: 6, min: 1, max: 10, onChanged: (_) {}),
            ),
            court(0, 2),
            court(1, 2, name: 'Court VIP'),
            court(2, 2),
            court(3, 2),
            court(4, 1),
            court(5, 1),
          ],
        ),
      ),
      '03i',
      region,
      label: 'courts',
    );
  });

  testWidgets('Baris ringkasan Skor dan Court: nilai + chevron (03a)', (tester) async {
    final at = hifiRect('03a', 'group', text: 'Race to 6');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: MabarGroup(
          children: [MabarRow(title: 'Race to 6 · 20 menit', chevron: true, onTap: () {})],
        ),
      ),
      '03a',
      at,
      label: 'row_skor',
    );
  });

  testWidgets('CourtColorGrid: warna terpilih bercincin + centang (03k)', (tester) async {
    final at = hifiRect('03k', 'swatches');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        background: MabarColors.card,
        at: at,
        child: CourtColorGrid(selected: 1, onSelect: (_) {}),
      ),
      '03k',
      at,
      label: 'swatches',
    );
  });
}
