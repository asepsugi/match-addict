import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';

/// `.compose` — kotak teks nama dengan toolbar aksi di dalam kartunya (paling banyak dua `MabarTextButton`
/// ikon 20), garis pemisah di atas toolbar; fokus = tepi biru court di seluruh kartu. Tinggi 4–6 baris,
/// lebih dari itu digulir di dalam dengan penanda gulir tipis.
class NameListField extends StatefulWidget {
  final TextEditingController controller;
  final FocusNode? focusNode;
  final String? hint;

  /// Aksi di kiri toolbar (Tempel, Contoh).
  final List<Widget> tools;

  /// Aksi di ujung kanan toolbar (Hapus semua, clay).
  final Widget? trailingTool;
  final ValueChanged<String>? onChanged;

  const NameListField({
    super.key,
    required this.controller,
    this.focusNode,
    this.hint,
    this.tools = const [],
    this.trailingTool,
    this.onChanged,
  });

  @override
  State<NameListField> createState() => _NameListFieldState();
}

class _NameListFieldState extends State<NameListField> {
  late final FocusNode _focus = widget.focusNode ?? FocusNode();
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    _focus.addListener(_refresh);
  }

  @override
  void dispose() {
    _focus.removeListener(_refresh);
    if (widget.focusNode == null) _focus.dispose();
    _scroll.dispose();
    super.dispose();
  }

  void _refresh() => setState(() {});

  static final _text = MabarType.body.copyWith(height: 1.6, color: MabarColors.ink);

  @override
  Widget build(BuildContext context) {
    final focused = _focus.hasFocus;
    return Container(
      decoration: BoxDecoration(
        color: MabarColors.card,
        borderRadius: BorderRadius.circular(MabarRadius.group),
      ),
      foregroundDecoration: BoxDecoration(
        borderRadius: BorderRadius.circular(MabarRadius.group),
        border: Border.all(color: focused ? MabarColors.court : MabarColors.edge, width: focused ? 2 : 1.5),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          RawScrollbar(
            controller: _scroll,
            // `.thumb` tampil selama isinya lebih panjang dari kotak, bukan hanya saat digulir (02b).
            thumbVisibility: true,
            thumbColor: MabarColors.off,
            thickness: 3,
            radius: const Radius.circular(2),
            crossAxisMargin: 5,
            mainAxisMargin: 10,
            child: TextField(
              controller: widget.controller,
              focusNode: _focus,
              scrollController: _scroll,
              minLines: 4,
              maxLines: 6,
              keyboardType: TextInputType.multiline,
              textCapitalization: TextCapitalization.words,
              style: _text,
              cursorHeight: 16 * 1.1,
              onChanged: widget.onChanged,
              decoration: InputDecoration(
                hintText: widget.hint,
                hintMaxLines: 6,
                hintStyle: _text.copyWith(color: MabarColors.ink3),
                isDense: true,
                filled: false,
                border: InputBorder.none,
                enabledBorder: InputBorder.none,
                focusedBorder: InputBorder.none,
                // CSS: padding 14 + baris 25,6. Mesin teks membulatkan tiap baris ke 26, jadi padding 13
                // menjaga tinggi kotak 4 dan 6 baris dalam 0,4 pt dari hi-fi (130,4 / 181,6).
                contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 13),
              ),
            ),
          ),
          DecoratedBox(
            decoration: const BoxDecoration(border: Border(top: BorderSide(color: MabarColors.line))),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(2, 1, 2, 0),
              child: Row(children: [...widget.tools, const Spacer(), ?widget.trailingTool]),
            ),
          ),
        ],
      ),
    );
  }
}
