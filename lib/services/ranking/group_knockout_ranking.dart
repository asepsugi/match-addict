import '../../models/models.dart';
import 'playoff_seeding.dart';
import 'ranking_calculator.dart';

export 'playoff_seeding.dart';

/// Klasemen satu grup (G7): hanya match grup itu, metode default format grup (keputusan 21/123, tanpa toggle).
class GroupTable {
  final int group;
  final List<StandingEntry> entries;

  /// Id pasangan tiap baris [entries], indeks sama.
  final List<String> pairIds;
  final RankingMethod method;

  const GroupTable({required this.group, required this.entries, required this.pairIds, required this.method});
}

/// Slot lolos yang tidak bisa dipastikan nomor tabel maupun head-to-head: host memilih (20i, 20l).
class OpenPick {
  final int group;

  /// Slot yang diperebutkan, mis. [2] atau [1, 2].
  final List<int> slots;

  /// Id pasangan yang masih seri setelah head-to-head, urut nama.
  final List<String> candidates;

  const OpenPick({required this.group, required this.slots, required this.candidates});

  /// Jumlah ketukan host: kandidat terakhir mengisi slot sisa sendiri (2 kandidat untuk [1, 2] → cukup pilih A1).
  int get taps => slots.length < candidates.length - 1 ? slots.length : candidates.length - 1;
}

/// Siapa lolos per grup (G8, logic.md §18.7, 21.4). [slots] per grup [slot 1, slot 2] (3 grup: + slot 3 = kandidat
/// wildcard); null = menunggu [picks].
class QualifierPlan {
  final List<List<String?>> slots;
  final List<OpenPick> picks;

  const QualifierPlan({required this.slots, required this.picks});

  /// Slot lengkap setelah pilihan host. [chosen] per grup = pasangan yang diketuk berurutan (slot pertama yang
  /// diperebutkan dulu), tepat jumlah [OpenPick.taps] semua pilihan grup itu (di 3 grup bisa ada dua [OpenPick],
  /// ketukan pilihan pertama dulu). Null kalau ada yang bukan kandidat, ganda, kurang/lebih, atau ada pilihan untuk grup
  /// tanpa [OpenPick] — pilihan hanya hidup di UI sampai dialog dikonfirmasi (AC-G7).
  List<List<String>>? withPicks(Map<int, List<String>> chosen) {
    if (chosen.keys.any((g) => !picks.any((p) => p.group == g))) return null;
    for (final MapEntry(key: g, value: taps) in chosen.entries) {
      final need = picks.where((p) => p.group == g).fold(0, (n, p) => n + p.taps);
      if (taps.length != need || taps.toSet().length != taps.length) return null;
    }
    final result = [for (final s in slots) List<String?>.of(s)];
    final used = <int, int>{};
    for (final pick in picks) {
      final from = used[pick.group] ?? 0;
      final all = chosen[pick.group] ?? const [];
      if (all.length < from + pick.taps) return null;
      final taps = all.sublist(from, from + pick.taps);
      used[pick.group] = from + pick.taps;
      if (taps.any((id) => !pick.candidates.contains(id))) return null;
      for (final (i, id) in taps.indexed) {
        result[pick.group][pick.slots[i] - 1] = id;
      }
      // Satu slot sisa dengan satu kandidat sisa: terisi tanpa ketukan.
      if (taps.length < pick.slots.length) {
        final rest = [
          for (final id in pick.candidates)
            if (!taps.contains(id)) id,
        ];
        result[pick.group][pick.slots.last - 1] = rest.single;
      }
    }
    if (result.any((s) => s.any((id) => id == null))) return null;
    return [
      for (final s in result) [for (final id in s) id!],
    ];
  }
}

/// Klasemen grup, siapa lolos, seeding, dan peringkat akhir Grup + Gugur (PRD §16.5, 16.8; logic.md §18.6, 18.7,
/// 18.9, 21.3–21.5, 21.8).
class GroupKnockoutRanking {
  /// Metode Playoff (G7a, AC-G30): satu parameter untuk tabel grup, siapa lolos, juara, dan wildcard. Race to / Best of
  /// → Win %, Americano → Point %. Layar tidak pernah mengoper `method` sendiri; parameter itu hanya untuk test 16G-pp.
  static RankingMethod playoffMethod(TournamentConfig c) => RankingCalculator.defaultMethod(c.format);

  /// Satu tabel per grup, urut huruf. Nomor tabel = aturan 4.3 (head-to-head tidak mengubahnya). Kosong untuk
  /// turnamen lain.
  static List<GroupTable> groupTables(ActiveTournament active, {RankingMethod? method}) {
    final config = active.config;
    final gk = config.groupKnockout;
    if (gk == null) return const [];
    final m = method ?? playoffMethod(config);
    return [for (final (g, ids) in gk.groups.indexed) _table(active, g, ids, m)];
  }

  static GroupTable _table(ActiveTournament active, int g, List<String> ids, RankingMethod method) {
    final config = active.config;
    final pairs = [
      for (final id in ids)
        if (active.pairById(id) case final pair?) pair,
    ];
    final players = [
      for (final pair in pairs)
        for (final id in pair.playerIds)
          if (config.playerById(id) case final p?) p,
    ];
    final entries = standingEntries(
      standings: RankingCalculator.rank(
        players: players,
        matches: [
          for (final m in active.matches)
            if (m.phase == GroupPhase(g)) m,
        ],
        method: method,
        format: config.format,
      ),
      method: method,
      fixedPairs: pairs,
    );
    String pairIdOf(StandingEntry e) =>
        pairs.firstWhere((p) => p.contains(e.players.first.id), orElse: () => Pair.tbd).id;
    return GroupTable(group: g, entries: entries, pairIds: [for (final e in entries) pairIdOf(e)], method: method);
  }

  /// Siapa lolos per grup (§18.7, 21.4): tingkat nomor tabel, lalu head-to-head satu kali di tiap himpunan seri,
  /// sisanya pilihan host. 2 slot per grup (2/4 grup) atau 3 (3 grup: slot 3 = kandidat wildcard, G14).
  static QualifierPlan qualifierPlan(ActiveTournament active, {RankingMethod? method}) {
    final count = active.config.groupKnockout?.groupCount == 3 ? 3 : 2;
    final slots = <List<String?>>[];
    final picks = <OpenPick>[];
    for (final table in groupTables(active, method: method)) {
      final row = List<String?>.filled(count, null);
      var filled = 0;
      for (final tier in _tiers(table)) {
        if (filled >= count) break;
        if (tier.length == 1) {
          row[filled++] = tier.single;
          continue;
        }
        // Tiap slot punya arti sendiri (juara, runner-up, kandidat), jadi seri selalu perlu urutan.
        final contested = [for (var s = filled + 1; s <= count && s <= filled + tier.length; s++) s];
        _headToHead(active, table, tier, contested, row, picks);
        filled += contested.length;
      }
      slots.add(row);
    }
    return QualifierPlan(slots: slots, picks: picks);
  }

  /// Juara J1–J3 dan wildcard 3 grup dari [perGroup] (hasil [QualifierPlan.withPicks]); 2/4 grup langsung [Seeding]
  /// (§21.5).
  static SeedingPlan seedingPlan(ActiveTournament active, List<List<String>> perGroup, {RankingMethod? method}) {
    final m = method ?? playoffMethod(active.config);
    return PlayoffSeeding.plan(
      perGroup: perGroup,
      standings: {
        for (final table in groupTables(active, method: m))
          for (final (i, id) in table.pairIds.indexed) id: table.entries[i].standing,
      },
      method: m,
    );
  }

  /// [seedingPlan] dari pilihan host per grup [picks] (`QualifierPlan.withPicks`; 3 grup = 3 id per grup). Null kalau
  /// pilihan grup belum lengkap atau tidak sah. Dipakai sheet Buat bagan (23e) lewat provider dan [bracketSeeding].
  static SeedingPlan? seedingPlanFor(ActiveTournament active, Map<int, List<String>> picks) {
    final perGroup = qualifierPlan(active).withPicks(picks);
    return perGroup == null ? null : seedingPlan(active, perGroup);
  }

  /// Seeding Buat bagan dari pilihan host: [picks] per grup, lalu [wildcardPick] kalau ada `WildcardPick` (3 grup).
  /// Null = pilihan belum lengkap atau tidak sah, termasuk [wildcardPick] yang nyasar (tanpa `WildcardPick` tapi
  /// terisi); tombol Buat bagan mati. Satu-satunya jalan [Seeding] untuk `createBracket`.
  static Seeding? bracketSeeding(ActiveTournament active, Map<int, List<String>> picks, List<String> wildcardPick) {
    final plan = seedingPlanFor(active, picks);
    if (plan == null) return null;
    if (plan.pick == null) return wildcardPick.isEmpty ? plan.seeding : null;
    return plan.withWildcardPick(wildcardPick);
  }

  /// Baris tabel dikelompokkan per nomor (null = belum main, tingkat terakhir).
  static List<List<String>> _tiers(GroupTable table) {
    final tiers = <List<String>>[];
    for (final (i, e) in table.entries.indexed) {
      if (i == 0 || e.position != table.entries[i - 1].position) tiers.add([]);
      tiers.last.add(table.pairIds[i]);
    }
    return tiers;
  }

  /// Head-to-head di [tied] untuk [contested]: menang 1, seri ½, WO = menang, hanya match grup yang kedua sisinya di
  /// [tied]. Sub-tingkat berukuran 1 = pasti; sub-tingkat ≥ 2 = pilihan host atas slot yang masih kosong.
  static void _headToHead(
    ActiveTournament active,
    GroupTable table,
    List<String> tied,
    List<int> contested,
    List<String?> row,
    List<OpenPick> picks,
  ) {
    // Poin ×2 supaya seri tetap bilangan bulat.
    final h = {for (final id in tied) id: 0};
    for (final m in active.matches) {
      if (m.phase != GroupPhase(table.group)) continue;
      if (m.status != MatchStatus.done && m.status != MatchStatus.wo) continue;
      if (!h.containsKey(m.pair1.id) || !h.containsKey(m.pair2.id)) continue;
      final w = m.winnerPairId;
      if (w == null) {
        h[m.pair1.id] = h[m.pair1.id]! + 1;
        h[m.pair2.id] = h[m.pair2.id]! + 1;
      } else {
        h[w] = h[w]! + 2;
      }
    }
    final levels = {...h.values}.toList()..sort((a, b) => b - a);
    var next = 0;
    for (final level in levels) {
      if (next >= contested.length) break;
      final sub = [
        for (final id in tied)
          if (h[id] == level) id,
      ];
      if (sub.length == 1) {
        row[contested[next++] - 1] = sub.single;
        continue;
      }
      // Sub-tingkat ≥ 2 mengambil slot sebanyak anggotanya; sisa slot lanjut ke sub-tingkat berikutnya (3 slot).
      final end = next + sub.length < contested.length ? next + sub.length : contested.length;
      final label = {for (final (i, id) in table.pairIds.indexed) id: table.entries[i].label};
      picks.add(
        OpenPick(
          group: table.group,
          slots: contested.sublist(next, end),
          candidates: sub..sort((a, b) => label[a]!.compareTo(label[b]!)),
        ),
      );
      next = end;
    }
  }

  /// Peringkat akhir (§18.9): tingkat dari babak yang dicapai, nomor rapat, senomor urut nama. Sebelum bagan = posisi
  /// grup; pasangan belum main (sebelum bagan) di belakang tanpa nomor dan tanpa babak.
  static List<StandingEntry> finalEntries(ActiveTournament active) {
    final gk = active.config.groupKnockout;
    if (gk == null) return const [];
    final knockout = [
      for (final m in active.matches)
        if (m.phase is KnockoutPhase) m,
    ]..sort((a, b) => _playOrder(a.phase! as KnockoutPhase).compareTo(_playOrder(b.phase! as KnockoutPhase)));
    final qualified = {
      for (final m in knockout) ...[m.pair1.id, m.pair2.id],
    }..remove('');
    final hasBracket = knockout.isNotEmpty;

    int qualifiedIn(GroupTable t) => t.pairIds.where(qualified.contains).length;

    final ranked = <({StandingEntry entry, int key, String stage})>[];
    final unplayed = <StandingEntry>[];
    for (final table in groupTables(active)) {
      final letter = GroupKnockout.letter(table.group);
      for (final (i, e) in table.entries.indexed) {
        final id = table.pairIds[i];
        if (hasBracket && qualified.contains(id)) {
          final (key, stage) = _knockoutState(id, knockout);
          ranked.add((entry: e, key: key, stage: stage));
          continue;
        }
        final position = e.position;
        if (position == null && !hasBracket) {
          unplayed.add(e);
          continue;
        }
        // Posisi grup (GP7): sebelum bagan 1 + yang nomornya lebih kecil; setelah bagan (jumlah lolos dari grup ini,
        // termasuk wildcard) + 1 + yang tidak lolos dan lebih kecil. Tanpa wildcard = 3 + … seperti 3.8.0.
        final above = [
          for (final (j, o) in table.entries.indexed)
            if (o.position != null &&
                (position == null || o.position! < position) &&
                (!hasBracket || !qualified.contains(table.pairIds[j])))
              o,
        ].length;
        final q = (hasBracket ? qualifiedIn(table) + 1 : 1) + above;
        ranked.add((entry: e, key: hasBracket ? 60 + q : q, stage: 'Grup $letter · $q'));
      }
    }
    ranked.sort((a, b) => a.key != b.key ? a.key - b.key : a.entry.label.compareTo(b.entry.label));
    final result = <StandingEntry>[];
    int? lastKey;
    var position = 0;
    for (final r in ranked) {
      if (r.key != lastKey) position++;
      lastKey = r.key;
      result.add(
        StandingEntry(players: r.entry.players, standing: r.entry.standing, position: position, stage: r.stage),
      );
    }
    return [
      ...result,
      for (final e in unplayed) StandingEntry(players: e.players, standing: e.standing, position: null),
    ];
  }

  static int _playOrder(KnockoutPhase p) => p.round.index * 10 + p.slot;

  /// Kunci dan babak dari match gugur paling akhir (urut main) yang memuat pasangan ini.
  static (int, String) _knockoutState(String pairId, List<MatchGame> knockout) {
    final m = knockout.lastWhere((x) => x.pair1.id == pairId || x.pair2.id == pairId);
    final round = (m.phase! as KnockoutPhase).round;
    final winner = m.winnerPairId;
    final played = m.status == MatchStatus.done || m.status == MatchStatus.wo;
    final won = winner == pairId;
    // Match tanpa pemenang (seharusnya tidak ada di gugur, I9) dihitung belum ada hasil.
    final open = !played || winner == null;
    return switch (round) {
      // Label juara keputusan 149: Juara 1/2 dari Final, Juara 3 = pemenang Perebutan juara 3.
      KnockoutRound.finalRound => open ? (15, 'Final') : (won ? (10, 'Juara 1') : (20, 'Juara 2')),
      KnockoutRound.thirdPlace =>
        open
            ? (m.status == MatchStatus.cancelled ? (35, 'Semifinal') : (35, KnockoutRound.thirdPlace.label))
            : (won ? (30, KnockoutRound.thirdPlace.shortLabel) : (40, 'Semifinal')),
      // Kalah SF tanpa match Juara 3; menang SF tapi belum di Final (tidak terjadi setelah resolve) = tanpa hasil.
      KnockoutRound.semifinal => open || won ? (25, 'Semifinal') : (30, 'Semifinal'),
      KnockoutRound.quarterfinal => open || won ? (45, 'Perempat final') : (50, 'Perempat final'),
    };
  }
}
