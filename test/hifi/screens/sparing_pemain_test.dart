import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/setup_peserta/setup_peserta_screen.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';

/// Golden layar Pemain pilihan Sparing, frame 13a–13g. Isi diketik lewat `enterText` seperti host mengetik/menempel.
void main() {
  const garuda = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'];
  const matcha = ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda'];
  String numbered(List<String> list) => [for (var i = 0; i < list.length; i++) '${i + 1}. ${list[i]}'].join('\n');

  Widget screen() => hifiScreen(const SetupPesertaScreen(sport: SportType.padel));

  // Urutan kotak teks Sparing: nama klub 1, pemain klub 1, nama klub 2, pemain klub 2.
  Finder box(int i) => find.byType(TextField).at(i);

  Future<void> pickSparing(WidgetTester tester) async {
    await tester.tap(find.text('Sparing'));
    await tester.pump();
  }

  Future<void> type(WidgetTester tester, int i, String text) async {
    await tester.enterText(box(i), text);
    await tester.pump();
  }

  /// Lepas fokus lalu gulirkan kotak pemain kembali ke baris pertama seperti di frame.
  Future<void> settle(WidgetTester tester, {List<int> rewind = const [1, 3]}) async {
    FocusManager.instance.primaryFocus?.unfocus();
    await tester.pump();
    for (final i in rewind) {
      tester.state<ScrollableState>(find.descendant(of: box(i), matching: find.byType(Scrollable))).position.jumpTo(0);
    }
    await tester.pump();
  }

  Future<void> scrollPage(WidgetTester tester, {bool bottom = true}) async {
    final page = tester.state<ScrollableState>(
      find.descendant(of: find.byType(SingleChildScrollView), matching: find.byType(Scrollable)).first,
    );
    page.position.jumpTo(bottom ? page.position.maxScrollExtent : 0);
    await tester.pump();
  }

  Future<void> scrollToBottom(WidgetTester tester) => scrollPage(tester);

  bool enabled(WidgetTester tester) =>
      tester.widget<MabarButton>(find.widgetWithText(MabarButton, 'Lanjut')).onPressed != null;

  /// Isi dua klub penuh (13b), tanpa melepas fokus.
  Future<void> fillBoth(WidgetTester tester, {String name2 = 'Matcha Club', List<String> club2 = matcha}) async {
    await pickSparing(tester);
    await type(tester, 0, 'PB Garuda');
    await type(tester, 1, numbered(garuda));
    await type(tester, 2, name2);
    await type(tester, 3, club2.join('\n'));
  }

  testWidgets('13a Sparing kosong', (tester) async {
    await expectMatchesHifi(tester, screen(), '13a', act: pickSparing);
    expect(find.text('Nama klub pertama'), findsOneWidget);
    expect(find.text('Nama klub kedua'), findsOneWidget);
    expect(enabled(tester), isFalse);
  });

  testWidgets('13b terisi, siap lanjut (AC-S1)', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(),
      '13b',
      act: (t) async {
        await fillBoth(t);
        await settle(t);
        // Mengetik di kotak bawah menggulir halaman; frame ini di posisi atas.
        await scrollPage(t, bottom: false);
      },
    );
    expect(find.text('8 pemain'), findsOneWidget);
    expect(find.text('6 pemain'), findsOneWidget);
    expect(enabled(tester), isTrue);
  });

  testWidgets('13c digulir ke bawah', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(),
      '13c',
      act: (t) async {
        await fillBoth(t);
        await settle(t);
        await scrollToBottom(t);
      },
    );
    expect(enabled(tester), isTrue);
  });

  testWidgets('13d klub kedua baru 1 pemain, catatan abu-abu (AC-S1)', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(),
      '13d',
      act: (t) async {
        await fillBoth(t, club2: ['Indra']);
        await settle(t, rewind: [1]);
        await t.tap(box(3));
        await t.pump();
        await scrollToBottom(t);
      },
    );
    expect(find.text('Minimal 2 pemain'), findsOneWidget);
    expect(find.text('1 pemain'), findsOneWidget);
    expect(enabled(tester), isFalse);
  });

  testWidgets('13e nama klub kosong, catatan abu-abu (AC-S2)', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(),
      '13e',
      act: (t) async {
        await fillBoth(t, name2: '');
        await settle(t);
        await scrollToBottom(t);
      },
    );
    expect(find.text('Isi nama klub'), findsOneWidget);
    expect(enabled(tester), isFalse);
  });

  testWidgets('13f nama klub sama, tepi dan catatan clay (AC-S2)', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(),
      '13f',
      act: (t) async {
        await fillBoth(t, name2: 'pb garuda');
        await settle(t);
        await scrollToBottom(t);
      },
    );
    expect(find.text('Sama dengan klub pertama'), findsOneWidget);
    expect(enabled(tester), isFalse);
  });

  testWidgets('13g pemain di dua klub, catatan menyebut nama (AC-S2)', (tester) async {
    await expectMatchesHifi(
      tester,
      screen(),
      '13g',
      act: (t) async {
        await fillBoth(t, club2: [...matcha, 'Andi']);
        await settle(t, rewind: [1]);
        await t.tap(box(3));
        await t.pump();
        await scrollToBottom(t);
      },
    );
    expect(find.text('Andi ada di dua klub'), findsOneWidget);
    expect(find.text('7 pemain'), findsOneWidget);
    expect(enabled(tester), isFalse);
  });

  testWidgets('pesan "Andi, Budi, Citra +2 ada di dua klub"', (tester) async {
    await tester.pumpWidget(screen());
    await fillBoth(tester, club2: ['Indra', 'Andi', 'Budi', 'Citra', 'Dewi', 'Eko']);
    expect(find.text('Andi, Budi, Citra +2 ada di dua klub'), findsOneWidget);
  });

  testWidgets('Contoh mengisi 8 dan 6 nama berbeda per klub, nama klub tidak ikut', (tester) async {
    await tester.pumpWidget(screen());
    await pickSparing(tester);
    for (var i = 0; i < 2; i++) {
      await tester.ensureVisible(find.text('Contoh').first);
      await tester.tap(find.text('Contoh').first);
      await tester.pump();
    }
    expect(find.text('8 pemain'), findsOneWidget);
    expect(find.text('6 pemain'), findsOneWidget);
    expect(find.text('Nama klub pertama'), findsOneWidget);
    expect(enabled(tester), isFalse);
  });

  testWidgets('nama klub maksimal 20 karakter: ketikan ke-21 tidak masuk', (tester) async {
    await tester.pumpWidget(screen());
    await pickSparing(tester);
    await type(tester, 0, 'A' * 25);
    expect(tester.widget<TextField>(box(0)).controller!.text, 'A' * 20);
  });

  testWidgets('isi tiap pilihan disimpan selama layar terbuka; default Mabar', (tester) async {
    await tester.pumpWidget(screen());
    expect(find.byType(TextField), findsOneWidget);
    await tester.enterText(box(0), 'Andi\nBudi\nCitra\nDewi');
    await tester.pump();
    await pickSparing(tester);
    expect(find.byType(TextField), findsNWidgets(4));
    await type(tester, 0, 'PB Garuda');
    await tester.tap(find.text('Mabar'));
    await tester.pump();
    expect(tester.widget<TextField>(box(0)).controller!.text, 'Andi\nBudi\nCitra\nDewi');
    expect(enabled(tester), isTrue);
    await pickSparing(tester);
    expect(tester.widget<TextField>(box(0)).controller!.text, 'PB Garuda');
    expect(enabled(tester), isFalse);
  });

  testWidgets('Lanjut sparing mengirim olahraga, dua klub, dan pemain berklub ke Atur turnamen', (tester) async {
    Object? extra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (_, _) => const SetupPesertaScreen(sport: SportType.padel),
        ),
        GoRoute(
          path: '/konfigurasi',
          builder: (_, state) {
            extra = state.extra;
            return const SizedBox();
          },
        ),
      ],
    );
    await tester.pumpWidget(hifiRouterScreen(router));
    await tester.pumpAndSettle();
    await fillBoth(tester, club2: ['Indra', 'Joko']);
    await tester.tap(find.text('Lanjut'));
    await tester.pumpAndSettle();
    final (sport, players, clubs) = extra as (SportType, List<Player>, List<Club>?);
    expect(sport, SportType.padel);
    expect([for (final c in clubs!) c.name], ['PB Garuda', 'Matcha Club']);
    expect(players, hasLength(10));
    expect(players.where((p) => p.clubId == clubs[0].id), hasLength(8));
    expect([for (final p in players.where((p) => p.clubId == clubs[1].id)) p.name], ['Indra', 'Joko']);
  });
}
