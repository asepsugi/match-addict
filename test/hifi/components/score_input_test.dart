import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/score_input/widgets/score_board.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/scoring/score_entry.dart';

import '../hifi_golden.dart';

/// Golden ScoreBoard + ScoreKeypad. Isi papan dibuat lewat ketikan [ScoreEntry] yang sama dengan yang
/// dilakukan host, bukan disusun tangan.
void main() {
  final theme = MabarTheme.light();
  const race6 = ScoreFormat(ScoringMethod.raceTo, 6);
  const americano21 = ScoreFormat(ScoringMethod.americano, 21);
  const bestOf5 = ScoreFormat(ScoringMethod.bestOf, 5), bestOf6 = ScoreFormat(ScoringMethod.bestOf, 6);

  ScoreEntry typed(ScoreFormat f, List<int> digits) => digits.fold(ScoreEntry.start(f), (e, d) => e.type(d));

  for (final (frame, entry, names) in [
    // 07b: 6 lalu 4 — kursor tetap di kotak kedua.
    ('07b', typed(race6, [6, 4]), (['Eko M', 'Fajar K'], ['Gina R', 'Hana T'])),
    // 07k: "4" penuh di Race to 6, kursor pindah ke kotak kedua yang kosong.
    ('07k', typed(race6, [4]), (['Eko M', 'Fajar K'], ['Gina R', 'Hana T'])),
    // 07h: "2" di Americano 21, lawan terisi 19 dan menang.
    ('07h', typed(americano21, [2]), (['Andi P', 'Dewant R'], ['Citra L', 'Fajar K'])),
  ]) {
    testWidgets('ScoreBoard ($frame)', (tester) async {
      final at = hifiRect(frame, 'board');
      await expectRegionMatchesHifi(
        tester,
        hifiStage(theme: theme, at: at, child: ScoreBoard(entry: entry, names: names, onSelect: (_) {})),
        frame,
        at,
        label: 'board',
      );
    });
  }

  for (final (frame, entry) in [
    ('07a', ScoreEntry.start(race6)),
    // Kotak penuh: angka berikutnya mengganti isi, jadi yang mati hanya angka di atas batas.
    ('07b', typed(race6, [6, 4])),
    ('07c', typed(race6, [6, 5])),
    ('07d', typed(race6, [6, 6])),
    ('07e', typed(bestOf5, [3])),
    ('07f', typed(bestOf6, [3])),
    ('07g', typed(americano21, [1, 3])),
    ('07h', typed(americano21, [2])),
    // Ubah skor: belum ada kotak aktif, semua angka mati.
    ('07i', ScoreEntry.edit(race6, const SetScore(side1: 6, side2: 4))),
    ('07k', typed(race6, [4])),
  ]) {
    testWidgets('ScoreKeypad: tombol di atas batas mati ($frame)', (tester) async {
      final at = hifiRect(frame, 'keypad');
      await expectRegionMatchesHifi(
        tester,
        hifiStage(theme: theme, at: at, child: ScoreKeypad(entry: entry, onChanged: (_) {})),
        frame,
        at,
        label: 'keypad',
      );
    });
  }
}
