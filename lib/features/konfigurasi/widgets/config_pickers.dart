import 'package:flutter/material.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../models/models.dart';

/// `.modes` — kartu mode tanpa deskripsi (keputusan 35): ilustrasi dari ikon (orang 30 pt + penghubung 16 pt, `equals`
/// = Fixed, `shuffle` = Mixed) di atas nama mode, rata tengah, tinggi 86. Warna ikut status terpilih.
///
/// [slots] = jumlah kolom; lebih besar dari [modes] menyisakan kolom kosong di kanan. Biasa tiga kolom (`.modes.m3`,
/// jarak 8), Sparing dua kolom (jarak 10). Kartu Mexicano (kolom ketiga) ditambahkan di KF-1 bagian 2.
class ModePicker extends StatelessWidget {
  final PartnerMode selected;
  final ValueChanged<PartnerMode> onChanged;
  final List<PartnerMode> modes;
  final int slots;

  const ModePicker({
    super.key,
    required this.selected,
    required this.onChanged,
    this.modes = const [PartnerMode.fixed, PartnerMode.mixed],
    this.slots = 3,
  });

  static IconData _link(PartnerMode mode) => switch (mode) {
    PartnerMode.fixed => MabarIcons.equals,
    PartnerMode.mixed => MabarIcons.shuffle,
    // Mexicano: ikon yang sama dengan Klasemen (03-konfigurasi.md); kartunya baru ditawarkan di KF-1 bagian 2.
    PartnerMode.mexicano => MabarIcons.ranking,
  };

  @override
  Widget build(BuildContext context) {
    final gap = SizedBox(width: slots >= 3 ? 8 : 10);
    return Row(
      children: [
        for (var i = 0; i < slots; i++) ...[
          if (i > 0) gap,
          Expanded(child: i < modes.length ? _card(modes[i]) : const SizedBox.shrink()),
        ],
      ],
    );
  }

  Widget _card(PartnerMode mode) {
    final on = mode == selected;
    final art = on ? MabarColors.ink : MabarColors.ink3;
    return Semantics(
      button: true,
      selected: on,
      child: SizedBox(
        height: 86,
        child: Material(
          color: MabarColors.card,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(14),
            side: BorderSide(color: on ? MabarColors.ink : MabarColors.line, width: on ? 2 : 1.5),
          ),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: () => onChanged(mode),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  height: 32,
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(MabarIcons.user, size: 30, color: art),
                      const SizedBox(width: 2),
                      Icon(_link(mode), size: 16, color: art),
                      const SizedBox(width: 2),
                      Icon(MabarIcons.user, size: 30, color: art),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  mode.label,
                  style: MabarType.body.copyWith(fontSize: 17, fontWeight: FontWeight.w700, color: MabarColors.ink),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// `.swatch` — lingkaran warna court. Dengan [number]: penanda court di baris Konfigurasi (30 pt, nomor
/// putih 15). [selected] = cincin tinta di luar dengan celah putih, plus centang (sheet warna).
class CourtSwatch extends StatelessWidget {
  final Color color;
  final double size;
  final int? number;
  final bool selected;
  final VoidCallback? onTap;

  const CourtSwatch({super.key, required this.color, this.size = 30, this.number, this.selected = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final circle = Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        // `0 0 0 3px card, 0 0 0 5px ink`: celah putih 3 lalu cincin tinta 2, di luar lingkaran.
        boxShadow: selected
            ? const [BoxShadow(color: MabarColors.ink, spreadRadius: 5), BoxShadow(color: MabarColors.card, spreadRadius: 3)]
            : null,
      ),
      child: number != null
          ? Text('$number', style: MabarType.numM.copyWith(fontSize: 15, color: Colors.white))
          : selected
          ? const Icon(MabarIcons.check, size: MabarSize.icon, color: Colors.white)
          : null,
    );
    return onTap == null
        ? circle
        : Semantics(
            button: true,
            selected: selected,
            child: GestureDetector(behavior: HitTestBehavior.opaque, onTap: onTap, child: circle),
          );
  }
}

/// `.swatches` — 10 warna court dalam 5 kolom (sheet pilih warna, 03e). Ketuk = pilih dan tutup.
class CourtColorGrid extends StatelessWidget {
  final int selected;
  final ValueChanged<int> onSelect;

  const CourtColorGrid({super.key, required this.selected, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    const palette = MabarColors.courtPalette;
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = (constraints.maxWidth - 4 * 12) / 5;
        return Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (var i = 0; i < palette.length; i++)
              CourtSwatch(color: palette[i], size: size, selected: i == selected, onTap: () => onSelect(i)),
          ],
        );
      },
    );
  }
}
