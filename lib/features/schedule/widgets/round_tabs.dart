import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/theme/mabar_icons.dart';
import '../../../core/widgets/mabar_ball.dart';
import '../../../core/widgets/mabar_controls.dart';

/// `.tabs` — tab round + label kanan. Round selesai teks biasa, round berjalan diberi titik bola
/// ([liveRound]), round Fixed yang belum terbuka bergembok ([isFuture], tetap ink-3 dan tetap bisa diketuk). Kalau tidak muat, hanya baris tab
/// yang digeser; label kanan tetap, dan tepi yang menyembunyikan tab dipudarkan 36 pt. Tab terpilih
/// otomatis digeser masuk tampilan saat dibuka dan saat [selected] berubah. Ganti round hanya lewat
/// tab (tanpa geser konten). Lihat frame 06n.
class RoundTabs extends StatefulWidget {
  /// Round 1…[count].
  final int count;
  final int selected;
  final ValueChanged<int> onSelect;
  final int? liveRound;
  final bool Function(int round)? isFuture;

  /// Label kanan: "1/2 match", atau "Waktu habis" dengan [metaAlert].
  final String? meta;
  final bool metaAlert;

  /// Grup + Gugur: teks tab per round (nama babak, 21b); null = "R{n}".
  final String Function(int round)? labelOf;

  /// Grup + Gugur: tab tambahan paling kanan ("Bagan", 21a); nomornya [count] + 1 di [selected] dan [onSelect].
  final String? extraTab;

  const RoundTabs({
    super.key,
    required this.count,
    required this.selected,
    required this.onSelect,
    this.liveRound,
    this.isFuture,
    this.meta,
    this.metaAlert = false,
    this.labelOf,
    this.extraTab,
  });

  @override
  State<RoundTabs> createState() => _RoundTabsState();
}

class _RoundTabsState extends State<RoundTabs> {
  final _scroll = ScrollController();
  final _keys = <int, GlobalKey>{};

  @override
  void initState() {
    super.initState();
    _revealSelected(animate: false);
  }

  @override
  void didUpdateWidget(RoundTabs old) {
    super.didUpdateWidget(old);
    if (old.selected != widget.selected || old.count != widget.count || old.extraTab != widget.extraTab) {
      _revealSelected(animate: true);
    }
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  /// Tab terpilih digeser seperlunya sampai utuh terlihat; round terakhir jadi rapat ke kanan.
  void _revealSelected({required bool animate}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final context = _keys[widget.selected]?.currentContext;
      if (context == null || !mounted) return;
      final duration = animate ? const Duration(milliseconds: 220) : Duration.zero;
      // Grup + Gugur (21b, 21e, 21v): tab sesudahnya ikut terlihat, jadi "Final" dan "Bagan" tidak tersembunyi di kanan.
      final next = widget.extraTab == null ? null : _keys[widget.selected + 1]?.currentContext;
      if (next != null) {
        Scrollable.ensureVisible(
          next,
          alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
          duration: duration,
          curve: Curves.easeOut,
        );
      }
      for (final policy in [
        ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
        ScrollPositionAlignmentPolicy.keepVisibleAtStart,
      ]) {
        Scrollable.ensureVisible(context, alignmentPolicy: policy, duration: duration, curve: Curves.easeOut);
      }
    });
  }

  Widget _tab(int round) {
    final on = round == widget.selected;
    final future = widget.isFuture?.call(round) ?? false;
    final live = round == widget.liveRound;
    final color = on ? MabarColors.ink : MabarColors.ink3;
    final text = round > widget.count ? widget.extraTab! : (widget.labelOf?.call(round) ?? 'R$round');
    // Status dibaca, bukan dari warna/titik: "R3, berjalan" · "R4, terkunci".
    final label = live ? '$text, berjalan' : (future ? '$text, terkunci' : text);
    return MabarTouchOutset(
      key: _keys.putIfAbsent(round, GlobalKey.new),
      // Setengah jarak antartab (22): lebar ketuk tab pendek ("R1") jadi ≥ 44 tanpa menggeser tata letak.
      horizontal: 11,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => widget.onSelect(round),
        child: Semantics(
          selected: on,
          button: true,
          label: label,
          excludeSemantics: true,
          child: Container(
            padding: const EdgeInsets.only(top: 6, bottom: 11),
            // Garis bawah di dalam kotak tab (`inset 0 -2.5px 0`), jadi tinggi tab tidak bertambah.
            foregroundDecoration: on
                ? const BoxDecoration(
                    border: Border(bottom: BorderSide(color: MabarColors.ink, width: 2.5)),
                  )
                : null,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                // `.tabs b.future .lk`: gembok 12 menggantikan pudar (tab terkunci terbaca ink-3).
                if (future) ...[Icon(MabarIcons.lockSimple, size: 12, color: color), const SizedBox(width: 6)],
                Text(
                  text,
                  style: MabarType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w700, color: color),
                ),
                if (live) ...[const SizedBox(width: 6), const LiveDot()],
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final strip = SingleChildScrollView(
      controller: _scroll,
      scrollDirection: Axis.horizontal,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var r = 1; r <= widget.count + (widget.extraTab == null ? 0 : 1); r++) ...[
            if (r > 1) const SizedBox(width: 22),
            _tab(r),
          ],
        ],
      ),
    );
    // Tinggi tab ±38 → area ketuk 48: ketukan 5 pt di atas/bawah dibelokkan ke dalam baris tab.
    return MabarTouchOutset(
      vertical: 5,
      innerInset: const EdgeInsets.only(bottom: 2),
      child: DecoratedBox(
        decoration: const BoxDecoration(
          border: Border(bottom: BorderSide(color: MabarColors.line)),
        ),
        child: Padding(
          // 1 pt bawah = garis (border-box CSS).
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 1),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: _EdgeFade(controller: _scroll, child: strip),
              ),
              if (widget.meta != null) ...[
                const SizedBox(width: 22),
                Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Text(
                    widget.meta!,
                    style: MabarType.caption.copyWith(
                      color: widget.metaAlert ? MabarColors.clay : MabarColors.ink3,
                      fontWeight: widget.metaAlert ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// Memudarkan 36 pt di tepi yang masih menyembunyikan tab (`fade-l` / `fade-r`).
class _EdgeFade extends StatefulWidget {
  final ScrollController controller;
  final Widget child;

  const _EdgeFade({required this.controller, required this.child});

  @override
  State<_EdgeFade> createState() => _EdgeFadeState();
}

class _EdgeFadeState extends State<_EdgeFade> {
  static const _width = 36.0;
  var _left = false, _right = false;

  void _update(ScrollMetrics m) {
    final left = m.pixels > m.minScrollExtent, right = m.pixels < m.maxScrollExtent;
    if (left == _left && right == _right) return;
    setState(() {
      _left = left;
      _right = right;
    });
  }

  @override
  Widget build(BuildContext context) {
    // Metrik (lebar isi) baru ada setelah layout pertama, jadi dengarkan dua-duanya: perubahan metrik
    // dan posisi gulir.
    final child = NotificationListener<ScrollMetricsNotification>(
      onNotification: (n) {
        _update(n.metrics);
        return false;
      },
      child: NotificationListener<ScrollUpdateNotification>(
        onNotification: (n) {
          _update(n.metrics);
          return false;
        },
        child: widget.child,
      ),
    );
    // Selalu ShaderMask: kalau dibungkus/dilepas bergantian, Scrollable di dalamnya dibuat ulang dan
    // posisi gulirnya kembali ke 0.
    return ShaderMask(
      blendMode: BlendMode.dstIn,
      shaderCallback: (rect) {
        final f = _width / rect.width;
        return LinearGradient(
          colors: [
            _left ? Colors.transparent : Colors.black,
            Colors.black,
            Colors.black,
            _right ? Colors.transparent : Colors.black,
          ],
          stops: [0, f, 1 - f, 1],
        ).createShader(rect);
      },
      child: child,
    );
  }
}
