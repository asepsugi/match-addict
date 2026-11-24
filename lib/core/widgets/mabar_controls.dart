import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../theme/mabar_icons.dart';
import '../theme/mabar_theme.dart';

/// Varian `.btn` (hi-fi → Komponen). Tombol mati tanpa varian [wait] otomatis tampil `.btn-off`.
enum MabarButtonVariant {
  /// Aksi utama layar.
  primary,

  /// Hanya untuk satu aksi "lanjutkan yang sedang berjalan" di Beranda.
  ball,
  secondary,

  /// `.btn-secondary.danger`: kartu putih bergaris, teks clay ("Kosongkan skor", 07p).
  secondaryDanger,
  danger,
  ghost,

  /// Mati karena menunggu sesuatu; alasannya ditulis di tombol ("Buat R4 · tunggu 1 match").
  wait,
}

/// `.btn` — tombol 52 pt (40 pt kalau [small]). Bawaannya memenuhi lebar yang tersedia (`flex: 1` di
/// CSS; di dalam `Row` bungkus dengan `Expanded`); [small] dan `expand: false` selebar isinya.
class MabarButton extends StatelessWidget {
  final String label;

  /// Keterangan pudar sesudah label (`.meta`), mis. "· ±6 round · 12 match".
  final String? meta;
  final IconData? icon;

  /// Pengganti [icon] berupa widget (mis. bola berputar 12r); ukuran ditentukan pemanggil.
  final Widget? leading;

  /// Null = mati (`.btn-off`, kecuali varian [MabarButtonVariant.wait]).
  final VoidCallback? onPressed;
  final MabarButtonVariant variant;
  final bool small;

  /// Tinggi lain dari bawaan, mis. tombol Lanjutkan di banner Beranda (46), Tambah pemain (48).
  final double? height;

  /// Selebar isi (`flex: none`) walau bukan [small].
  final bool? expand;

  const MabarButton({
    super.key,
    required this.label,
    this.meta,
    this.icon,
    this.leading,
    this.onPressed,
    this.variant = MabarButtonVariant.primary,
    this.small = false,
    this.height,
    this.expand,
  });

  /// `.btn-wait` memakai garis putus `#BFCAD3`.
  static const _waitBorder = Color(0xFFBFCAD3);

  @override
  Widget build(BuildContext context) {
    final off = onPressed == null && variant != MabarButtonVariant.wait;
    final (Color bg, Color fg) = off
        ? (MabarColors.fill, MabarColors.faint)
        : switch (variant) {
            MabarButtonVariant.primary => (MabarColors.ink, Colors.white),
            MabarButtonVariant.ball => (MabarColors.ball, MabarColors.ink),
            MabarButtonVariant.secondary => (MabarColors.card, MabarColors.ink),
            MabarButtonVariant.secondaryDanger => (MabarColors.card, MabarColors.clay),
            MabarButtonVariant.danger => (MabarColors.clay, Colors.white),
            MabarButtonVariant.ghost => (Colors.transparent, MabarColors.court),
            MabarButtonVariant.wait => (Colors.transparent, MabarColors.ink3),
          };
    final radius = BorderRadius.circular(small ? MabarRadius.smallButton : MabarRadius.button);
    final text = MabarType.button.copyWith(fontSize: small ? 14 : 16, color: fg);

    final fill = expand ?? !small;
    final metaStyle = text.copyWith(
      fontWeight: FontWeight.w500,
      // `.btn-wait .meta { opacity: 1 }`: alasan menunggu harus terbaca (ink-3 penuh, 5,3:1).
      color: variant == MabarButtonVariant.wait ? fg : fg.withValues(alpha: 0.62),
    );
    final lead = [
      if (leading != null) ...[
        leading!,
        const SizedBox(width: 8),
      ] else if (icon != null) ...[
        Icon(icon, size: MabarSize.iconInButton, color: fg),
        const SizedBox(width: 8),
      ],
    ];

    Widget body(bool two) {
      if (two) {
        // `.btn.two`: aksi di baris 1, keterangan utuh di baris 2 tanpa "·" pembuka.
        final second = meta!.replaceFirst(RegExp(r'^·\s*'), '');
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ...lead,
                Text(label, style: text.copyWith(height: 1.15)),
              ],
            ),
            const SizedBox(height: 4),
            Text(second, style: metaStyle.copyWith(height: 1.15), textAlign: TextAlign.center),
          ],
        );
      }
      return Row(
        mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ...lead,
          // Label utuh; kalau sempit, yang dipotong meta-nya (keterangan, bukan aksinya).
          Flexible(
            flex: meta == null ? 1 : 0,
            child: Text(label, style: text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
          ),
          if (meta != null) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(meta!, style: metaStyle, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
            ),
          ],
        ],
      );
    }

    // Satu baris kalau muat; kalau tidak (teks membesar, Fondasi → Skala teks HP) keterangan pindah ke baris 2.
    // Tombol selebar isi tidak bisa diukur terhadap lebar sisa, jadi tetap satu baris.
    bool needsTwoLines(double maxWidth) {
      if (!maxWidth.isFinite) return false;
      double width(String value, TextStyle style) {
        final painter = TextPainter(
          text: TextSpan(text: value, style: style),
          textDirection: TextDirection.ltr,
          textScaler: MediaQuery.textScalerOf(context),
        )..layout();
        final w = painter.width;
        painter.dispose();
        return w;
      }

      final iconWidth = (leading != null || icon != null) ? (leading == null ? MabarSize.iconInButton : 0) + 8 : 0;
      final padding = small ? 28 : 40;
      return width(label, text) + 8 + width(meta!, metaStyle) + iconWidth + padding > maxWidth;
    }

    Widget button(bool two) => Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: (variant == MabarButtonVariant.secondary || variant == MabarButtonVariant.secondaryDanger) && !off
              ? const BorderSide(color: MabarColors.line, width: 1.5)
              : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: CustomPaint(
            foregroundPainter: variant == MabarButtonVariant.wait
                ? _DashedBorderPainter(radius: radius, color: _waitBorder)
                : null,
            // Tinggi minimum, bukan tetap: teks yang membesar menumbuhkan tombol.
            child: ConstrainedBox(
              constraints: BoxConstraints(
                minHeight: height ?? (small ? MabarSize.smallButton : MabarSize.primaryButton),
                minWidth: fill ? double.infinity : 0,
              ),
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20, vertical: two ? 8 : 0),
                child: Center(widthFactor: 1, heightFactor: 1, child: body(two)),
              ),
            ),
          ),
        ),
      ),
    );

    // LayoutBuilder tidak mendukung ukuran intrinsik (IntrinsicHeight di baris match): hanya dipakai kalau perlu.
    if (meta == null || !fill) return button(false);
    return LayoutBuilder(builder: (context, constraints) => button(needsTwoLines(constraints.maxWidth)));
  }
}

/// Garis putus 1,5 pt di tepi dalam, seperti `border: 1.5px dashed` Chrome (garis 3× tebal, celah sama).
class _DashedBorderPainter extends CustomPainter {
  final BorderRadius radius;
  final Color color;

  const _DashedBorderPainter({required this.radius, required this.color});

  static const _width = 1.5;

  @override
  void paint(Canvas canvas, Size size) {
    final rrect = radius.toRRect(Offset.zero & size).deflate(_width / 2);
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = _width;
    const dash = _width * 3;
    for (final metric in (Path()..addRRect(rrect)).computeMetrics()) {
      for (var d = 0.0; d < metric.length; d += dash * 2) {
        canvas.drawPath(metric.extractPath(d, min(d + dash, metric.length)), paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DashedBorderPainter old) => old.color != color || old.radius != radius;
}

enum MabarTextTone {
  /// Biru court — aksi biasa, dan aksi "lanjut" di dialog.
  court,

  /// Clay — WO, hapus, akhiri.
  danger,

  /// Tinta kedua — "Batal" di dialog.
  neutral,
}

/// `.txtbtn` — aksi teks 44 pt (header, dialog, samping konten).
class MabarTextButton extends StatelessWidget {
  final String label;
  final IconData? icon;
  final VoidCallback? onPressed;
  final MabarTextTone tone;

  const MabarTextButton({super.key, required this.label, this.icon, this.onPressed, this.tone = MabarTextTone.court});

  @override
  Widget build(BuildContext context) {
    final color = onPressed == null
        ? MabarColors.faint
        : switch (tone) {
            MabarTextTone.court => MabarColors.court,
            MabarTextTone.danger => MabarColors.clay,
            MabarTextTone.neutral => MabarColors.ink2,
          };
    // Perluasan di luar Semantics: simpul proxy menolak ketukan di luar kotaknya sendiri.
    return MabarTouchOutset(
      vertical: (MabarSize.tapTarget - MabarSize.iconButton) / 2,
      child: Semantics(
        button: true,
        enabled: onPressed != null,
        child: InkWell(
          onTap: onPressed,
          borderRadius: BorderRadius.circular(MabarRadius.smallButton),
          child: SizedBox(
            height: MabarSize.iconButton,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (icon != null) ...[
                    Icon(icon, size: MabarSize.iconInButton, color: color),
                    const SizedBox(width: 6),
                  ],
                  Text(label, style: MabarType.textButton.copyWith(color: color), maxLines: 1, softWrap: false),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.icbtn` — tombol ikon 44 pt, atau 52 pt berlatar kartu di action bar ([solid]). Ikon tanpa label
/// wajib punya [semanticLabel] ("Kembali", "Menu", "Klasemen", "Pemain").
class MabarIconButton extends StatelessWidget {
  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final bool solid;

  /// Angka kecil di pojok kanan atas, mis. jumlah pemain aktif.
  final int? count;

  const MabarIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.solid = false,
    this.count,
  });

  /// 0 pada skala teks 1,0 sampai 1 pada 1,3.
  static double _crowding(BuildContext context) =>
      ((MediaQuery.textScalerOf(context).scale(11) / 11 - 1) / 0.3).clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final size = solid ? MabarSize.iconButtonInActionBar : MabarSize.iconButton;
    return MabarTouchOutset(
      // 44 → 48; tombol 52 di action bar sudah cukup.
      horizontal: solid ? 0 : (MabarSize.tapTarget - size) / 2,
      vertical: solid ? 0 : (MabarSize.tapTarget - size) / 2,
      child: Semantics(
        button: true,
        label: count == null ? semanticLabel : '$semanticLabel, $count aktif',
        child: Material(
          color: solid ? MabarColors.card : Colors.transparent,
          borderRadius: BorderRadius.circular(MabarRadius.button),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onPressed,
            child: SizedBox.square(
              dimension: size,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Icon(icon, size: MabarSize.icon, color: onPressed == null ? MabarColors.off : MabarColors.ink2),
                  if (count != null)
                    Positioned(
                      // `.actionbar.ts13 .icbtn .count`: pada 1,3 angka bergeser ke sudut (atas 2, kanan 3) supaya tidak
                      // menimpa ikon; di antara 1,0 dan 1,3 bergeser sebanding.
                      top: 5 - 3 * _crowding(context),
                      right: 6 - 3 * _crowding(context),
                      // Jumlah sudah dibaca lewat label tombol.
                      child: ExcludeSemantics(
                        child: Text(
                          '$count',
                          style: MabarType.label.copyWith(
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                            fontVariations: const [FontVariation('wdth', 80)],
                            fontFeatures: MabarType.tabular,
                            height: 1.4,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.rowact` — aksi di ujung baris daftar: tombol 36 pt bertepi tipis, area sentuh tetap 44.
/// Netral untuk aksi yang bisa dibatalkan (Keluarkan), biru court untuk memulihkan ([restore],
/// Kembalikan), pudar saat mati.
class MabarRowAction extends StatelessWidget {
  final String label;
  final VoidCallback? onPressed;
  final bool restore;

  const MabarRowAction({super.key, required this.label, this.onPressed, this.restore = false});

  @override
  Widget build(BuildContext context) {
    final off = onPressed == null;
    final color = off ? MabarColors.dim : (restore ? MabarColors.court : MabarColors.ink2);
    final radius = BorderRadius.circular(MabarRadius.chip);
    // Tata letak 36 seperti CSS (baris dua tingkat tidak ikut meninggi), area ketuk 48.
    return MabarTouchOutset(
      vertical: (MabarSize.tapTarget - MabarSize.rowAction) / 2,
      child: Semantics(
        button: true,
        enabled: !off,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onPressed,
          // Tepi `inset box-shadow` tidak memakan tempat: foregroundDecoration, bukan border dekorasi (yang
          // oleh Container ditambahkan ke padding).
          child: Container(
            height: MabarSize.rowAction,
            padding: const EdgeInsets.symmetric(horizontal: 14),
            alignment: Alignment.center,
            decoration: BoxDecoration(color: off ? Colors.transparent : MabarColors.card, borderRadius: radius),
            foregroundDecoration: BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: MabarColors.line),
            ),
            child: Text(
              label,
              style: MabarType.body.copyWith(fontSize: 14, fontWeight: FontWeight.w600, height: 1, color: color),
              maxLines: 1,
              softWrap: false,
            ),
          ),
        ),
      ),
    );
  }
}

/// Memperluas area ketuk anaknya [horizontal] / [vertical] pt ke tiap sisi tanpa memperbesar tata letaknya
/// (aturan area ketuk ≥ 48 di hi-fi → Fondasi, PATCH 3.8.1). Perluasan hanya bekerja di dalam kotak induk yang
/// memuatnya: induk menolak ketukan di luar batasnya sendiri. [innerInset] = tepi tempat anak benar-benar
/// bisa dikenai ketukan (mis. padding track segmented), ke sanalah ketukan di luar dibelokkan.
class MabarTouchOutset extends SingleChildRenderObjectWidget {
  final double horizontal;
  final double vertical;
  final EdgeInsets innerInset;

  const MabarTouchOutset({
    super.key,
    this.horizontal = 0,
    this.vertical = 0,
    this.innerInset = EdgeInsets.zero,
    required super.child,
  });

  @override
  RenderObject createRenderObject(BuildContext context) => _RenderTouchOutset(horizontal, vertical, innerInset);

  @override
  void updateRenderObject(BuildContext context, RenderObject renderObject) {
    (renderObject as _RenderTouchOutset)
      ..horizontal = horizontal
      ..vertical = vertical
      ..innerInset = innerInset;
  }
}

class _RenderTouchOutset extends RenderProxyBox {
  double horizontal;
  double vertical;
  EdgeInsets innerInset;

  _RenderTouchOutset(this.horizontal, this.vertical, this.innerInset);

  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) {
    final reach = Rect.fromLTRB(-horizontal, -vertical, size.width + horizontal, size.height + vertical);
    if (!reach.contains(position)) return false;
    // Ketukan di luar kotak diteruskan sebagai ketukan di tepi terdekatnya.
    final inner = innerInset.deflateRect(Offset.zero & size);
    // Tepi kanan/bawah kotak tidak termasuk di dalamnya (`Size.contains`), jadi dijepit sedikit ke dalam.
    final inside = Offset(
      position.dx.clamp(inner.left, max(inner.left, inner.right - 0.01)),
      position.dy.clamp(inner.top, max(inner.top, inner.bottom - 0.01)),
    );
    if (hitTestChildren(result, position: inside)) {
      result.add(BoxHitTestEntry(this, position));
      return true;
    }
    return false;
  }
}

/// `.actionbar` — bilah tombol yang menempel di bawah, garis tipis di atasnya. Jarak bawah mengikuti
/// safe area (34 di iPhone pada frame), minimal 12. Di mode baris, tombol yang mengisi sisa lebar
/// dibungkus `Expanded` oleh pemanggil (seperti `flex: 1` di CSS); [column] menumpuk anaknya.
class MabarActionBar extends StatelessWidget {
  final List<Widget> children;
  final bool column;

  const MabarActionBar({super.key, required this.children, this.column = false});

  @override
  Widget build(BuildContext context) {
    final bottom = max(12.0, MediaQuery.paddingOf(context).bottom);
    final gap = column ? const SizedBox(height: 10) : const SizedBox(width: 10);
    final spaced = [
      for (var i = 0; i < children.length; i++) ...[if (i > 0) gap, children[i]],
    ];
    return DecoratedBox(
      decoration: const BoxDecoration(
        color: MabarColors.paper,
        border: Border(top: BorderSide(color: MabarColors.line)),
      ),
      child: Padding(
        // 12 + 1: di CSS garis atasnya memakan tempat (border-box); `Border` Flutter hanya digambar.
        padding: EdgeInsets.fromLTRB(16, 13, 16, bottom),
        child: column
            ? Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.stretch, children: spaced)
            : Row(children: spaced),
      ),
    );
  }
}

/// `.appbar` — judul rata kiri + subjudul berisi fakta, tombol kembali, aksi di kanan. Mulai 7 pt di
/// bawah safe area atas. Tanpa [onBack] judul bergeser ke tepi 16 (`.no-back`). [scrolled] memberi
/// garis bawah saat isi di bawahnya sudah digulir.
class MabarAppBar extends StatelessWidget {
  final String title;
  final String? subtitle;

  /// Pengganti [subtitle] kalau yang penuh tidak muat satu baris (Detail: olahraga dibuang dulu, B-6). Tanpa ini
  /// subjudul yang panjang terpotong elipsis.
  final String? shorterSubtitle;

  /// Bagian akhir subjudul yang ditulis clay ("sisa 00:12" di Input Skor), setelah " · ".
  final String? subtitleAlert;

  /// Bagian akhir subjudul berwarna biasa yang tidak boleh terpotong ("sisa 01:20"), setelah " · ".
  final String? subtitleTail;
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool scrolled;

  const MabarAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.shorterSubtitle,
    this.subtitleAlert,
    this.subtitleTail,
    this.onBack,
    this.actions = const [],
    this.scrolled = false,
  });

  /// [subtitle] kalau muat selebar [maxWidth], kalau tidak [shorterSubtitle].
  String _fitted(BuildContext context, double maxWidth) {
    final full = subtitle!;
    final shorter = shorterSubtitle;
    if (shorter == null) return full;
    final painter = TextPainter(
      text: TextSpan(text: full, style: MabarType.caption),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final fits = painter.width <= maxWidth;
    painter.dispose();
    return fits ? full : shorter;
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 7;
    final children = <Widget>[
      if (onBack != null) MabarIconButton(icon: MabarIcons.caretLeft, semanticLabel: 'Kembali', onPressed: onBack),
      Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: MabarType.title.copyWith(color: MabarColors.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (subtitle != null)
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: LayoutBuilder(
                  builder: (context, box) {
                    final kept = [
                      if (subtitleTail != null) (subtitleTail!, MabarColors.ink3),
                      if (subtitleAlert != null) (subtitleAlert!, MabarColors.clay),
                    ];
                    final head = _fitted(context, box.maxWidth);
                    if (kept.isEmpty) {
                      return Text(head, style: MabarType.caption, maxLines: 1, overflow: TextOverflow.ellipsis);
                    }
                    final painter = TextPainter(
                      text: TextSpan(
                        text: head + [for (final (text, _) in kept) ' · $text'].join(),
                        style: MabarType.caption,
                      ),
                      textDirection: TextDirection.ltr,
                      textScaler: MediaQuery.textScalerOf(context),
                      maxLines: 1,
                    )..layout();
                    final fits = painter.width <= box.maxWidth;
                    painter.dispose();
                    if (fits) {
                      return Text.rich(
                        TextSpan(
                          text: head,
                          children: [
                            for (final (text, color) in kept)
                              TextSpan(
                                text: ' · $text',
                                style: color == MabarColors.clay ? TextStyle(color: color) : null,
                              ),
                          ],
                        ),
                        style: MabarType.caption,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      );
                    }
                    // Tidak muat: bagian yang berubah ("sisa 01:20") tetap utuh, yang dielipsis meta di depannya (`.ts13`).
                    return MergeSemantics(
                      child: Row(
                        children: [
                          Flexible(
                            child: Text(head, style: MabarType.caption, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          for (final (text, color) in kept)
                            Text(
                              ' · $text',
                              style: MabarType.caption.copyWith(color: color),
                              maxLines: 1,
                              softWrap: false,
                            ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      ...actions,
    ];
    return DecoratedBox(
      decoration: BoxDecoration(
        color: MabarColors.paper,
        boxShadow: scrolled ? const [BoxShadow(color: MabarColors.line, offset: Offset(0, 1))] : null,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(onBack == null ? 16 : 6, top, 12, 12),
        child: Row(
          children: [
            for (var i = 0; i < children.length; i++) ...[if (i > 0) const SizedBox(width: 6), children[i]],
          ],
        ),
      ),
    );
  }
}
