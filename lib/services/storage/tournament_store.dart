import 'dart:convert';

import 'package:hive/hive.dart';

import '../../models/models.dart';
import '../live/live_relay.dart';
import 'last_settings.dart';
import 'tournament_codec.dart';

/// Penyimpanan turnamen di device. Isinya persis yang diminta PRD bagian 5:
/// satu turnamen aktif (auto-save tiap perubahan) + satu turnamen terakhir yang
/// sudah ditutup, ditambah live score yang sedang dibagikan dari HP ini (§13).
///
/// Nilainya disimpan sebagai JSON string, bukan TypeAdapter Hive: model domain
/// jadi tidak perlu anotasi/codegen, dan format datanya bisa dites lepas dari
/// plugin. Lihat [TournamentCodec].
class TournamentStore {
  static const boxName = 'tournament';
  static const _activeKey = 'active';
  static const _lastFinishedKey = 'lastFinished';
  static const _liveKey = 'live';

  final Box<String>? _box;

  /// Tanpa Hive: dipakai test widget dan sebagai penyelamat kalau box gagal
  /// dibuka (disk penuh, browser mode private) — app tetap jalan, cuma tidak
  /// bertahan setelah ditutup.
  final Map<String, String> _memory = {};

  TournamentStore(Box<String> box) : _box = box;
  TournamentStore.memory() : _box = null;

  String? _read(String key) => _box == null ? _memory[key] : _box.get(key);

  Future<void> _write(String key, String? value) async {
    if (value == null) {
      _box == null ? _memory.remove(key) : await _box.delete(key);
    } else {
      _box == null ? _memory[key] = value : await _box.put(key, value);
    }
  }

  static String _settingsKey(SportType sport) => 'settings.${sport.name}';

  /// Pengaturan terakhir per olahraga; null = belum ada atau tak terbaca (logic.md §14.5).
  LastSettings? loadLastSettings(SportType sport) => LastSettings.read(_read(_settingsKey(sport)));

  /// Kegagalan tulis (disk penuh) ditelan: turnamen tetap jalan, hanya pengaturan tidak tersimpan.
  Future<void> saveLastSettings(SportType sport, LastSettings settings) async {
    try {
      await _write(_settingsKey(sport), settings.toJson());
    } catch (_) {}
  }

  ActiveTournament? loadActive() => TournamentCodec.decode(_read(_activeKey));

  ActiveTournament? loadLastFinished() => TournamentCodec.decode(_read(_lastFinishedKey));

  Future<void> saveActive(ActiveTournament active) async {
    final raw = _encodeOrNull(active);
    if (raw != null) await _write(_activeKey, raw);
  }

  /// Null = bentuk tidak bisa dibaca lagi ([TournamentCodec.encode]); simpanan sah terakhir dibiarkan, lebih baik
  /// resume ke keadaan sebelumnya daripada turnamennya hilang.
  static String? _encodeOrNull(ActiveTournament active) {
    try {
      return TournamentCodec.encode(active);
    } on UnreadableTournamentError {
      return null;
    }
  }

  /// Satu live saja: turnamen aktif, atau turnamen terakhir yang masih bisa dilanjutkan dari Beranda.
  LiveSession? loadLive() => LiveSession.fromJson(_read(_liveKey));

  Future<void> saveLive(LiveSession? session) =>
      _write(_liveKey, session == null ? null : jsonEncode(session.toJson()));

  /// Menutup turnamen: pindah dari slot aktif ke slot "terakhir selesai".
  /// Sesuai PRD, menutup turnamen tidak menghapus hasilnya.
  Future<void> archiveActive(ActiveTournament active) async {
    final raw = _encodeOrNull(active);
    // Slot aktif hanya dikosongkan kalau hasilnya benar tersimpan; kalau tidak, turnamen kembali saat app dibuka.
    if (raw == null) return;
    await _write(_lastFinishedKey, raw);
    await _write(_activeKey, null);
  }
}
