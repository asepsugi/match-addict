import '../../models/models.dart';
import '../../services/schedule/knockout_bracket.dart';
import '../../services/scoring/score_reset.dart';
import 'knockout_text.dart';

/// Teks dialog Kosongkan skor / Hapus WO (07q, 07r, 07u, 07v, 07w). Murni, tanpa widget; ketersediaan dan isi
/// dialog dari [ScoreReset.check], di sini hanya kalimatnya.

/// Judul dialog: "Kosongkan skor Court 1?" / "Hapus WO Court 2?"; gugur memakai kode match ("Kosongkan skor SF1?").
String resetDialogTitle(ActiveTournament a, MatchGame m, ResetAction action) {
  final verb = action == ResetAction.clearScore ? 'Kosongkan skor' : 'Hapus WO';
  final where = switch (m.phase) {
    final KnockoutPhase p => KnockoutBracket.code(p),
    _ => a.courtById(m.courtId).name,
  };
  return '$verb $where?';
}

/// Label tombol dialog: mengulang kata kerja judul.
String resetConfirmLabel(ResetAction action) => action == ResetAction.clearScore ? 'Kosongkan' : 'Hapus';

/// Isi dialog: kalimat akibat per [ResetAllowed.outcome], lalu susunan baru match gugur lanjutan kalau ada (07w).
String resetDialogMessage(ActiveTournament a, ResetAllowed allowed) {
  final sets = allowed.result.sets;
  final first = switch (allowed.outcome) {
    ResetOutcome.pending => 'Match kembali belum dimainkan.',
    ResetOutcome.cancelled => 'Match jadi tidak dimainkan.',
    // Urut papan atas–bawah = pair1–pair2.
    ResetOutcome.oldScore => 'Match kembali ke skor ${sets.first.side1}–${sets.first.side2}.',
  };
  return [first, if (allowed.preview.isNotEmpty) knockoutFlipMessage(a, allowed.preview)].join('\n');
}
