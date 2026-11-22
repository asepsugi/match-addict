import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:screenshot/screenshot.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../../services/share/podium.dart';
import '../../services/share/result_text_builder.dart';
import '../schedule/sparing_providers.dart';
import '../schedule/tournament_controller.dart';
import 'podium_theme.dart';
import 'share_content.dart';
import 'share_download.dart';
import 'share_exports.dart';
import 'share_theme.dart';
import 'widgets/podium_poster.dart';
import 'widgets/share_poster.dart';

/// Hasil [runShare]: [done] = share sheet menangani (sukses, ditutup, atau `unavailable` di web) → tanpa toast;
/// [downloaded] = gambar diunduh; [captionOnly] = hanya caption yang disalin.
enum ShareOutcome { done, downloaded, captionOnly }

/// Tiga tahap terpisah (11c, 11n, keputusan 117), tanpa `catch` tunggal: render gagal → [ShareOutcome.captionOnly]
/// tanpa membuka share sheet; share_plus melempar → unduh ([ShareOutcome.downloaded] kalau berhasil); apa pun yang
/// dikembalikan share_plus (termasuk `dismissed`) → [ShareOutcome.done].
Future<ShareOutcome> runShare({
  required Future<List<XFile>> Function() render,
  required Future<Object?> Function(List<XFile> files) share,
  required Future<bool> Function(List<XFile> files) download,
}) async {
  final List<XFile> files;
  try {
    files = await render();
  } catch (_) {
    return ShareOutcome.captionOnly;
  }
  try {
    await share(files);
    return ShareOutcome.done;
  } catch (_) {
    // Share sheet tidak ada/gagal (desktop, browser tertentu): unduh gambar kalau platformnya bisa.
  }
  final downloaded = await download(files);
  return downloaded ? ShareOutcome.downloaded : ShareOutcome.captionOnly;
}

/// Pengganti [ShareResultScreen] untuk test; null = perilaku sebenarnya.
class ShareHooks {
  final Future<XFile> Function(ShareImage image)? render;
  final Future<bool> Function(List<XFile> files)? download;

  const ShareHooks({this.render, this.download});
}

/// Screen 11 · Bagikan — kartu pratinjau, tema, Ringkas/Lengkap; dua gambar (Feed 1:1, Story 9:16)
/// dibagikan lewat share sheet sistem dengan teks hasil sebagai caption. Tema dan format tidak disimpan.
class ShareResultScreen extends ConsumerStatefulWidget {
  /// Hanya test: mengganti render/unduhan supaya 11c (unduh berhasil) dan 11n (render gagal) bisa digolden.
  @visibleForTesting
  final ShareHooks hooks;

  const ShareResultScreen({super.key, this.hooks = const ShareHooks()});

  @override
  ConsumerState<ShareResultScreen> createState() => _ShareResultScreenState();
}

class _ShareResultScreenState extends ConsumerState<ShareResultScreen> {
  ShareFormat _format = ShareFormat.ringkas;

  /// Null = lapangan (bawaan kedua format, lantainya ikut olahraga).
  ShareTheme? _theme;
  bool _sharing = false;
  final _actionBar = GlobalKey();

  Future<XFile> _render(ShareImage image) async {
    final bytes = await ScreenshotController().captureFromWidget(
      image.poster,
      context: context,
      targetSize: image.size,
      pixelRatio: image.pixelRatio,
      delay: const Duration(milliseconds: 60),
    );
    return XFile.fromData(bytes, name: image.fileName, mimeType: 'image/png');
  }

  Future<void> _share(ActiveTournament active, List<ShareImage> images) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final caption = ResultTextBuilder.build(
      active: active,
      standings: ref.read(standingEntriesProvider),
      format: _format,
      now: ref.read(clockProvider)(),
      method: ref.read(rankingMethodProvider),
      clubStandings: ref.read(clubStandingEntriesProvider),
    );
    final outcome = await runShare(
      render: () async => [for (final image in images) await (widget.hooks.render ?? _render)(image)],
      share: (files) {
        // Tanpa ini share_plus web mengunduh sendiri lalu diam-diam "berhasil" tanpa caption (jebakan PM #6).
        Share.downloadFallbackEnabled = false;
        return Share.shareXFiles(files, text: caption);
      },
      download: widget.hooks.download ?? downloadShareFiles,
    );
    try {
      if (outcome != ShareOutcome.done) {
        await Clipboard.setData(ClipboardData(text: caption));
        if (mounted) {
          // Action bar Bagikan dua tombol: toast tetap 19 pt di atasnya, tidak menutupi "Bagikan hasil".
          final bar = _actionBar.currentContext?.size?.height;
          showMabarToast(
            context,
            outcome == ShareOutcome.downloaded ? 'Gambar diunduh · hasil disalin' : 'Hasil disalin',
            bottom: bar == null ? null : bar + 19,
          );
        }
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  Widget _gradientSwatch(ShareTheme t, double size) => _ThemeSwatch(
    size: size,
    label: 'Tema ${t.name}',
    gradient: t.gradientFor(Size.square(size)),
    selected: t == _theme,
    soft: t.isLight,
    onTap: () => setState(() => _theme = t),
  );

  void _finish() {
    ref.read(tournamentProvider.notifier).close();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    if (active == null) return const Scaffold(backgroundColor: MabarColors.paper);

    final entries = ref.watch(standingEntriesProvider);
    final clubEntries = ref.watch(clubStandingEntriesProvider);
    final clubResult = ref.watch(clubScoreProvider);
    final method = ref.watch(rankingMethodProvider);
    final isFinal = active.isFinal(ref.read(clockProvider)());
    final ringkas = _format == ShareFormat.ringkas;
    final config = active.config;

    // Ringkas = podium, Lengkap = podium mini + daftar penuh; pratinjau dan gambar ekspor dari data yang sama. Kedua
    // format memakai tema poster yang sama (keputusan 76): lapangan → lantai ikut olahraga, gradien → turunannya.
    final theme = _theme == null ? PodiumTheme.court(config.sport) : PodiumTheme.gradient(_theme!);
    final Widget preview;
    final List<ShareImage> images;
    if (ringkas) {
      final data = podiumPosterData(
        active: active,
        entries: entries,
        method: method,
        isFinal: isFinal,
        clubResult: clubResult,
        clubEntries: clubEntries,
      );
      preview = PodiumPoster(data: data, theme: theme, target: PodiumPosterTarget.card);
      images = podiumImages(data, theme);
    } else {
      final data = sharePosterData(
        active: active,
        entries: entries,
        method: method,
        isFinal: isFinal,
        clubResult: clubResult,
        clubEntries: clubEntries,
      );
      preview = SharePoster(data: data, theme: theme, target: PodiumPosterTarget.card);
      images = lengkapImages(data, theme);
    }
    // Sparing: jumlah dan kata dari baris per klub (nomor per klub), bukan dari Klasemen gabungan.
    final rowsByClub = clubEntries.isEmpty ? entries : [for (final g in clubEntries) ...g.entries];
    final count = rowsByClub.where((e) => e.position != null).length;

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: 'Bagikan hasil',
            subtitle: '${config.sport.label} · ${shareModeLabel(config)} · ${isFinal ? 'Final' : 'Sementara'}',
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                // Poster berukuran tetap (358): di layar lebih sempit mengecil, bukan meluber.
                ClipRRect(
                  borderRadius: BorderRadius.circular(MabarRadius.poster),
                  child: FittedBox(fit: BoxFit.scaleDown, child: preview),
                ),
                const SizedBox(height: 14),
                // `.themes.fit`: lapangan + 10 gradien = 11 lingkaran 27 pt satu baris, sama di Ringkas dan Lengkap
                // (keputusan 76).
                MabarTouchOutset(
                  // Deret 30 → area ketuk 48 (lingkaran 27).
                  vertical: 9,
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: SizedBox(
                      height: 30,
                      child: Row(
                        spacing: 6,
                        children: [
                          _ThemeSwatch(
                            size: 27,
                            label: 'Tema lapangan',
                            gradient: _courtSwatch(config.sport),
                            selected: _theme == null,
                            onTap: () => setState(() => _theme = null),
                          ),
                          for (final t in ShareTheme.values) _gradientSwatch(t, 27),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                MabarSection(
                  note: MabarGroupNote(
                    '${ringkas ? 'Podium' : ['Semua $count', ?rowNoun(active, rowsByClub)].join(' ')}'
                    ' · gambar Feed 1:1 & Story 9:16',
                  ),
                  child: MabarSegmented<ShareFormat>(
                    options: [for (final f in ShareFormat.values) (f, f.label)],
                    selected: _format,
                    onChanged: (f) => setState(() => _format = f),
                  ),
                ),
              ],
            ),
          ),
          MabarActionBar(
            key: _actionBar,
            column: true,
            children: [
              _sharing
                  ? const MabarButton(label: 'Menyiapkan gambar…', icon: MabarIcons.image)
                  : MabarButton(
                      label: 'Bagikan hasil',
                      icon: MabarIcons.shareNetwork,
                      onPressed: () => _share(active, images),
                    ),
              MabarButton(
                label: 'Selesai',
                icon: MabarIcons.house,
                variant: MabarButtonVariant.secondary,
                onPressed: _finish,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// `.theme.fit` — lingkaran gradien tema (27 pt) dengan tepi tipis; terpilih = celah paper 3 lalu cincin
/// tinta 2.
class _ThemeSwatch extends StatelessWidget {
  final double size;
  final String label;
  final Gradient gradient;
  final bool selected;

  /// `.theme.soft`: gradien lembut bertepi tinta 20% (tetap ada saat terpilih), bukan tepi hitam 8% yang nyaris tak terlihat.
  final bool soft;
  final VoidCallback onTap;

  const _ThemeSwatch({
    required this.size,
    required this.label,
    required this.gradient,
    required this.selected,
    this.soft = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) => MabarTouchOutset(
    // Slot selebar lingkaran + setengah jarak (3) tiap sisi; tinggi 48 dari deret (lihat pemanggil).
    horizontal: 3,
    child: Semantics(
      button: true,
      selected: selected,
      label: label,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: Container(
          width: size,
          height: size,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: gradient,
            boxShadow: selected
                ? const [
                    BoxShadow(color: MabarColors.ink, spreadRadius: 5),
                    BoxShadow(color: MabarColors.paper, spreadRadius: 3),
                  ]
                : null,
          ),
          // `inset 0 0 0 1px rgba(0,0,0,.08)`; cincin terpilih menggantikannya.
          foregroundDecoration: selected && !soft
              ? null
              : BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: soft ? const Color(0x330F1E2C) : const Color(0x14000000)),
                ),
        ),
      ),
    ),
  );
}

/// Lingkaran lapangan: `linear-gradient(180deg, court-deep 46%, #fff 46% 54%, lantai 54%)`; lantai ikut olahraga.
LinearGradient _courtSwatch(SportType sport) {
  final floor = PodiumTheme.court(sport).floor;
  return LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [MabarColors.courtDeep, MabarColors.courtDeep, Colors.white, Colors.white, floor, floor],
    stops: const [0, 0.46, 0.46, 0.54, 0.54, 1],
  );
}
