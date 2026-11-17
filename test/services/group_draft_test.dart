import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/group_draft.dart';

/// logic.md §18.14: data test dari frame 19s–19x.
void main() {
  Pair pair(String a, String b) => Pair(id: a, player1Id: a, player2Id: b);

  const names = [
    'Andi',
    'Citra',
    'Eko',
    'Gita',
    'Indra',
    'Kiki',
    'Maya',
    'Oki',
    'Rudi',
    'Tono',
    'Vina',
    'Yoga',
    'Zaki',
  ];
  List<Pair> pairs(int n) => [for (final name in names.take(n)) pair(name, '$name-2')];

  GroupDraft draft(int n, int groups, List<List<String>> placed) => GroupDraft(pairs(n), groups, groups: placed);

  group('ukuran dan label', () {
    test('8 pasangan 2 grup → 4 + 4, label n dari t, penuh = t pasangan', () {
      final d = GroupDraft(pairs(8), 2).tap('Andi', 0).tap('Citra', 0).tap('Indra', 1);
      expect(d.targets, [4, 4]);
      expect([d.countLabel(0), d.countLabel(1)], ['2 dari 4', '1 dari 4']);
      expect(draft(8, 2, [names.sublist(0, 4), names.sublist(4, 8)]).countLabel(0), '4 pasangan');
    });

    test('7 pasangan → 4 + 3 (yang besar Grup A); 5 di A tandai kelebihan (19v)', () {
      final d = draft(7, 2, [
        ['Andi', 'Eko', 'Indra', 'Kiki', 'Maya'],
        ['Citra', 'Gita'],
      ]);
      expect(d.targets, [4, 3]);
      expect(d.isOver(0), isTrue);
      expect(d.isOver(1), isFalse);
      expect([d.countLabel(0), d.countLabel(1)], ['5 dari 4', '2 dari 3']);
    });
  });

  group('tap', () {
    test('masuk di akhir grup; urutan masuk dipertahankan (19s)', () {
      final d = GroupDraft(pairs(8), 2).tap('Eko', 0).tap('Andi', 0);
      expect(d.groups[0], ['Eko', 'Andi']);
    });

    test('huruf yang sama mengembalikan ke belum masuk grup', () {
      final d = GroupDraft(pairs(8), 2).tap('Andi', 0).tap('Andi', 0);
      expect(d.groups[0], isEmpty);
      expect(d.unassigned.length, 8);
    });

    test('huruf lain memindah grup, di akhir grup baru', () {
      final d = GroupDraft(pairs(8), 2).tap('Andi', 0).tap('Citra', 1).tap('Andi', 1);
      expect(d.groups, [
        [],
        ['Citra', 'Andi'],
      ]);
      expect(d.groupOf('Andi'), 1);
    });

    test('belum masuk grup tetap urut daftar pasangan', () {
      final d = GroupDraft(pairs(8), 2).tap('Citra', 0);
      expect([for (final p in d.unassigned) p.id], ['Andi', 'Eko', 'Gita', 'Indra', 'Kiki', 'Maya', 'Oki']);
    });
  });

  group('blockReason (AC-G2)', () {
    test('19t 16A 4 + 4 → null', () {
      expect(draft(8, 2, [names.sublist(0, 4), names.sublist(4, 8)]).blockReason, isNull);
    });

    test('19s 3 dari 8 masuk → "5 pasangan tanpa grup"; 2 dari 8 → 6', () {
      expect(
        draft(8, 2, [
          ['Andi', 'Citra'],
          ['Indra'],
        ]).blockReason,
        '5 pasangan tanpa grup',
      );
      expect(
        draft(8, 2, [
          ['Andi', 'Citra'],
          [],
        ]).blockReason,
        '6 pasangan tanpa grup',
      );
    });

    test('19r semua kosong → "8 pasangan tanpa grup"', () {
      expect(GroupDraft(pairs(8), 2).blockReason, '8 pasangan tanpa grup');
    });

    test('19v 7 pasangan 5 + 2 → "Grup A lebih 1 pasangan"; pindah satu ke B → null', () {
      final d = draft(7, 2, [
        ['Andi', 'Eko', 'Indra', 'Kiki', 'Maya'],
        ['Citra', 'Gita'],
      ]);
      expect(d.blockReason, 'Grup A lebih 1 pasangan');
      expect(d.tap('Maya', 1).blockReason, isNull);
    });

    test('7 pasangan 3 + 4 → "Grup B lebih 1 pasangan" (B ditetapkan 3)', () {
      final d = draft(7, 2, [
        ['Andi', 'Citra', 'Eko'],
        ['Gita', 'Indra', 'Kiki', 'Maya'],
      ]);
      expect(d.blockReason, 'Grup B lebih 1 pasangan');
    });

    test('19x 13 pasangan 4 grup: 4 + 3 + 3 + 3 → null, 3 + 4 + 3 + 3 → "Grup B lebih 1 pasangan"', () {
      expect(
        draft(13, 4, [
          ['Andi', 'Citra', 'Eko', 'Gita'],
          ['Indra', 'Kiki', 'Maya'],
          ['Oki', 'Rudi', 'Tono'],
          ['Vina', 'Yoga', 'Zaki'],
        ]).blockReason,
        isNull,
      );
      expect(
        draft(13, 4, [
          ['Andi', 'Citra', 'Eko'],
          ['Gita', 'Indra', 'Kiki', 'Maya'],
          ['Oki', 'Rudi', 'Tono'],
          ['Vina', 'Yoga', 'Zaki'],
        ]).blockReason,
        'Grup B lebih 1 pasangan',
      );
    });

    test('kelebihan didahulukan dari tanpa grup', () {
      final d = draft(8, 2, [
        ['Andi', 'Citra', 'Eko', 'Gita', 'Indra'],
        ['Kiki', 'Maya', 'Oki'],
      ]);
      expect(d.blockReason, 'Grup A lebih 1 pasangan');
    });
  });

  group('random (GU2)', () {
    test('semua masuk, ukuran = target, tanpa pasangan ganda; seed sama → hasil sama', () {
      final a = GroupDraft(pairs(13), 4).random(Random(7));
      expect([for (final g in a.groups) g.length], [4, 3, 3, 3]);
      expect({for (final g in a.groups) ...g}.length, 13);
      expect(a.blockReason, isNull);
      expect(GroupDraft(pairs(13), 4).random(Random(7)).groups, a.groups);
    });

    test('cleared mengosongkan semua grup', () {
      final d = GroupDraft(pairs(8), 2).random(Random(1)).cleared();
      expect(d.groups, [[], []]);
      expect(d.unassigned.length, 8);
    });
  });

  group('reconcile (19o)', () {
    // Pasangan sama (himpunan pemain, urutan dua nama boleh terbalik) tetap di grup dan posisinya, walau id berubah.
    test('pasangan tak berubah tetap; yang berubah keluar dari grupnya', () {
      final old = [pair('Andi', 'Budi'), pair('Citra', 'Dewi'), pair('Eko', 'Fajar'), pair('Gita', 'Hadi')];
      final d = GroupDraft(
        old,
        2,
        groups: [
          ['Andi', 'Citra'],
          ['Eko', 'Gita'],
        ],
      );
      final fresh = [
        Pair(id: 'x1', player1Id: 'Budi', player2Id: 'Andi'), // sama, nama terbalik, id baru
        Pair(id: 'x2', player1Id: 'Citra', player2Id: 'Fajar'), // berubah
        Pair(id: 'x3', player1Id: 'Dewi', player2Id: 'Eko'), // berubah
        Pair(id: 'x4', player1Id: 'Gita', player2Id: 'Hadi'), // sama
      ];
      final r = d.reconcile(fresh);
      expect(r.groups, [
        ['x1'],
        ['x4'],
      ]);
      expect([for (final p in r.unassigned) p.id], ['x2', 'x3']);
      expect(r.blockReason, '2 pasangan tanpa grup');
    });

    test('jumlah pasangan berubah → target ikut jumlah baru', () {
      final d = GroupDraft(pairs(8), 2).tap('Andi', 0);
      final r = d.reconcile(pairs(7));
      expect(r.targets, [4, 3]);
      expect(r.groups[0], ['Andi']);
    });
  });
}
