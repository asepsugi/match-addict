import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../schedule/mixed/resume_tournament_sheet.dart';
import '../schedule/tournament_controller.dart';
import 'app_install.dart';
import 'ios_install_sheet.dart';
import 'widgets/court_banner.dart';
import 'widgets/home_panel.dart';

/// Status pasang PWA. Provider supaya golden bisa menampilkan baris pasang (di `flutter test` implementasinya
/// stub yang selalu `none`).
final appInstallModeProvider = Provider<ValueListenable<AppInstallMode>>((ref) => appInstallMode);

/// Screen 01 · Beranda — lapangan di atas, panel main di bawah (zona jempol). Banner menggambar olahraga
/// yang dipilih, atau olahraga turnamen yang sedang berjalan beserta info round-nya. Panel: pilih olahraga
/// + satu tombol mulai, lalu baris turnamen terakhir (Mixed) dan pasang di HP (web) dalam satu grup.
class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  /// Null = belum diubah host: ikut turnamen berjalan, lalu turnamen terakhir, lalu Tennis.
  SportType? _picked;

  SportType _sport(ActiveTournament? active, ActiveTournament? last) =>
      _picked ?? active?.config.sport ?? last?.config.sport ?? SportType.tennis;

  /// Nama turnamen, atau "Padel · Mixed · 8 pemain" (jumlah pemain aktif sekarang) kalau tanpa nama.
  static String _summary(ActiveTournament t) =>
      t.config.name ?? '${t.config.sport.label} · ${t.config.mode.label} · ${t.activePlayers.length} pemain';

  /// Slot turnamen aktif cuma satu, jadi memulai turnamen baru membuang yang sedang berjalan; dialog 01h
  /// menyebut turnamen mana yang akan hilang.
  Future<void> _start(SportType sport, ActiveTournament? active) async {
    if (active != null) {
      final replace = await showMabarConfirm(
        context,
        title: 'Mulai turnamen baru?',
        message:
            'Turnamen yang berjalan akan dihapus:\n'
            '${active.config.name ?? '${active.config.sport.label} · ${active.config.mode.label}'}, '
            'Round ${active.currentRound}',
        confirmLabel: 'Hapus & mulai baru',
        destructive: true,
      );
      if (!replace) return;
    }
    // Turnamen yang sudah diakhiri tidak dibuang: pindah ke turnamen terakhir, sama dengan "Selesai" di Bagikan.
    final controller = ref.read(tournamentProvider.notifier);
    if (ref.read(tournamentProvider)?.tournament.isFinished ?? false) await controller.close();
    if (mounted) context.push('/setup-peserta', extra: sport);
  }

  Future<void> _resumeLast(ActiveTournament last) async {
    if (!await showResumeTournamentSheet(context, last, archived: true)) return;
    final resumed = ref.read(tournamentProvider);
    if (resumed != null && mounted) context.push('/schedule', extra: resumed.config);
  }

  @override
  Widget build(BuildContext context) {
    // Turnamen yang belum ditutup, dibaca dari device saat app dibuka. Yang sudah diakhiri bukan turnamen berjalan
    // lagi: tampil sebagai turnamen terakhir, seperti sesudah "Selesai" di Bagikan.
    final stored = ref.watch(tournamentProvider);
    final ended = stored?.tournament.isFinished ?? false;
    final active = ended ? null : stored;
    // Turnamen terakhir; hanya Mixed yang bisa dilanjutkan, dan tidak tampil bersama turnamen berjalan.
    final last = ended ? stored : ref.watch(lastFinishedProvider);
    final sport = _sport(active, last);
    final installMode = ref.watch(appInstallModeProvider);

    final banner = CourtBanner(
      // Turnamen berjalan: banner mengikuti turnamen itu, bukan pilihan di panel.
      sport: active?.config.sport ?? sport,
      live: active == null
          ? null
          : CourtBannerLive(
              subtitle: _summary(active),
              title: 'Round ${active.currentRound}',
              progress: active.matches.isEmpty ? 0 : active.playedMatchCount / active.matches.length,
              matches: '${active.playedMatchCount} dari ${active.matches.length} match',
              // Config dioper apa adanya supaya `startIfNeeded` mengenalinya sebagai turnamen yang sama
              // (perbandingannya `identical`) dan tidak menimpa state.
              onContinue: () => context.push('/schedule', extra: active.config),
            ),
    );

    final panel = ValueListenableBuilder(
      valueListenable: installMode,
      builder: (context, mode, _) => HomePanel(
        sport: sport,
        onSport: (s) => setState(() => _picked = s),
        onStart: () => _start(sport, active),
        rows: [
          if (active == null && last != null && last.config.mode == PartnerMode.mixed)
            MabarRow(
              padded: true,
              leading: const MabarRowIcon(MabarIcons.clockCounterClockwise),
              title: _summary(last),
              titleOneLine: true,
              subtitle: 'Selesai di R${last.roundCount} · tambah jam untuk lanjut',
              chevron: true,
              onTap: () => _resumeLast(last),
            ),
          if (mode != AppInstallMode.none)
            MabarRow(
              padded: true,
              leading: const MabarRowIcon(MabarIcons.deviceMobile),
              title: 'Pasang Match Addict di HP',
              subtitle: 'Buka dari layar utama, tanpa browser',
              chevron: true,
              onTap: mode == AppInstallMode.prompt ? promptAppInstall : () => showIosInstallSheet(context),
            ),
        ],
      ),
    );

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: MabarTheme.statusBarLight,
      child: Scaffold(
        backgroundColor: MabarColors.card,
        body: Column(
          children: [
            // Lapangan mengisi sisa tinggi layar dan menerus 24 pt di bawah sudut bulat panel
            // (`.homepanel { margin-top: -24px }`); panel digambar sesudahnya, jadi di atasnya.
            Expanded(
              child: Stack(
                clipBehavior: Clip.none,
                children: [Positioned(left: 0, right: 0, top: 0, bottom: -MabarRadius.homePanel, child: banner)],
              ),
            ),
            panel,
          ],
        ),
      ),
    );
  }
}
