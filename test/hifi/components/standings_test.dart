import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/detail_player/widgets/stat_line.dart';
import 'package:match_addict/features/leaderboard/widgets/standing_table.dart';

import '../hifi_golden.dart';

/// Golden StandingTable (Peringkat) dan StatLine (Detail), data = data set 1 dan Fixed 09c.
void main() {
  final theme = MabarTheme.light();

  testWidgets('StandingTable: Mixed, nomor sama, belum main (09a)', (tester) async {
    final at = hifiRect('09a', 'rank');
    const rows = [
      (1, 'Andi P', '3–0–0', '+12', '42'),
      (1, 'Dewant R', '3–0–0', '+12', '42'),
      (2, 'Hana T', '1–1–1', '0', '36'),
      (3, 'Fajar K', '0–2–1', '−12', '30'),
      (4, 'Gina R', '1–0–1', '+6', '27'),
      (5, 'Citra L', '1–1–0', '+4', '26'),
      (6, 'Joko S', '1–1–0', '−2', '23'),
      (7, 'Eko M', '0–1–1', '−4', '22'),
      (8, 'Budi S', '0–2–0', '−8', '20'),
      (8, 'Indra W', '0–2–0', '−8', '20'),
    ];
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: StandingTable(
          subjectLabel: 'Pemain',
          recordLabel: 'W–L–D',
          valueLabel: 'Poin',
          rows: [
            for (final (p, n, r, d, v) in rows)
              StandingTableRow(position: p, names: [n], played: _played(r), record: r, diff: d, value: v),
          ],
          idleNames: const [
            ['Gilang S'],
          ],
        ),
      ),
      '09a',
      at,
      label: 'rank',
    );
  });

  testWidgets('StandingTable: pasangan Fixed dua baris, W–L (09c)', (tester) async {
    final at = hifiRect('09c', 'rank');
    const rows = [
      (1, ['Andi P', 'Budi S'], '4–0', '+11', '24'),
      (2, ['Gina R', 'Hana T'], '3–1', '+7', '23'),
      (3, ['Eko M', 'Fajar K'], '2–2', '−2', '16'),
      (4, ['Citra L', 'Dewant R'], '1–3', '0', '14'),
      (5, ['Indra W', 'Joko S'], '0–4', '−16', '8'),
    ];
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        child: StandingTable(
          subjectLabel: 'Pasangan',
          recordLabel: 'W–L',
          valueLabel: 'Game',
          rows: [
            for (final (p, n, r, d, v) in rows) StandingTableRow(position: p, names: n, played: _played(r), record: r, diff: d, value: v),
          ],
        ),
      ),
      '09c',
      at,
      label: 'rank',
    );
  });

  for (final (frame, items) in [
    ('10a', const <StatLineItem>[
      (value: '42', unit: null, label: 'Poin'),
      (value: '100', unit: '%', label: 'Win'),
      (value: '3–0–0', unit: null, label: 'W–L–D'),
      (value: '+12', unit: null, label: 'Selisih poin'),
    ]),
    ('10b', const <StatLineItem>[
      (value: '23', unit: null, label: 'Game'),
      (value: '75', unit: '%', label: 'Win'),
      (value: '3–1', unit: null, label: 'W–L'),
      (value: '+7', unit: null, label: 'Selisih game'),
    ]),
  ]) {
    testWidgets('StatLine ($frame)', (tester) async {
      final at = hifiRect(frame, 'statline');
      await expectRegionMatchesHifi(
        tester,
        hifiStage(theme: theme, at: at, child: StatLine(items: items)),
        frame,
        at,
        label: 'statline',
      );
    });
  }
}

/// Jumlah main = W + L + D, sama dengan kolom Main di frame.
int _played(String record) => record.split('–').map(int.parse).fold(0, (a, b) => a + b);
