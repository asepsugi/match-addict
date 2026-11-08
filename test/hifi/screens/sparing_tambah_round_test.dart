import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/pair_edit/pair_edit_screen.dart';
import 'package:match_addict/features/schedule/schedule_fixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/pair_draft.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';

/// Golden sheet Tambah round sparing 14n dan Atur pasangan sparing 14o, plus AC-S18 dan jalur simpan (SP-16).
void main() {
  late TournamentStore store;

  Widget screen(ActiveTournament active, DateTime now) => hifiScreen(
    ScheduleFixedScreen(config: active.config),
    overrides: [
      tournamentStoreProvider.overrideWithValue(store),
      tournamentProvider.overrideWith(() => LoadedTournament(active)),
      clockProvider.overrideWithValue(() => now),
    ],
  );

  setUp(() => store = TournamentStore.memory());

  Future<void> openSheet(WidgetTester tester) async {
    await tester.tap(find.text('Tambah round'));
    await tester.pumpAndSettle();
  }

  Future<void> pump(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  /// Ketik nama di kotak klub ke-[club] (0 = PB Garuda, 1 = Matcha Club) lalu Tambah; bagian bawah perlu digulir.
  Future<void> typeNew(WidgetTester tester, int club, String name) async {
    final field = find.byType(TextField).at(club);
    await tester.ensureVisible(field);
    await tester.pump();
    await tester.enterText(field, name);
    final add = find.text('Tambah').at(club);
    await tester.ensureVisible(add);
    await tester.pump();
    await tester.tap(add);
    await tester.pump();
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
  }

  /// 14o: Citra · Dewi diubah, Gilang diketik di PB Garuda, Citra dipilih.
  Future<void> garudaReplace(WidgetTester tester) async {
    await tester.tap(find.text('Ubah').at(1));
    await tester.pump();
    await typeNew(tester, 0, 'Gilang');
    await tester.tap(find.text('Citra'));
  }

  Widget editor(ActiveTournament a) =>
      hifiScreen(PairEditScreen(initial: PairDraft.of(a.config), sport: SportType.padel, firstRound: 7));

  testWidgets('14n sheet tambah round sparing: ringkasan per klub · AC-S18', (tester) async {
    await expectMatchesHifi(tester, screen(sparingFull(), sparingAt(6)), '14n', act: openSheet);
    expect(find.text('4 + 3 pasangan · sama dengan sebelumnya'), findsOneWidget);
    expect(find.text('match lagi tiap pasangan PB Garuda'), findsOneWidget);
    expect(find.text('match lagi tiap pasangan Matcha Club'), findsOneWidget);
    expect(find.text('3'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('6 round (R7–R12) · 2 court · lewat booking 01:00'), findsOneWidget);
    expect(find.text('Buat R7–R12'), findsOneWidget);
  });

  testWidgets('pasangan sama (3 + 3): satu angka tanpa nama klub', (tester) async {
    final equal = sparingScored(
      sparingSchedule(sparingConfig(garudaPlayers: garudaNames.take(6).toList())),
      scores13c,
      filled: 9,
    );
    await pump(tester, screen(equal, sparingAt(5)));
    await openSheet(tester);
    expect(find.text('match lagi tiap pasangan'), findsOneWidget);
    expect(find.text('match lagi tiap pasangan PB Garuda'), findsNothing);
    expect(find.text('match lagi tiap pasangan Matcha Club'), findsNothing);
    expect(find.text('3 + 3 pasangan · sama dengan sebelumnya'), findsOneWidget);
    expect(find.textContaining(' round (R'), findsOneWidget);
  });

  testWidgets('AC-S18: 1 jam di kedua court → tetap 1 satuan, tanpa lewat booking', (tester) async {
    await pump(tester, screen(sparingFull(), sparingAt(6)));
    await openSheet(tester);
    await tester.tap(find.bySemanticsLabel('Tambah').first);
    await tester.pump();
    await tester.tap(find.bySemanticsLabel('Tambah').last);
    await tester.pump();
    expect(find.text('6 round (R7–R12) · 2 court'), findsOneWidget);
    expect(find.textContaining('lewat booking'), findsNothing);
    expect(find.text('match lagi tiap pasangan PB Garuda'), findsOneWidget);
  });

  testWidgets('14o atur pasangan sparing: pengganti di satu klub', (tester) async {
    await expectMatchesHifi(tester, editor(sparingFull()), '14o', act: garudaReplace);
    expect(find.text('PB Garuda · 3 pasangan'), findsOneWidget);
    expect(find.text('Matcha Club · 3 pasangan'), findsOneWidget);
    expect(find.text('Ketuk satu lagi untuk dipasangkan dengan Citra'), findsOneWidget);
    expect(find.text('Nama pemain baru'), findsNWidgets(2));
  });

  testWidgets('Atur pasangan: Citra lalu Nanda (beda klub) memindah pilihan, tidak berpasangan', (tester) async {
    await pump(tester, editor(sparingFull()));
    await tester.tap(find.text('Ubah').at(1));
    await tester.pump();
    await tester.tap(find.text('Ubah').at(5));
    await tester.pump();
    await tester.tap(find.text('Citra'));
    await tester.pump();
    await tester.tap(find.text('Nanda'));
    await tester.pump();
    expect(find.text('PB Garuda · 3 pasangan'), findsOneWidget);
    expect(find.text('Matcha Club · 2 pasangan'), findsOneWidget);
    expect(find.text('Ketuk satu lagi untuk dipasangkan dengan Nanda'), findsOneWidget);
  });

  testWidgets('Simpan mati "· minimal 1 pasangan tiap klub" kalau satu klub tanpa pasangan', (tester) async {
    await pump(tester, editor(sparingFull()));
    for (var i = 0; i < 3; i++) {
      await tester.tap(find.text('Ubah').at(4));
      await tester.pump();
    }
    expect(find.text('Matcha Club · 0 pasangan'), findsOneWidget);
    final button = tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Simpan pasangan'));
    expect(button.onPressed, isNull);
    expect(button.meta, '· minimal 1 pasangan tiap klub');
  });

  testWidgets('Nama baru diketik di klubnya, nama kembar antar klub ditolak', (tester) async {
    await pump(tester, editor(sparingFull()));
    await typeNew(tester, 1, 'Oki');
    expect(find.text('Oki'), findsOneWidget);
    await typeNew(tester, 0, 'oki');
    expect(find.text('Oki sudah ada di daftar'), findsOneWidget);
  });

  testWidgets('Atur pasangan 14o → Buat R7–R12 = sparingReplaced (14p), tersimpan sah', (tester) async {
    final full = sparingFull();
    await pump(
      tester,
      hifiScreen(
        ScheduleFixedScreen(config: full.config),
        overrides: [
          tournamentStoreProvider.overrideWithValue(store),
          tournamentProvider.overrideWith(() => _Saving(full)),
          clockProvider.overrideWithValue(() => sparingAt(6)),
        ],
      ),
    );
    await openSheet(tester);
    await tester.tap(find.text('Pasangan'));
    await tester.pumpAndSettle();
    await garudaReplace(tester);
    await tester.tap(find.text('Gilang'));
    await tester.pump();
    // Bagian Matcha Club: Nanda diubah, Oki diketik, Maya · Oki.
    await tester.tap(find.text('Ubah').at(6));
    await tester.pump();
    await typeNew(tester, 1, 'Oki');
    await tester.ensureVisible(find.text('Maya'));
    await tester.pump();
    await tester.tap(find.text('Maya'));
    await tester.pump();
    await tester.ensureVisible(find.text('Oki'));
    await tester.pump();
    await tester.tap(find.text('Oki'));
    await tester.pump();
    await tester.tap(find.text('Simpan pasangan'));
    await tester.pumpAndSettle();
    expect(find.text('4 + 3 pasangan · 2 baru · 2 tidak main'), findsOneWidget);
    expect(find.text('Buat R7–R12'), findsOneWidget);
    await tester.tap(find.text('Buat R7–R12'));
    await tester.pumpAndSettle();

    final saved = store.loadActive()!;
    final expected = sparingReplaced();
    // Id pasangan dan pemain baru dari uuid: bandingkan lewat nama dan klub.
    String names(ActiveTournament a, Pair p) =>
        p.playerIds.map((id) => a.config.players.firstWhere((x) => x.id == id).name).join('+');
    List<String> shape(ActiveTournament a) => [
      for (final m in a.matches)
        '${m.roundNumber}.${m.matchNumberInRound}@${m.courtId} ${names(a, m.pair1)} v ${names(a, m.pair2)}',
    ];
    expect(shape(saved), shape(expected));
    expect(
      [for (final p in saved.config.fixedPairs!) names(saved, p)],
      [for (final p in expected.config.fixedPairs!) names(expected, p)],
    );
    expect(
      [for (final p in saved.config.players) '${p.name}@${p.clubId}'],
      [for (final p in expected.config.players) '${p.name}@${p.clubId}'],
    );
    expect(saved.extraPutaran, expected.extraPutaran);
    expect(saved.roundCount, 12);
    expect(TournamentCodec.decode(TournamentCodec.encode(saved)), isNotNull);
  });
}

/// Seperti `LoadedTournament` (config identik dengan yang dioper ke layar) tapi auto-save controller asli tetap jalan,
/// supaya hasil "Buat R7–R12" bisa dibaca dari simpanan.
class _Saving extends TournamentController {
  final ActiveTournament active;
  _Saving(this.active);

  @override
  ActiveTournament? build() {
    super.build();
    return active;
  }
}
