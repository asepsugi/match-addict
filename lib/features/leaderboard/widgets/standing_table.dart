import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_controls.dart';

/// Satu baris [StandingTable]. [names] satu nama (Mixed) atau dua nama ditumpuk (pasangan Fixed).
class StandingTableRow {
  final int position;
  final List<String> names;

  /// Kolom Main: jumlah match yang sudah dimainkan (selesai + WO).
  final int played;

  /// Kolom W–L–D, "3–0–0" atau "4–0".
  final String record;

  /// Kolom +/−: selisih poin/game, "+12", "−4", "0". Pemisah nilai metode yang sama (logic.md §4).
  final String diff;

  /// Kolom terakhir: nilai metode ("42", "75").
  final String value;
  final VoidCallback? onTap;

  /// Fase grup Grup + Gugur: slot lolos ("A1") di kanan nama (22b). Null = tanpa tanda.
  final String? tag;

  /// Peringkat akhir Grup + Gugur: babak yang dicapai ("Juara", "Grup A · 3"), mengganti kolom Main sampai nilai
  /// (GU16). Non-null hanya kalau tabelnya memakai [StandingTable.stageLabel].
  final String? stage;

  const StandingTableRow({
    required this.position,
    required this.names,
    this.played = 0,
    this.record = '',
    this.diff = '',
    this.value = '',
    this.onTap,
    this.tag,
    this.stage,
  });
}

/// `.rank` — tabel peringkat rapat dengan angka rata kanan: # · nama · Main · W–L–D (atau W–L kalau format
/// tidak bisa seri) · +/− · nilai metode. Peringkat 1 diberi bola (semua baris bernomor 1). Pemain yang belum
/// main dikelompokkan di bawah judul "Belum main" tanpa nomor ([idleNames]).
class StandingTable extends StatelessWidget {
  /// Judul kolom nama: "Pemain" atau "Pasangan".
  final String subjectLabel;

  /// "W–L–D" atau "W–L".
  final String recordLabel;

  /// "Poin", "Game", atau "Win %".
  final String valueLabel;
  final List<StandingTableRow> rows;
  final List<List<String>> idleNames;

  /// Non-null = tabel peringkat akhir Grup + Gugur: tiga kolom (# · nama · [stageLabel] "Babak"), tanpa angka (22a).
  final String? stageLabel;

  const StandingTable({
    super.key,
    required this.subjectLabel,
    required this.recordLabel,
    required this.valueLabel,
    required this.rows,
    this.idleNames = const [],
    this.stageLabel,
  });

  @override
  Widget build(BuildContext context) {
    final children = <Widget>[
      _row(
        minHeight: 34,
        afterLine: false,
        cells: [
          Text('#', style: _head, textAlign: TextAlign.left),
          Text(subjectLabel, style: _head),
          if (stageLabel case final label?)
            Text(label, style: _head, textAlign: TextAlign.right)
          else ...[
            Text('Main', style: _head, textAlign: TextAlign.right),
            Text(recordLabel, style: _head, textAlign: TextAlign.right),
            Text('+/−', style: _head, textAlign: TextAlign.right),
            Text(valueLabel, style: _head, textAlign: TextAlign.right),
          ],
        ],
      ),
      for (final r in rows) _ranked(r),
      if (idleNames.isNotEmpty) ...[
        _row(
          minHeight: 32,
          color: _subBackground,
          cells: [
            const SizedBox(),
            Text('Belum main', style: _head),
            for (var i = 0; i < _columns - 2; i++) const SizedBox(),
          ],
        ),
        for (final names in idleNames) _idle(names),
      ],
    ];
    return ClipRRect(
      borderRadius: BorderRadius.circular(MabarRadius.group),
      child: ColoredBox(
        color: MabarColors.card,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (var i = 0; i < children.length; i++)
              if (i == 0)
                children[i]
              else
                DecoratedBox(
                  decoration: const BoxDecoration(
                    border: Border(top: BorderSide(color: MabarColors.line)),
                  ),
                  child: Padding(padding: const EdgeInsets.only(top: 1), child: children[i]),
                ),
          ],
        ),
      ),
    );
  }

  static final _head = MabarType.label.copyWith(fontSize: 12);
  static const _subBackground = Color(0xFFF5F7F9);
  static const _idleNumber = Color(0xFFA3AEB8);

  /// Lebar kolom grid: # · nama (sisa) · Main · W–L–D · +/− · nilai.
  static const _widths = <double?>[30, null, 30, 52, 36, 44];

  /// Peringkat akhir: # · nama · babak (sisa lebar, rata kanan).
  static const _stageWidths = <double?>[30, null, 160];

  int get _columns => stageLabel == null ? _widths.length : _stageWidths.length;

  /// Kolom grid [_widths], jarak 6, padding samping 14. Tinggi minimal termasuk garis atas 1 pt (border-box),
  /// jadi baris setelah garis dikurangi 1.
  Widget _row({
    required double minHeight,
    required List<Widget> cells,
    Color? color,
    VoidCallback? onTap,
    String? label,
    bool afterLine = true,
  }) {
    final row = ColoredBox(
      color: color ?? Colors.transparent,
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: minHeight - (afterLine ? 1 : 0)),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 14),
          child: Row(
            children: [
              for (final (i, cell) in cells.indexed) ...[
                if (i > 0) const SizedBox(width: 6),
                if ((stageLabel == null ? _widths : _stageWidths)[i] case final width?)
                  SizedBox(width: width, child: cell)
                else
                  Expanded(child: cell),
              ],
            ],
          ),
        ),
      ),
    );
    // Baris 44 → area ketuk 48.
    final labeled = label == null ? row : Semantics(label: label, excludeSemantics: true, child: row);
    return onTap == null
        ? labeled
        : MabarTouchOutset(
            vertical: (MabarSize.tapTarget - MabarSize.rankRow) / 2,
            child: InkWell(onTap: onTap, child: labeled),
          );
  }

  /// "Peringkat 1, Andi P, main 3, 3 menang 0 kalah 0 seri, selisih +12, 42 poin": satu baris dibaca utuh.
  String _rowLabel(StandingTableRow r) {
    final who = r.names.join(' dan ');
    if (r.stage case final stage?) return 'Peringkat ${r.position}, $who, $stage';
    final parts = r.record.split('–');
    final record = [
      for (final (i, word) in ['menang', 'kalah', 'seri'].indexed)
        if (i < parts.length) '${parts[i]} $word',
    ].join(' ');
    final unit = valueLabel == 'Win %' ? 'persen' : valueLabel.toLowerCase();
    return 'Peringkat ${r.position}, $who${r.tag == null ? '' : ' ${r.tag}'}, main ${r.played}, $record, '
        'selisih ${r.diff}, ${r.value} $unit';
  }

  Widget _ranked(StandingTableRow r) {
    final lead = r.position == 1;
    final number = lead
        ? Align(
            alignment: Alignment.centerLeft,
            child: Container(
              width: 28,
              height: 28,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: MabarColors.ball,
                shape: BoxShape.circle,
                border: Border.all(color: MabarColors.ballEdge),
              ),
              child: Text('1', style: MabarType.numM.copyWith(fontSize: 17, height: 1, color: MabarColors.ink)),
            ),
          )
        : Text(
            '${r.position}',
            textAlign: TextAlign.center,
            style: MabarType.numM.copyWith(fontSize: 20, color: MabarColors.ink2),
          );
    final names = Text(
      r.names.join('\n'),
      maxLines: r.names.length,
      overflow: TextOverflow.ellipsis,
      style: MabarType.body.copyWith(fontWeight: FontWeight.w600, color: MabarColors.ink),
    );
    return _row(
      // Pasangan Fixed: dua nama ditumpuk, baris 62 (09c).
      minHeight: r.names.length > 1 ? 62 : MabarSize.rankRow,
      onTap: r.onTap,
      label: _rowLabel(r),
      cells: [
        number,
        if (r.tag case final tag?)
          Row(
            children: [
              Expanded(child: names),
              Text(
                tag,
                style: MabarType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: MabarColors.ink3),
              ),
            ],
          )
        else
          names,
        if (r.stage case final stage?)
          _stage(stage)
        else ...[
          for (final small in ['${r.played}', r.record, r.diff])
            Text(
              small,
              textAlign: TextAlign.right,
              style: MabarType.numM.copyWith(fontSize: 18, color: MabarColors.ink2),
            ),
          Text(
            r.value,
            textAlign: TextAlign.right,
            style: MabarType.numM.copyWith(color: MabarColors.ink),
          ),
        ],
      ],
    );
  }

  /// Kolom Babak (22a): "Juara" tinta tebal, babak gugur tinta kedua, posisi grup ("Grup A · 3") abu.
  Widget _stage(String stage) {
    final (color, weight) = switch (stage) {
      'Juara' => (MabarColors.ink, FontWeight.w800),
      final s when s.startsWith('Grup ') => (MabarColors.ink3, FontWeight.w500),
      _ => (MabarColors.ink2, FontWeight.w700),
    };
    return Text(
      stage,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MabarType.body.copyWith(fontSize: 18, fontWeight: weight, color: color),
    );
  }

  Widget _idle(List<String> names) {
    final dash = MabarType.body.copyWith(color: _idleNumber);
    return _row(
      minHeight: names.length > 1 ? 62 : MabarSize.rankRow,
      cells: [
        Text(
          '–',
          textAlign: TextAlign.center,
          style: MabarType.numM.copyWith(fontSize: 20, color: _idleNumber),
        ),
        Text(
          names.join('\n'),
          maxLines: names.length,
          overflow: TextOverflow.ellipsis,
          style: MabarType.body.copyWith(color: MabarColors.ink3),
        ),
        for (var i = 0; i < _columns - 2; i++) Text('–', textAlign: TextAlign.right, style: dash),
      ],
    );
  }
}
