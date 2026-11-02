import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/time_text.dart';
import '../../core/widgets/mabar_ball.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../../services/live/live_relay.dart';
import '../schedule/tournament_controller.dart';
import 'live_host_controller.dart';
import 'live_view_controller.dart';

/// Item "Live score" menu ⋯ Jadwal (12a, 12f): titik bola kalau live menyala.
MabarMenuItem<T> liveScoreMenuItem<T>(WidgetRef ref, T value) => MabarMenuItem(
  icon: MabarIcons.broadcast,
  label: 'Live score',
  value: value,
  live: ref.read(liveHostProvider) != null,
);

/// Dari menu ⋯: belum live → dialog mulai (12b), gagal → toast (12g); sudah live → langsung sheet (12c).
Future<void> openLiveScore(BuildContext context, WidgetRef ref) async {
  if (ref.read(liveHostProvider) == null) {
    final ok = await showMabarConfirm(
      context,
      title: 'Mulai live score?',
      message: 'Jadwal, skor, dan nama pemain bisa dilihat siapa saja yang punya link.',
      confirmLabel: 'Mulai',
    );
    if (!ok || !context.mounted) return;
    if (!await ref.read(liveHostProvider.notifier).start()) {
      if (context.mounted) {
        showMabarToast(context, 'Tidak ada internet · live belum dimulai', icon: MabarIcons.wifiSlash);
      }
      return;
    }
  }
  if (context.mounted) await showMabarSheetRoute<void>(context, builder: (_) => const LiveScoreSheet());
}

/// Sheet Live score (12c, 12d): link penonton, jam kiriman terakhir, Bagikan link, Hentikan (→ 12e).
class LiveScoreSheet extends ConsumerWidget {
  const LiveScoreSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final live = ref.watch(liveHostProvider);
    if (live == null) return const SizedBox.shrink();
    final sent = live.sentAt == null ? null : clockText(live.sentAt!);
    return MabarSheet(
      title: 'Live score',
      subtitle: live.waiting
          ? ['Menunggu internet', if (sent != null) 'terakhir terkirim $sent'].join(' · ')
          : 'Terkirim ${sent ?? ''}'.trim(),
      action: MabarTextButton(label: 'Hentikan', tone: MabarTextTone.danger, onPressed: () => _stop(context, ref)),
      footer: MabarButton(
        label: 'Bagikan link',
        icon: MabarIcons.shareNetwork,
        onPressed: () => _share(context, ref, live),
      ),
      child: MabarGroup(
        children: [
          MabarRow(
            padded: true,
            leading: const MabarRowIcon(MabarIcons.link),
            // `.url` — tanpa skema, pindah baris sesudah "match-addict/" (<wbr> di frame) supaya kodenya tidak terpotong.
            titleWidget: Text(
              '${LiveRelay.viewerBase.replaceFirst('https://', '')}\n#/live/${live.code}',
              style: MabarType.body.copyWith(fontSize: 15, fontWeight: FontWeight.w600, height: 1.35),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _stop(BuildContext context, WidgetRef ref) async {
    final ok = await showMabarConfirm(
      context,
      title: 'Hentikan live score?',
      message: 'Link tidak bisa dibuka lagi.',
      confirmLabel: 'Hentikan',
      destructive: true,
    );
    if (!ok || !context.mounted) return;
    if (await ref.read(liveHostProvider.notifier).stop()) {
      if (context.mounted) Navigator.of(context).pop();
    } else if (context.mounted) {
      showMabarToast(
        context,
        'Tidak ada internet · live belum dihentikan',
        icon: MabarIcons.wifiSlash,
        bottom: _toastBottom(context),
      );
    }
  }

  Future<void> _share(BuildContext context, WidgetRef ref, LiveHost live) async {
    final config = ref.read(tournamentProvider)?.config;
    final text = 'Live score ${config?.name ?? config?.sport.label ?? ''}'.trim();
    try {
      await Share.share('$text\n${live.link}');
    } catch (_) {
      // Share sheet tidak tersedia (browser lama): link disalin, seperti Bagikan poster.
      await Clipboard.setData(ClipboardData(text: live.link));
      if (context.mounted) showMabarToast(context, 'Link disalin', bottom: _toastBottom(context));
    }
  }

  /// 19 pt di atas tombol Bagikan link, seperti toast di atas action bar.
  static double _toastBottom(BuildContext context) =>
      MabarSize.primaryButton + max(16.0, MediaQuery.paddingOf(context).bottom) + 19;
}

/// `.livetag` — pengganti ⋯ di Jadwal penonton: "Live" (12h) atau "Offline" abu (12m). Tidak tampil setelah Final.
class LiveTag extends ConsumerWidget {
  const LiveTag({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final offline = ref.watch(liveViewProvider.select((v) => v?.status == LiveViewStatus.offline));
    return Padding(
      padding: const EdgeInsets.only(right: 4),
      child: Container(
        height: 30,
        padding: const EdgeInsets.symmetric(horizontal: 11),
        decoration: BoxDecoration(color: MabarColors.card, borderRadius: BorderRadius.circular(15)),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            LiveDot(off: offline),
            const SizedBox(width: 6),
            Text(
              offline ? 'Offline' : 'Live',
              style: MabarType.body.copyWith(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                color: offline ? MabarColors.ink3 : MabarColors.ink,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
