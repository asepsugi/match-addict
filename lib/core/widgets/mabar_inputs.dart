import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../theme/mabar_icons.dart';
import '../theme/mabar_theme.dart';

/// `.seg` — pilihan segmented. Setiap opsi berbagi lebar sama.
class MabarSegmented<T> extends StatelessWidget {
  final List<(T, String)> options;
  final T selected;
  final ValueChanged<T> onChanged;

  const MabarSegmented({super.key, required this.options, required this.selected, required this.onChanged});

  /// `0 1px 2px rgba(15,30,44,.16)`; blur CSS dikonversi seperti [MabarShadows].
  static const _onShadow = [BoxShadow(color: Color(0x290F1E2C), offset: Offset(0, 1), blurRadius: (2 / 2 - 0.5) / 0.57735)];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(3),
      decoration: BoxDecoration(color: MabarColors.fill, borderRadius: BorderRadius.circular(MabarRadius.smallButton)),
      child: Row(
        children: [
          for (var i = 0; i < options.length; i++) ...[
            if (i > 0) const SizedBox(width: 2),
            Expanded(child: _segment(options[i])),
          ],
        ],
      ),
    );
  }

  Widget _segment((T, String) option) {
    final (value, label) = option;
    final on = value == selected;
    return Semantics(
      button: true,
      selected: on,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => onChanged(value),
        child: Container(
          height: 38,
          alignment: Alignment.center,
          decoration: on
              ? BoxDecoration(color: MabarColors.card, borderRadius: BorderRadius.circular(8), boxShadow: _onShadow)
              : null,
          child: Text(
            label,
            maxLines: 1,
            softWrap: false,
            style: MabarType.body.copyWith(
              fontSize: 15,
              fontWeight: on ? FontWeight.w700 : FontWeight.w600,
              color: on ? MabarColors.ink : MabarColors.ink2,
            ),
          ),
        ),
      ),
    );
  }
}

/// `.stepper` — − angka + dengan lebar angka tetap 60, supaya tombol di semua baris satu grup sejajar
/// satu kolom. Di batas, tombolnya pudar dan tidak bisa ditekan. Angka bisa diketuk untuk diketik;
/// ketikan dirapikan [normalizeTyped] (bawaan: dikembalikan ke batas terdekat). [error] = angka clay
/// (nilai penyebab error di catatan grup, 03d).
class MabarStepper extends StatefulWidget {
  /// Null = kosong (angka dihapus host, durasi di 03p): tombol − mati, + mengisi [min].
  final int? value;
  final int min;
  final int max;
  final int step;

  /// Satuan kecil di sebelah angka ("game", "mnt", "jam").
  final String? unit;
  final ValueChanged<int> onChanged;

  /// Dipanggil begitu isian diketik jadi kosong; tanpa ini kosong diabaikan dan angka lama kembali.
  final VoidCallback? onCleared;
  final int Function(int typed)? normalizeTyped;
  final bool error;

  const MabarStepper({
    super.key,
    required this.value,
    required this.min,
    required this.max,
    required this.onChanged,
    this.onCleared,
    this.step = 1,
    this.unit,
    this.normalizeTyped,
    this.error = false,
  });

  @override
  State<MabarStepper> createState() => _MabarStepperState();
}

class _MabarStepperState extends State<MabarStepper> {
  bool _editing = false;
  final _controller = TextEditingController();
  final _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _focus.addListener(() {
      if (!_focus.hasFocus && _editing) _commit();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _startEditing() {
    setState(() => _editing = true);
    _controller
      ..text = '${widget.value ?? ''}'
      ..selection = TextSelection(baseOffset: 0, extentOffset: '${widget.value ?? ''}'.length);
    _focus.requestFocus();
  }

  void _commit() {
    final typed = int.tryParse(_controller.text);
    setState(() => _editing = false);
    if (typed == null) return;
    final value = (widget.normalizeTyped?.call(typed) ?? typed).clamp(widget.min, widget.max);
    if (value != widget.value) widget.onChanged(value);
  }

  static final _number = MabarType.numM.copyWith(color: MabarColors.ink);

  @override
  Widget build(BuildContext context) {
    final value = widget.value;
    final canDown = value != null && value - widget.step >= widget.min;
    final canUp = value == null || value + widget.step <= widget.max;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _StepButton(
          icon: MabarIcons.minus,
          label: 'Kurangi',
          onPressed: canDown ? () => widget.onChanged(value - widget.step) : null,
        ),
        const SizedBox(width: 4),
        SizedBox(
          width: 60,
          child: _editing
              ? TextField(
                  controller: _controller,
                  focusNode: _focus,
                  keyboardType: TextInputType.number,
                  inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
                  textAlign: TextAlign.center,
                  style: _number,
                  decoration: InputDecoration(
                    suffixText: _controller.text.isEmpty ? widget.unit : null,
                    suffixStyle: MabarType.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                    isDense: true,
                    filled: false,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                  ),
                  onChanged: (text) {
                    // Kosong: satuan tetap terlihat di samping kursor (03p).
                    setState(() {});
                    if (text.isEmpty) widget.onCleared?.call();
                  },
                  onSubmitted: (_) => _focus.unfocus(),
                )
              : GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _startEditing,
                  child: Text.rich(
                    TextSpan(
                      text: '${widget.value ?? ''}',
                      children: [
                        // `small { margin-left: 3px }`, sejajar baseline angka.
                        if (widget.unit != null)
                          WidgetSpan(
                            alignment: PlaceholderAlignment.baseline,
                            baseline: TextBaseline.alphabetic,
                            child: Padding(
                              padding: const EdgeInsets.only(left: 3),
                              child: Text(
                                widget.unit!,
                                style: MabarType.caption.copyWith(fontSize: 12, fontWeight: FontWeight.w600),
                              ),
                            ),
                          ),
                      ],
                    ),
                    style: widget.error ? _number.copyWith(color: MabarColors.clay) : _number,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    softWrap: false,
                  ),
                ),
        ),
        const SizedBox(width: 4),
        _StepButton(
          icon: MabarIcons.plus,
          label: 'Tambah',
          onPressed: canUp ? () => widget.onChanged(value == null ? widget.min : value + widget.step) : null,
        ),
      ],
    );
  }
}

class _StepButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  const _StepButton({required this.icon, required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    enabled: onPressed != null,
    label: label,
    child: Material(
      color: MabarColors.fill,
      borderRadius: BorderRadius.circular(MabarRadius.chip),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onPressed,
        child: SizedBox.square(
          dimension: 36,
          child: Icon(icon, size: MabarSize.iconInButton, color: onPressed == null ? MabarColors.off : MabarColors.ink2),
        ),
      ),
    ),
  );
}

/// Kotak isian. Frame hanya memakai `.inline-field` (radius 9, padding 0 12, huruf 16) dalam dua
/// ukuran: [MabarField] 48 pt berlatar kartu di sheet (Tambah pemain, 08a/08b) — tepi 1,5 line saat
/// diam (aturan `.field`), fokus 2 court, [error] 2 clay; pesannya di catatan, bukan di bawah kotak — dan
/// [MabarField.inline] 40 pt berlatar paper tanpa tepi di baris grup (nama court, 03a).
class MabarField extends StatelessWidget {
  final TextEditingController? controller;
  final FocusNode? focusNode;
  final String? hint;
  final bool error;
  final bool inline;

  /// Latar kolom: inline paper di grup putih (03a), card di grup sheet yang berlatar paper (Kelola court).
  final Color fillColor;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final List<TextInputFormatter>? inputFormatters;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final bool autofocus;
  final TextCapitalization textCapitalization;

  const MabarField({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.error = false,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
  }) : inline = false,
       fillColor = MabarColors.card;

  const MabarField.inline({
    super.key,
    this.controller,
    this.focusNode,
    this.hint,
    this.keyboardType,
    this.textInputAction,
    this.inputFormatters,
    this.onChanged,
    this.onSubmitted,
    this.autofocus = false,
    this.textCapitalization = TextCapitalization.none,
    this.fillColor = MabarColors.paper,
  }) : inline = true,
       error = false;

  /// Tinggi baris teks 16/1,4 = 22,4, tapi mesin teks Flutter membulatkannya ke pt bulat (22); padding
  /// vertikal dihitung dari nilai bulat itu supaya kotak tepat 48/40.
  static final _lineHeight = (16 * 1.4).roundToDouble();

  @override
  Widget build(BuildContext context) {
    final height = inline ? 40.0 : 48.0;
    OutlineInputBorder ring(Color color, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(MabarRadius.chip),
      borderSide: width == 0 ? BorderSide.none : BorderSide(color: color, width: width),
      // Bawaan 4: celah label melayang, yang juga menggeser isi 4 pt ke dalam. Mabar tidak memakai label.
      gapPadding: 0,
    );
    final InputBorder rest, focus;
    if (inline) {
      rest = focus = ring(MabarColors.paper, 0);
    } else if (error) {
      rest = focus = ring(MabarColors.clay, 2);
    } else {
      rest = ring(MabarColors.line, 1.5);
      focus = ring(MabarColors.court, 2);
    }
    return TextField(
      controller: controller,
      focusNode: focusNode,
      style: MabarType.body.copyWith(color: MabarColors.ink),
      // `.caret`: 2 pt, setinggi 1,1 em — lebih pendek dari tinggi baris.
      cursorHeight: 16 * 1.1,
      cursorWidth: 2,
      cursorColor: error ? MabarColors.clay : null,
      decoration: InputDecoration(
        hintText: hint,
        isDense: true,
        filled: true,
        fillColor: fillColor,
        contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: (height - _lineHeight) / 2),
        border: rest,
        enabledBorder: rest,
        focusedBorder: focus,
      ),
      keyboardType: keyboardType,
      textInputAction: textInputAction,
      inputFormatters: inputFormatters,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      autofocus: autofocus,
      textCapitalization: textCapitalization,
    );
  }
}

/// `.chip` — pilihan yang bisa diketuk: biasa atau [selected]. [tall] = chip di `.chips.cols` (44 pt,
/// nama dipotong elipsis), dipakai lewat [MabarChipGrid]. Chip tidak dipakai untuk aksi atau daftar hasil.
class MabarChip extends StatelessWidget {
  final String label;
  final bool selected;
  final bool tall;
  final VoidCallback? onTap;

  const MabarChip({super.key, required this.label, this.selected = false, this.tall = false, this.onTap});

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(MabarRadius.chip);
    final text = Text(
      label,
      maxLines: 1,
      softWrap: false,
      overflow: TextOverflow.ellipsis,
      style: MabarType.body.copyWith(
        fontSize: tall ? 16 : 15,
        fontWeight: FontWeight.w500,
        color: selected ? Colors.white : MabarColors.ink,
      ),
    );
    return Semantics(
      button: true,
      selected: selected,
      child: Material(
        color: selected ? MabarColors.ink : MabarColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: radius,
          side: selected ? BorderSide.none : const BorderSide(color: MabarColors.line),
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(
            height: tall ? MabarSize.chipCols : 34,
            child: Padding(
              padding: EdgeInsets.symmetric(horizontal: tall ? 14 : 12),
              // Chip biasa selebar isinya; chip kolom mengisi kolomnya.
              child: Align(alignment: Alignment.centerLeft, widthFactor: tall ? null : 1, child: text),
            ),
          ),
        ),
      ),
    );
  }
}

/// `.chips` — pilihan pendek yang mengalir (alasan WO).
class MabarChipWrap extends StatelessWidget {
  final List<Widget> children;

  const MabarChipWrap({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Wrap(spacing: 6, runSpacing: 6, children: children);
}

/// `.chips.cols` — dua kolom rata 44 pt (daftar nama di Pasangan manual), urut kiri-kanan per baris.
class MabarChipGrid extends StatelessWidget {
  final List<Widget> children;

  const MabarChipGrid({super.key, required this.children});

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var i = 0; i < children.length; i += 2) ...[
        if (i > 0) const SizedBox(height: 8),
        Row(
          children: [
            Expanded(child: children[i]),
            const SizedBox(width: 8),
            Expanded(child: i + 1 < children.length ? children[i + 1] : const SizedBox()),
          ],
        ),
      ],
    ],
  );
}
