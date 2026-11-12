import 'package:flutter/widgets.dart';

import 'podium_theme.dart';
import 'share_theme.dart';
import 'widgets/podium_poster.dart';
import 'widgets/share_poster.dart';

/// Satu gambar yang dibagikan: poster, ukuran rancangan, rasio render, dan nama berkas (1080 px lebarnya).
/// Dipisah dari layar supaya ukuran dan rasio ekspor bisa diuji tanpa share sheet.
class ShareImage {
  final Widget poster;
  final Size size;
  final double pixelRatio;
  final String fileName;

  const ShareImage({required this.poster, required this.size, required this.pixelRatio, required this.fileName});
}

const _feedName = 'match-addict-feed-1080x1080.png';
const _storyName = 'match-addict-story-1080x1920.png';

/// Ringkas: Feed 360 × 360 dan Story 360 × 640 dari [PodiumPoster], ×3 (bukan kanvas 203 × 360 poster Lengkap).
List<ShareImage> podiumImages(PodiumPosterData data, PodiumTheme theme) => [
  for (final t in [PodiumPosterTarget.feed, PodiumPosterTarget.story])
    ShareImage(
      poster: PodiumPoster(data: data, theme: theme, target: t),
      size: t.designSize,
      pixelRatio: t.exportPixelRatio,
      fileName: t == PodiumPosterTarget.story ? _storyName : _feedName,
    ),
];

/// Lengkap: [SharePoster] Feed dan Story pada kanvas lamanya.
List<ShareImage> lengkapImages(SharePosterData data, ShareTheme theme) => [
  for (final t in [SharePosterTarget.feed, SharePosterTarget.story])
    ShareImage(
      poster: SharePoster(data: data, theme: theme, target: t),
      size: t.designSize,
      pixelRatio: t.exportPixelRatio,
      fileName: t == SharePosterTarget.story ? _storyName : _feedName,
    ),
];
