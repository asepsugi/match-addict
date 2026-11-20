import '../../models/models.dart';
import '../schedule/knockout_bracket.dart';

/// Kosongkan skor (K1) / Hapus WO (K2), PRD §17.
enum ResetAction { clearScore, removeWalkover }

/// Isi dialog: match kembali belum dimainkan / jadi tidak dimainkan (turnamen diakhiri) / kembali ke skor lama.
enum ResetOutcome { pending, cancelled, oldScore }

/// Hasil [ScoreReset.check]. Layar membaca ini, tidak menghitung ketersediaan sendiri (logic.md §19.5).
sealed class ResetCheck {
  const ResetCheck();
}

/// Tidak tersedia (K5): layar tampil seperti 3.8.1, tanpa teks baru.
final class ResetUnavailable extends ResetCheck {
  const ResetUnavailable();
}

/// Gugur: babak berikutnya sudah ada hasil (GU11), aksi mati + pesan 21l dari [flip].
final class ResetBlocked extends ResetCheck {
  final FlipBlocked flip;
  const ResetBlocked(this.flip);
}

/// Boleh. [result] = match sesudahnya; [preview] = susunan baru match gugur lanjutan (21k), kosong di luar gugur.
final class ResetAllowed extends ResetCheck {
  final MatchGame result;
  final ResetOutcome outcome;
  final List<MatchGame> preview;
  const ResetAllowed({required this.result, required this.outcome, this.preview = const []});
}

/// Aturan ketersediaan + mutasi Kosongkan skor / Hapus WO (logic.md §19.2). Dart murni, total: data tak dikenal →
/// [ResetUnavailable] / null, tidak melempar.
abstract final class ScoreReset {
  static ResetCheck check(ActiveTournament a, String matchId, ResetAction action) {
    final m = a.matchById(matchId);
    if (m == null) return const ResetUnavailable();
    // K3: match WO hanya punya Hapus WO, match Selesai hanya Kosongkan; Belum/Tidak dimainkan tidak punya keduanya.
    final wanted = action == ResetAction.clearScore ? MatchStatus.done : MatchStatus.wo;
    if (m.status != wanted) return const ResetUnavailable();
    if (!_isOpen(a, m)) return const ResetUnavailable();

    final finished = a.tournament.isFinished;
    final result = action == ResetAction.clearScore
        ? m.cleared(finished: finished)
        : m.withoutWalkover(finished: finished);
    final outcome = result.status == MatchStatus.done
        ? ResetOutcome.oldScore
        : finished
        ? ResetOutcome.cancelled
        : ResetOutcome.pending;

    if (m.phase is! KnockoutPhase) return ResetAllowed(result: result, outcome: outcome);
    // I9: gugur Selesai selalu punya pemenang. Skor lama seri hanya mungkin dari simpanan rusak; jangan dipulihkan.
    if (result.status == MatchStatus.done && result.winnerPairId == null) return const ResetUnavailable();
    // GU11 tanpa aturan baru: kosong = tanpa pemenang; Hapus WO ke skor lama bisa membalik pemenang.
    return switch (KnockoutBracket.flipCheck(a, m.id, result.winnerPairId)) {
      final FlipBlocked flip => ResetBlocked(flip),
      FlipAllowed(:final preview) => ResetAllowed(result: result, outcome: outcome, preview: preview),
    };
  }

  /// Turnamen sesudah aksi, atau null kalau [check] bukan [ResetAllowed] (state pemanggil tidak berubah). Pemenang
  /// maju di Grup + Gugur ikut di sini ([KnockoutBracket.resolve], no-op di turnamen lain), jadi satu `state =`.
  static ActiveTournament? apply(ActiveTournament a, String matchId, ResetAction action) {
    final c = check(a, matchId, action);
    if (c is! ResetAllowed) return null;
    final matches = [
      for (final x in a.matches)
        if (x.id == matchId) c.result else x,
    ];
    return a.copyWith(tournament: a.tournament.copyWith(matches: KnockoutBracket.resolve(a.config, matches)));
  }

  /// Tabel mode 17.3, sama sebelum dan sesudah diakhiri (K6). Mixed/Mexicano hanya round terakhir (keputusan 114),
  /// tanpa kunci round; Fixed mengikuti kunci round, dan skor grup terkunci begitu bagan ada (GU6).
  static bool _isOpen(ActiveTournament a, MatchGame m) {
    if (a.config.mode.isEndless) return m.isScorable && m.roundNumber == a.roundCount;
    return a.canOpenScore(m) && !a.isGroupKnockoutLocked(m);
  }
}
