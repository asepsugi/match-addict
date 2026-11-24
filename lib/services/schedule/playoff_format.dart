import '../../models/models.dart';
import 'knockout_bracket.dart';

/// Kunci tiap kontrol sheet Playoff (23n–23r): alasan per babak yang dimainkan + alasan Ada / Tidak ada juara 3.
/// null = boleh diubah.
typedef PlayoffLocks = ({Map<KnockoutRound, String?> formats, String? thirdPlace});

/// Ubah format babak dan Perebutan juara 3 setelah jadwal dibuat (PRD G16, 16H; logic.md §21.10). Dart murni. Kunci
/// adalah turunan match tersimpan (seperti RP9): Kosongkan skor / Hapus WO yang mengosongkan babak membukanya lagi.
class PlayoffFormat {
  /// Alasan semua kontrol terkunci setelah turnamen diakhiri. Layar tidak menampilkannya (menu dan sheet tidak
  /// tersedia); non-null supaya mutator menolak.
  static const finished = 'Turnamen diakhiri';

  /// null = format [round] boleh diubah; selain itu alasan untuk subjudul sheet: "QF1 ada skor" (23p), "QF1–4 ada skor"
  /// (23q), "QF1–2, QF4 ada skor", "Final ada skor". Sebelum bagan selalu null.
  static String? formatLock(ActiveTournament active, KnockoutRound round) {
    if (active.config.groupKnockout == null || active.tournament.isFinished) return finished;
    final slots = [
      for (final m in active.matches)
        if (m.phase case KnockoutPhase(round: final r, :final slot) when r == round && _hasResult(m)) slot,
    ]..sort();
    if (slots.isEmpty) return null;
    return '${_codes(round, slots)} ada skor';
  }

  /// null = Perebutan juara 3 boleh dinyalakan/dimatikan: Final dan Juara 3 sama-sama tanpa hasil (23r). Final
  /// didahulukan kalau keduanya berskor.
  static String? thirdPlaceLock(ActiveTournament active) {
    if (active.config.groupKnockout == null || active.tournament.isFinished) return finished;
    for (final round in const [KnockoutRound.finalRound, KnockoutRound.thirdPlace]) {
      if (formatLock(active, round) case final reason?) return reason;
    }
    return null;
  }

  /// Semua kunci sekaligus untuk sheet Playoff: satu entri per babak yang dimainkan (`GroupKnockout.rounds`).
  static PlayoffLocks locks(ActiveTournament active) {
    final gk = active.config.groupKnockout;
    return (
      formats: {for (final round in gk?.rounds ?? const <KnockoutRound>[]) round: formatLock(active, round)},
      thirdPlace: thirdPlaceLock(active),
    );
  }

  /// Ganti format [round]. null = ditolak (terkunci, babak tidak ada di bagan ini, atau [format] bisa seri). Match tidak
  /// berubah; `formatFor(m)` langsung memakai format baru. Bidang `groupKnockout` lain (wildcards!) ikut lewat
  /// `copyWith` (jebakan 21.12 #1).
  static ActiveTournament? withFormat(ActiveTournament active, KnockoutRound round, ScoreFormat format) {
    final gk = active.config.groupKnockout;
    if (gk == null || formatLock(active, round) != null || !format.isValidKnockout) return null;
    // Juara 3 yang dimatikan tetap punya format (19g), jadi boleh diubah; Perempat final hanya di 3/4 grup.
    if (round == KnockoutRound.quarterfinal && gk.groupCount < 3) return null;
    if (gk.formats[round] == format) return active;
    final config = active.config.copyWith(
      groupKnockout: gk.copyWith(formats: Map.unmodifiable({...gk.formats, round: format})),
    );
    return _with(active, config, active.matches);
  }

  /// Nyalakan/matikan Perebutan juara 3. null = ditolak ([thirdPlaceLock]). Sebelum bagan hanya config (pratinjau
  /// ikut); sesudah bagan match gugur disusun ulang lewat [relayout].
  static ActiveTournament? withThirdPlace(ActiveTournament active, bool thirdPlace) {
    final gk = active.config.groupKnockout;
    if (gk == null || thirdPlaceLock(active) != null) return null;
    if (gk.thirdPlace == thirdPlace) return active;
    final config = active.config.copyWith(groupKnockout: gk.copyWith(thirdPlace: thirdPlace));
    if (!active.hasBracket) return _with(active, config, active.matches);
    return _with(active, config, relayout(active, thirdPlace: thirdPlace));
  }

  /// Match sesudah Juara 3 [thirdPlace]: posisi semua match gugur dihitung ulang dari `KnockoutBracket.layout`, id
  /// `m-r{round}-{n}` ikut posisi baru, Juara 3 baru = Belum bersisi tbd, Juara 3 dihapus kalau mati, lalu pemenang
  /// maju (`resolve`). Match fase grup tidak disentuh. Pemanggil menjamin [thirdPlaceLock] null: hanya Final/Juara 3
  /// (keduanya tanpa hasil) yang bisa bergeser, jadi match ber-hasil tidak pernah berpindah.
  static List<MatchGame> relayout(ActiveTournament active, {required bool thirdPlace}) {
    final config = active.config;
    final gk = config.groupKnockout;
    if (gk == null) return active.matches;
    final groupMatches = [
      for (final m in active.matches)
        if (m.phase is! KnockoutPhase) m,
    ];
    final old = <KnockoutPhase, MatchGame>{
      for (final m in active.matches)
        if (m.phase case final KnockoutPhase p) p: m,
    };
    final knockout = [
      for (final s in KnockoutBracket.slots(active, thirdPlace: thirdPlace))
        KnockoutBracket.matchAt(config, s, from: old[s.phase]),
    ];
    return KnockoutBracket.resolve(config.copyWith(groupKnockout: gk.copyWith(thirdPlace: thirdPlace)), [
      ...groupMatches,
      ...knockout,
    ]);
  }

  /// Satu turnamen baru dengan [config] dan [matches]; pemenang maju dihitung di langkah yang sama (jebakan 21.12 #3).
  static ActiveTournament _with(ActiveTournament active, TournamentConfig config, List<MatchGame> matches) =>
      active.copyWith(
        tournament: active.tournament.copyWith(config: config, matches: KnockoutBracket.resolve(config, matches)),
      );

  /// "QF1", "QF1–4", "QF1–2, QF4", "SF1–2"; Final/Juara 3 = label pendek.
  static String _codes(KnockoutRound round, List<int> slots) {
    if (round.codePrefix == null) return KnockoutBracket.code(KnockoutPhase(round, 1));
    final runs = <String>[];
    var start = 0;
    for (var i = 1; i <= slots.length; i++) {
      if (i < slots.length && slots[i] == slots[i - 1] + 1) continue;
      final first = KnockoutBracket.code(KnockoutPhase(round, slots[start]));
      runs.add(i - 1 == start ? first : '$first–${slots[i - 1]}');
      start = i;
    }
    return runs.join(', ');
  }

  static bool _hasResult(MatchGame m) => m.status == MatchStatus.done || m.status == MatchStatus.wo;
}
