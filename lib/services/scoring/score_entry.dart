import 'package:flutter/foundation.dart';

import '../../models/models.dart';

/// Hasil pemeriksaan skor satu match (pesan di bawah papan skor Input Skor, frame 07b–07h).
sealed class ScoreVerdict {
  const ScoreVerdict();
}

/// Skor sah dengan pemenang. Sisi 1 = `pair1`, 2 = `pair2`.
class ScoreWin extends ScoreVerdict {
  final int winnerSide;
  final int winnerScore;
  final int loserScore;

  const ScoreWin({required this.winnerSide, required this.winnerScore, required this.loserScore});
}

/// Skor sah dan seri — hanya mungkin di format yang [ScoreFormat.canDraw].
class ScoreDraw extends ScoreVerdict {
  const ScoreDraw();
}

/// Skor tidak sah; Simpan mati dan [message] ditampilkan.
class ScoreInvalid extends ScoreVerdict {
  final String message;
  const ScoreInvalid(this.message);
}

/// Aturan skor akhir per format (`design/spec/logic.md` §1).
class ScoreRules {
  /// Memeriksa skor [side1]–[side2] satu match.
  static ScoreVerdict judge(ScoreFormat format, int side1, int side2) {
    final n = format.target;
    final high = side1 > side2 ? side1 : side2;
    final low = side1 > side2 ? side2 : side1;
    switch (format.method) {
      case ScoringMethod.raceTo:
        // Race to N murni: match selesai begitu satu tim mencapai N, jadi skor akhir N lawan 0..N−1.
        if (side1 == side2 && side1 == n) return ScoreInvalid('Hanya satu tim yang bisa mencapai $n');
        if (high < n) return ScoreInvalid('Belum ada yang sampai $n');
        if (high > n || low >= n) return ScoreInvalid('Skor akhir race to $n: $n–0 sampai $n–${n - 1}');
        return _win(side1, side2);
      case ScoringMethod.bestOf:
      case ScoringMethod.americano:
        // Total boleh kurang dari N: match dihentikan begitu lawan tidak mungkin mengejar, yaitu pemenang sudah
        // mencapai ⌊N ÷ 2⌋ + 1 (11–5 di Americano 21). Sisa yang tidak dimainkan bukan poin gratis untuk yang kalah
        // (keputusan host 2026-10-26). Seri hanya dengan total penuh, jadi tetap cuma di N genap ([ScoreFormat.canDraw]).
        if (side1 + side2 > n) return ScoreInvalid('Total ${format.unit} lebih dari $n');
        if (side1 + side2 == n && side1 == side2) return const ScoreDraw();
        if (high < format.minWinningScore) return ScoreInvalid('Minimal skor pemenang ${format.minWinningScore}');
        return _win(side1, side2);
    }
  }

  static ScoreWin _win(int side1, int side2) => side1 > side2
      ? ScoreWin(winnerSide: 1, winnerScore: side1, loserScore: side2)
      : ScoreWin(winnerSide: 2, winnerScore: side2, loserScore: side1);
}

/// Isi papan skor Input Skor: dua kotak (sisi 1 = `pair1`, 2 = `pair2`), kotak aktif, dan aturan keypad
/// (`design/spec/logic.md` §2, frame 07a–07k). Hanya untuk format satu skor per match; format lama
/// tidak diisi lewat keypad ini.
@immutable
class ScoreEntry {
  final ScoreFormat format;
  final int? side1;
  final int? side2;

  /// Kotak yang menerima ketikan; null = belum ada (skor tersimpan dibuka, 07i).
  final int? active;

  /// Sisi yang diisi otomatis `N − x` (Best of, Americano), ditampilkan pudar. Nilainya ikut berubah selama sisi lain
  /// diketik; begitu diketik sendiri jadi nilai tetap.
  final int? autoSide;

  /// Ketikan berikutnya mengganti isi kotak aktif, bukan menambah digit. Benar setelah kotak dipilih
  /// (ketuk, →, atau pindah otomatis), supaya salah ketik 6–4 bisa langsung diganti 7 tanpa menghapus.
  final bool _replaceNext;

  const ScoreEntry._(this.format, this.side1, this.side2, this.active, this.autoSide, this._replaceNext);

  /// Match baru: dua kotak kosong, kotak tim pertama aktif.
  factory ScoreEntry.start(ScoreFormat format) => ScoreEntry._(format, null, null, 1, null, true);

  /// Skor tersimpan dibuka lagi: terisi, belum ada kotak aktif sampai diketuk.
  factory ScoreEntry.edit(ScoreFormat format, SetScore score) =>
      ScoreEntry._(format, score.side1, score.side2, null, null, true);

  int? valueOf(int side) => side == 1 ? side1 : side2;

  static int _other(int side) => side == 1 ? 2 : 1;

  /// Tombol angka [digit] aktif kalau hasilnya tidak melewati [ScoreFormat.maxPerSide]. Sengaja tidak
  /// melihat isi kotak lawan (koreksi 6–4 → 4–6 harus bisa tanpa mengubah lawan dulu).
  bool canType(int digit) {
    final side = active;
    if (side == null) return false;
    return _typed(valueOf(side), digit) <= format.maxPerSide;
  }

  /// Nilai kotak setelah [digit] diketik. Digit ditambahkan di belakang selama masih ada digit yang
  /// muat; kotak yang sudah penuh (atau baru dipilih) diganti isinya — keputusan host 2026-10-22, catatan
  /// 07e: Best of 5 berisi "3" → hanya 6–9 yang mati. Hasil di atas batas = tombol mati.
  int _typed(int? current, int digit) =>
      _replaceNext || current == null || !_canAppend(current) ? digit : current * 10 + digit;

  /// Masih ada digit yang bisa ditambahkan di belakang [current] tanpa melewati batas. 0 tidak diberi
  /// digit kedua.
  bool _canAppend(int current) => current != 0 && current * 10 <= format.maxPerSide;

  ScoreEntry type(int digit) {
    final side = active;
    if (side == null || !canType(digit)) return this;
    final value = _typed(valueOf(side), digit);
    var entry = _set(side, value);

    // Tidak ada digit lagi yang bisa ditambahkan → kursor pindah sendiri ke kotak lawan yang masih kosong.
    if (!_canAppend(value) && entry.valueOf(_other(side)) == null) entry = entry.select(_other(side));
    return entry;
  }

  ScoreEntry backspace() {
    final side = active;
    final current = side == null ? null : valueOf(side);
    if (side == null || current == null) return this;
    // Kotak lawan yang kosong tidak diisi otomatis saat menghapus (jebakan PM #7, logic.md §19.5): menghapus 13–8
    // sampai kosong tidak boleh melewati 1–20; lawan berisi nilai otomatis tetap ikut seperti biasa.
    return _set(side, current < 10 ? null : current ~/ 10, fillEmpty: false);
  }

  /// Kedua kotak kosong: tombol Input Skor membaca Kosongkan skor (logic.md §19.5).
  bool get isEmpty => side1 == null && side2 == null;

  /// Memilih kotak (ketuk kotak, atau → ke tim lawan).
  ScoreEntry select(int side) => ScoreEntry._(format, side1, side2, side, autoSide, true);

  ScoreEntry next() => select(_other(active ?? 2));

  /// Mengisi [side] dengan [value]; Best of & Americano sekalian mengisi lawan `N − x` (atau mengosongkannya kalau
  /// [value] dihapus), tapi hanya kalau kotak lawan kosong atau masih berisi nilai otomatis. Lawan yang sudah diketik
  /// tidak dihitung ulang: mengoreksi 11–5 tidak boleh mengembalikan 11 jadi 16 (keputusan host 2026-10-26).
  /// [fillEmpty] false: kotak lawan yang kosong dibiarkan kosong (⌫).
  ScoreEntry _set(int side, int? value, {bool fillEmpty = true}) {
    var one = side == 1 ? value : side1;
    var two = side == 2 ? value : side2;
    var auto = autoSide == side ? null : autoSide;
    final other = _other(side);
    if (format.fillsOpponent && ((fillEmpty && valueOf(other) == null) || autoSide == other)) {
      final fill = value == null ? null : format.target - value;
      if (other == 1) {
        one = fill;
      } else {
        two = fill;
      }
      auto = fill == null ? null : other;
    }
    return ScoreEntry._(format, one, two, active, auto, false);
  }

  /// Null selama salah satu kotak kosong: Simpan mati tanpa pesan (host sedang mengetik).
  ScoreVerdict? get verdict {
    final a = side1, b = side2;
    if (a == null || b == null) return null;
    return ScoreRules.judge(format, a, b);
  }

  /// Skor yang siap disimpan, atau null kalau belum lengkap/tidak sah.
  SetScore? get score => switch (verdict) {
    ScoreWin() || ScoreDraw() => SetScore(side1: side1!, side2: side2!),
    _ => null,
  };
}
