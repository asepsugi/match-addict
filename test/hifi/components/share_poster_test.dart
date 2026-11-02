import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/theme/mabar_theme.dart';
import 'package:match_addict/features/share/share_theme.dart';
import 'package:match_addict/features/share/widgets/share_poster.dart';
import 'package:match_addict/models/models.dart';

import '../hifi_golden.dart';
import 'share_poster_data.dart';

/// Golden SharePoster: pratinjau di layar Bagikan (11a, 11b, 11e, 11h, 11i) dan gambar Feed/Story
/// (11d, 11f, 11g, 11k, 11l; di frame Feed 360×360 di x 0, Story 203×360 di x 374, lalu di 11k/11l kartu
/// pratinjau 358×372 di x 591).
void main() {
  final theme = MabarTheme.light();
  const feedAt = Rect.fromLTWH(0, 0, 360, 360), storyAt = Rect.fromLTWH(374, 0, 203, 360);
  const previewAt = Rect.fromLTWH(591, 0, 358, 372);

  Future<void> check(
    WidgetTester tester, {
    required String frame,
    int index = 0,
    required Rect at,
    required SharePosterTarget target,
    required ShareTheme shareTheme,
    required SportType sport,
    required String eyebrow,
    required bool isFinal,
    required String summary,
    String? more,
    bool complete = true,
    double maxDiffRatio = 0.02,
  }) async {
    await precacheHifiAssets(tester, [sport.assetPath]);
    final data = SharePosterData(
      sport: sport,
      eyebrow: eyebrow,
      isFinal: isFinal,
      rows: posterRows[(frame, index)]!,
      summary: summary,
      more: more,
      complete: complete,
    );
    await expectRegionMatchesHifi(
      tester,
      hifiStage(
        theme: theme,
        at: at,
        height: at.height,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(target == SharePosterTarget.preview ? MabarRadius.poster : 4),
          child: SharePoster(data: data, theme: shareTheme, target: target),
        ),
      ),
      frame,
      at,
      label: '${target.name}$index',
      maxDiffRatio: maxDiffRatio,
    );
  }

  testWidgets('pratinjau Ringkas, tema biru, sementara (11a)', (tester) async {
    await check(
      tester,
      frame: '11a',
      at: hifiRect('11a', 'poster'),
      target: SharePosterTarget.preview,
      shareTheme: ShareTheme.biru,
      sport: SportType.padel,
      eyebrow: 'Mabar Jumat PB Garuda',
      isFinal: false,
      summary: '3 round · 6 match · 21 Okt 2026',
      more: '+6 pemain lainnya',
      complete: false,
    );
  });

  testWidgets('pratinjau Lengkap Fixed 10 pasangan, tema peach (11b)', (tester) async {
    await check(
      tester,
      frame: '11b',
      at: hifiRect('11b', 'poster'),
      target: SharePosterTarget.preview,
      shareTheme: ShareTheme.peach,
      sport: SportType.tennis,
      eyebrow: 'Tennis · Fixed · 21 Okt 2026',
      isFinal: true,
      summary: '9 round · 45 match',
    );
  });

  for (final (frame, summary) in [('11e', '8 round · 32 match'), ('11h', '6 round · 18 match'), ('11i', '6 round · 18 match')]) {
    testWidgets('pratinjau Lengkap dua kolom rata ($frame)', (tester) async {
      await check(
        tester,
        frame: frame,
        at: hifiRect(frame, 'poster'),
        target: SharePosterTarget.preview,
        shareTheme: ShareTheme.biru,
        sport: SportType.padel,
        eyebrow: 'Padel · Mixed · 21 Okt 2026',
        isFinal: true,
        summary: summary,
      );
    });
  }

  for (final (target, at, index) in [(SharePosterTarget.feed, feedAt, 0), (SharePosterTarget.story, storyAt, 1)]) {
    testWidgets('gambar Ringkas ${target.name} (11d)', (tester) async {
      await check(
        tester,
        frame: '11d',
        index: index,
        at: at,
        target: target,
        shareTheme: ShareTheme.biru,
        sport: SportType.padel,
        eyebrow: 'Mabar Jumat PB Garuda x Matcha Club 2026',
        isFinal: true,
        summary: '4 round · 8 match · 1 WO · 21 Okt 2026',
        more: '+5 pemain lainnya',
        complete: false,
      );
    });

    testWidgets('gambar Lengkap Mixed 20 ${target.name} (11f)', (tester) async {
      await check(
        tester,
        frame: '11f',
        index: index,
        at: at,
        target: target,
        shareTheme: ShareTheme.biru,
        sport: SportType.padel,
        eyebrow: 'Mabar Jumat PB Garuda x Matcha Club',
        isFinal: true,
        summary: '8 round · 32 match · 21 Okt 2026',
      );
    });

    testWidgets('gambar Lengkap Fixed 10 ${target.name} (11g)', (tester) async {
      await check(
        tester,
        frame: '11g',
        index: index,
        at: at,
        target: target,
        shareTheme: ShareTheme.peach,
        sport: SportType.tennis,
        eyebrow: 'Tennis · Fixed · 21 Okt 2026',
        isFinal: true,
        summary: '9 round · 45 match',
      );
    });
  }

  // Lebih padat dari frame terpadat yang disetujui: pasangan tetap satu kolom, huruf baris dikecilkan.
  for (final (target, at, index) in [
    (SharePosterTarget.feed, feedAt, 0),
    (SharePosterTarget.story, storyAt, 1),
    (SharePosterTarget.preview, previewAt, 2),
  ]) {
    testWidgets('gambar Lengkap Fixed 15 pasangan ${target.name} (11k)', (tester) async {
      await check(
        tester,
        frame: '11k',
        index: index,
        at: at,
        target: target,
        shareTheme: ShareTheme.peach,
        sport: SportType.tennis,
        eyebrow: 'Tennis · Fixed · 21 Okt 2026',
        isFinal: true,
        summary: '10 round · 35 match',
      );
    });

    testWidgets('gambar Lengkap Mixed 30 ${target.name} (11l)', (tester) async {
      await check(
        tester,
        frame: '11l',
        index: index,
        at: at,
        target: target,
        shareTheme: ShareTheme.biru,
        sport: SportType.padel,
        eyebrow: 'Padel · Mixed · 21 Okt 2026',
        isFinal: true,
        summary: '8 round · 32 match',
        // Kotak kepala, baris, dan kaki sama dengan Chrome sampai 0,05 pt; yang tersisa posisi huruf di dalam
        // baris yang lebih rapat dari tinggi alami font (line-height 1,05–1,1), ≤ 1 pt. Di 30 baris rapat itu
        // 1,7% (Feed) / 1,2% (Story) piksel di Mac dan ±0,7 poin lebih tinggi di CI Linux.
        maxDiffRatio: target == SharePosterTarget.preview ? 0.02 : 0.03,
      );
    });
  }
}
