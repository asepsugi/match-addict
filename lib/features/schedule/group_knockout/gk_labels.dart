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

/// Subjudul tab Bagan: sebelum Buat bagan "Padel · Fase grup" (23s), sesudahnya "Padel · 4 pasangan lolos" (21a).
String gkBaganSubtitle(ActiveTournament a) {
  final sport = a.config.sport.label;
  if (!a.hasBracket) return '$sport · Fase grup${_ended(a)}';
  final groups = a.config.groupKnockout?.groupCount ?? 0;
  // 3 grup: 3 juara + 2 wildcard = 8 pasangan, sama dengan 2 × 4 grup.
  return '$sport · ${(groups == 3 ? 4 : groups) * 2} pasangan lolos${_ended(a)}';
}

/// Label kanan tab Bagan: match gugur terisi / semua match gugur ("0/4 match", 21a, 23s); sebelum bagan jumlah semua
/// dari susunan bagan (`KnockoutBracket.progress`).
String gkBaganMeta(ActiveTournament a) {
  final p = KnockoutBracket.progress(a);
  return '${p.done}/${p.total} match';
}

/// Satu baris ringkasan di dialog Buat bagan (`.bracket .bm`): kode match, slot, dan nama tiap sisi.
typedef BracketPreviewRow = ({String code, String slot1, String name1, String slot2, String name2});

/// Match babak pertama bagan dari [seeding] (Perempat final 3/4 grup, Semifinal 2 grup; 20g, 20o, 23d, 23g): bagan
/// disusun oleh `KnockoutBracket.build` (tukar wildcard ikut), slot dari `seedLabel` ("A1", "WC2 · B3"), kode UI
/// ("QF1"), bukan kode simpanan "PF".
List<BracketPreviewRow> gkBracketPreview(ActiveTournament a, Seeding seeding, {required String Function(Pair) nameOf}) {
  final built = KnockoutBracket.build(a, seeding);
  final withBracket = a.copyWith(
    tournament: a.tournament.copyWith(config: built.config, matches: [...a.matches, ...built.matches]),
  );
  final first = built.matches.map((m) => m.phase).whereType<KnockoutPhase>().first.round;
  return [
    for (final m in built.matches)
      if (m.phase case final KnockoutPhase p when p.round == first)
        (
          code: KnockoutBracket.code(p),
          slot1: KnockoutBracket.seedLabel(withBracket, m.pair1.id) ?? '',
          name1: nameOf(m.pair1),
          slot2: KnockoutBracket.seedLabel(withBracket, m.pair2.id) ?? '',
          name2: nameOf(m.pair2),
        ),
  ];
}

/// Judul bagian wildcard sheet Buat bagan: "Wildcard", atau "Wildcard · pilih WC2" selama seri belum dipilih (23e).
/// [sure] = wildcard yang sudah pasti, [chosen] = ketukan host sejauh ini.
String gkWildcardLabel(WildcardPick? pick, int sure, int chosen) {
  if (pick == null) return 'Wildcard';
  final left = gkWildcardMissing(pick, sure, chosen);
  return left == null ? 'Wildcard' : 'Wildcard · $left';
}

/// "pilih WC2" / "pilih WC1 dan WC2" untuk slot wildcard yang belum dipilih; null = semua terpilih (23e, 23f).
String? gkWildcardMissing(WildcardPick pick, int sure, int chosen) {
  final slots = [for (var i = sure + chosen + 1; i <= sure + pick.need; i++) 'WC$i'];
  return slots.isEmpty ? null : 'pilih ${_slotList(slots)}';
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
