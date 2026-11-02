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

  testWidgets('ModePicker: Fixed terpilih (03a)', (tester) async {
    final at = hifiRect('03a', 'modes');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(theme: theme, at: at, child: ModePicker(selected: PartnerMode.fixed, onChanged: (_) {})),
      '03a',
      at,
      label: 'modes',
    );
  });

  testWidgets('Baris court: swatch bernomor + isian sebaris + stepper (03a, grup Court)', (tester) async {
    final label = hifiRect('03a', 'glabel', text: 'Court');
    final group = hifiRect('03a', 'group', text: 'Jumlah court');
    final region = Rect.fromLTRB(group.left, label.top, group.right, group.bottom);
    MabarRow court(int i) => MabarRow(
      leading: CourtSwatch(color: MabarColors.courtPalette[i], number: i + 1, onTap: () {}),
      titleWidget: MabarField.inline(hint: 'Court ${i + 1}'),
      trailing: MabarStepper(value: 2, min: 1, max: 12, unit: 'jam', onChanged: (_) {}),
    );
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: region,
        child: MabarSection(
          bodyGap: 12,
          header: const MabarGroupLabel('Court'),
          child: MabarGroup(
            children: [
              MabarRow(title: 'Jumlah court', trailing: MabarStepper(value: 2, min: 1, max: 10, onChanged: (_) {})),
              court(0),
              court(1),
            ],
          ),
        ),
      ),
      '03a',
      region,
      label: 'courts',
    );
  });

  testWidgets('CourtColorGrid: warna terpilih bercincin + centang (03e)', (tester) async {
    final at = hifiRect('03e', 'swatches');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(theme: theme, background: MabarColors.card, at: at, child: CourtColorGrid(selected: 1, onSelect: (_) {})),
      '03e',
      at,
      label: 'swatches',
    );
  });
}
