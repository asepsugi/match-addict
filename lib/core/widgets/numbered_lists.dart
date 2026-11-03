import 'package:flutter/material.dart';

import '../theme/mabar_theme.dart';
import 'mabar_controls.dart';

// Daftar bernomor berbaris 40 pt: hasil parser di layar Pemain (`.roster`) dan pasangan Fixed
// (`.pairlist`). Gayanya sama, jadi tinggal di sini bersama.

/// Nomor kecil rata kanan di daftar bernomor (`.roster b`, `.pairlist b`).
Widget _number(String text) => SizedBox(
  width: 20,
  child: Text(text, textAlign: TextAlign.right, style: MabarType.numM.copyWith(fontSize: 17, color: MabarColors.ink3)),
);

Widget _name(String text, {Color color = MabarColors.ink}) =>
    Text(text, maxLines: 1, overflow: TextOverflow.ellipsis, style: MabarType.body.copyWith(color: color));

/// Kartu daftar berbaris [height] (40 pt) dengan garis antar-baris (garisnya memakan 1 pt, seperti CSS).
Widget _lines(List<Widget> rows, {double height = MabarSize.rosterRow}) => ClipRRect(
  borderRadius: BorderRadius.circular(MabarRadius.group),
  child: ColoredBox(
    color: MabarColors.card,
    child: Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < rows.length; i++)
            // Container menambahkan tebal garis atas ke padding, jadi isi tetap 39 di bawah garis (border-box).
            Container(
              height: height,
              decoration: i == 0 ? null : const BoxDecoration(border: Border(top: BorderSide(color: MabarColors.line))),
              child: rows[i],
            ),
        ],
      ),
    ),
  ),
);

/// `.roster` — hasil parser di layar Pemain: bernomor, dua kolom, urut ke bawah dulu (⌈n/2⌉ di kiri).
class RosterPreview extends StatelessWidget {
  final List<String> names;

  const RosterPreview({super.key, required this.names});

  @override
  Widget build(BuildContext context) {
    final rows = (names.length + 1) ~/ 2;
    Widget cell(int i) => i >= names.length
        ? const SizedBox()
        : Row(children: [_number('${i + 1}'), const SizedBox(width: 10), Expanded(child: _name(names[i]))]);
    return _lines([
      for (var r = 0; r < rows; r++)
        Row(children: [Expanded(child: cell(r)), const SizedBox(width: 12), Expanded(child: cell(r + rows))]),
    ]);
  }
}

/// `.pairlist` — pasangan Fixed: satu nomor per baris, dua kolom nama rata, tidak bisa diketuk. Pemain sisa
/// ganjil tampil di baris bernomor "–" dengan kolom kedua "tanpa pasangan" yang pudar.
///
/// `.pairlist.edit` (Atur pasangan, 04f): [onEdit] memberi tiap baris aksi "Ubah" di ujungnya dan tinggi baris 52.
class PairList extends StatelessWidget {
  final List<(String, String)> pairs;
  final String? leftover;
  final void Function(int index)? onEdit;

  const PairList({super.key, required this.pairs, this.leftover, this.onEdit});

  @override
  Widget build(BuildContext context) {
    final edit = onEdit;
    Widget row(String number, String a, String? b, {VoidCallback? onTap}) => Row(
      children: [
        _number(number),
        const SizedBox(width: 12),
        Expanded(child: _name(a)),
        const SizedBox(width: 12),
        Expanded(child: b == null ? _name('tanpa pasangan', color: MabarColors.faint) : _name(b)),
        if (onTap != null) ...[const SizedBox(width: 12), MabarRowAction(label: 'Ubah', onPressed: onTap)],
      ],
    );
    return _lines([
      for (var i = 0; i < pairs.length; i++)
        row('${i + 1}', pairs[i].$1, pairs[i].$2, onTap: edit == null ? null : () => edit(i)),
      if (leftover != null) row('–', leftover!, null),
    ], height: edit == null ? MabarSize.pairRow : MabarSize.row);
  }
}
