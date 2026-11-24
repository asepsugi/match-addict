import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/pair_name.dart';

/// Satu baris [StandingTable]. [names] satu nama (Mixed) atau dua nama pasangan Fixed (satu baris "A · B", 09m).
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

  /// Peringkat akhir Grup + Gugur: babak yang dicapai ("Juara 1", "Grup A · 3"), mengganti kolom Main sampai nilai
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
  Widget build(BuildContext context) =>
      LayoutBuilder(builder: (context, box) => _table(_pairSize(context, box.maxWidth)));

  /// Ukuran huruf nama pasangan satu tabel (09m, keputusan 151): 16 turun 0,5 sampai **semua** baris pasangan muat
  /// satu baris (termasuk yang di luar layar, supaya ukuran tidak berubah saat digulir), paling kecil 14; sesudah itu
  /// elipsis per nama ([PairName]). Skala teks sistem ikut diukur (A-15).
  double _pairSize(BuildContext context, double width) {
    final pairs = [
      for (final r in rows)
        if (r.names.length > 1) (r.names, r.tag),
      for (final names in idleNames)
        if (names.length > 1) (names, null),
    ];
    if (pairs.isEmpty || !width.isFinite) return _pairMax;
    final scaler = MediaQuery.textScalerOf(context);
    final widths = stageLabel == null ? _widths : _stageWidths;
    final fixed = widths.fold<double>(0, (sum, w) => sum + (w ?? 0));
    final column = width - 2 * 14 - fixed - 6 * (widths.length - 1);
    final tagWidths = {
      for (final (_, tag) in pairs)
        if (tag != null) tag: _textWidth(tag, _tagStyle, scaler),
    };
    bool fits(double size) => pairs.every((p) {
      final (names, tag) = p;
      final avail = column - (tag == null ? 0 : tagWidths[tag]!);
      return PairName.fits(names.first, names.last, _nameStyle.copyWith(fontSize: size), avail, scaler: scaler);
    });
    var size = _pairMax;
    while (size > _pairMin && !fits(size)) {
      size -= 0.5;
    }
    return size;
  }

  static double _textWidth(String text, TextStyle style, TextScaler scaler) {
    final tp = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = tp.width;
    tp.dispose();
    return w;
  }

  Widget _table(double pairSize) {
    final children = <Widget>[
      _row(
        minHeight: 34,
        afterLine: false,
        cells: [
          _headCell('#', left: true),
          _headCell(subjectLabel, left: true),
          if (stageLabel case final label?)
            _headCell(label)
          else ...[
            _headCell('Main'),
            _headCell(recordLabel),
            _headCell('+/−'),
            _headCell(valueLabel),
          ],
        ],
      ),
      for (final r in rows) _ranked(r, pairSize),
      if (idleNames.isNotEmpty) ...[
        _row(
          minHeight: 32,
          color: _subBackground,
          cells: [
            const SizedBox(),
            _headCell('Belum main', left: true),
            for (var i = 0; i < _columns - 2; i++) const SizedBox(),
          ],
        ),
        for (final names in idleNames) _idle(names, pairSize),
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

  /// Judul kolom: satu baris di kolom tetap, mengecil secukupnya kalau skala teks membuatnya tidak muat (`.ts13`).
  static Widget _headCell(String text, {bool left = false}) => FittedBox(
    fit: BoxFit.scaleDown,
    alignment: left ? Alignment.centerLeft : Alignment.centerRight,
    child: Text(text, style: _head, maxLines: 1, softWrap: false),
  );
  static final _nameStyle = MabarType.body.copyWith(fontWeight: FontWeight.w600, color: MabarColors.ink);
  static final _tagStyle = MabarType.label.copyWith(fontSize: 13, fontWeight: FontWeight.w800, color: MabarColors.ink3);

  /// `.rrow .pname` `--pn`: 16 → 14 (keputusan 151).
  static const _pairMax = 16.0, _pairMin = 14.0;
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

  Widget _ranked(StandingTableRow r, double pairSize) {
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
    final names = r.names.length > 1
        ? _pair(r.names, _nameStyle.copyWith(fontSize: pairSize))
        : _singleName(r.names.single, _nameStyle);
    return _row(
      // Pasangan Fixed satu baris setinggi baris pemain (09c, keputusan 151).
      minHeight: MabarSize.rankRow,
      onTap: r.onTap,
      label: _rowLabel(r),
      cells: [
        number,
        if (r.tag case final tag?)
          Row(
            children: [
              Expanded(child: names),
              Text(tag, style: _tagStyle),
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

  /// `.rrow.two` (09h): satu nama Mixed yang muat tetap satu baris (tinggi 44); yang lebih lebar dari kolom turun ke
  /// baris kedua di batas kata dan barisnya setinggi 62. Lebih dari dua baris →
  /// elipsis. Tinggi 62 dipaksa lewat sel setinggi 61 (baris setelah garis atas 1 pt, lihat [_row]).
  Widget _singleName(String name, TextStyle style) => LayoutBuilder(
    builder: (context, box) {
      final painter = TextPainter(
        text: TextSpan(text: name, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
        maxLines: 2,
      )..layout(maxWidth: box.maxWidth);
      final two = painter.computeLineMetrics().length > 1;
      painter.dispose();
      final text = Text(name, maxLines: 2, overflow: TextOverflow.ellipsis, style: style);
      return two
          ? SizedBox(
              height: 61,
              child: Align(alignment: Alignment.centerLeft, child: text),
            )
          : text;
    },
  );

  /// `.pname`: rata kiri, tengah vertikal di sel nama.
  Widget _pair(List<String> names, TextStyle style) => Align(
    alignment: Alignment.centerLeft,
    child: PairName(first: names.first, second: names.last, style: style),
  );

  /// Kolom Babak (22a): "Juara 1" tinta tebal, babak gugur tinta kedua, posisi grup ("Grup A · 3") abu.
  Widget _stage(String stage) {
    final (color, weight) = switch (stage) {
      'Juara 1' => (MabarColors.ink, FontWeight.w800),
      final s when s.startsWith('Grup ') => (MabarColors.ink3, FontWeight.w500),
      _ => (MabarColors.ink2, FontWeight.w600),
    };
    return Text(
      stage,
      textAlign: TextAlign.right,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: MabarType.body.copyWith(fontSize: 16, fontWeight: weight, color: color),
    );
  }

  Widget _idle(List<String> names, double pairSize) {
    final dash = MabarType.body.copyWith(color: _idleNumber);
    return _row(
      minHeight: MabarSize.rankRow,
      cells: [
        Text(
          '–',
          textAlign: TextAlign.center,
          style: MabarType.numM.copyWith(fontSize: 20, color: _idleNumber),
        ),
        if (names.length > 1)
          _pair(names, MabarType.body.copyWith(fontSize: pairSize, color: MabarColors.ink3))
        else
          _singleName(names.single, MabarType.body.copyWith(color: MabarColors.ink3)),
        for (var i = 0; i < _columns - 2; i++) Text('–', textAlign: TextAlign.right, style: dash),
      ],
    );
  }
}
