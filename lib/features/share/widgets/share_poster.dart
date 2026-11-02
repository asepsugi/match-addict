import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_ball.dart';
import '../../../models/models.dart';
import '../share_theme.dart';

/// Di mana poster tampil: kartu pratinjau di layar Bagikan, atau salah satu dari dua gambar yang
/// dibagikan. Gambar dirancang di ukuran frame hi-fi ([designSize]) lalu dirender ke 1080 px.
enum SharePosterTarget {
  preview,

  /// Feed 1:1 — 1080×1080.
  feed,

  /// Story 9:16 — 1080×1920.
  story;

  /// Ukuran rancangan gambar (frame 11d/11f/11g); pratinjau mengikuti lebar layar.
  Size get designSize => switch (this) {
    SharePosterTarget.preview => const Size(358, 372),
    SharePosterTarget.feed => const Size(360, 360),
    SharePosterTarget.story => const Size(202.5, 360),
  };

  /// pixelRatio saat merender gambar ke file: lebar 1080 px.
  double get exportPixelRatio => 1080 / designSize.width;
}

/// Satu baris poster. [names] satu nama, atau dua nama pasangan Fixed (digabung "A + B", ditumpuk di
/// Story). [value] = nilai metode ("42", "75%"); sesudahnya keterangan kecil "[detail] · [diff]" ("poin ·
/// +12"). Satuan [detail] hanya di satu kolom selain Story; selisih [diff] selalu ada ("42 · +12"), karena
/// dialah yang menjelaskan nomor berbeda untuk nilai yang sama (logic.md §4).
class SharePosterRow {
  final int position;
  final List<String> names;
  final String value;
  final String? detail;
  final String diff;

  const SharePosterRow({required this.position, required this.names, required this.value, this.detail, required this.diff});
}

/// Isi poster yang sudah jadi teks.
class SharePosterData {
  final SportType sport;

  /// Nama turnamen, atau "Padel · Mixed · 21 Okt 2026" kalau tanpa nama (ditulis kapital di poster).
  final String eyebrow;
  final bool isFinal;
  final List<SharePosterRow> rows;

  /// "+6 pemain lainnya" / "+n pasangan lainnya" — hanya Ringkas.
  final String? more;

  /// "3 round · 6 match · 1 WO" (+ " · 21 Okt 2026" kalau turnamen bernama).
  final String summary;

  /// Lengkap = semua baris berbagi tinggi kartu; Ringkas di pratinjau = baris setinggi isinya.
  final bool complete;

  const SharePosterData({
    required this.sport,
    required this.eyebrow,
    required this.isFinal,
    required this.rows,
    required this.summary,
    this.more,
    this.complete = false,
  });
}

/// Ukuran huruf satu tata letak baris (font dasar/nama, nomor, nilai) dan lebar kolom nomor. Angka-angka
/// ini dipilih tangan per varian di hi-fi (11a–11j), bukan hasil rumus; di atas frame terpadat dikecilkan
/// [SharePoster._density].
typedef _RowSizes = ({double text, double rank, double value, double rankWidth});

/// `.poster` — kartu/gambar hasil: wordmark + bola, keterangan, judul berpiala, daftar peringkat, kaki.
/// Nomor ditulis "#n"; semua baris peringkat 1 diberi lencana emas bertulisan tinta. Lebih dari 10 pemain
/// (Mixed) di pratinjau dan Feed dibagi dua kolom rata (⌈n/2⌉ di kiri, urut ke bawah, baris kiri-kanan
/// sejajar); pasangan dan Story selalu satu kolom. Semua warna diturunkan dari tinta [theme].
class SharePoster extends StatelessWidget {
  final SharePosterData data;
  final ShareTheme theme;
  final SharePosterTarget target;

  const SharePoster({super.key, required this.data, required this.theme, required this.target});

  bool get _story => target == SharePosterTarget.story;
  bool get _pairRows => data.rows.any((r) => r.names.length > 1);

  /// Pasangan (Fixed) tidak pernah dua kolom: nama kedua anggota butuh lebar penuh, di kolom sempit yang kedua
  /// terpotong habis.
  bool get _twoColumns => !_story && data.rows.length > 10 && !_pairRows;
  bool get _stackPairs => _story && _pairRows;

  /// Lengkap yang lebih padat dari frame terpadat yang disetujui (Story 20 baris nama, 11f/11g; satu kolom 10
  /// baris, 11b/11g; dua kolom 15 baris per kolom, 11l) mengecilkan semua huruf baris sebanding: 30 baris nama
  /// di Story → 20/30. Dua kolom lewat 15 baris hanya kalau pemain yang keluar ikut di klasemen (30 aktif + keluar).
  double get _density {
    if (!data.complete) return 1;
    if (_twoColumns) return min(1, 15 / ((data.rows.length + 1) ~/ 2));
    final lines = data.rows.length * (_stackPairs ? 2 : 1);
    return min(1, (_story ? 20 : 10) / lines);
  }

  /// Tinggi baris teks poster, sama di kartu pratinjau dan gambar. Gambar dulu mewarisi 1,55 dari dokumen
  /// hi-fi dan kaki Feed Ringkas meluber dari padding; disamakan atas keputusan host 2026-10-22.
  static const _lineHeight = 1.4;

  _RowMode get _mode => data.complete
      ? _RowMode.share
      : (target == SharePosterTarget.preview ? _RowMode.natural : _RowMode.atLeastContent);

  _RowSizes get _rowSizes {
    final (:text, :rank, :value, :rankWidth) = _presetSizes;
    final d = _density;
    return (text: text * d, rank: rank * d, value: value * d, rankWidth: rankWidth * d);
  }

  _RowSizes get _presetSizes {
    switch (target) {
      case SharePosterTarget.preview:
        if (!data.complete) return (text: 14, rank: 18, value: 18, rankWidth: 32);
        if (_twoColumns) return (text: 12, rank: 13, value: 13.5, rankWidth: 24);
        return data.rows.length >= 10
            ? (text: 12.5, rank: 14, value: 14, rankWidth: 32)
            : (text: 13, rank: 15, value: 15, rankWidth: 32);
      case SharePosterTarget.feed:
        if (!data.complete) return (text: 14, rank: 18, value: 18, rankWidth: 32);
        if (_twoColumns) return (text: 11.5, rank: 12.5, value: 13, rankWidth: 24);
        return (text: 12, rank: 14, value: 14, rankWidth: 32);
      case SharePosterTarget.story:
        if (!data.complete) return (text: 11, rank: 14, value: 14, rankWidth: 22);
        if (_stackPairs) return (text: 9.5, rank: 11, value: 11, rankWidth: 20);
        return (text: 9.5, rank: 9.5, value: 10, rankWidth: 20);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ink = theme.ink;
    final (EdgeInsets padding, double word, double wordGap, double ball, double eyebrow, double title, double trophy) =
        switch (target) {
          SharePosterTarget.preview => (const EdgeInsets.all(22), 15.0, 7.0, 18.0, 11.0, 26.0, 24.0),
          SharePosterTarget.feed => (
            const EdgeInsets.symmetric(horizontal: 26, vertical: 24),
            17.0,
            data.complete ? 7.0 : 8.0,
            20.0,
            11.0,
            28.0,
            26.0,
          ),
          SharePosterTarget.story => (
            const EdgeInsets.fromLTRB(14, 22, 14, 18),
            13.0,
            data.complete ? 7.0 : 6.0,
            data.complete ? 16.0 : 15.0,
            8.5,
            19.0,
            18.0,
          ),
        };
    final (double wmWidth, double wmRight, double wmBottom) = switch (target) {
      SharePosterTarget.preview => (150.0, -18.0, -14.0),
      SharePosterTarget.feed => (223.0, -30.0, -26.0),
      SharePosterTarget.story => (126.0, -18.0, -14.0),
    };

    final base = MabarType.body.copyWith(color: ink, height: _lineHeight);
    final header = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        _CssLines(
          fontSize: word,
          lineHeight: _lineHeight,
          child: Row(
            children: [
              MabarBall(size: ball),
              SizedBox(width: wordGap),
              // Story sempit + teks diperbesar: wordmark mengecil, tidak meluber.
              Flexible(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Match Addict',
                    style: base.copyWith(fontSize: word, fontWeight: FontWeight.w800, fontVariations: const [FontVariation('wdth', 125)]),
                  ),
                ),
              ),
            ],
          ),
        ),
        SizedBox(height: target == SharePosterTarget.preview && !data.complete ? 14 : 12),
        _CssLines(
          fontSize: eyebrow,
          lineHeight: _lineHeight,
          child: Opacity(
            opacity: 0.75,
            child: Text(
              data.eyebrow.toUpperCase(),
              // Nama turnamen panjang turun ke baris kedua di Story; "olahraga · mode · tanggal" selalu sebaris.
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: base.copyWith(fontSize: eyebrow, fontWeight: FontWeight.w700, letterSpacing: eyebrow * 0.08),
            ),
          ),
        ),
        const SizedBox(height: 6),
        _CssLines(
          fontSize: title,
          lineHeight: 1.05,
          child: Row(
            children: [
              Icon(MabarIcons.trophy, size: trophy, color: theme.trophy),
              const SizedBox(width: 8),
              Flexible(
                child: Text(
                  data.isFinal ? 'Klasemen akhir' : 'Klasemen sementara',
                  maxLines: 1,
                  style: MabarType.title.copyWith(fontSize: title, height: 1.05, color: ink),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
      ],
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        return ClipRect(
          child: DecoratedBox(
            decoration: BoxDecoration(gradient: theme.gradientFor(size)),
            child: Stack(
              children: [
                Positioned(right: wmRight, bottom: wmBottom, width: wmWidth, child: _watermark()),
                Positioned.fill(
                  child: Padding(
                    padding: padding,
                    child: CustomMultiChildLayout(
                      delegate: _BodyLayout(fill: _mode != _RowMode.natural),
                      children: [
                        LayoutId(id: _Part.header, child: header),
                        LayoutId(id: _Part.rows, child: _rows(base)),
                        LayoutId(id: _Part.foot, child: _footer(base)),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  /// `.wm` — raket olahraga turnamen, diwarnai tinta tema (putih 12% di tema gelap, tinta 16% di tema
  /// lembut); padel diputar 20°.
  Widget _watermark() {
    final racket = Opacity(
      opacity: theme.isLight ? 0.16 : 0.12,
      child: ColorFiltered(
        colorFilter: ColorFilter.mode(theme.ink, BlendMode.srcIn),
        child: Image.asset(data.sport.assetPath, fit: BoxFit.fitWidth),
      ),
    );
    return data.sport == SportType.padel ? Transform.rotate(angle: 20 * pi / 180, child: racket) : racket;
  }

  /// Kaki: ringkasan round/match, dan di gambar Ringkas juga "+n lainnya". Di pratinjau Ringkas "+n
  /// lainnya" ikut daftar ([_rows]) dan kaki menempel di bawah (`margin-top: auto`).
  Widget _footer(TextStyle base) {
    final size = _story ? 8.5 : 11.5;
    final foot = base.copyWith(fontSize: size);
    Widget line(Widget child) => _CssLines(fontSize: size, lineHeight: _lineHeight, child: child);
    final more = target == SharePosterTarget.preview ? null : data.more;
    final Widget body = switch (target) {
      SharePosterTarget.preview => line(Text(data.summary, style: foot, maxLines: 1, overflow: TextOverflow.ellipsis)),
      // `justify-content: space-between`: tanpa "+n lainnya" (Lengkap) ringkasannya rata kiri.
      SharePosterTarget.feed => line(
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            if (more != null) ...[Text(more, style: foot), const Spacer()],
            Text(data.summary, style: foot),
          ],
        ),
      ),
      SharePosterTarget.story => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (more != null) ...[line(Text(more, style: foot)), const SizedBox(height: 2)],
          line(Text(data.summary, style: foot)),
        ],
      ),
    };
    final gap = switch (target) {
      SharePosterTarget.preview => data.complete ? 10.0 : 0.0,
      _ => 8.0,
    };
    return Padding(padding: EdgeInsets.only(top: gap), child: Opacity(opacity: 0.8, child: body));
  }

  /// Daftar baris. Tingginya ditentukan [_BodyLayout]: sisa ruang antara kepala dan kaki diberikan sebagai
  /// tinggi minimal ([_RowMode.atLeastContent]) atau tinggi pasti ([_RowMode.share]).
  Widget _rows(TextStyle base) {
    final sizes = _rowSizes;
    final rows = data.rows;
    return LayoutBuilder(
      builder: (context, constraints) {
        final space = constraints.minHeight;
        if (_twoColumns) {
          // `grid-template-rows: repeat(k, minmax(0, 1fr))` + `grid-auto-flow: column`: ⌈n/2⌉ baris tetap,
          // kiri diisi dulu dari atas; slot sisa di kanan kosong supaya baris kiri-kanan sejajar.
          final k = (rows.length + 1) ~/ 2;
          Widget column(int from) => Column(
            children: [
              for (var i = from; i < from + k; i++)
                SizedBox(
                  height: space / k,
                  child: i < rows.length ? _row(rows[i], sizes, base, divider: i != from) : null,
                ),
            ],
          );
          return Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [Expanded(child: column(0)), const SizedBox(width: 14), Expanded(child: column(k))],
          );
        }
        // `.rows .prow { flex: 1 }` = flex-basis 0: sisa ruang dibagi rata ke isi baris dan garis atas 1 pt
        // ada di luar bagian itu, jadi baris pertama (tanpa garis) 1 pt lebih pendek dari baris lain.
        final shared = (space - (rows.length - 1)) / rows.length;
        Widget sized(Widget row, int i) => switch (_mode) {
          _RowMode.natural => row,
          _RowMode.atLeastContent => ConstrainedBox(constraints: BoxConstraints(minHeight: space / rows.length), child: row),
          _RowMode.share => SizedBox(height: shared + (i > 0 ? 1 : 0), child: row),
        };
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            for (var i = 0; i < rows.length; i++) sized(_row(rows[i], sizes, base, divider: i > 0), i),
            if (target == SharePosterTarget.preview && !data.complete && data.more != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Opacity(opacity: 0.75, child: Text(data.more!, style: base.copyWith(fontSize: 12.5))),
              ),
          ],
        );
      },
    );
  }

  Widget _row(SharePosterRow row, _RowSizes sizes, TextStyle base, {required bool divider}) {
    final gold = row.position == 1;
    // `.rows`/`.cols` (Lengkap): line-height 1,1, tanpa padding, isi di tengah. Selain itu `.prow` biasa:
    // padding 6 dan tinggi baris warisan; pratinjau Ringkas rata baseline, gambar Ringkas di tengah.
    final share = _mode == _RowMode.share;
    final lineHeight = share ? 1.1 : _lineHeight;
    final number = MabarType.numM.copyWith(fontSize: sizes.rank, height: gold ? 1.0 : lineHeight, color: theme.ink);
    final rank = Text.rich(
      TextSpan(
        children: [
          TextSpan(text: '#', style: TextStyle(color: (gold ? MabarColors.ink : theme.ink).withValues(alpha: gold ? 0.6 : 0.55))),
          TextSpan(text: '${row.position}'),
        ],
      ),
      style: gold ? number.copyWith(color: MabarColors.ink, height: 1) : number,
      maxLines: 1,
      softWrap: false,
    );
    final name = base.copyWith(fontSize: sizes.text, fontWeight: gold ? FontWeight.w800 : FontWeight.w600, height: lineHeight);
    final Widget names = _stackPairs && row.names.length > 1
        // Dua nama bertumpuk bisa sedikit lebih tinggi dari barisnya (20 baris Story); seperti CSS, dibiarkan
        // meluber di tengah, bukan dipotong.
        ? OverflowBox(
            minHeight: 0,
            maxHeight: double.infinity,
            alignment: Alignment.centerLeft,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final n in row.names)
                  Text(n, maxLines: 1, overflow: TextOverflow.ellipsis, style: name.copyWith(height: 1.15)),
              ],
            ),
          )
        : Text(row.names.join(' + '), maxLines: 1, overflow: TextOverflow.ellipsis, style: name);
    final unit = row.detail != null && !_story && !_twoColumns;
    final value = Text.rich(
      TextSpan(
        text: row.value,
        children: [
          WidgetSpan(
            alignment: PlaceholderAlignment.baseline,
            baseline: TextBaseline.alphabetic,
            child: Padding(
              padding: const EdgeInsets.only(left: 3),
              child: Opacity(
                opacity: 0.7,
                child: Text(
                  unit ? '${row.detail} · ${row.diff}' : '· ${row.diff}',
                  style: base.copyWith(fontSize: 11 * _density, fontWeight: FontWeight.w600, height: lineHeight),
                ),
              ),
            ),
          ),
        ],
      ),
      style: MabarType.numM.copyWith(fontSize: sizes.value, height: lineHeight, color: theme.ink),
      maxLines: 1,
      softWrap: false,
    );

    final rankCell = SizedBox(
      width: sizes.rankWidth,
      child: Align(
        alignment: Alignment.centerLeft,
        // Lencana digantung ke kiri sebesar padding-nya (`margin-left: -.3em`), jadi "#1" sejajar dengan "#2" dst.
        child: gold
            ? Transform.translate(
                offset: Offset(-sizes.rank * 0.3, 0),
                child: Container(
                  padding: EdgeInsets.symmetric(horizontal: sizes.rank * 0.3),
                  decoration: BoxDecoration(color: MabarColors.gold, borderRadius: BorderRadius.circular(sizes.rank * 0.35)),
                  child: rank,
                ),
              )
            : rank,
      ),
    );
    final gap = _twoColumns ? 6.0 : 8.0;
    final content = Row(
      crossAxisAlignment: _mode == _RowMode.natural ? CrossAxisAlignment.baseline : CrossAxisAlignment.center,
      textBaseline: TextBaseline.alphabetic,
      children: [rankCell, SizedBox(width: gap), Expanded(child: names), SizedBox(width: gap), value],
    );
    final pad = share ? 0.0 : 6.0;
    // Tinggi isi = kotak baris CSS (huruf terbesar × line-height, mis. 18 × 1,4 = 25,2). Mesin teks
    // membulatkan tinggi baris ke pt bulat (25); di lima baris selisihnya menumpuk jadi 1 pt lebih.
    final lineBox = max(sizes.rank, sizes.value) * lineHeight;
    return Container(
      // Garis atas 1 pt memakan tempat (border-box); Container sendiri menambahkan tebal border ke padding.
      padding: EdgeInsets.only(top: pad, bottom: pad),
      alignment: _mode == _RowMode.natural ? null : Alignment.centerLeft,
      decoration: divider ? BoxDecoration(border: Border(top: BorderSide(color: theme.inkAlpha(0.18)))) : null,
      child: share ? content : SizedBox(height: lineBox, child: content),
    );
  }
}

/// Teks kepala/kaki setinggi kotak baris CSS: n baris × ukuran × line-height (ikut skala teks). Mesin teks
/// membulatkan tinggi tiap baris ke pt bulat (keterangan 15,4 → 15, judul 29,4 → 29, wordmark 23,8 → 24), jadi
/// sisa ruang yang dibagi baris Lengkap meleset ±0,7 pt dan di daftar rapat (11l, 15 baris) menumpuk jadi geseran
/// yang kelihatan. Isinya di tengah kotak, seperti half-leading CSS.
class _CssLines extends SingleChildRenderObjectWidget {
  final double fontSize, lineHeight;

  const _CssLines({required this.fontSize, required this.lineHeight, required Widget super.child});

  double _line(BuildContext context) => MediaQuery.textScalerOf(context).scale(fontSize) * lineHeight;

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderCssLines(_line(context));

  @override
  void updateRenderObject(BuildContext context, _RenderCssLines renderObject) => renderObject.line = _line(context);
}

class _RenderCssLines extends RenderShiftedBox {
  _RenderCssLines(this._line) : super(null);

  double _line;
  set line(double value) {
    if (value == _line) return;
    _line = value;
    markNeedsLayout();
  }

  Size _sizeFor(BoxConstraints constraints, Size child) =>
      constraints.constrain(Size(child.width, max(1, (child.height / _line).round()) * _line));

  @override
  Size computeDryLayout(BoxConstraints constraints) => _sizeFor(constraints, child!.getDryLayout(constraints.loosen()));

  @override
  void performLayout() {
    final child = this.child!..layout(constraints.loosen(), parentUsesSize: true);
    size = _sizeFor(constraints, child.size);
    (child.parentData! as BoxParentData).offset = Offset(0, (size.height - child.size.height) / 2);
  }
}

/// Cara baris mengisi ruang di antara kepala dan kaki poster.
enum _RowMode {
  /// Pratinjau Ringkas: setinggi isi, kaki menempel di bawah poster.
  natural,

  /// Gambar Ringkas: sisa ruang dibagi rata tapi tidak di bawah tinggi isi (flex tanpa `min-height: 0`);
  /// kalau tidak cukup, kaki terdorong ke bawah dan terpotong tepi poster, seperti di frame 11d.
  atLeastContent,

  /// Lengkap (`.rows`/`.cols`): sisa ruang dibagi rata persis (`min-height: 0` / `minmax(0, 1fr)`).
  share,
}

enum _Part { header, rows, foot }

/// Kepala di atas, daftar di bawahnya, kaki sesudah daftar tapi paling atas di dasar poster
/// (`margin-top: auto`). Dengan [fill] daftar mendapat sisa ruang sebagai tinggi minimal; anak boleh
/// melewati dasar (digambar lalu dipotong `ClipRect` poster), persis seperti flexbox yang meluber.
class _BodyLayout extends MultiChildLayoutDelegate {
  final bool fill;

  _BodyLayout({required this.fill});

  @override
  void performLayout(Size size) {
    final width = BoxConstraints.tightFor(width: size.width);
    final header = layoutChild(_Part.header, width);
    final foot = layoutChild(_Part.foot, width);
    final space = fill ? max(0.0, size.height - header.height - foot.height) : 0.0;
    final rows = layoutChild(_Part.rows, BoxConstraints(minWidth: size.width, maxWidth: size.width, minHeight: space));
    positionChild(_Part.header, Offset.zero);
    positionChild(_Part.rows, Offset(0, header.height));
    positionChild(_Part.foot, Offset(0, max(header.height + rows.height, size.height - foot.height)));
  }

  @override
  bool shouldRelayout(_BodyLayout oldDelegate) => oldDelegate.fill != fill;
}
