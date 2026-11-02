import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/mabar_group.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';

import '../hifi_golden.dart';

/// Golden per komponen: grup/baris, label, segmented, stepper, chip (wilayah dari design/spec/rects.json).
void main() {
  final theme = MabarTheme.light();

  testWidgets('MabarSection + MabarGroup: segmented + dua baris stepper (03a, grup Skor)', (tester) async {
    final label = hifiRect('03a', 'glabel', text: 'Skor');
    final group = hifiRect('03a', 'group', text: 'Race to');
    final region = Rect.fromLTRB(group.left, label.top, group.right, group.bottom);
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: region,
        child: MabarSection(
          bodyGap: 12,
          header: const MabarGroupLabel('Skor'),
          child: MabarGroup(
            children: [
              MabarRow.stack(
                children: [
                  MabarSegmented(
                    options: const [(0, 'Race to'), (1, 'Best of'), (2, 'Americano')],
                    selected: 0,
                    onChanged: (_) {},
                  ),
                ],
              ),
              MabarRow(
                title: 'Target game',
                trailing: MabarStepper(value: 6, min: 2, max: 9, unit: 'game', onChanged: (_) {}),
              ),
              MabarRow(
                title: 'Durasi match',
                trailing: MabarStepper(value: 20, min: 5, max: 120, step: 5, unit: 'mnt', onChanged: (_) {}),
              ),
            ],
          ),
        ),
      ),
      '03a',
      region,
      label: 'group',
    );
  });

  testWidgets('MabarChipWrap: chip biasa + terpilih (07j, alasan WO)', (tester) async {
    final at = hifiRect('07j', 'chips');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        background: MabarColors.card,
        at: at,
        child: MabarChipWrap(
          children: [
            for (final (label, on) in [('Absen', true), ('Cedera', false), ('Waktu habis', false), ('Lainnya', false)])
              MabarChip(label: label, selected: on, onTap: () {}),
          ],
        ),
      ),
      '07j',
      at,
      label: 'chips',
    );
  });

  testWidgets('MabarChipGrid: dua kolom 44 pt (04b)', (tester) async {
    final at = hifiRect('04b', 'chips');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: MabarChipGrid(
          children: [
            for (final n in ['Citra L', 'Dewant R', 'Eko M', 'Fajar K', 'Gina R', 'Hana T'])
              MabarChip(label: n, tall: true, selected: n == 'Citra L', onTap: () {}),
          ],
        ),
      ),
      '04b',
      at,
      label: 'chips',
    );
  });

  // Fokus otomatis di Android test menggambar pegangan seleksi berbentuk tetesan; di iOS tidak.
  testWidgets('MabarField 48 + tombol (08a, Tambah pemain; isian fokus)', variant: TargetPlatformVariant.only(TargetPlatform.iOS), (tester) async {
    final field = hifiRect('08a', 'inline-field');
    final button = hifiRect('08a', 'btn', text: 'Tambah');
    final region = Rect.fromLTRB(field.left, field.top, button.right, button.bottom);
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        // Dibuat di sini: ThemeData mengunci platform saat dibuat.
        theme: MabarTheme.light(),
        background: MabarColors.card,
        at: region,
        // Tombol Tambah 48, sama tinggi dengan isian di sebelahnya.
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(child: MabarField(controller: TextEditingController(text: 'Gilang S'), autofocus: true)),
            const SizedBox(width: 8),
            MabarButton(label: 'Tambah', expand: false, height: 48, onPressed: () {}),
          ],
        ),
      ),
      '08a',
      region,
      label: 'field',
    );
  });

  testWidgets('MabarRowAction di grup sheet: netral, pulihkan, baris pudar (08a)', (tester) async {
    final label = hifiRect('08a', 'glabel', text: '10 pemain aktif · 1 keluar');
    final group = hifiRect('08a', 'group');
    // Daftar 11 baris digulir di dalam sheet; yang terlihat berhenti di atas padding bawah sheet (34).
    final region = Rect.fromLTRB(group.left, label.top, group.right, 844 - 34);
    Widget row(String name) => MabarRow(title: name, trailing: MabarRowAction(label: 'Keluarkan', onPressed: () {}));
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        background: MabarColors.card,
        at: region,
        child: MabarSection(
          header: const MabarGroupLabel('10 pemain aktif · 1 keluar'),
          child: MabarGroup(
            color: MabarColors.paper,
            children: [
              for (final n in ['Andi P', 'Budi S', 'Citra L', 'Dewant R']) row(n),
              MabarRow(
                padded: true,
                titleWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Kiki A',
                      style: MabarType.body.copyWith(color: MabarColors.faint, decoration: TextDecoration.lineThrough),
                    ),
                    const Text('Keluar · skornya tetap dihitung', style: MabarType.caption),
                  ],
                ),
                trailing: MabarRowAction(label: 'Kembalikan', restore: true, onPressed: () {}),
              ),
              for (final n in ['Eko M', 'Fajar K', 'Gina R', 'Hana T', 'Indra W', 'Joko S']) row(n),
            ],
          ),
        ),
      ),
      '08a',
      region,
      label: 'rowact',
    );
  });

  testWidgets('MabarGroupHeader dengan aksi teks (04a)', (tester) async {
    final at = hifiRect('04a', 'ghead');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: MabarGroupHeader.text(
          '4 pasangan',
          trailing: MabarTextButton(label: 'Acak ulang', icon: MabarIcons.arrowClockwise, onPressed: () {}),
        ),
      ),
      '04a',
      // Aksi 44 pt meluber dari kepala 18 pt; wilayahnya ikut dibandingkan.
      hifiRect('04a', 'txtbtn').expandToInclude(at),
      label: 'ghead',
    );
  });
}
