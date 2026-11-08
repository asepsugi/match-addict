import 'package:flutter_test/flutter_test.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/club_score.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/share/result_text_builder.dart';

import '../hifi/screens/sparing_fixture.dart';

/// Caption dan kepadatan poster Bagikan sparing (SP-15, logic.md §13.9, catatan 13q–13w). Caption 13q persis dicek di
/// `test/hifi/screens/sparing_bagikan_test.dart` lewat layar.
void main() {
  setUpAll(() => initializeDateFormatting('id'));

  String caption(ActiveTournament active, {ShareFormat format = ShareFormat.ringkas}) {
    const method = RankingMethod.totalGames;
    final standings = RankingCalculator.rank(
      players: active.config.players,
      matches: active.matches,
      method: method,
      format: active.config.format,
    );
    return ResultTextBuilder.build(
      active: active,
      standings: standingEntries(standings: standings, method: method),
      format: format,
      now: sparingAt(6),
      clubStandings: clubStandings(active: active, standings: standings, method: method),
    );
  }

  group('caption sparing (K7)', () {
    test('Seri menang dan Total Point sama: "6–6 … · Seri · Padel" (14t)', () {
      expect(caption(sparing14t()).split('\n').first, '🏆 PB Garuda 6–6 Matcha Club · Seri · Padel');
    });

    test('match seri: "6½–5½" tanpa "Seri" (14u)', () {
      expect(caption(sparing14u()).split('\n').first, '🏆 PB Garuda 6½–5½ Matcha Club · Padel');
    });

    test('klub kedua unggul: urutan klub tetap (14s)', () {
      expect(caption(sparing14s()).split('\n').first, '🏆 PB Garuda 5–7 Matcha Club · Padel');
    });

    test('sparing bernama: nama di baris kedua sebelum tanggal', () {
      final named = sparingScored(sparingSchedule(sparingConfig(name: 'Mabar Jumat')), scores13c);
      expect(caption(named).split('\n').take(3), [
        '🏆 PB Garuda 7–5 Matcha Club · Padel',
        'Mabar Jumat',
        '4 November 2026',
      ]);
    });

    test('Sementara: blok per klub "Klasemen Sementara · {klub}"', () {
      final text = caption(sparingAfterR5());
      expect(text, contains('Klasemen Sementara · PB Garuda\n'));
      expect(text, contains('\n\nKlasemen Sementara · Matcha Club\n'));
      expect(text.split('\n').first, '🏆 PB Garuda 6–4 Matcha Club · Padel');
    });

    test('Lengkap menambah Hasil per Round, pasangan klub pertama di kiri', () {
      final text = caption(sparingFull(), format: ShareFormat.lengkap);
      expect(text, contains('\n\nHasil per Round\n· Round 1\n  Andi+Budi vs Indra+Joko → 6-3\n'));
      expect(text, endsWith('\n\n6 round · 12 match · 1 WO · 4 Nov 2026'));
    });
  });

  group('sparingPosterDensity (catatan 13s)', () {
    double density(SharePosterTarget target, List<int> clubRows, {bool complete = true, bool pairs = true}) =>
        sparingPosterDensity(
          target: target,
          clubRows: clubRows,
          complete: complete,
          stackPairs: pairs && target == SharePosterTarget.story,
          clubColumns: !pairs && target != SharePosterTarget.story,
        );

    test('Ringkas tidak pernah dikecilkan (13q, 13r)', () {
      for (final t in SharePosterTarget.values) {
        expect(density(t, [3, 3], complete: false), 1);
      }
    });

    test('satu kolom: ambang 8 baris termasuk label; 4 + 3 pasangan → ×8/9 (13s, 13t Feed)', () {
      expect(density(SharePosterTarget.preview, [3, 3]), 1);
      expect(density(SharePosterTarget.preview, [4, 3]), closeTo(8 / 9, 1e-9));
      expect(density(SharePosterTarget.feed, [4, 3]), closeTo(8 / 9, 1e-9));
    });

    test('Story: ambang 16 baris nama; pasangan bertumpuk 7 × 2 + 2 = 16 → penuh (13t)', () {
      expect(density(SharePosterTarget.story, [4, 3]), 1);
      expect(density(SharePosterTarget.story, [4, 4]), closeTo(16 / 18, 1e-9));
    });

    test('Mixed dua kolom per klub: klub terbesar + label, ambang 10 (13u, 13w)', () {
      expect(density(SharePosterTarget.preview, [8, 6], pairs: false), 1);
      expect(density(SharePosterTarget.feed, [16, 14], pairs: false), closeTo(10 / 17, 1e-9));
      expect(density(SharePosterTarget.story, [8, 6], pairs: false), 1);
      expect(density(SharePosterTarget.story, [16, 14], pairs: false), 0.5);
    });
  });
}
