import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';

/// Satu angka di [StatLine]: nilai besar, satuan kecil opsional ("%"), label di bawah.
typedef StatLineItem = ({String value, String? unit, String label});

/// `.statline.s5` — lima angka di Detail (Total Point, Point %, Win, W–L(–D), selisih), dipisah garis tipis.
class StatLine extends StatelessWidget {
  final List<StatLineItem> items;

  const StatLine({super.key, required this.items});

  /// Lebar kolom (flex) lima angka: W–L–D dan selisih lebih lebar (10-detail.md, keputusan 130).
  static const _flex5 = [4, 4, 4, 5, 5];

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(MabarRadius.group),
      child: ColoredBox(
        color: MabarColors.card,
        child: IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < items.length; i++)
                Expanded(
                  flex: items.length == _flex5.length ? _flex5[i] : 1,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      border: i == 0 ? null : const Border(left: BorderSide(color: MabarColors.line)),
                    ),
                    child: Padding(
                      // Garis kiri memakan 1 pt (border-box), jadi isi kolom setelahnya bergeser 1.
                      padding: EdgeInsets.fromLTRB(i == 0 ? 6 : 7, 14, 6, 12),
                      child: Column(
                        children: [
                          // Angka yang lebih lebar dari kolomnya diperkecil, tidak dipotong ("10–5–1").
                          // Tinggi dikunci 28: FittedBox di dalam IntrinsicHeight membuat statline membengkak.
                          SizedBox(
                            height: 28,
                            child: FittedBox(
                              fit: BoxFit.scaleDown,
                              child: Text.rich(
                                TextSpan(
                                  text: items[i].value,
                                  children: [
                                    if (items[i].unit != null)
                                      TextSpan(text: items[i].unit, style: const TextStyle(fontSize: 16)),
                                  ],
                                ),
                                textAlign: TextAlign.center,
                                style: MabarType.numM.copyWith(fontSize: 28, height: 1, color: MabarColors.ink),
                              ),
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            items[i].label,
                            textAlign: TextAlign.center,
                            style: MabarType.caption.copyWith(fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
