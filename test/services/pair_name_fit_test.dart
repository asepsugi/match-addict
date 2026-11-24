import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/services/layout/pair_name_fit.dart';

void main() {
  group('PairNameFit.split (logic.md §21.11)', () {
    test('nama pertama di bawah jatah: utuh, nama kedua memakai sisanya', () {
      expect(PairNameFit.split(40, 120, 10, 100), (40, 50));
    });

    test('dua nama di atas jatah: masing-masing (avail − sep) ÷ 2', () {
      expect(PairNameFit.split(80, 90, 10, 100), (45, 45));
    });

    test('seluruh baris muat: dua nama utuh', () {
      expect(PairNameFit.split(30, 40, 10, 100), (30, 40));
    });

    test('nama kedua di bawah jatah: utuh, nama pertama memakai sisanya (09m "Citra … · Dewi")', () {
      expect(PairNameFit.split(120, 30, 10, 100), (60, 30));
    });

    test('tepat muat dihitung muat', () {
      expect(PairNameFit.split(45, 45, 10, 100), (45, 45));
      expect(PairNameFit.fits(45, 45, 10, 100), isTrue);
      expect(PairNameFit.fits(45, 45.01, 10, 100), isFalse);
    });

    test('kolom lebih sempit dari pemisah: nama dapat 0, pemisah tetap', () {
      expect(PairNameFit.split(20, 30, 10, 6), (0, 0));
    });

    test('hasil tidak pernah melebihi kolom dan tidak memanjangkan nama', () {
      for (final a in const <double>[0, 12, 40, 84, 90, 200]) {
        for (final b in const <double>[0, 12, 40, 84, 90, 200]) {
          for (final avail in const <double>[20, 100, 176, 238]) {
            final (x, y) = PairNameFit.split(a, b, 9, avail);
            expect(x + 9 + y, lessThanOrEqualTo(avail + 1e-9), reason: '$a $b $avail');
            expect((x <= a, y <= b), (true, true), reason: '$a $b $avail');
          }
        }
      }
    });
  });
}
