import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/models.dart';
import '../../services/live/live_relay.dart';
import '../../services/storage/tournament_codec.dart';
import '../schedule/tournament_controller.dart';

/// Relay live score; di-override test dengan `MockClient`.
final liveRelayProvider = Provider<LiveRelay>((ref) => LiveRelay());

/// Live turnamen aktif di HP host, untuk menu ⋯ dan sheet Live score (12a–12g).
class LiveHost {
  final String code;
  final DateTime? sentAt;

  /// Kiriman terakhir gagal (tidak ada internet); dicoba lagi tiap 30 detik dan tiap ada perubahan.
  final bool waiting;

  const LiveHost({required this.code, this.sentAt, this.waiting = false});

  String get link => LiveRelay.link(code);
}

/// Mengirim turnamen aktif ke relay setiap kali berubah, selama live-nya menyala. Null = turnamen aktif
/// tidak sedang live. Harus hidup sepanjang app (didengar `MabarApp`), bukan hanya selama layar Jadwal
/// terbuka: skor juga diisi dari Input Skor, dan resume dari Beranda harus langsung mengirim lagi.
class LiveHostController extends Notifier<LiveHost?> {
  LiveSession? _session;
  bool _sending = false;
  bool _dirty = false;
  bool _waiting = false;
  bool _disposed = false;
  Timer? _retry;

  static const retryDelay = Duration(seconds: 30);

  LiveRelay get _relay => ref.read(liveRelayProvider);

  @override
  LiveHost? build() {
    _session = ref.read(tournamentStoreProvider).loadLive();
    ref.onDispose(() {
      _disposed = true;
      _retry?.cancel();
    });
    ref.listen(tournamentProvider, (_, next) => _onTournament(next));
    // App dibuka ulang: perubahan yang belum sempat terkirim sebelum app ditutup ikut terkirim sekarang.
    if (_isLive(ref.read(tournamentProvider))) Future.microtask(_send);
    return _view();
  }

  bool _isLive(ActiveTournament? active) => active != null && active.tournament.id == _session?.tournamentId;

  LiveHost? _view() {
    final s = _session;
    if (s == null || !_isLive(ref.read(tournamentProvider))) return null;
    return LiveHost(code: s.code, sentAt: s.sentAt, waiting: _waiting);
  }

  void _onTournament(ActiveTournament? next) {
    final s = _session;
    if (s == null) return;
    if (_isLive(next)) {
      unawaited(_send());
    } else if (next != null && ref.read(lastFinishedProvider)?.tournament.id != s.tournamentId) {
      // Turnamen live-nya dibuang ("Hapus & mulai baru"): link ikut berhenti. Kalau tidak ada internet, data
      // di relay terhapus sendiri setelah 3 hari. Selesai lewat Bagikan tidak masuk sini: turnamennya pindah
      // ke Turnamen terakhir dan live tetap menampilkan hasilnya.
      unawaited(_relay.delete(s.code, s.token).catchError((_) {}));
      _setSession(null);
    }
    state = _view();
  }

  void _setSession(LiveSession? session) {
    // Balasan relay yang datang setelah controller dibuang (test, hot restart) tidak menyentuh simpanan lagi.
    if (_disposed) return;
    _session = session;
    if (session == null) {
      _retry?.cancel();
      _retry = null;
      _waiting = false;
    }
    unawaited(ref.read(tournamentStoreProvider).saveLive(session));
  }

  /// Mulai live untuk turnamen aktif (dialog 12b). False = gagal (tidak ada internet, relay menolak).
  Future<bool> start() async {
    final active = ref.read(tournamentProvider);
    if (active == null) return false;
    try {
      final created = await _relay.create(TournamentCodec.encode(active));
      _setSession(
        LiveSession(
          tournamentId: active.tournament.id,
          code: created.code,
          token: created.token,
          sentAt: ref.read(clockProvider)(),
        ),
      );
    } catch (_) {
      return false;
    }
    if (_disposed) return true;
    state = _view();
    // Skor yang masuk selama permintaan berjalan.
    if (!identical(active, ref.read(tournamentProvider))) unawaited(_send());
    return true;
  }

  /// Hentikan live (dialog 12e): data di relay dihapus saat itu juga. False = tidak ada internet; live tetap
  /// menyala supaya "Link tidak bisa dibuka lagi" benar.
  Future<bool> stop() async {
    final s = _session;
    if (s == null) return true;
    try {
      await _relay.delete(s.code, s.token);
    } catch (_) {
      return false;
    }
    if (_disposed) return true;
    _setSession(null);
    state = _view();
    return true;
  }

  /// Satu kiriman berjalan sekaligus; perubahan selama itu dikirim sesudahnya sebagai keadaan terbaru.
  Future<void> _send() async {
    final s = _session;
    final active = ref.read(tournamentProvider);
    if (s == null || !_isLive(active)) return;
    if (_sending) {
      _dirty = true;
      return;
    }
    _sending = true;
    _dirty = false;
    try {
      await _relay.push(s.code, s.token, TournamentCodec.encode(active!));
      if (_session?.code == s.code) {
        _waiting = false;
        _setSession(s.sent(ref.read(clockProvider)()));
      }
    } on LiveRelayException catch (e) {
      // 404: terhapus di relay (3 hari tanpa perubahan); 403: token tidak cocok lagi. Live-nya sudah mati,
      // jadi menu kembali menawarkan "Mulai" dengan link baru.
      if ((e.status == 404 || e.status == 403) && _session?.code == s.code) {
        _setSession(null);
      } else {
        _scheduleRetry();
      }
    } on UnreadableTournamentError {
      // Bentuk tidak terbaca (TournamentCodec.encode): penonton tetap melihat kiriman sah terakhir; perubahan
      // berikutnya mencoba lagi, tanpa retry berkala.
    } catch (_) {
      _scheduleRetry();
    } finally {
      _sending = false;
    }
    if (_disposed) return;
    state = _view();
    if (_dirty) unawaited(_send());
  }

  void _scheduleRetry() {
    if (_disposed) return;
    _waiting = true;
    _retry ??= Timer(retryDelay, () {
      _retry = null;
      unawaited(_send());
    });
  }
}

final liveHostProvider = NotifierProvider<LiveHostController, LiveHost?>(LiveHostController.new);
