import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/core/widgets/numbered_lists.dart';
import 'package:match_addict/features/setup_peserta/widgets/name_list_field.dart';

import '../hifi_golden.dart';

/// Golden NameListField, RosterPreview, PairList (layar Pemain dan Pasangan).
void main() {
  final theme = MabarTheme.light();
  const sample = ['Andi P', 'Budi S', 'Citra L', 'Dewant R', 'Eko M', 'Fajar K', 'Gina R', 'Hana T'];

  testWidgets('NameListField kosong: contoh pudar, Tempel + Contoh (02a)', (tester) async {
    final at = hifiRect('02a', 'compose');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: NameListField(
          controller: TextEditingController(),
          hint: '1. Andi P\n2. Budi S\n3) Citra L',
          tools: [
            MabarTextButton(label: 'Tempel', icon: MabarIcons.clipboardText, onPressed: () {}),
            MabarTextButton(label: 'Contoh', icon: MabarIcons.userList, onPressed: () {}),
          ],
        ),
      ),
      '02a',
      at,
      label: 'compose',
    );
  });

  testWidgets('NameListField berisi: 6 baris + penanda gulir, Hapus semua di kanan (02b)', (tester) async {
    final at = hifiRect('02b', 'compose');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: NameListField(
          controller: TextEditingController(text: [for (var i = 0; i < 9; i++) '${i + 1}. ${[...sample, 'andi p'][i]}'].join('\n')),
          tools: [MabarTextButton(label: 'Tempel', icon: MabarIcons.clipboardText, onPressed: () {})],
          trailingTool: MabarTextButton(label: 'Hapus semua', icon: MabarIcons.trash, tone: MabarTextTone.danger, onPressed: () {}),
        ),
      ),
      '02b',
      at,
      label: 'compose',
    );
  });

  testWidgets('RosterPreview 8 pemain (02b)', (tester) async {
    final at = hifiRect('02b', 'roster');
    await expectRegionMatchesHifi(tester, hifiStage(theme: theme, at: at, child: const RosterPreview(names: sample)), '02b', at, label: 'roster');
  });

  testWidgets('RosterPreview 31 pemain: 16 kiri, 15 kanan (02d)', (tester) async {
    // 02d digulir sampai bawah: bagian atas daftar ada di bawah app bar, jadi yang dibandingkan yang terlihat saja.
    final at = hifiRect('02d', 'roster');
    final visible = Rect.fromLTRB(at.left, hifiRect('02d', 'appbar').bottom, at.right, at.bottom);
    const names = [
      ...sample,
      'Indra W', 'Joko S', 'Kiki A', 'Lina M', 'Maya P', 'Nanda R', 'Oki S', 'Putri A', 'Rizky H', 'Sari D', 'Tono B',
      'Umar F', 'Vina K', 'Wulan S', 'Yoga P', 'Zaki M', 'Bayu S', 'Dimas A', 'Galih P', 'Rina K', 'Tari W', 'Hendra G',
      'Iwan K',
    ];
    await expectRegionMatchesHifi(tester, hifiStage(theme: theme, at: at, child: const RosterPreview(names: names)), '02d', visible, label: 'roster');
  });

  testWidgets('PairList (04a)', (tester) async {
    final at = hifiRect('04a', 'pairlist');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: const PairList(pairs: [('Gina R', 'Citra L'), ('Andi P', 'Hana T'), ('Eko M', 'Fajar K'), ('Dewant R', 'Budi S')]),
      ),
      '04a',
      at,
      label: 'pairlist',
    );
  });

  testWidgets('PairList dengan pemain sisa ganjil (04c)', (tester) async {
    final at = hifiRect('04c', 'pairlist');
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: const PairList(
          pairs: [('Gina R', 'Citra L'), ('Andi P', 'Indra W'), ('Eko M', 'Fajar K'), ('Dewant R', 'Budi S')],
          leftover: 'Hana T',
        ),
      ),
      '04c',
      at,
      label: 'pairlist',
    );
  });
}
