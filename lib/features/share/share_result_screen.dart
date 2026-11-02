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
import '../../services/share/result_text_builder.dart';
import '../schedule/tournament_controller.dart';
import 'share_content.dart';
import 'share_theme.dart';
import 'widgets/share_poster.dart';

/// Screen 11 · Bagikan — kartu pratinjau, tema, Ringkas/Lengkap; dua gambar (Feed 1:1, Story 9:16)
/// dibagikan lewat share sheet sistem dengan teks hasil sebagai caption. Tema dan format tidak disimpan.
class ShareResultScreen extends ConsumerStatefulWidget {
  const ShareResultScreen({super.key});

  @override
  ConsumerState<ShareResultScreen> createState() => _ShareResultScreenState();
}

class _ShareResultScreenState extends ConsumerState<ShareResultScreen> {
  ShareFormat _format = ShareFormat.ringkas;
  ShareTheme _theme = ShareTheme.biru;
  bool _sharing = false;
  final _actionBar = GlobalKey();

  Future<XFile> _render(SharePosterData data, SharePosterTarget target) async {
    final bytes = await ScreenshotController().captureFromWidget(
      SharePoster(data: data, theme: _theme, target: target),
      context: context,
      targetSize: target.designSize,
      pixelRatio: target.exportPixelRatio,
      delay: const Duration(milliseconds: 60),
    );
    final name = switch (target) {
      SharePosterTarget.story => 'match-addict-story-1080x1920.png',
      _ => 'match-addict-feed-1080x1080.png',
    };
    return XFile.fromData(bytes, name: name, mimeType: 'image/png');
  }

  Future<void> _share(ActiveTournament active, SharePosterData data) async {
    if (_sharing) return;
    setState(() => _sharing = true);
    final caption = ResultTextBuilder.build(
      active: active,
      standings: ref.read(standingEntriesProvider),
      format: _format,
      now: ref.read(clockProvider)(),
    );
    try {
      // Watermark raket harus sudah ter-decode sebelum render di luar layar, kalau tidak posternya tanpa gambar.
      await precacheImage(AssetImage(active.config.sport.assetPath), context);
      if (!mounted) return;
      final files = [for (final t in [SharePosterTarget.feed, SharePosterTarget.story]) await _render(data, t)];
      await Share.shareXFiles(files, text: caption);
    } catch (_) {
      // Share sheet tidak tersedia (desktop/web tertentu): caption disalin.
      await Clipboard.setData(ClipboardData(text: caption));
      if (mounted) {
        // Action bar Bagikan dua tombol: toast tetap 19 pt di atasnya, tidak menutupi "Bagikan hasil".
        final bar = _actionBar.currentContext?.size?.height;
        showMabarToast(context, 'Hasil disalin', bottom: bar == null ? null : bar + 19);
      }
    } finally {
      if (mounted) setState(() => _sharing = false);
    }
  }

  void _finish() {
    ref.read(tournamentProvider.notifier).close();
    context.go('/');
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    if (active == null) return const Scaffold(backgroundColor: MabarColors.paper);

    final entries = ref.watch(standingEntriesProvider);
    final isFinal = active.isFinal(ref.read(clockProvider)());
    final data = sharePosterData(
      active: active,
      entries: entries,
      method: ref.watch(rankingMethodProvider),
      format: _format,
      isFinal: isFinal,
    );
    final config = active.config;
    final fixed = config.mode == PartnerMode.fixed;
    final count = entries.where((e) => e.position != null).length;

    return Scaffold(
      backgroundColor: MabarColors.paper,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          MabarAppBar(
            title: 'Bagikan hasil',
            subtitle: '${config.sport.label} · ${config.mode.label} · ${isFinal ? 'akhir' : 'sementara'}',
            onBack: () => context.pop(),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
              children: [
                SizedBox(
                  height: SharePosterTarget.preview.designSize.height,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(MabarRadius.poster),
                    child: SharePoster(data: data, theme: _theme, target: SharePosterTarget.preview),
                  ),
                ),
                const SizedBox(height: 14),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final t in ShareTheme.values)
                      _ThemeSwatch(theme: t, selected: t == _theme, onTap: () => setState(() => _theme = t)),
                  ],
                ),
                const SizedBox(height: 14),
                MabarSection(
                  note: MabarGroupNote(
                    '${_format == ShareFormat.ringkas ? '$shareSummaryCount teratas' : 'Semua $count ${fixed ? 'pasangan' : 'pemain'}'}'
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
                  : MabarButton(label: 'Bagikan hasil', icon: MabarIcons.shareNetwork, onPressed: () => _share(active, data)),
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

/// `.theme` — lingkaran gradien tema 30 pt dengan tepi tipis; terpilih = celah paper 3 lalu cincin tinta 2.
class _ThemeSwatch extends StatelessWidget {
  final ShareTheme theme;
  final bool selected;
  final VoidCallback onTap;

  const _ThemeSwatch({required this.theme, required this.selected, required this.onTap});

  @override
  Widget build(BuildContext context) => Semantics(
    button: true,
    selected: selected,
    label: 'Tema ${theme.name}',
    child: GestureDetector(
      onTap: onTap,
      child: Container(
        width: 30,
        height: 30,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: theme.gradientFor(const Size.square(30)),
          boxShadow: selected
              ? const [BoxShadow(color: MabarColors.ink, spreadRadius: 5), BoxShadow(color: MabarColors.paper, spreadRadius: 3)]
              : null,
        ),
        // `inset 0 0 0 1px rgba(0,0,0,.08)`; cincin terpilih menggantikannya.
        foregroundDecoration: selected
            ? null
            : BoxDecoration(shape: BoxShape.circle, border: Border.all(color: const Color(0x14000000))),
      ),
    ),
  );
}
