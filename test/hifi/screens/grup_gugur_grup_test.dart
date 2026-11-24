import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:match_addict/core/widgets/mabar_controls.dart';
import 'package:match_addict/features/groups/group_screen.dart';
import 'package:match_addict/features/pair_setup/pair_setup_screen.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/group_draft.dart';

import '../hifi_golden.dart';
import 'grup_gugur_fixture.dart';
import 'screen_harness.dart';

/// `Random` yang membuat `List.shuffle` menghasilkan urutan [target] (pola `pasangan_test.dart`).
class _ScriptedRandom implements Random {
  final List<int> _picks = [];
  var _next = 0;

  _ScriptedRandom(List<String> original, List<String> target) {
    final list = [...original];
    for (var length = list.length; length > 1; length--) {
      final pos = list.indexOf(target[length - 1]);
      _picks.add(pos);
      final tmp = list[length - 1];
      list[length - 1] = list[pos];
      list[pos] = tmp;
    }
  }

  @override
  int nextInt(int max) => _picks[_next++ % _picks.length];

  @override
  bool nextBool() => throw UnimplementedError();

  @override
  double nextDouble() => throw UnimplementedError();
}

/// Golden Pasangan Grup + Gugur dan layar Grup (GG-6), frame 19m–19y. Teks kecil lolos toleransi 2% walau salah, jadi
/// label, tombol, dan isi grup dicek juga lewat finder/state.
void main() {
  // 16 pemain 16A: pasangan dari `partners` fixture (Andi+Budi, Citra+Dewi, …), id pasangan = pemain pertama.
  List<String> roster(int pairs) => [
    for (final n in partners.keys.take(pairs)) ...[n, partners[n]!],
  ];

  GroupKnockout ko(int groups) => GroupKnockout(groupCount: groups, formats: formats16A, thirdPlace: true);

  /// Config Pasangan (belum ada pasangan) dengan [names] sebagai pemain.
  TournamentConfig playersConfig(List<String> names, {int groups = 2}) => TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.fixed,
    matchDurationMinutes: 15,
    courts: courtsOf(2),
    players: [for (final n in names) Player(id: n, name: n)],
    format: raceTo6,
    groupKnockout: ko(groups),
  );

  /// Config layar Grup: pasangan [pairs] (pemain pertama, kedua) sudah jadi.
  TournamentConfig pairedConfig(List<(String, String)> pairs, {int groups = 2}) {
    final base = playersConfig([
      for (final (a, b) in pairs) ...[a, b],
    ], groups: groups);
    return base.copyWith(
      fixedPairs: [for (final (a, b) in pairs) Pair(id: a, player1Id: a, player2Id: b)],
    );
  }

  List<(String, String)> padelPairs(int n) => [for (final k in partners.keys.take(n)) (k, partners[k]!)];

  Widget pairing(List<String> names, {Random? random}) =>
      hifiScreen(PairSetupScreen(config: playersConfig(names), random: random));

  Widget grup(TournamentConfig config, {GroupDraft? initial, Random? random}) =>
      hifiScreen(GroupScreen(config: config, initial: initial, random: random));

  Future<void> tapName(WidgetTester tester, String name) async {
    await tester.tap(find.text(name));
    await tester.pump();
  }

  /// Ketuk huruf grup [letter] di baris pasangan [pairId].
  Future<void> tapChip(WidgetTester tester, String pairId, String letter) async {
    await tester.tap(find.byKey(ValueKey('$pairId/$letter')));
    await tester.pump();
  }

  GroupDraft draft(TournamentConfig c, List<List<String>> groups) =>
      GroupDraft(c.fixedPairs!, c.groupKnockout!.groupCount, groups: groups);

  MabarButton button(WidgetTester tester) => tester.widget<MabarButton>(find.byType(MabarButton));

  group('Pasangan', () {
    testWidgets('19m dibuka Manual · kosong', (tester) async {
      await expectMatchesHifi(tester, pairing(roster(8)), '19m');
      expect(button(tester).label, 'Lanjut');
      expect(button(tester).meta, '· 8 pasangan lagi');
      expect(button(tester).icon, isNull);
      expect(find.text('0 dari 8 pasangan'), findsOneWidget);
    });

    testWidgets('19n sebagian · sedang memilih', (tester) async {
      await expectMatchesHifi(
        tester,
        pairing(roster(8)),
        '19n',
        act: (tester) async {
          for (final n in ['Andi', 'Budi', 'Citra', 'Dewi', 'Indra', 'Joko', 'Kiki']) {
            await tapName(tester, n);
          }
        },
      );
      expect(button(tester).meta, '· 5 pasangan lagi');
    });

    testWidgets('19o lengkap · label jumlah saja, tombol aktif tanpa kunci', (tester) async {
      await expectMatchesHifi(
        tester,
        pairing(roster(8)),
        '19o',
        act: (tester) async {
          for (final n in roster(8)) {
            await tapName(tester, n);
          }
        },
      );
      expect(find.text('8 pasangan'), findsOneWidget);
      expect(button(tester).label, 'Lanjut');
      expect(button(tester).onPressed, isNotNull);
      expect(button(tester).icon, isNull);
    });

    testWidgets('19p Acak dipilih', (tester) async {
      final names = roster(8);
      const order = ['Kiki', 'Lina', 'Andi', 'Budi', 'Oki', 'Putri', 'Eko', 'Fajar', 'Indra', 'Joko', 'Gita', 'Hadi'];
      final target = [...order, 'Maya', 'Nanda', 'Citra', 'Dewi'];
      await expectMatchesHifi(
        tester,
        pairing(names, random: _ScriptedRandom(names, target)),
        '19p',
        act: (tester) async {
          await tester.tap(find.text('Acak'));
          await tester.pump();
        },
      );
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('19q 17 pemain · ganjil menahan tombol', (tester) async {
      await expectMatchesHifi(
        tester,
        pairing([...roster(8), 'Rina']),
        '19q',
        act: (tester) async {
          for (final n in roster(8)) {
            await tapName(tester, n);
          }
        },
      );
      expect(button(tester).meta, '· 1 pemain tanpa pasangan');
    });
  });

  group('Grup', () {
    testWidgets('19r Manual · kosong · 2 grup', (tester) async {
      await expectMatchesHifi(tester, grup(pairedConfig(padelPairs(8))), '19r');
      expect(button(tester).meta, '· 8 pasangan tanpa grup');
      expect(find.text('Grup A · 0 dari 4', findRichText: true), findsOneWidget);
    });

    testWidgets('19s Manual · sebagian (lewat ketukan chip)', (tester) async {
      await expectMatchesHifi(
        tester,
        grup(pairedConfig(padelPairs(8))),
        '19s',
        act: (tester) async {
          await tapChip(tester, 'Andi', 'A');
          await tapChip(tester, 'Citra', 'A');
          await tapChip(tester, 'Indra', 'B');
        },
      );
      expect(button(tester).meta, '· 5 pasangan tanpa grup');
      expect(find.text('Tanpa grup · 5 pasangan'), findsOneWidget);
    });

    testWidgets('19t Manual · lengkap · 4 + 4', (tester) async {
      final c = pairedConfig(padelPairs(8));
      await expectMatchesHifi(tester, grup(c, initial: draft(c, g16A)), '19t');
      expect(button(tester).onPressed, isNotNull);
      expect(button(tester).icon, isNotNull);
    });

    testWidgets('19u Acak dipilih', (tester) async {
      final c = pairedConfig(padelPairs(8));
      const target = ['Maya', 'Citra', 'Gita', 'Indra', 'Andi', 'Oki', 'Eko', 'Kiki'];
      await expectMatchesHifi(
        tester,
        grup(c, random: _ScriptedRandom([for (final p in c.fixedPairs!) p.id], target)),
        '19u',
        act: (tester) async {
          await tester.tap(find.text('Acak'));
          await tester.pump();
        },
      );
      expect(button(tester).onPressed, isNotNull);
    });

    testWidgets('19v 7 pasangan · 5 + 2 · tidak valid', (tester) async {
      final c = pairedConfig(padelPairs(7));
      final d = draft(c, [
        ['Andi', 'Eko', 'Indra', 'Kiki', 'Maya'],
        ['Citra', 'Gita'],
      ]);
      await expectMatchesHifi(tester, grup(c, initial: d), '19v');
      expect(button(tester).meta, '· Grup A lebih 1 pasangan');
    });

    // 16 pasangan (19w, 19x): nama dari daftar contoh layar Pemain (pasangan_test).
    const names30 = [
      'Andi P',
      'Budi S',
      'Citra L',
      'Dewant R',
      'Eko M',
      'Fajar K',
      'Gina R',
      'Hana T',
      'Indra W',
      'Joko S',
      'Kiki A', //
      'Lina M', 'Maya P', 'Nanda R', 'Oki S', 'Putri A', 'Rizky H', 'Sari D', 'Tono B', 'Umar F', 'Vina K', //
      'Wulan S',
      'Yoga P',
      'Zaki M',
      'Bayu S',
      'Dimas A',
      'Galih P',
      'Rina K',
      'Tari W',
      'Hendra G',
      'Lukas J',
      'Mira D',
    ];
    List<(String, String)> pairs30(int n) => [for (var i = 0; i < n; i++) (names30[i * 2], names30[i * 2 + 1])];
    // Id pasangan = nama pemain pertama; `draft` memakai id itu.
    List<String> ids(List<String> firsts) => firsts;

    testWidgets('19w 4 grup · 16 pasangan · sebagian (terpadat)', (tester) async {
      final c = pairedConfig(pairs30(16), groups: 4);
      final d = draft(c, [
        ids(['Andi P', 'Oki S']),
        ids(['Citra L', 'Rizky H']),
        ids(['Eko M']),
        ids(['Gina R']),
      ]);
      await expectMatchesHifi(tester, grup(c, initial: d), '19w');
      expect(d.targets, [4, 4, 4, 4]);
      expect(button(tester).meta, '· 10 pasangan tanpa grup');
    });

    testWidgets('19x 3 grup · 16 pasangan · 6 + 5 + 5 · lengkap · digulir ke bawah', (tester) async {
      final c = pairedConfig(pairs30(16), groups: 3);
      final d = draft(c, [
        ids(['Andi P', 'Indra W', 'Rizky H', 'Bayu S', 'Kiki A', 'Lukas J']),
        ids(['Citra L', 'Maya P', 'Galih P', 'Oki S', 'Yoga P']),
        ids(['Eko M', 'Gina R', 'Tono B', 'Vina K', 'Tari W']),
      ]);
      await expectMatchesHifi(
        tester,
        grup(c, initial: d),
        '19x',
        act: (tester) async {
          await tester.drag(find.byType(SingleChildScrollView), const Offset(0, -3000));
          await tester.pumpAndSettle();
        },
      );
      expect(d.targets, [6, 5, 5]);
      expect(d.blockReason, isNull);
      expect(button(tester).icon, isNotNull);
    });

    testWidgets('19y dialog buat jadwal', (tester) async {
      final c = pairedConfig(padelPairs(8));
      await expectMatchesHifi(
        tester,
        grup(c, initial: draft(c, g16A)),
        '19y',
        act: (tester) async {
          await tester.tap(find.text('Buat jadwal'));
          await tester.pumpAndSettle();
        },
      );
      expect(find.text('Pasangan dan grup tidak bisa diubah setelah jadwal dibuat.'), findsOneWidget);
    });
  });

  group('perilaku', () {
    testWidgets('ketuk huruf sama mengembalikan; ke Acak lalu Manual mengosongkan tanpa konfirmasi', (tester) async {
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(grup(pairedConfig(padelPairs(8))));
      await tapChip(tester, 'Andi', 'A');
      expect(find.text('Tanpa grup · 7 pasangan'), findsOneWidget);
      await tapChip(tester, 'Andi', 'A');
      expect(find.text('Tanpa grup · 8 pasangan'), findsOneWidget);
      await tester.tap(find.text('Acak'));
      await tester.pump();
      expect(find.text('Grup A · 4 pasangan', findRichText: true), findsOneWidget);
      await tester.tap(find.text('Manual'));
      await tester.pump();
      expect(find.text('Tanpa grup · 8 pasangan'), findsOneWidget);
    });

    testWidgets('Buat jadwal → /schedule dengan groupKnockout.groups lewat copyWith (thirdPlace + format terbawa)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      final c = pairedConfig(padelPairs(8));
      TournamentConfig? sent;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => GroupScreen(config: c, initial: draft(c, g16A)),
          ),
          GoRoute(
            path: '/schedule',
            builder: (_, state) {
              sent = state.extra as TournamentConfig;
              return const Scaffold(body: Text('jadwal'));
            },
          ),
        ],
      );
      await tester.pumpWidget(hifiRouterScreen(router));
      await tester.tap(find.text('Buat jadwal'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Buat jadwal').last);
      await tester.pumpAndSettle();
      final got = sent!;
      expect(got.groupKnockout!.groups, g16A);
      expect(got.groupKnockout!.thirdPlace, isTrue);
      expect(got.groupKnockout!.formats, formats16A);
      expect(got.groupKnockout!.groupCount, 2);
      expect(got.fixedPairs, c.fixedPairs);
      expect(got.format, c.format);
    });

    testWidgets('Pasangan → Grup → kembali: pembagian dibawa, pasangan yang berubah keluar dari grupnya (19o)', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844) * hifiPixelRatio;
      tester.view.devicePixelRatio = hifiPixelRatio;
      addTearDown(tester.view.reset);
      final config = playersConfig(roster(8));
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, __) => PairSetupScreen(config: config),
          ),
          GoRoute(
            path: '/groups',
            builder: (_, state) {
              final (c, d) = state.extra as (TournamentConfig, GroupDraft?);
              return GroupScreen(config: c, initial: d);
            },
          ),
        ],
      );
      await tester.pumpWidget(hifiRouterScreen(router));
      for (final n in roster(8)) {
        await tapName(tester, n);
      }
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      expect(find.text('Grup'), findsOneWidget);
      await tapChip(tester, 'pair-Andi-Budi', 'A');
      await tapChip(tester, 'pair-Citra-Dewi', 'B');
      await tapChip(tester, 'pair-Oki-Putri', 'A');
      await tester.tap(find.bySemanticsLabel('Kembali'));
      await tester.pumpAndSettle();
      // Dua pasangan terakhir dibongkar dan dipasang silang; tiga lainnya tidak berubah.
      await tester.tap(find.text('Urungkan'));
      await tester.pump();
      await tester.tap(find.text('Urungkan'));
      await tester.pump();
      for (final n in ['Oki', 'Nanda', 'Maya', 'Putri']) {
        await tapName(tester, n);
      }
      await tester.tap(find.text('Lanjut'));
      await tester.pumpAndSettle();
      // Andi·Budi (A) dan Citra·Dewi (B) tetap; Oki·Putri hilang dari A.
      expect(find.text('Grup A · 1 dari 4', findRichText: true), findsOneWidget);
      expect(find.text('Grup B · 1 dari 4', findRichText: true), findsOneWidget);
      expect(find.text('Tanpa grup · 6 pasangan'), findsOneWidget);
    });
  });
}
