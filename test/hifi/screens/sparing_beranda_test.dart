import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/app_version.dart';
import 'package:match_addict/features/home/app_install.dart';
import 'package:match_addict/features/home/home_screen.dart';
import 'package:match_addict/features/home/widgets/court_banner.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi_golden.dart';
import 'screen_harness.dart';
import 'sparing_fixture.dart';
import 'sparing_mixed_fixture.dart';

/// Golden Beranda sparing, frame 14x–14y. Data = `sparingAfterR5` (R6 berjalan, 6 – 4, 10 dari 12 match).
void main() {
  Widget screen(ActiveTournament active, {ActiveTournament? last}) {
    final store = TournamentStore.memory();
    // [last] = turnamen terakhir (selesai, sudah ditutup), bukan yang berjalan.
    if (last == null) store.saveActive(active);
    return hifiScreen(
      const HomeScreen(),
      overrides: [
        tournamentStoreProvider.overrideWithValue(store),
        lastFinishedProvider.overrideWith((ref) => last),
        appInstallModeProvider.overrideWithValue(ValueNotifier(AppInstallMode.none) as ValueListenable<AppInstallMode>),
      ],
    );
  }

  Future<void> golden(
    WidgetTester tester,
    String frame,
    Widget screen, {
    Future<void> Function(WidgetTester)? act,
  }) async {
    await precacheHifiAssets(tester, [SportType.tennis.assetPath, SportType.padel.assetPath]);
    await expectMatchesHifi(tester, screen, frame, act: act);
  }

  testWidgets('14x turnamen sparing berjalan', (tester) async {
    await golden(tester, '14x', screen(sparingAfterR5()));
    // Teks kecil lolos toleransi 2% walau salah: cek terpisah.
    expect(find.text('PB Garuda'), findsOneWidget);
    expect(find.text('6 – 4'), findsOneWidget);
    expect(find.text('Matcha Club'), findsOneWidget);
    expect(find.text('Round 6'), findsOneWidget);
    expect(find.text('10 dari 12 match'), findsOneWidget);
  });

  testWidgets('14y dialog mulai turnamen baru saat sparing berjalan', (tester) async {
    await golden(
      tester,
      '14y',
      screen(sparingAfterR5()),
      act: (tester) => tester.tap(find.text('Mulai turnamen Padel')),
    );
    expect(find.text('Turnamen yang berjalan akan dihapus:\nPB Garuda vs Matcha Club, Round 6'), findsOneWidget);
  });

  testWidgets('skor klub "0 – 0" sebelum ada hasil', (tester) async {
    await tester.pumpWidget(screen(sparingSchedule()));
    await tester.pump();
    expect(find.text('0 – 0'), findsOneWidget);
  });

  testWidgets('skor klub seri tampil setengah angka', (tester) async {
    final base = sparingAfterR5();
    // Satu match yang sudah selesai dibuat seri: klub pertama dan kedua masing-masing dapat ½.
    final matches = [...base.matches];
    final i = matches.lastIndexWhere((m) => m.status == MatchStatus.done);
    matches[i] = matches[i].withScore(const [SetScore(side1: 10, side2: 10)]);
    await tester.pumpWidget(screen(base.copyWith(tournament: base.tournament.copyWith(matches: matches))));
    await tester.pump();
    expect(find.textContaining('½'), findsOneWidget);
  });

  testWidgets('15w sparing bernama berjalan: nama di baris kecil, skor dua baris di samping Round', (tester) async {
    await golden(tester, '15w', screen(mixedSparing15w().active));
    expect(find.text(mixedSparingName), findsOneWidget);
    expect(find.text('Round 4'), findsOneWidget);
    expect(find.text('PB Garuda'), findsOneWidget);
    expect(find.text('Matcha Club'), findsOneWidget);
    expect(find.text('4'), findsOneWidget);
    expect(find.text('2'), findsOneWidget);
    expect(find.text('6 dari 8 match'), findsOneWidget);
    expect(find.text('v$appVersion'), findsOneWidget);
    // Skor tidak lagi dirangkai di baris kecil.
    expect(find.text('4 – 2'), findsNothing);
  });

  testWidgets('15w: skor di samping Round tidak menambah tinggi info round', (tester) async {
    await tester.pumpWidget(screen(mixedSparing15w().active));
    await tester.pump();
    final round = tester.getRect(find.text('Round 4'));
    final progress = tester.getRect(find.text('6 dari 8 match'));
    final first = tester.getRect(find.text('PB Garuda'));
    final second = tester.getRect(find.text('Matcha Club'));
    expect(first.top, greaterThanOrEqualTo(round.top - 6));
    expect(second.bottom, lessThanOrEqualTo(round.bottom + 6));
    expect(first.top, lessThan(second.top));
    expect(progress.top, greaterThan(round.bottom));
  });

  testWidgets('15y dialog mulai baru saat sparing bernama berjalan menyebut nama turnamen', (tester) async {
    await golden(
      tester,
      '15y',
      screen(mixedSparing15w().active),
      act: (tester) => tester.tap(find.text('Mulai turnamen Padel')),
    );
    expect(find.text('Turnamen yang berjalan akan dihapus:\n$mixedSparingName, Round 4'), findsOneWidget);
  });

  testWidgets('15x turnamen terakhir Mixed sparing tanpa nama: judul memuat skor klub', (tester) async {
    final last = mixedSparing15f().active;
    await golden(tester, '15x', screen(last, last: last));
    expect(find.text('PB Garuda 10 – 6 Matcha Club', findRichText: true), findsOneWidget);
    expect(find.text('Selesai di R8 · tambah jam untuk lanjut'), findsOneWidget);
    expect(find.text('v$appVersion'), findsOneWidget);
  });

  testWidgets('turnamen terakhir Mixed sparing bernama: judul = nama turnamen saja', (tester) async {
    final last = mixedSparing15w().active;
    await tester.pumpWidget(screen(last, last: last));
    await tester.pump();
    expect(find.text(mixedSparingName), findsOneWidget);
    expect(find.textContaining('Matcha Club', findRichText: true), findsNothing);
  });

  testWidgets('turnamen terakhir Fixed sparing tidak tampil', (tester) async {
    final last = sparingAfterR5();
    await tester.pumpWidget(screen(last, last: last));
    await tester.pump();
    expect(find.textContaining('Selesai di R'), findsNothing);
  });

  // Nama pendek tidak ikut terpotong hanya karena nama temannya panjang; skor tetap utuh.
  testWidgets('baris klub: nama pendek utuh, nama panjang berelipsis, skor utuh', (tester) async {
    const long = 'Matcha Club Jakarta Selatan Besar Raya Sejahtera';
    await tester.pumpWidget(
      MaterialApp(
        home: Center(
          child: SizedBox(
            width: 300,
            child: CourtBanner(
              sport: SportType.padel,
              live: CourtBannerLive(
                subtitle: '',
                title: 'Round 6',
                progress: 0.5,
                matches: '10 dari 12 match',
                onContinue: () {},
                clubs: const CourtBannerClubs(club1: 'PB', score: '6 – 4', club2: long),
              ),
            ),
          ),
        ),
      ),
    );
    Size size(String t) => tester.getSize(find.text(t));
    final style = tester.widget<Text>(find.text('PB')).style!;
    final natural = (TextPainter(
      text: TextSpan(text: 'PB', style: style),
      textDirection: TextDirection.ltr,
    )..layout()).width;
    // Nama pendek memakai lebar alaminya (tidak terpotong, tidak melebar); sisanya untuk nama panjang.
    expect(size('PB').width, inInclusiveRange(natural, natural + 2));
    expect(size(long).width, greaterThan(150));
    expect(find.text('6 – 4'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
