import '../../models/models.dart';

/// Isi dialog "Akhiri turnamen?" (06e, 20r, 21z; PATCH 3.8.1, A-2/C-1). Judul dan tombol tetap; yang berbeda per mode
/// adalah akibatnya. Tidak mengubah peringkat akhir, hanya teks.
class FinishNotice {
  static const _base = 'Match yang belum main tidak dihitung.';

  /// Kalimat akibat untuk [active] kalau host mengakhiri sekarang.
  static String message(ActiveTournament active) {
    final config = active.config;
    // Mixed/Mexicano bisa dilanjutkan (06m), jadi tidak ada kalimat tambahan.
    if (config.mode != PartnerMode.fixed) return _base;
    if (!config.isGroupKnockout) return '$_base Turnamen tidak bisa dilanjutkan.';
    if (!active.hasBracket) return '$_base Bagan tidak dibuat; peringkat dari posisi grup.';
    return _knockout(active) ?? _base;
  }

  static const _order = [
    KnockoutRound.quarterfinal,
    KnockoutRound.semifinal,
    KnockoutRound.finalRound,
    KnockoutRound.thirdPlace,
  ];

  /// Fase gugur: babak yang batal; kalau kedua Semifinal sudah ada hasil tapi Final belum, pemenang SF1 dan SF2
  /// berbagi #1. Null kalau tidak ada match gugur yang batal.
  static String? _knockout(ActiveTournament active) {
    final knockout = [
      for (final m in active.matches)
        if (m.phase is KnockoutPhase) m,
    ];
    bool open(MatchGame m) => m.status == MatchStatus.pending;
    final cancelled = {for (final m in knockout.where(open)) (m.phase! as KnockoutPhase).round};
    if (cancelled.isEmpty) return null;
    final rounds = [
      for (final r in _order)
        if (cancelled.contains(r)) r.shortLabel,
    ];
    final text = '${_list(rounds)} tidak dimainkan.';

    final semis = [
      for (final m in knockout)
        if ((m.phase! as KnockoutPhase).round == KnockoutRound.semifinal) m,
    ];
    final finalOpen = cancelled.contains(KnockoutRound.finalRound);
    final semisDone = semis.length == 2 && semis.every((m) => m.winnerPairId != null);
    if (!finalOpen || !semisDone) return text;
    String name(MatchGame m) {
      final w = m.pair1.id == m.winnerPairId ? m.pair1 : m.pair2;
      return w.playerIds.map(active.playerName).join(' · ');
    }

    semis.sort((a, b) => (a.phase! as KnockoutPhase).slot.compareTo((b.phase! as KnockoutPhase).slot));
    return '$text ${name(semis[0])} dan ${name(semis[1])} sama-sama #1.';
  }

  static String _list(List<String> items) => switch (items.length) {
    1 => items.single,
    2 => '${items[0]} dan ${items[1]}',
    _ => '${items.sublist(0, items.length - 1).join(', ')}, dan ${items.last}',
  };
}
