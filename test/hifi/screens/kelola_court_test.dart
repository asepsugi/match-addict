import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/schedule/schedule_mixed_screen.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/features/score_input/score_input_screen.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'schedule_fixture.dart';
import 'screen_harness.dart';

/// Golden + perilaku Kelola court (06p–06t, 07l, 08e–08k; menu 06i di `jadwal_mixed_test`). Data `courtTournament` (logic.md §10): mulai 19.00
/// dengan Court 1, Court 2 ditambah 20.02. Golden bertoleransi 2% piksel, jadi teks hitung mundur dicek terpisah.
void main() {
  final p = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5Court1], courts: 1);
  final q = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5]);
  final r = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5Done, courtR6, courtR7]);
  final s = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5Done, courtR6, courtR7, courtR8, courtR9]);

  List<Override> overrides(ActiveTournament active, int minutes) => [
    tournamentProvider.overrideWith(() => LoadedTournament(active)),
    clockProvider.overrideWithValue(() => fixtureStart.add(Duration(minutes: minutes))),
  ];
  Widget screen(ActiveTournament active, int minutes) =>
      hifiScreen(ScheduleMixedScreen(config: active.config), overrides: overrides(active, minutes));

  Future<void> openCourts(WidgetTester tester) async {
    await tester.tap(find.bySemanticsLabel('Menu'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Kelola court'));
    await tester.pumpAndSettle();
  }

  Future<void> openCourt(WidgetTester tester, String name, {bool plus = false}) async {
    await openCourts(tester);
    await tester.tap(find.text(name));
    await tester.pumpAndSettle();
    if (plus) {
      await tester.tap(find.bySemanticsLabel('Tambah').first);
      await tester.pumpAndSettle();
    }
  }

  /// Layar ponsel 390×844 seperti golden; ukuran bawaan test (800×600) membuat keypad Input Skor meluber.
  Future<void> pump(WidgetTester tester, Widget widget) async {
    tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(widget);
    await tester.pumpAndSettle();
  }

  ActiveTournament stateOf(WidgetTester tester) =>
      ProviderScope.containerOf(tester.element(find.byType(ScheduleMixedScreen))).read(tournamentProvider)!;

  group('golden', () {
    for (final (id, active, minutes, act) in <(String, ActiveTournament, int, Future<void> Function(WidgetTester)?)>[
      ('06p', p, 62, null),
      ('06q', q, 62, null),
      ('06r', r, 108, null),
      ('06s', s, 124, null),
      ('06t', q, 62, (t) => t.tap(find.text('R3'))),
      ('08e', p, 62, openCourts),
      ('08f', r, 108, openCourts),
      ('08g', q, 62, openCourts),
      ('08h', q, 62, (t) => openCourt(t, 'Court 2')),
      ('08i', q, 62, (t) => openCourt(t, 'Court 1', plus: true)),
      ('08j', s, 124, (t) => openCourt(t, 'Court 1')),
      ('08k', s, 124, (t) => openCourt(t, 'Court 1', plus: true)),
    ]) {
      testWidgets(id, (tester) async {
        await expectMatchesHifi(tester, screen(active, minutes), id, act: act);
      });
    }

    testWidgets('07l Input Skor · sisa court yang baru ditambah', (tester) async {
      await expectMatchesHifi(
        tester,
        hifiScreen(const ScoreInputScreen(matchId: 'r5c2'), overrides: overrides(q, 62)),
        '07l',
      );
    });
  });

  group('teks hitung mundur', () {
    testWidgets('strip: hanya di round berjalan, subjudul tanpa waktu', (tester) async {
      await pump(tester, screen(q, 62));
      expect(find.text('Padel · Americano 21'), findsOneWidget);
      expect(find.text('00:58'), findsOneWidget);
      expect(find.text('02:00'), findsOneWidget);
      await tester.tap(find.text('R3'));
      await tester.pumpAndSettle();
      expect(find.text('00:58'), findsNothing, reason: 'round lewat: strip tanpa kotak jam (06t)');
    });

    testWidgets('06r: Court 1 tinggal 00:12 → Buat R8 · 1 court, Prioritas = Citra, Gina', (tester) async {
      await pump(tester, screen(r, 108));
      expect(find.text('00:12'), findsOneWidget);
      expect(find.text('01:14'), findsOneWidget);
      expect(find.widgetWithText(MabarButton, 'Buat R8'), findsOneWidget);
      expect(find.textContaining('· 1 court'), findsOneWidget);
      expect(find.text('Citra L'), findsOneWidget);
      expect(find.text('Gina R'), findsOneWidget);
    });

    testWidgets('06s: Court 1 habis tidak tampil; R9 di Court 2 00:58', (tester) async {
      await pump(tester, screen(s, 124));
      expect(find.text('00:58'), findsOneWidget);
      for (final name in ['Citra L', 'Dewant R', 'Gina R', 'Hana T', 'Budi S', 'Indra W']) {
        expect(find.text(name), findsOneWidget);
      }
    });

    testWidgets('Input Skor: sisa court di subjudul (07l)', (tester) async {
      await pump(tester, hifiScreen(const ScoreInputScreen(matchId: 'r5c2'), overrides: overrides(q, 62)));
      expect(find.text('Round 5 · Americano 21 · sisa 02:00'), findsOneWidget);
    });

    testWidgets('Input Skor: sisa kurang dari satu match ditulis clay', (tester) async {
      await pump(tester, hifiScreen(const ScoreInputScreen(matchId: 'r5c1'), overrides: overrides(q, 112)));
      final rich = tester.widgetList<RichText>(find.byType(RichText)).map((t) => t.text.toPlainText());
      expect(rich, contains('Round 5 · Americano 21 · sisa 00:08'));
    });
  });

  group('Kelola court', () {
    testWidgets('08e: isi sheet, lalu Tambah court → match ke-2 R5 untuk 4 pemain prioritas', (tester) async {
      await pump(tester, screen(p, 62));
      await openCourts(tester);
      expect(find.text('1 court'), findsOneWidget);
      expect(find.text('19.00–21.00 · sisa 00:58'), findsOneWidget);
      expect(find.text('Sampai 22.02'), findsOneWidget);
      expect(find.text('Langsung main di R5'), findsOneWidget);
      await tester.tap(find.widgetWithText(MabarButton, 'Tambah court'));
      await tester.pumpAndSettle();
      final a = stateOf(tester);
      expect(a.matchesOfRound(5), hasLength(2));
      expect(find.text('02:00'), findsOneWidget);
      expect(find.text('0/2 match'), findsOneWidget);
    });

    testWidgets('08f/08g: tombol menulis kapan court dipakai', (tester) async {
      await pump(tester, screen(r, 108));
      await openCourts(tester);
      expect(find.textContaining('mulai R8'), findsOneWidget);
      await tester.tapAt(const Offset(195, 60));
      await tester.pumpAndSettle();

      await pump(tester, screen(q, 62));
      await openCourts(tester);
      expect(find.textContaining('belum terpakai'), findsOneWidget);
      expect(find.text('Langsung main di R5'), findsNothing);
    });

    testWidgets('08h: Simpan mati sebelum ada perubahan; Hapus → dialog → match Court 2 ikut terhapus', (tester) async {
      await pump(tester, screen(q, 62));
      await openCourt(tester, 'Court 2');
      expect(tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Simpan')).onPressed, isNull);
      await tester.tap(find.text('Hapus'));
      await tester.pumpAndSettle();
      expect(find.text('Hapus Court 2?'), findsOneWidget);
      expect(find.text('Match R5 di court ini ikut dihapus.'), findsOneWidget);
      await tester.tap(find.widgetWithText(MabarTextButton, 'Hapus').last);
      await tester.pumpAndSettle();
      final a = stateOf(tester);
      expect(a.config.courts, hasLength(1));
      expect(a.matchesOfRound(5), hasLength(1));
    });

    testWidgets('08i: court yang sudah punya skor tanpa Hapus; +1 jam hanya pratinjau sampai Simpan', (tester) async {
      await pump(tester, screen(q, 62));
      await openCourt(tester, 'Court 1', plus: true);
      expect(find.text('Hapus'), findsNothing);
      expect(find.text('19.00–22.00 · sisa 01:58'), findsOneWidget);
      expect(stateOf(tester).config.courts.first.endMinute, 120, reason: 'belum disimpan');
      await tester.tap(find.widgetWithText(MabarButton, 'Simpan'));
      await tester.pumpAndSettle();
      expect(stateOf(tester).config.courts.first.endMinute, 180);
      expect(find.text('01:58'), findsOneWidget);
    });

    testWidgets('08j–08k: court habis mulai 0 jam; +1 → 21.04–22.04, langsung main di R9', (tester) async {
      await pump(tester, screen(s, 124));
      await openCourt(tester, 'Court 1');
      expect(find.text('19.00–21.00 · waktu habis'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Tambah').first);
      await tester.pumpAndSettle();
      expect(find.text('21.04–22.04 · sisa 01:00'), findsOneWidget);
      expect(find.text('Langsung main di R9'), findsOneWidget);
      await tester.tap(find.widgetWithText(MabarButton, 'Simpan'));
      await tester.pumpAndSettle();
      final a = stateOf(tester);
      expect(a.matchesOfRound(9).map((m) => m.courtId), ['c2', 'c1']);
      expect(find.text('01:00'), findsOneWidget);
    });
  });
}
