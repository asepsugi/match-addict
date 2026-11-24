import '../../../models/models.dart';
import '../../../services/ranking/group_knockout_ranking.dart';
import '../../../services/schedule/knockout_bracket.dart';

/// Teks Jadwal Grup + Gugur (frame 20, 21): murni, tanpa widget, supaya bisa dites tanpa render.

String _ended(ActiveTournament a) => a.tournament.isFinished ? ' · diakhiri' : '';

/// Subjudul round: fase grup "Padel · Fase grup · Race to 6" (20a), round gugur "R7 · Padel" (21b); "· diakhiri"
/// kalau turnamen diakhiri (20q).
String gkRoundSubtitle(ActiveTournament a, int round) {
  final sport = a.config.sport.label;
  final inKnockout = a.matchesOfRound(round).any((m) => m.phase is KnockoutPhase);
  return inKnockout ? '$sport · R$round${_ended(a)}' : '$sport · Fase grup · ${a.config.format.label}${_ended(a)}';
}

/// Subjudul tab Bagan: "Padel · 4 pasangan lolos" (21a).
String gkBaganSubtitle(ActiveTournament a) {
  final groups = a.config.groupKnockout?.groupCount ?? 0;
  return '${a.config.sport.label} · ${groups * 2} pasangan lolos${_ended(a)}';
}

/// Label kanan tab Bagan: match gugur terisi / semua match gugur ("0/4 match", 21a).
String gkBaganMeta(ActiveTournament a) {
  final knockout = [
    for (final m in a.matches)
      if (m.phase is KnockoutPhase) m,
  ];
  final done = knockout.where((m) => m.status == MatchStatus.done || m.status == MatchStatus.wo).length;
  return '$done/${knockout.length} match';
}

/// Satu baris ringkasan di dialog Buat bagan (`.bracket .bm`): kode match, slot, dan nama tiap sisi.
typedef BracketPreviewRow = ({String code, String slot1, String name1, String slot2, String name2});

/// Match babak pertama bagan dari [qualifiers] (per grup [slot 1, slot 2]): SF1 = A1 vs B2 (20g), QF1–QF4 (20o); kode UI, bukan kode simpanan "PF".
List<BracketPreviewRow> gkBracketPreview(
  ActiveTournament a,
  List<List<String>> qualifiers, {
  required String Function(Pair) nameOf,
}) {
  final groups = qualifiers.length;
  final first = groups == 4 ? KnockoutRound.quarterfinal : KnockoutRound.semifinal;
  final rows = <BracketPreviewRow>[];
  for (final phase in KnockoutBracket.phases(groupCount: groups, thirdPlace: false)) {
    if (phase.round != first) continue;
    final (s1, s2) = KnockoutBracket.sources(phase, groupCount: groups);
    if (s1 is! SeedSource || s2 is! SeedSource) continue;
    String name(SeedSource s) {
      final pair = a.pairById(qualifiers[s.group][s.slot - 1]);
      return pair == null ? '' : nameOf(pair);
    }

    rows.add((code: KnockoutBracket.code(phase), slot1: s1.code, name1: name(s1), slot2: s2.code, name2: name(s2)));
  }
  return rows;
}

/// Slot yang butuh ketukan host di [picks] ("A2", "C2"), urut grup lalu slot.
List<String> _slots(List<OpenPick> picks) => [
  for (final p in picks)
    for (var i = 0; i < p.taps; i++) '${GroupKnockout.letter(p.group)}${p.slots[i]}',
];

String _slotList(List<String> slots) =>
    slots.length < 2 ? slots.join() : '${slots.sublist(0, slots.length - 1).join(', ')} dan ${slots.last}';

/// Judul sheet pilih slot: "Pilih A2", "Pilih A1 dan A2", "Pilih A2 dan C2" (20i, 20l). Hanya slot yang butuh ketukan.
String gkPickTitle(List<OpenPick> picks) => 'Pilih ${_slotList(_slots(picks))}';

/// Keterangan tombol sheet selama belum lengkap: "pilih A2" / "pilih A2 dan C2" (20i). Null = semua slot terisi.
/// [taps] = ketukan yang sudah dipilih per grup.
String? gkMissingSlots(List<OpenPick> picks, Map<int, List<String>> taps) {
  final missing = [
    for (final p in picks)
      for (var i = (taps[p.group] ?? const []).length; i < p.taps; i++) '${GroupKnockout.letter(p.group)}${p.slots[i]}',
  ];
  return missing.isEmpty ? null : 'pilih ${_slotList(missing)}';
}

/// Ketukan baru pada [id] untuk [pick]: ketuk yang terpilih = lepas dan slot sesudahnya ikut lepas; ketuk yang lain =
/// ambil slot berikutnya, atau pindahkan ketukan terakhir kalau semua slot sudah terisi (20j, 20l).
List<String> gkTap(OpenPick pick, List<String> taps, String id) {
  final at = taps.indexOf(id);
  if (at >= 0) return taps.sublist(0, at);
  if (taps.length < pick.taps) return [...taps, id];
  return [...taps.sublist(0, taps.length - 1), id];
}

/// Subjudul satu pilihan (20i): "Grup A · #2 seri · head-to-head 1–1". Catatan head-to-head hanya dari match grup yang
/// kedua sisinya kandidat: menang–kalah tiap kandidat (WO = menang).
String gkPickSubtitle(OpenPick pick, List<MatchGame> matches) {
  final ids = pick.candidates.toSet();
  final wins = {for (final id in ids) id: 0}, losses = {for (final id in ids) id: 0};
  for (final m in matches) {
    if (m.phase != GroupPhase(pick.group) || !ids.contains(m.pair1.id) || !ids.contains(m.pair2.id)) continue;
    final winner = m.winnerPairId;
    if (winner == null) continue;
    final loser = winner == m.pair1.id ? m.pair2.id : m.pair1.id;
    wins[winner] = wins[winner]! + 1;
    losses[loser] = losses[loser]! + 1;
  }
  final records = {for (final id in ids) '${wins[id]}–${losses[id]}'};
  // Semua kandidat seri di head-to-head, jadi catatannya sama; tanpa hasil sama sekali (Americano seri) = "seri".
  final h2h = records.length == 1 && records.first != '0–0' ? records.first : 'seri';
  return 'Grup ${GroupKnockout.letter(pick.group)} · #${pick.slots.first} seri · head-to-head $h2h';
}
