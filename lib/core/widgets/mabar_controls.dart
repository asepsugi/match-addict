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
            MabarButtonVariant.danger => (MabarColors.clay, Colors.white),
            MabarButtonVariant.ghost => (Colors.transparent, MabarColors.court),
            MabarButtonVariant.wait => (Colors.transparent, MabarColors.ink3),
          };
    final radius = BorderRadius.circular(small ? MabarRadius.smallButton : MabarRadius.button);
    final text = MabarType.button.copyWith(fontSize: small ? 14 : 16, color: fg);

    final fill = expand ?? !small;
    final content = Row(
      mainAxisSize: fill ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (icon != null) ...[Icon(icon, size: MabarSize.iconInButton, color: fg), const SizedBox(width: 8)],
        // Label utuh; kalau sempit, yang dipotong meta-nya (keterangan, bukan aksinya).
        Flexible(
          flex: meta == null ? 1 : 0,
          child: Text(label, style: text, maxLines: 1, softWrap: false, overflow: TextOverflow.ellipsis),
        ),
        if (meta != null) ...[
          const SizedBox(width: 8),
          Flexible(
            child: Text(
              meta!,
              // `.btn-wait .meta { opacity: 1 }`: alasan menunggu harus terbaca (ink-3 penuh, 5,3:1).
              style: text.copyWith(fontWeight: FontWeight.w500, color: variant == MabarButtonVariant.wait ? fg : fg.withValues(alpha: 0.62)),
              maxLines: 1,
              softWrap: false,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ],
    );

    return Semantics(
      button: true,
      enabled: onPressed != null,
      child: Material(
        color: bg,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: variant == MabarButtonVariant.secondary && !off
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
            child: SizedBox(
              height: height ?? (small ? MabarSize.smallButton : MabarSize.primaryButton),
              width: fill ? double.infinity : null,
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: small ? 14 : 20),
                child: Center(widthFactor: 1, child: content),
              ),
            ),
          ),
        ),
      ),
    );
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
                      top: 5,
                      right: 6,
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
  final VoidCallback? onBack;
  final List<Widget> actions;
  final bool scrolled;

  const MabarAppBar({
    super.key,
    required this.title,
    this.subtitle,
    this.shorterSubtitle,
    this.subtitleAlert,
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
                  builder: (context, box) => Text.rich(
                    TextSpan(
                      text: _fitted(context, box.maxWidth),
                      children: [
                        if (subtitleAlert != null)
                          TextSpan(
                            text: ' · $subtitleAlert',
                            style: const TextStyle(color: MabarColors.clay),
                          ),
                      ],
                    ),
                    style: MabarType.caption,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
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
