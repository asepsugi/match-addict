import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

/// Live yang dimulai dari HP ini (PRD §13). [code] masuk ke link penonton; [token] rahasia dan hanya
/// dipegang HP host — relay menolak kiriman tanpa token ini. Disimpan bersama turnamen di device
/// ([TournamentStore]) supaya live tetap jalan setelah app dibuka ulang.
class LiveSession {
  final String tournamentId;
  final String code;
  final String token;

  /// Kiriman terakhir yang sampai di relay ("Terkirim 20.14").
  final DateTime? sentAt;

  const LiveSession({required this.tournamentId, required this.code, required this.token, this.sentAt});

  LiveSession sent(DateTime at) => LiveSession(tournamentId: tournamentId, code: code, token: token, sentAt: at);

  Map<String, dynamic> toJson() => {
    'tournamentId': tournamentId,
    'code': code,
    'token': token,
    if (sentAt != null) 'sentAt': sentAt!.toIso8601String(),
  };

  /// Null kalau simpanannya rusak — live-nya saja yang hilang (kedaluwarsa sendiri di relay).
  static LiveSession? fromJson(String? raw) {
    if (raw == null) return null;
    try {
      final json = jsonDecode(raw) as Map<String, dynamic>;
      return LiveSession(
        tournamentId: json['tournamentId'] as String,
        code: json['code'] as String,
        token: json['token'] as String,
        sentAt: json['sentAt'] == null ? null : DateTime.parse(json['sentAt'] as String),
      );
    } catch (_) {
      return null;
    }
  }
}

/// Hasil [LiveRelay.fetch].
sealed class LiveFetch {
  const LiveFetch();
}

/// Salinan turnamen terbaru: [payload] = JSON [TournamentCodec], [rev] naik setiap kiriman host.
class LiveSnapshot extends LiveFetch {
  final int rev;
  final String payload;
  const LiveSnapshot(this.rev, this.payload);
}

/// Belum ada kiriman baru sejak `since`.
class LiveUnchanged extends LiveFetch {
  const LiveUnchanged();
}

/// Kode salah, live dihentikan, atau terhapus setelah 3 hari tanpa perubahan.
class LiveGone extends LiveFetch {
  const LiveGone();
}

/// Relay menjawab dengan status yang tidak diharapkan (403 token salah, 404 live hilang, 5xx).
class LiveRelayException implements Exception {
  final int status;
  const LiveRelayException(this.status);

  @override
  String toString() => 'LiveRelayException($status)';
}

/// Klien relay live score (`relay/src/index.js`). Setiap kiriman membawa seluruh turnamen, jadi tidak ada
/// antrean perubahan: yang dikirim selalu keadaan terbaru. Error jaringan dan timeout diteruskan apa adanya.
class LiveRelay {
  /// Worker hasil `npm run deploy` di `relay/`; `--dart-define=LIVE_RELAY=http://127.0.0.1:8790` untuk
  /// `npm run dev`.
  static const url = String.fromEnvironment('LIVE_RELAY', defaultValue: 'https://mabar-live.mabar-live.workers.dev');

  /// Web Match Addict di GitHub Pages; penonton membuka `#/live/KODE` di sini.
  static const viewerBase = 'https://asepsugi.github.io/match-addict/';

  static const _timeout = Duration(seconds: 15);
  static final _code = RegExp(r'^/live/([23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6})$', caseSensitive: false);

  final Uri base;
  final http.Client _client;

  LiveRelay({Uri? base, http.Client? client}) : base = base ?? Uri.parse(url), _client = client ?? http.Client();

  static String link(String code) => '$viewerBase#/live/$code';

  /// Kode live di fragment URL halaman (`#/live/K7Q2MX`), huruf kecil diterima; null = bukan halaman live.
  static String? codeIn(Uri page) => _code.firstMatch(page.fragment)?.group(1)?.toUpperCase();

  Uri _live([String? code, Map<String, String>? query]) =>
      base.replace(path: code == null ? '/live' : '/live/$code', queryParameters: query);

  Future<({String code, String token})> create(String payload) async {
    final res = await _client.post(_live(), body: payload).timeout(_timeout);
    if (res.statusCode != 201) throw LiveRelayException(res.statusCode);
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (code: json['code'] as String, token: json['token'] as String);
  }

  Future<void> push(String code, String token, String payload) async {
    final res = await _client.put(_live(code), headers: _auth(token), body: payload).timeout(_timeout);
    if (res.statusCode != 204) throw LiveRelayException(res.statusCode);
  }

  Future<void> delete(String code, String token) async {
    final res = await _client.delete(_live(code), headers: _auth(token)).timeout(_timeout);
    if (res.statusCode != 204) throw LiveRelayException(res.statusCode);
  }

  /// [since] = `rev` yang sudah dimiliki penonton; relay menjawab kosong kalau belum berubah. Tanpa header
  /// tambahan supaya browser tidak mengirim preflight CORS di setiap pengecekan.
  Future<LiveFetch> fetch(String code, {int? since}) async {
    final res = await _client.get(_live(code, since == null ? null : {'since': '$since'})).timeout(_timeout);
    switch (res.statusCode) {
      case 200:
        final json = jsonDecode(res.body) as Map<String, dynamic>;
        return LiveSnapshot(json['rev'] as int, json['payload'] as String);
      case 204:
        return const LiveUnchanged();
      case 404:
        return const LiveGone();
    }
    throw LiveRelayException(res.statusCode);
  }

  static Map<String, String> _auth(String token) => {'Authorization': 'Bearer $token'};
}
