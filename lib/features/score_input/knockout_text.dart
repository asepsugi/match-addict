import '../../models/models.dart';
import '../../services/schedule/knockout_bracket.dart';

/// Teks Input Skor / WO untuk match gugur Grup + Gugur (frame 21g–21n). Murni, tanpa widget; aturannya dari
/// [KnockoutBracket] (`code`, `flipCheck`, `sources`).

/// "R8 · Final · Race to 9" (21g), "R7 · SF1 · Race to 6" (21k): round · kode/nama babak · format babak. Null untuk
/// match bukan gugur (subjudul lama "Round n · format").
String? knockoutScoreSubtitle(ActiveTournament a, MatchGame m) => switch (m.phase) {
  final KnockoutPhase p => 'R${m.roundNumber} · ${KnockoutBracket.code(p)} · ${a.config.formatFor(m).label}',
  _ => null,
};

/// Subjudul sheet WO gugur: "R7 · SF2 · Court 2" (21n). Null untuk match bukan gugur.
String? knockoutWalkoverSubtitle(ActiveTournament a, MatchGame m) => switch (m.phase) {
  final KnockoutPhase p => 'R${m.roundNumber} · ${KnockoutBracket.code(p)} · ${a.courtById(m.courtId).name}',
  _ => null,
};

/// Kalimat akibat WO di gugur (21n): pemenang masuk babak berikutnya; nilai WO tidak ditulis (peringkat dari babak).
String knockoutWalkoverNote(KnockoutPhase p, String winner) =>
    '$winner menang WO dan ${switch (p.round) {
      KnockoutRound.quarterfinal => 'masuk ${KnockoutRound.semifinal.label}',
      KnockoutRound.semifinal => 'masuk ${KnockoutRound.finalRound.label}',
      KnockoutRound.finalRound => 'juara',
      KnockoutRound.thirdPlace => 'juara 3',
    }}.';

/// Pesan tolak ganti pemenang (21l): "Final sudah ada skor · pemenang SF1 tetap Andi & Budi"; dua babak →
/// "Final dan Juara 3 sudah ada skor · …". [oldWinner] = nama pemenang tersimpan.
String knockoutBlockedMessage(FlipBlocked blocked, KnockoutPhase p, String oldWinner) =>
    '${blocked.rounds.map((r) => r.shortLabel).join(' dan ')} sudah ada skor · '
    'pemenang ${KnockoutBracket.code(p)} tetap $oldWinner';

/// Judul dialog 21k: "Ganti pemenang SF1?".
String knockoutFlipTitle(KnockoutPhase p) => 'Ganti pemenang ${KnockoutBracket.code(p)}?';

/// Isi dialog 21k: susunan baru tiap match yang berganti, "Final: Maya · Nanda vs Citra · Dewi". Sisi yang belum
/// diketahui ditulis dari asalnya ("Pemenang SF2").
String knockoutFlipMessage(ActiveTournament a, List<MatchGame> preview) {
  final gk = a.config.groupKnockout;
  return [
    for (final m in preview)
      if (m.phase case final KnockoutPhase p when gk != null) _previewLine(a, m, p, gk.groupCount),
  ].join('\n');
}

String _previewLine(ActiveTournament a, MatchGame m, KnockoutPhase p, int groupCount) {
  final (s1, s2) = KnockoutBracket.sources(p, groupCount: groupCount);
  String side(Pair pair, SideSource source) =>
      pair.isTbd ? KnockoutBracket.sourceLabel(source) : pair.playerIds.map(a.playerName).join(' · ');
  return '${KnockoutBracket.code(p)}: ${side(m.pair1, s1)} vs ${side(m.pair2, s2)}';
}
