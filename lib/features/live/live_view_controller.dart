import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/live/live_relay.dart';
import '../../services/storage/tournament_codec.dart';
import '../schedule/tournament_controller.dart';
import 'live_host_controller.dart';

/// Kode live halaman ini (`#/live/K7Q2MX`). Null = app biasa; di-override `main()` saat web dibuka dari
/// link live, dan sejak itu seluruh app berjalan sebagai penonton.
final liveCodeProvider = Provider<String?>((ref) => null);

enum LiveViewStatus {
  /// Pengecekan pertama belum kembali (12o).
  loading,

  /// Pengecekan terakhir berhasil: tag "Live" (12h).
  live,

  /// Dua pengecekan berturut-turut gagal; data terakhir tetap tampil (12m).
  offline,

  /// Kode salah, live dihentikan, atau terhapus (12n).
  gone,

  /// Dua cek berturut-turut gagal dan belum pernah ada data: "Tidak ada internet" + "Coba lagi" (12p). Beda dengan
  /// [offline] (12m), yang hanya untuk penonton yang sudah punya data.
  noInternet,

  /// "Coba lagi" di [noInternet] sedang berjalan (12r): tombol mati, bola berputar, paling sedikit [LiveViewController.minRetry].
  retrying,

  /// Data dari versi app host yang tidak bisa dibaca (`schemaVersion` lain).
  unreadable,
}

class LiveView {
  final LiveViewStatus status;
  final ActiveTournament? active;

  /// Jam cek terakhir yang berhasil; dipakai tag "Offline · 19.48" (12m).
  final DateTime? lastOk;
  const LiveView(this.status, [this.active, this.lastOk]);
}

/// Halaman penonton: mengecek relay tiap 10 detik selama halaman terlihat (tiap menit setelah Final, kalau
/// host melanjutkan). Null = bukan halaman live — layar memakai ini sebagai tanda mode baca saja.
class LiveViewController extends Notifier<LiveView?> {
  static const interval = Duration(seconds: 10);
  static const finalInterval = Duration(minutes: 1);

  /// Lama tampilan "mencoba" paling sedikit, supaya ketukan terlihat walau cek gagal seketika (12r).
  static const minRetry = Duration(seconds: 1);

  int? _rev;
  int _failures = 0;
  DateTime? _lastOk;
  bool _hidden = false;
  bool _disposed = false;
  Timer? _timer;

  @override
  LiveView? build() {
    final code = ref.watch(liveCodeProvider);
    if (code == null) return null;
    final lifecycle = AppLifecycleListener(onStateChange: _onLifecycle);
    ref.onDispose(() {
      _disposed = true;
      _timer?.cancel();
      lifecycle.dispose();
    });
    Future.microtask(() => _check(code));
    return const LiveView(LiveViewStatus.loading);
  }

  void _onLifecycle(AppLifecycleState lifecycle) {
    final hidden = lifecycle == AppLifecycleState.hidden || lifecycle == AppLifecycleState.paused;
    if (hidden == _hidden) return;
    _hidden = hidden;
    _timer?.cancel();
    // Tab dibuka lagi: langsung dicek, tidak menunggu sisa 10 detik.
    final code = ref.read(liveCodeProvider);
    if (!hidden && code != null && state?.status != LiveViewStatus.gone) unawaited(_check(code));
  }

  /// "Coba lagi" di 12p: cek yang sama dengan cek otomatis, hanya tampilannya ditahan [minRetry] (12r).
  Future<void> retry() async {
    final code = ref.read(liveCodeProvider);
    if (code == null || state?.status != LiveViewStatus.noInternet) return;
    state = const LiveView(LiveViewStatus.retrying);
    await _check(code, hold: Future<void>.delayed(minRetry));
  }

  /// [hold] (khusus [retry]) menahan hasil sampai selesai, supaya hasil yang cepat tidak mematikan putaran bola.
  Future<void> _check(String code, {Future<void>? hold}) async {
    _timer?.cancel();
    final active = state?.active;
    try {
      final result = await ref.read(liveRelayProvider).fetch(code, since: _rev);
      if (hold != null) await hold;
      if (_disposed) return;
      switch (result) {
        case LiveSnapshot(:final rev, :final payload):
          final next = TournamentCodec.decode(payload);
          if (next == null) {
            state = const LiveView(LiveViewStatus.unreadable);
            return;
          }
          _rev = rev;
          _lastOk = ref.read(clockProvider)();
          state = LiveView(LiveViewStatus.live, next, _lastOk);
        case LiveUnchanged():
          _lastOk = ref.read(clockProvider)();
          state = LiveView(LiveViewStatus.live, active, _lastOk);
        case LiveGone():
          state = const LiveView(LiveViewStatus.gone);
          return;
      }
      _failures = 0;
    } catch (_) {
      if (hold != null) await hold;
      if (_disposed) return;
      _failures++;
      // Cek otomatis yang gagal tidak mengakhiri "mencoba" milik [retry].
      final retrying = state?.status == LiveViewStatus.retrying && hold == null;
      if (_failures >= 2 && !retrying) {
        state = LiveView(active == null ? LiveViewStatus.noInternet : LiveViewStatus.offline, active, _lastOk);
      }
    }
    if (_hidden) return;
    final done = state?.active?.isFinal(ref.read(clockProvider)()) ?? false;
    _timer?.cancel();
    _timer = Timer(done ? finalInterval : interval, () => _check(code));
  }
}

final liveViewProvider = NotifierProvider<LiveViewController, LiveView?>(LiveViewController.new);

/// [tournamentProvider] di halaman penonton: turnamen terakhir dari relay, tanpa simpanan ke device
/// (turnamen penonton sendiri di HP-nya tidak tersentuh) dan tanpa mutasi — layarnya baca saja.
class LiveTournamentController extends TournamentController {
  @override
  ActiveTournament? build() => ref.watch(liveViewProvider)?.active;
}
