import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_icons.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/core/widgets/mabar_inputs.dart';
import 'package:match_addict/core/widgets/match_score_row.dart';
import 'package:match_addict/features/live/live_score.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/schedule/widgets/round_tabs.dart';
import 'package:match_addict/features/score_input/widgets/score_board.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/scoring/score_entry.dart';

/// PATCH 3.8.1 (P1 kontras, P2 area ketuk + Semantics): label pembaca layar dari `design/spec/components.md` →
/// Semantics, dan area ketuk ≥ 48 yang tidak mengubah tata letak.
class _FakeLive extends LiveViewController {
  final LiveView view;
  _FakeLive(this.view);

  @override
  LiveView? build() => view;
}

Matcher _enabled(bool value) => isA<SemanticsNode>().having(
  (n) => n.getSemanticsData().flagsCollection.isEnabled.name,
  'isEnabled',
  value ? 'isTrue' : 'isFalse',
);

final _liveRegion = isA<SemanticsNode>().having(
  (n) => n.getSemanticsData().flagsCollection.isLiveRegion,
  'liveRegion',
  true,
);

Widget _host(Widget child, {List<Override> overrides = const []}) => ProviderScope(
  overrides: overrides,
  child: MaterialApp(
    theme: MabarTheme.light(),
    home: Scaffold(
      body: Align(
        alignment: Alignment.topLeft,
        // Margin di dalam Align: perluasan area ketuk hanya bekerja di dalam kotak induk.
        child: Padding(padding: const EdgeInsets.all(40), child: child),
      ),
    ),
  ),
);

void main() {
  testWidgets('MatchScoreRow: label tim dan strip court', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        MatchScoreRow(
          badge: '1',
          badgeColor: MabarColors.courtPalette[0],
          badgeSemantics: 'Court 1, sisa 1 jam 15 menit',
          top: const MatchScoreSide(names: ['Andi P', 'Budi S'], scores: ['6'], win: true),
          bottom: const MatchScoreSide(names: ['Citra L', 'Dewi N'], scores: ['4'], tone: MatchScoreTone.lost),
        ),
      ),
    );
    // Tanpa onTap tiap bagian jadi simpul sendiri; label per tim memuat status menang dan skor.
    expect(find.bySemanticsLabel(RegExp('Court 1, sisa 1 jam 15 menit')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Andi P · Budi S, menang, 6')), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp('Citra L · Dewi N, 4')), findsOneWidget);
    // Skor yang kalah ink-3 (5,3:1), bukan abu pucat 2,3:1.
    expect(tester.widget<Text>(find.text('4')).style!.color, MabarColors.ink3);
    handle.dispose();
  });

  testWidgets('RoundTabs: label status, gembok, tab terkunci tetap bisa diketuk (juga 4 pt di atasnya)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    final tapped = <int>[];
    await tester.pumpWidget(
      _host(RoundTabs(count: 4, selected: 2, liveRound: 2, isFuture: (r) => r > 2, onSelect: tapped.add)),
    );
    expect(find.bySemanticsLabel('R2, berjalan'), findsOneWidget);
    expect(find.bySemanticsLabel('R4, terkunci'), findsOneWidget);
    expect(find.byIcon(MabarIcons.lockSimple), findsNWidgets(2));
    final r4 = tester.getRect(find.text('R4'));
    await tester.tapAt(r4.center);
    // Kotak tab mulai 6 pt di atas teks; 3 pt lagi di atasnya = area perluasan (maks 5).
    await tester.tapAt(Offset(r4.center.dx, r4.top - 6 - 3));
    expect(tapped, [4, 4]);
    // Tab 22 pt dari R3 ke R4: celah antartab jatuh ke tab terdekat.
    final r3 = tester.getRect(find.text('R3'));
    await tester.tapAt(Offset(r3.right + 14, r3.center.dy));
    expect(tapped.last, 4);
    handle.dispose();
  });

  testWidgets('ScoreKeypad: ⌫ mati tanpa kotak aktif, tombol → "Kotak berikutnya"', (tester) async {
    final handle = tester.ensureSemantics();
    const format = ScoreFormat(ScoringMethod.raceTo, 6);
    final edit = ScoreEntry.edit(format, const SetScore(side1: 6, side2: 4));
    await tester.pumpWidget(_host(ScoreKeypad(entry: edit, onChanged: (_) {})));
    expect(tester.getSemantics(find.bySemanticsLabel('Hapus')), _enabled(false));
    expect(find.bySemanticsLabel('Kotak berikutnya'), findsOneWidget);

    await tester.pumpWidget(_host(ScoreKeypad(entry: ScoreEntry.start(format), onChanged: (_) {})));
    expect(tester.getSemantics(find.bySemanticsLabel('Hapus')), _enabled(true));
    handle.dispose();
  });

  testWidgets('ScoreBoard: kotak skor dibaca dengan nama tim, nilai, dan status dipilih', (tester) async {
    final handle = tester.ensureSemantics();
    const format = ScoreFormat(ScoringMethod.raceTo, 6);
    final entry = ScoreEntry.start(format).type(6);
    await tester.pumpWidget(
      _host(
        ScoreBoard(entry: entry, names: (const ['Eko M', 'Fajar K'], const ['Gina R', 'Hana T']), onSelect: (_) {}),
      ),
    );
    expect(find.bySemanticsLabel('Skor Eko M & Fajar K, 6'), findsOneWidget);
    expect(find.bySemanticsLabel('Skor Gina R & Hana T, kosong, dipilih'), findsOneWidget);
    handle.dispose();
  });

  testWidgets('LiveTag offline: "Offline · 19.48" sebagai live region', (tester) async {
    final handle = tester.ensureSemantics();
    final lastOk = DateTime(2026, 11, 18, 19, 48);
    await tester.pumpWidget(
      _host(
        const LiveTag(),
        overrides: [liveViewProvider.overrideWith(() => _FakeLive(LiveView(LiveViewStatus.offline, null, lastOk)))],
      ),
    );
    expect(find.text('Offline · 19.48'), findsOneWidget);
    expect(tester.getSemantics(find.bySemanticsLabel('Offline · 19.48')), _liveRegion);
    handle.dispose();
  });

  testWidgets('LiveTag live: "Live" sebagai live region', (tester) async {
    final handle = tester.ensureSemantics();
    await tester.pumpWidget(
      _host(
        const LiveTag(),
        overrides: [liveViewProvider.overrideWith(() => _FakeLive(const LiveView(LiveViewStatus.live)))],
      ),
    );
    expect(tester.getSemantics(find.bySemanticsLabel('Live')), _liveRegion);
    handle.dispose();
  });

  testWidgets('MabarStepper: label "Kurangi durasi, 15 menit" dan area ketuk 48 (6 pt di luar tombol 36)', (
    tester,
  ) async {
    final handle = tester.ensureSemantics();
    var value = 30;
    await tester.pumpWidget(
      _host(
        StatefulBuilder(
          builder: (context, setState) => MabarStepper(
            semanticName: 'durasi',
            value: value,
            min: 15,
            max: 120,
            step: 15,
            unit: 'mnt',
            onChanged: (v) => setState(() => value = v),
          ),
        ),
      ),
    );
    expect(find.bySemanticsLabel('Kurangi durasi, 30 menit'), findsOneWidget);
    expect(find.bySemanticsLabel('Tambah durasi'), findsOneWidget);
    final minus = tester.getRect(find.byIcon(MabarIcons.minus));
    // 5 pt di atas tepi tombol 36 (ikon 20 di tengah: tepi tombol = pusat ± 18).
    await tester.tapAt(Offset(minus.center.dx, minus.center.dy - 18 - 5));
    expect(value, 15);
    handle.dispose();
  });

  testWidgets('MabarSegmented: ketukan 2 pt di luar track tetap memilih segmen', (tester) async {
    var selected = 'a';
    await tester.pumpWidget(
      _host(
        MabarSegmented<String>(
          options: const [('a', 'Satu'), ('b', 'Dua')],
          selected: selected,
          onChanged: (v) => selected = v,
        ),
      ),
    );
    final box = tester.getRect(find.byType(MabarSegmented<String>));
    await tester.tapAt(Offset(box.right - 20, box.bottom + 1.5));
    expect(selected, 'b');
  });
}
