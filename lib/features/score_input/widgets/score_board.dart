import 'package:flutter/material.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../services/scoring/score_entry.dart';

/// `.board` — papan skor gelap: satu baris per tim, nama pemain satu per baris di kiri, satu angka besar di kanan.
/// Kotak aktif berwarna bola dengan garis bawah, angka yang terisi otomatis pudar, kotak kosong "–"
/// (kotak aktif yang kosong dibiarkan kosong). Pemenang ditandai bola di kolom tetap kiri nama — kolom
/// itu ada di kedua tim supaya nama selalu rata — dan nama tim yang kalah dipudarkan. Ketuk kotak =
/// pilih kotak itu.
class ScoreBoard extends StatelessWidget {
  final ScoreEntry entry;

  /// Nama lengkap per tim, satu pemain per baris; yang tidak muat dipotong elipsis di barisnya sendiri.
  final (List<String>, List<String>) names;
  final ValueChanged<int> onSelect;

  const ScoreBoard({super.key, required this.entry, required this.names, required this.onSelect});

  @override
  Widget build(BuildContext context) {
    final winner = switch (entry.verdict) {
      ScoreWin(:final winnerSide) => winnerSide,
      _ => null,
    };
    return ClipRRect(
      borderRadius: BorderRadius.circular(MabarRadius.scoreBoard),
      child: ColoredBox(
        color: MabarColors.ink,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _row(1, names.$1, winner),
            const Divider(height: 1, thickness: 1, color: Color(0x14FFFFFF)),
            _row(2, names.$2, winner),
          ],
        ),
      ),
    );
  }

  Widget _row(int side, List<String> names, int? winner) {
    final win = winner == side, lose = winner != null && !win;
    final value = entry.valueOf(side);
    final active = entry.active == side;
    final cellColor = active
        ? MabarColors.ball
        : value == null
        ? const Color(0x38FFFFFF)
        : entry.autoSide == side
        ? const Color(0x66FFFFFF)
        : const Color(0xF2FFFFFF);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(shape: BoxShape.circle, color: win ? MabarColors.ball : null),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                for (final name in names)
                  Text(
                    name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: MabarType.body.copyWith(
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      height: 1.25,
                      color: lose ? const Color(0x80FFFFFF) : Colors.white,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(width: 6),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => onSelect(side),
            child: Semantics(
              button: true,
              selected: active,
              // "Skor Eko M & Fajar K, 6, dipilih"
              label: 'Skor ${names.join(' & ')}, ${value ?? 'kosong'}${active ? ', dipilih' : ''}',
              excludeSemantics: true,
              // Aktif: latar putih 9% dan garis bawah bola 3 pt di dalam kotak (`inset 0 -3px 0`).
              child: ClipRRect(
                borderRadius: BorderRadius.circular(MabarRadius.smallButton),
                child: Container(
                  width: 128,
                  height: 92,
                  color: active ? const Color(0x17FFFFFF) : null,
                  alignment: Alignment.center,
                  foregroundDecoration: active
                      ? const BoxDecoration(border: Border(bottom: BorderSide(color: MabarColors.ball, width: 3)))
                      : null,
                  child: Text(
                    value?.toString() ?? (active ? '' : '–'),
                    style: MabarType.scoreXl.copyWith(height: 1, color: cellColor),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// `.keypad` — keypad sendiri (tidak membuka keyboard sistem): 1–9, hapus, 0, → ke tim lawan. Tombol
/// angka yang membuat isi kotak melewati batas format mati ([ScoreEntry.canType]); tombol tidak
/// melihat isi kotak lawan. Setiap ketukan menghasilkan [ScoreEntry] baru lewat [onChanged].
class ScoreKeypad extends StatelessWidget {
  final ScoreEntry entry;
  final ValueChanged<ScoreEntry> onChanged;

  const ScoreKeypad({super.key, required this.entry, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    final bottom = MediaQuery.paddingOf(context).bottom.clamp(12.0, double.infinity);
    final keys = <Widget>[
      for (var d = 1; d <= 9; d++) _digit(d),
      _KeypadKey(
        semanticLabel: 'Hapus',
        // Belum ada kotak aktif: ⌫ mati seperti angka (PATCH 3.8.1, B-12).
        onTap: entry.active == null ? null : () => onChanged(entry.backspace()),
        child: Icon(
          MabarIcons.backspace,
          size: MabarSize.icon,
          color: entry.active == null ? MabarColors.off : MabarColors.ink2,
        ),
      ),
      _digit(0),
      _KeypadKey(
        semanticLabel: 'Kotak berikutnya',
        onTap: () => onChanged(entry.next()),
        child: const Icon(MabarIcons.arrowRight, size: MabarSize.icon, color: MabarColors.ink2),
      ),
    ];
    return Padding(
      // 24 pt dari tombol Simpan (dulu 12): jari yang meleset dari Simpan tidak jatuh ke angka (B-11).
      padding: EdgeInsets.fromLTRB(16, 24, 16, bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var r = 0; r < 4; r++) ...[
            if (r > 0) const SizedBox(height: 8),
            Row(
              children: [
                for (var c = 0; c < 3; c++) ...[if (c > 0) const SizedBox(width: 8), Expanded(child: keys[r * 3 + c])],
              ],
            ),
          ],
        ],
      ),
    );
  }

  Widget _digit(int d) {
    final enabled = entry.canType(d);
    return _KeypadKey(
      semanticLabel: '$d',
      onTap: enabled ? () => onChanged(entry.type(d)) : null,
      child: Text(
        '$d',
        style: MabarType.body.copyWith(
          fontSize: 26,
          fontWeight: FontWeight.w700,
          fontVariations: const [FontVariation('wdth', 85)],
          height: 1,
          color: enabled ? MabarColors.ink : MabarColors.off,
        ),
      ),
    );
  }
}

class _KeypadKey extends StatelessWidget {
  final Widget child;
  final String semanticLabel;
  final VoidCallback? onTap;

  const _KeypadKey({required this.child, required this.semanticLabel, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final off = onTap == null;
    return Semantics(
      button: true,
      enabled: !off,
      label: semanticLabel,
      excludeSemantics: true,
      child: Material(
        color: off ? Colors.transparent : MabarColors.card,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(MabarRadius.button),
          side: off ? const BorderSide(color: MabarColors.line) : BorderSide.none,
        ),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: SizedBox(height: MabarSize.keypadKey, child: Center(child: child)),
        ),
      ),
    );
  }
}
