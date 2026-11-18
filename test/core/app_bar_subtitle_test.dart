import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';

/// PATCH 3.8.1, B-6: subjudul penuh dipakai kalau muat satu baris, kalau tidak `shorterSubtitle` (Detail membuang
/// olahraga dulu). Font Ahem: lebar tiap huruf = ukuran font (13), jadi lebarnya pasti.
void main() {
  const full = 'Peringkat 1 · Total Point · Padel · Mixed';
  const shorter = 'Peringkat 1 · Total Point · Mixed';

  Future<void> pump(WidgetTester tester, double width, {String? shorterSubtitle = shorter}) => tester.pumpWidget(
    MaterialApp(
      home: Align(
        alignment: Alignment.topLeft,
        child: SizedBox(
          width: width,
          child: MabarAppBar(title: 'Andi P', subtitle: full, shorterSubtitle: shorterSubtitle),
        ),
      ),
    ),
  );

  testWidgets('muat: subjudul penuh', (tester) async {
    await pump(tester, 800);
    expect(find.textContaining(full, findRichText: true), findsOneWidget);
  });

  testWidgets('tidak muat: subjudul pendek', (tester) async {
    await pump(tester, 460);
    expect(find.textContaining(full, findRichText: true), findsNothing);
    expect(find.textContaining(shorter, findRichText: true), findsOneWidget);
  });

  testWidgets('tanpa pengganti: tetap subjudul penuh (elipsis)', (tester) async {
    await pump(tester, 460, shorterSubtitle: null);
    expect(find.textContaining(full, findRichText: true), findsOneWidget);
  });
}
