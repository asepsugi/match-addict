import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';

import '../theme/mabar_icons.dart';
import '../theme/mabar_theme.dart';
import 'mabar_ball.dart';
import 'mabar_controls.dart';

/// `.sheet` — satu-satunya bottom sheet app. Anatomi: pegangan 38×5 · judul 21/800 · [subtitle] berisi
/// fakta · isi · [footer], berjarak 16, padding 8/16/34. Isi yang melebihi 92% tinggi layar digulir di
/// dalam; judul dan footer tetap. Geser turun, ketuk scrim, atau back = tutup dengan hasil null.
///
/// Footer menurut jenis sheet: info (satu tombol "Mengerti"), aksi (satu tombol utama, mati kalau belum
/// valid dengan alasannya di atas), aksi bahaya (Batal + aksi clay dua kali lebar), atau tanpa footer
/// untuk pilih-langsung dan kelola. Grup di dalam sheet berlatar paper (`MabarGroup(color: paper)`).
Future<T?> showMabarSheet<T>(
  BuildContext context, {
  required String title,
  String? subtitle,
  required WidgetBuilder builder,
  WidgetBuilder? footer,
}) => showMabarSheetRoute<T>(
  context,
  builder: (context) =>
      MabarSheet(title: title, subtitle: subtitle, footer: footer?.call(context), child: builder(context)),
);

/// Route bottom sheet [showMabarSheet] untuk sheet yang menyusun [MabarSheet] sendiri, karena judul atau subjudulnya
/// ikut berubah dengan isinya (pratinjau detail court).
Future<T?> showMabarSheetRoute<T>(BuildContext context, {required WidgetBuilder builder}) =>
    showModalBottomSheet<T>(context: context, isScrollControlled: true, useSafeArea: false, builder: builder);

/// Isi [showMabarSheet]; publik supaya golden bisa merender sheet tanpa animasi route.
class MabarSheet extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final Widget? footer;

  /// Satu aksi teks di kanan judul ("Hapus" di detail court), seperti WO di app bar Input Skor.
  final Widget? action;

  const MabarSheet({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.footer,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final bottom = max(16.0, media.padding.bottom) + media.viewInsets.bottom;
    return ConstrainedBox(
      constraints: BoxConstraints(maxHeight: media.size.height * 0.92),
      child: Padding(
        padding: EdgeInsets.fromLTRB(16, 8, 16, bottom),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 38,
                height: 5,
                decoration: BoxDecoration(
                  color: MabarColors.line,
                  borderRadius: BorderRadius.circular(3),
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: MabarType.sheetTitle.copyWith(color: MabarColors.ink),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 2),
                          child: Text(
                            subtitle!,
                            style: MabarType.caption.copyWith(fontSize: 14),
                          ),
                        ),
                    ],
                  ),
                ),
                // `margin: -10px -10px 0 0`: tombol 44 pt menjorok ke atas dan ke kanan, sejajar dengan judul.
                if (action != null) Transform.translate(offset: const Offset(10, -10), child: action),
              ],
            ),
            const SizedBox(height: 16),
            Flexible(child: SingleChildScrollView(child: child)),
            if (footer != null) ...[const SizedBox(height: 16), footer!],
          ],
        ),
      ),
    );
  }
}

/// `.opt` — pilihan radio di sheet (WO: pasangan yang tidak main). Terpilih = latar tinta, radio bola.
class MabarOption extends StatelessWidget {
  final String label;
  final String? sublabel;
  final bool selected;
  final VoidCallback? onTap;

  /// `.opt .slot` — slot yang didapat pilihan ini ("A2"), bola di kanan baris terpilih (sheet Buat bagan, 20j).
  final String? slot;

  const MabarOption({
    super.key,
    required this.label,
    this.sublabel,
    this.selected = false,
    this.onTap,
    this.slot,
  });

  static const _radioOff = Color(0xFFB9C4CE);

  @override
  Widget build(BuildContext context) {
    final fg = selected ? Colors.white : MabarColors.ink;
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? MabarColors.ink : MabarColors.paper,
        borderRadius: BorderRadius.circular(MabarRadius.button),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: ConstrainedBox(
            constraints: const BoxConstraints(minHeight: 60),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  // Radio: cincin 2 pt abu, atau cincin bola 7 pt (sisa tengahnya warna latar).
                  Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                        color: selected ? MabarColors.ball : _radioOff,
                        width: selected ? 7 : 2,
                      ),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          label,
                          style: MabarType.body.copyWith(
                            fontSize: 17,
                            fontWeight: FontWeight.w600,
                            color: fg,
                          ),
                        ),
                        if (sublabel != null)
                          Text(
                            sublabel!,
                            style: MabarType.caption.copyWith(
                              fontWeight: FontWeight.w500,
                              color: fg.withValues(alpha: 0.7),
                            ),
                          ),
                      ],
                    ),
                  ),
                  if (slot != null) Text(slot!, style: MabarType.numM.copyWith(fontSize: 20, color: MabarColors.ball)),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.dialog` — satu fungsi untuk semua konfirmasi ya/tidak yang tidak bisa diurungkan. Judul berupa
/// pertanyaan berkata kerja, [message] menyebut akibat dan bendanya, [confirmLabel] mengulang kata kerja
/// judul. [destructive] = aksi clay (akhiri, hapus), selain itu biru court. Ketuk scrim atau back = false.
Future<bool> showMabarConfirm(
  BuildContext context, {
  required String title,
  required String message,
  required String confirmLabel,
  bool destructive = false,
}) async {
  final result = await showDialog<bool>(
    context: context,
    // `.dialog { top: 50% }`: tepat di tengah layar penuh. Dengan SafeArea bawaan dialog turun setengah
    // selisih status bar dan home indicator.
    useSafeArea: false,
    builder: (context) => MabarConfirmDialog(
      title: title,
      message: message,
      confirmLabel: confirmLabel,
      destructive: destructive,
      onCancel: () => Navigator.pop(context, false),
      onConfirm: () => Navigator.pop(context, true),
    ),
  );
  return result ?? false;
}

/// Isi [showMabarConfirm]; publik supaya golden bisa merendernya tanpa route.
class MabarConfirmDialog extends StatelessWidget {
  final String title;
  final String message;
  final String confirmLabel;
  final bool destructive;
  final VoidCallback onCancel;
  final VoidCallback onConfirm;

  const MabarConfirmDialog({
    super.key,
    required this.title,
    required this.message,
    required this.confirmLabel,
    required this.destructive,
    required this.onCancel,
    required this.onConfirm,
  });

  @override
  Widget build(BuildContext context) {
    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 24),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 22, 20, 12),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: MabarType.dialogTitle.copyWith(color: MabarColors.ink),
            ),
            const SizedBox(height: 8),
            Text(
              message,
              style: MabarType.body.copyWith(
                fontSize: 15,
                height: 1.5,
                color: MabarColors.ink2,
              ),
            ),
            const SizedBox(height: 8 + 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                MabarTextButton(
                  label: 'Batal',
                  tone: MabarTextTone.neutral,
                  onPressed: onCancel,
                ),
                const SizedBox(width: 4),
                MabarTextButton(
                  label: confirmLabel,
                  tone: destructive
                      ? MabarTextTone.danger
                      : MabarTextTone.court,
                  onPressed: onConfirm,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Satu item menu ⋯. [dividerBefore] = garis pemisah di atasnya (item berbahaya di bawah garis).
class MabarMenuItem<T> {
  final IconData icon;
  final String label;
  final T value;
  final bool danger;
  final bool enabled;
  final bool dividerBefore;

  /// Titik bola di ujung kanan: fitur item ini sedang menyala (Live score, 12f).
  final bool live;

  const MabarMenuItem({
    required this.icon,
    required this.label,
    required this.value,
    this.danger = false,
    this.enabled = true,
    this.dividerBefore = false,
    this.live = false,
  });
}

/// `.menu` — menu ⋯: kartu putih berbayangan selebar 250, menempel di bawah tombol [anchor] dan rata
/// 12 pt dari tepi kanan layar, tanpa scrim. Mengembalikan nilai item yang diketuk, atau null.
Future<T?> showMabarMenu<T>(
  BuildContext anchor, {
  required List<MabarMenuItem<T>> items,
}) {
  final box = anchor.findRenderObject()! as RenderBox;
  final top = box.localToGlobal(Offset(0, box.size.height)).dy;
  return Navigator.of(anchor).push(_MenuRoute<T>(top: top, items: items));
}

class _MenuRoute<T> extends PopupRoute<T> {
  final double top;
  final List<MabarMenuItem<T>> items;

  _MenuRoute({required this.top, required this.items});

  @override
  Color? get barrierColor => null;

  @override
  bool get barrierDismissible => true;

  @override
  String? get barrierLabel => 'Tutup menu';

  @override
  Duration get transitionDuration => const Duration(milliseconds: 120);

  @override
  Widget buildPage(
    BuildContext context,
    Animation<double> animation,
    Animation<double> secondaryAnimation,
  ) {
    return Stack(
      children: [
        Positioned(
          top: top,
          right: 12,
          width: 250,
          child: FadeTransition(
            opacity: animation,
            child: MabarMenu<T>(
              items: items,
              onSelected: (value) => Navigator.pop(context, value),
            ),
          ),
        ),
      ],
    );
  }
}

/// Isi [showMabarMenu]; publik supaya golden bisa merendernya tanpa route.
class MabarMenu<T> extends StatelessWidget {
  final List<MabarMenuItem<T>> items;
  final ValueChanged<T> onSelected;

  const MabarMenu({super.key, required this.items, required this.onSelected});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 6),
      decoration: BoxDecoration(
        color: MabarColors.card,
        borderRadius: BorderRadius.circular(MabarRadius.menu),
        boxShadow: MabarShadows.menu,
      ),
      child: Material(
        type: MaterialType.transparency,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final item in items) ...[
              if (item.dividerBefore)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 6),
                  child: Divider(
                    height: 1,
                    thickness: 1,
                    color: MabarColors.line,
                  ),
                ),
              _item(item),
            ],
          ],
        ),
      ),
    );
  }

  Widget _item(MabarMenuItem<T> item) {
    final (Color text, Color icon) = !item.enabled
        ? (MabarColors.faint, MabarColors.off)
        : item.danger
        ? (MabarColors.clay, MabarColors.clay)
        : (MabarColors.ink, MabarColors.ink3);
    return InkWell(
      onTap: item.enabled ? () => onSelected(item.value) : null,
      child: SizedBox(
        height: 48,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Row(
            children: [
              Icon(item.icon, size: MabarSize.icon, color: icon),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  item.label,
                  style: MabarType.body.copyWith(color: text),
                  maxLines: 1,
                ),
              ),
              if (item.live) const LiveDot(),
            ],
          ),
        ),
      ),
    );
  }
}

/// `.toast` — pesan singkat bertinta di atas action bar (hanya "Hasil disalin", 11c), hilang sendiri.
/// Diletakkan 19 pt di atas action bar: bawaannya 84 + safe area bawah (minimal 12) dari bawah layar, untuk
/// action bar satu tombol; layar dengan action bar lain memberi [bottom] (tinggi action bar + 19).
void showMabarToast(
  BuildContext context,
  String message, {
  IconData icon = MabarIcons.check,
  double? bottom,
}) {
  final overlay = Overlay.of(context);
  late final OverlayEntry entry;
  entry = OverlayEntry(
    builder: (context) => Positioned(
      left: 16,
      right: 16,
      bottom: bottom ?? 84 + max(12.0, MediaQuery.paddingOf(context).bottom),
      child: IgnorePointer(
        child: MabarToast(message: message, icon: icon),
      ),
    ),
  );
  overlay.insert(entry);
  Timer(const Duration(milliseconds: 2400), entry.remove);
}

/// Isi [showMabarToast]; publik supaya golden bisa merendernya tanpa overlay.
class MabarToast extends StatelessWidget {
  final String message;
  final IconData icon;

  const MabarToast({
    super.key,
    required this.message,
    this.icon = MabarIcons.check,
  });

  @override
  Widget build(BuildContext context) {
    // Overlay tidak punya Material di atasnya; tanpa ini teks mewarisi gaya error (garis bawah kuning).
    return Semantics(
      liveRegion: true,
      child: Material(type: MaterialType.transparency, child: _content()),
    );
  }

  Widget _content() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: MabarColors.ink,
        borderRadius: BorderRadius.circular(MabarRadius.button),
      ),
      child: Row(
        children: [
          Icon(icon, size: MabarSize.iconInButton, color: MabarColors.ball),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              message,
              style: MabarType.body.copyWith(fontSize: 15, color: Colors.white),
            ),
          ),
        ],
      ),
    );
  }
}
