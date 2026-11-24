// Nama pasangan satu baris "A · B" (keputusan 148, 150, 151; logic.md §21.11). Dart murni: hanya lebar terukur
// (px pada ukuran huruf yang sama), pengukuran teks milik widget `PairName`. Satu aturan untuk poster dan Klasemen.

/// Pembagian lebar dua nama pasangan = perilaku CSS `.pname` (span `flex: 1 1 0; max-width: max-content`, pemisah
/// `flex: none`).
abstract final class PairNameFit {
  /// Lebar yang didapat nama pertama dan kedua dari [avail] setelah pemisah [sep] (tidak pernah dipotong). Seluruh
  /// baris muat → keduanya utuh; selain itu jatah h = (avail − sep) ÷ 2: nama yang ≤ h utuh dan sisanya dipakai nama
  /// lain, kalau dua-duanya > h masing-masing h. Lebar hasil < lebar nama = nama itu dipotong "…" sendiri.
  static (double, double) split(double a, double b, double sep, double avail) {
    if (fits(a, b, sep, avail)) return (a, b);
    final rest = avail - sep < 0 ? 0.0 : avail - sep;
    final h = rest / 2;
    if (a <= h) return (a, rest - a);
    if (b <= h) return (rest - b, b);
    return (h, h);
  }

  /// "Muat" untuk loop pengecil huruf = seluruh baris muat (sama dengan `fits()` di `tool/hifi_poster_fit.py`: semua
  /// span `.pname` utuh ⇔ seluruh baris muat).
  static bool fits(double a, double b, double sep, double avail) => a + sep + b <= avail;
}
