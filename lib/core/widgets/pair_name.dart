import 'package:flutter/widgets.dart';

import '../../services/layout/pair_name_fit.dart';

/// `.pname` — nama pasangan satu baris "A · B" (keputusan 148, 151): dua nama di lebar hasil [PairNameFit.split],
/// masing-masing dipotong "…" sendiri; pemisah [separator] tidak pernah terpotong. Dipakai poster dan Klasemen (satu
/// aturan, logic.md §21.11). Ukuran huruf ditentukan pemanggil (loop pengecil memakai [PairName.fits]).
class PairName extends StatelessWidget {
  final String first, second;
  final TextStyle style;

  const PairName({super.key, required this.first, required this.second, required this.style});

  static const separator = ' · ';

  /// Lebar terukur (nama pertama, pemisah, nama kedua) dengan gaya dan skala teks yang sama dengan [Text].
  static (double, double, double) measure(String first, String second, TextStyle style, TextScaler scaler) {
    double width(String s) {
      final tp = TextPainter(
        text: TextSpan(text: s, style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = tp.width;
      tp.dispose();
      return w;
    }

    return (width(first), width(separator), width(second));
  }

  /// Seluruh baris muat di [avail] (kriteria loop pengecil, [PairNameFit.fits]).
  static bool fits(String first, String second, TextStyle style, double avail, {TextScaler? scaler}) {
    final (a, sep, b) = measure(first, second, style, scaler ?? TextScaler.noScaling);
    return PairNameFit.fits(a, b, sep, avail);
  }

  @override
  Widget build(BuildContext context) {
    // Gaya efektif = yang dipakai [Text] (gabung DefaultTextStyle), supaya yang diukur = yang digambar.
    final effective = DefaultTextStyle.of(context).style.merge(style);
    final scaler = MediaQuery.textScalerOf(context);
    return LayoutBuilder(
      builder: (context, box) {
        final (a, sep, b) = measure(first, second, effective, scaler);
        final (wa, wb) = PairNameFit.split(a, b, sep, box.maxWidth);
        // Nama utuh tanpa batas lebar (lebar terukur = lebar gambar); yang dipotong di kotak selebar jatahnya.
        Widget name(String s, double full, double got) {
          final text = Text(s, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis, style: style);
          return got < full ? SizedBox(width: got, child: text) : text;
        }

        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            name(first, a, wa),
            Text(separator, maxLines: 1, softWrap: false, style: style),
            name(second, b, wb),
          ],
        );
      },
    );
  }
}
