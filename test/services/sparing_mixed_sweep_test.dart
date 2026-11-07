@Tags(['slow'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'sparing_mixed_property.dart';

/// Sweep penuh test properti Mixed sparing (logic.md §13.12). Lama (±11 menit), jadi bertag `slow` dan dilewati di
/// `flutter test` biasa (dart_test.yaml). Jalankan sebelum rilis: `flutter test --tags slow --run-skipped` — tanpa
/// `--run-skipped` tidak ada yang dijalankan. Satu test per jumlah pemain klub pertama supaya batas waktunya wajar.
void main() {
  for (var n1 = 2; n1 <= 28; n1++) {
    test('AC-S9 Mixed sparing: klub pertama $n1, klub kedua 2–${30 - n1} × court 1/2/3/4/7/10 × 30 round', () {
      for (var n2 = 2; n1 + n2 <= 30; n2++) {
        for (final c in [1, 2, 3, 4, 7, 10]) {
          checkSize(n1, n2, c);
        }
      }
    }, timeout: const Timeout(Duration(minutes: 2)));
  }
}
