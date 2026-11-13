// Poster Lengkap arah B (PRD §5.9, keputusan 80, 81, 86, 88–90; logic.md §17.3, 17.4, 17.9). Dart murni: hanya angka
// masukan, tidak membaca jam, provider, atau font (L4). Ukuran huruf milik widget, bukan file ini.

/// Kunci `posterLengkap.density`: kartu/Feed 1 kolom, kartu/Feed 2 kolom, Story 1 kolom, Story 2 kolom.
enum LengkapSizing { feed1, feed2, story1, story2 }

/// Angka acuan kepadatan per susunan (`tokens.json → posterLengkap.density`).
class LengkapSizingSpec {
  /// Tinggi baris yang menghasilkan skala 1.
  final double refRow;
  final double maxRow;
  final double maxScale;

  const LengkapSizingSpec({required this.refRow, required this.maxRow, required this.maxScale});
}

const lengkapSizingSpecs = <LengkapSizing, LengkapSizingSpec>{
  LengkapSizing.feed1: LengkapSizingSpec(refRow: 22, maxRow: 30, maxScale: 1.04),
  LengkapSizing.feed2: LengkapSizingSpec(refRow: 18, maxRow: 26, maxScale: 1.0),
  LengkapSizing.story1: LengkapSizingSpec(refRow: 17, maxRow: 42, maxScale: 1.33),
  LengkapSizing.story2: LengkapSizingSpec(refRow: 18, maxRow: 30, maxScale: 1.0),
};

/// Gerbang dua kolom (`posterLengkap.columns`): n di atas angka ini.
const _feedTwoAbove = 10;
const _storyTwoAbove = 20;

/// Satu sel kolom poster Lengkap. `club` = 0 kalau bukan Sparing.
sealed class LengkapCell {
  const LengkapCell();

  /// Tinggi sel dalam satuan tinggi baris.
  int get units;
}

/// Baris pemain/pasangan. `row` = indeks di klubnya (bukan Sparing: indeks Klasemen).
final class LengkapRowCell extends LengkapCell {
  final int club;
  final int row;
  @override
  final int units;

  const LengkapRowCell({required this.club, required this.row, required this.units});
}

/// Kepala klub Sparing: nama + baris kedua, selalu 2 satuan.
final class LengkapClubCell extends LengkapCell {
  final int club;

  const LengkapClubCell({required this.club});

  @override
  int get units => 2;
}

class LengkapGrid {
  final LengkapSizing sizing;

  /// 1 atau 2 kolom, dibaca kiri atas → bawah lalu kanan.
  final List<List<LengkapCell>> columns;

  /// Tinggi kolom terpanjang dalam satuan; 0 = Kosong.
  final int units;

  const LengkapGrid({required this.sizing, required this.columns, required this.units});
}

/// Aturan kolom (81, 86, 88). [rowCounts]: bukan Sparing `[n]`; Sparing `[n1, n2]`. [endless] = `config.mode.isEndless`
/// (Mixed, Mexicano; gerbang dua kolom, bukan "tidak ada baris pasangan"). [pairs] = ada baris dua nama (Fixed).
LengkapGrid lengkapGrid({
  required bool story,
  required bool endless,
  required List<int> rowCounts,
  required bool pairs,
}) {
  assert(rowCounts.length == 1 || rowCounts.length == 2);
  assert(rowCounts.every((n) => n >= 0));
  final sparing = rowCounts.length == 2;
  final total = rowCounts.fold<int>(0, (a, b) => a + b);
  final limit = story ? _storyTwoAbove : _feedTwoAbove;

  // Kosong (termasuk Sparing 0 – 0, keputusan 89): tanpa sel, tanpa kepala klub.
  if (total == 0) {
    return LengkapGrid(sizing: story ? LengkapSizing.story1 : LengkapSizing.feed1, columns: const [[]], units: 0);
  }

  // Fixed Story: semua baris setinggi baris pasangan kalau ada baris dua nama (keputusan 90).
  final rowUnits = !endless && story && pairs ? 2 : 1;

  List<LengkapCell> clubColumn(int club) => [
    LengkapClubCell(club: club),
    for (var i = 0; i < rowCounts[club]; i++) LengkapRowCell(club: club, row: i, units: rowUnits),
  ];

  List<LengkapRowCell> flat(int from, int to) => [
    for (var i = from; i < to; i++) LengkapRowCell(club: 0, row: i, units: rowUnits),
  ];

  final List<List<LengkapCell>> columns;
  final bool two;
  if (!endless) {
    // Fixed (semua pasangan, campuran, Sparing Fixed): tidak pernah dua kolom (L2).
    two = false;
    columns = [
      sparing ? [...clubColumn(0), ...clubColumn(1)] : flat(0, total),
    ];
  } else if (sparing) {
    // Feed selalu per klub; Story hanya kalau total > 20 (86).
    two = !story || total > limit;
    columns = two
        ? [clubColumn(0), clubColumn(1)]
        : [
            [...clubColumn(0), ...clubColumn(1)],
          ];
  } else {
    two = total > limit;
    final k = (total + 1) ~/ 2;
    columns = two ? [flat(0, k), flat(k, total)] : [flat(0, total)];
  }

  final units = columns.map((c) => c.fold<int>(0, (a, cell) => a + cell.units)).reduce((a, b) => a > b ? a : b);
  final sizing = story
      ? (two ? LengkapSizing.story2 : LengkapSizing.story1)
      : (two ? LengkapSizing.feed2 : LengkapSizing.feed1);
  return LengkapGrid(sizing: sizing, columns: columns, units: units);
}

class LengkapDensity {
  /// Tinggi satu satuan baris.
  final double rowHeight;

  /// Pengali ukuran huruf, nomor, jarak (bukan judul, baris kecil, wordmark, fakta, podium mini).
  final double scale;

  const LengkapDensity({required this.rowHeight, required this.scale});
}

/// Kepadatan (80). [space] = ruang panel `bawahPanel − (garisBelakang + jarakPanel) − 6 − kaki`, dihitung tata letak.
/// [units] == 0 (Kosong) → rowHeight 0, scale 1: panel hanya `6 + kaki`.
LengkapDensity lengkapDensity({required LengkapSizing sizing, required int units, required double space}) {
  if (units <= 0) return const LengkapDensity(rowHeight: 0, scale: 1);
  final spec = lengkapSizingSpecs[sizing]!;
  final perUnit = space / units;
  final rowHeight = perUnit < spec.maxRow ? perUnit : spec.maxRow;
  final raw = rowHeight / spec.refRow;
  return LengkapDensity(rowHeight: rowHeight, scale: raw < spec.maxScale ? raw : spec.maxScale);
}
