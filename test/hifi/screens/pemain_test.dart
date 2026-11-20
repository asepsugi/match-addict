import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/setup_peserta/setup_peserta_screen.dart';
import 'package:match_addict/features/setup_peserta/widgets/name_list_field.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';

/// Golden layar penuh Pemain, frame 02a–02d. Isi diketik lewat `enterText` seperti host menempel.
void main() {
  const names = [
    'Andi P', 'Budi S', 'Citra L', 'Dewant R', 'Eko M', 'Fajar K', 'Gina R', 'Hana T', 'Indra W', 'Joko S', 'Kiki A', //
    'Lina M', 'Maya P', 'Nanda R', 'Oki S', 'Putri A', 'Rizky H', 'Sari D', 'Tono B', 'Umar F', 'Vina K', //
    'Wulan S', 'Yoga P', 'Zaki M', 'Bayu S', 'Dimas A', 'Galih P', 'Rina K', 'Tari W', 'Hendra G', 'Iwan K',
  ];
  String numbered(List<String> list) => [for (var i = 0; i < list.length; i++) '${i + 1}. ${list[i]}'].join('\n');

  Widget screen(SportType sport) => hifiScreen(SetupPesertaScreen(sport: sport));

  /// Isi kotak lalu lepas fokus; kotak digulir kembali ke baris pertama seperti di frame.
  Future<void> fill(WidgetTester tester, String text, {bool keepFocus = false}) async {
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    if (keepFocus) return;
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    tester.state<ScrollableState>(find.descendant(of: find.byType(TextField), matching: find.byType(Scrollable))).position.jumpTo(0);
  }

  testWidgets('02a kosong', (tester) async {
    await expectMatchesHifi(tester, screen(SportType.tennis), '02a');
  });

  testWidgets('02b berisi + duplikat', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis),
      '02b',
      act: (tester) => fill(tester, numbered([...names.take(8), 'andi p'])),
    );
  });

  testWidgets('02c kurang dari 4, sedang mengetik', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.padel),
      '02c',
      act: (tester) => fill(tester, 'Andi P\nBudi S\nCitra L', keepFocus: true),
    );
  });

  testWidgets('02d lebih dari 30, halaman digulir sampai bawah', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis),
      '02d',
      act: (tester) async {
        await fill(tester, numbered(names));
        final page = tester.state<ScrollableState>(find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first);
        page.position.jumpTo(page.position.maxScrollExtent);
      },
    );
  });

  testWidgets('02e sesudah Hapus semua: placeholder, Lanjut mati, Tempel · Urungkan', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(SportType.tennis),
      '02e',
      act: (tester) async {
        await fill(tester, numbered([...names.take(8), 'andi p']));
        await tester.tap(find.text('Hapus semua'));
        await tester.pump();
      },
    );
  });

  testWidgets('Contoh hanya saat kosong; Hapus semua mengosongkan, Urungkan menggantikan Contoh', (tester) async {
    await tester.pumpWidget(screen(SportType.tennis));
    await tester.tap(find.text('Contoh'));
    await tester.pump();
    expect(find.text('8 pemain'), findsOneWidget);
    expect(find.text('Contoh'), findsNothing);
    await tester.tap(find.text('Hapus semua'));
    await tester.pump();
    expect(find.text('Urungkan'), findsOneWidget);
    expect(find.text('Contoh'), findsNothing);
    expect(find.textContaining('pemain'), findsNothing);
  });

  bool lanjutEnabled(WidgetTester tester) =>
      tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Lanjut')).onPressed != null;

  testWidgets('AC-P1 Urungkan mengembalikan 9 baris persis (termasuk duplikat), Lanjut aktif lagi', (tester) async {
    await tester.pumpWidget(screen(SportType.tennis));
    final text = numbered([...names.take(8), 'andi p']);
    await tester.enterText(find.byType(TextField), text);
    await tester.pump();
    expect(find.text('Duplikat dibuang: andi p'), findsOneWidget);
    await tester.tap(find.text('Hapus semua'));
    await tester.pump();
    expect(lanjutEnabled(tester), isFalse);
    expect(find.text('Duplikat dibuang: andi p'), findsNothing);
    expect(find.text('Urungkan'), findsOneWidget);
    await tester.tap(find.text('Urungkan'));
    await tester.pump();
    expect(tester.widget<TextField>(find.byType(TextField)).controller!.text, text);
    expect(find.text('8 pemain'), findsOneWidget);
    expect(find.text('Duplikat dibuang: andi p'), findsOneWidget);
    expect(lanjutEnabled(tester), isTrue);
    expect(find.text('Urungkan'), findsNothing);
    expect(find.text('Hapus semua'), findsOneWidget);
  });

  testWidgets('AC-P1 perubahan lain (ketik, Tempel) membuang Urungkan', (tester) async {
    await tester.pumpWidget(screen(SportType.tennis));
    await tester.enterText(find.byType(TextField), numbered(names.take(8).toList()));
    await tester.pump();
    await tester.tap(find.text('Hapus semua'));
    await tester.pump();
    await tester.enterText(find.byType(TextField), 'R');
    await tester.pump();
    expect(find.text('1 pemain'), findsOneWidget);
    expect(find.text('Urungkan'), findsNothing);
    expect(find.text('Hapus semua'), findsOneWidget);
    // Kosong lagi sesudahnya (bukan lewat Hapus semua): kembali ke Contoh, bukan Urungkan lama.
    await tester.enterText(find.byType(TextField), '');
    await tester.pump();
    expect(find.text('Contoh'), findsOneWidget);
    expect(find.text('Urungkan'), findsNothing);
  });

  testWidgets('AC-P1 Sparing: Hapus semua klub 1 tidak menyentuh klub 2; Urungkan hanya di kotak klub 1', (tester) async {
    tester.view.physicalSize = const Size(390, 1600) * hifiPixelRatio;
    tester.view.devicePixelRatio = hifiPixelRatio;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(screen(SportType.tennis));
    await tester.tap(find.text('Sparing'));
    await tester.pump();
    final boxes = find.byType(NameListField);
    await tester.enterText(find.descendant(of: boxes.at(0), matching: find.byType(TextField)), 'Andi\nBudi');
    await tester.enterText(find.descendant(of: boxes.at(1), matching: find.byType(TextField)), 'Indra\nJoko');
    await tester.pump();
    await tester.tap(find.descendant(of: boxes.at(0), matching: find.text('Hapus semua')));
    await tester.pump();
    expect(find.descendant(of: boxes.at(0), matching: find.text('Urungkan')), findsOneWidget);
    expect(find.descendant(of: boxes.at(1), matching: find.text('Urungkan')), findsNothing);
    expect(find.descendant(of: boxes.at(1), matching: find.text('Hapus semua')), findsOneWidget);
    expect(tester.widget<TextField>(find.descendant(of: boxes.at(1), matching: find.byType(TextField))).controller!.text, 'Indra\nJoko');
    await tester.tap(find.text('Urungkan'));
    await tester.pump();
    expect(tester.widget<TextField>(find.descendant(of: boxes.at(0), matching: find.byType(TextField))).controller!.text, 'Andi\nBudi');
  });

  testWidgets('Lanjut aktif hanya untuk 4–20 pemain', (tester) async {
    await tester.pumpWidget(screen(SportType.tennis));
    bool enabled() => tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Lanjut')).onPressed != null;
    await tester.enterText(find.byType(TextField), 'A\nB\nC');
    await tester.pump();
    expect(enabled(), isFalse);
    await tester.enterText(find.byType(TextField), 'A\nB\nC\nD');
    await tester.pump();
    expect(enabled(), isTrue);
  });
}
