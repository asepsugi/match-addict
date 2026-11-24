import '../../models/models.dart';

/// Asal satu sisi match gugur (logic.md §18.8): slot lolos grup ("A1") atau hasil match gugur lain.
sealed class SideSource {
  const SideSource();
}

/// Slot lolos: [group] 0 = Grup A, [slot] 1 atau 2.
final class SeedSource extends SideSource {
  final int group;
  final int slot;
  const SeedSource(this.group, this.slot);

  /// 'A1', 'B2'.
  String get code => '${GroupKnockout.letter(group)}$slot';

  @override
  bool operator ==(Object other) => other is SeedSource && other.group == group && other.slot == slot;

  @override
  int get hashCode => Object.hash(group, slot);
}

/// 3 grup (logic.md §21.6): juara ke-[rank] (J1–J3, urut `Seeding.champions`). Huruf grupnya baru pasti saat Buat bagan.
final class ChampionSource extends SideSource {
  final int rank;
  const ChampionSource(this.rank);

  @override
  bool operator ==(Object other) => other is ChampionSource && other.rank == rank;

  @override
  int get hashCode => Object.hash(ChampionSource, rank);
}

/// 3 grup: slot 2 grup juara ke-[rank] ("#2 grup J2").
final class RunnerUpSource extends SideSource {
  final int rank;
  const RunnerUpSource(this.rank);

  @override
  bool operator ==(Object other) => other is RunnerUpSource && other.rank == rank;

  @override
  int get hashCode => Object.hash(RunnerUpSource, rank);
}

/// 3 grup: wildcard ke-[index] ("WC1") sebelum tukar; sesudah Buat bagan sisinya sudah berisi pasangan.
final class WildcardSource extends SideSource {
  final int index;
  const WildcardSource(this.index);

  @override
  bool operator ==(Object other) => other is WildcardSource && other.index == index;

  @override
  int get hashCode => Object.hash(WildcardSource, index);
}

/// Pemenang ([winner] true) atau yang kalah di match [match].
final class ResultSource extends SideSource {
  final KnockoutPhase match;
  final bool winner;
  const ResultSource(this.match, {required this.winner});

  @override
  bool operator ==(Object other) => other is ResultSource && other.match == match && other.winner == winner;

  @override
  int get hashCode => Object.hash(match, winner);
}

/// Satu match di susunan bagan: round, nomor match di round itu, dan indeks court (urut `config.courts`).
typedef KnockoutSlot = ({KnockoutPhase phase, int round, int matchNumber, int court});

/// Satu slot pratinjau bagan sebelum Buat bagan (23s, 23t): susunan [KnockoutSlot] + asal kedua sisi.
typedef KnockoutPreviewSlot = ({
  KnockoutPhase phase,
  int round,
  int matchNumber,
  int court,
  SideSource side1,
  SideSource side2,
});

/// Hasil [KnockoutBracket.build]: match gugur baru + config yang harus dipasang di `state =` yang sama (3 grup:
/// `groupKnockout.wildcards` terisi; 2/4 grup: config yang sama persis, `identical`).
typedef KnockoutBuild = ({TournamentConfig config, List<MatchGame> matches});

/// Hasil [KnockoutBracket.flipCheck].
sealed class FlipCheck {
  const FlipCheck();
}

/// Boleh disimpan. [preview] = match yang susunannya berganti (dialog 21k); kosong = tanpa dialog.
final class FlipAllowed extends FlipCheck {
  final List<MatchGame> preview;
  const FlipAllowed([this.preview = const []]);
}

/// Ditolak (21l): babak yang sudah ada hasilnya, urut [KnockoutBracket.dependents].
final class FlipBlocked extends FlipCheck {
  final List<KnockoutRound> rounds;
  const FlipBlocked(this.rounds);
}

/// Bagan Grup + Gugur (PRD §16.6, logic.md §18.8, 18.10): topologi, susunan round/court, Buat bagan, pemenang maju,
/// ubah skor gugur, dan label round. Semua helper total: data tak dikenal dilewati, tidak melempar (dipakai decoder).
class KnockoutBracket {
  /// Match gugur urut main: [QF1..QF4] SF1, SF2, [Juara 3] Final. QF ada di 3 dan 4 grup.
  static List<KnockoutPhase> phases({required int groupCount, required bool thirdPlace}) => [
    if (groupCount >= 3)
      for (var s = 1; s <= 4; s++) KnockoutPhase(KnockoutRound.quarterfinal, s),
    const KnockoutPhase(KnockoutRound.semifinal, 1),
    const KnockoutPhase(KnockoutRound.semifinal, 2),
    if (thirdPlace) const KnockoutPhase(KnockoutRound.thirdPlace, 1),
    const KnockoutPhase(KnockoutRound.finalRound, 1),
  ];

  /// Dua sisi (pair1, pair2) match [phase] di bagan [groupCount] grup. 2 grup: SF1 = A1–B2, SF2 = B1–A2. 4 grup: QF1 =
  /// A1–B2, QF2 = C1–D2, QF3 = B1–A2, QF4 = D1–C2, SF dari pemenang QF. Slot 1 dan 2 satu grup selalu di paruh berbeda
  /// (AC-G8). 3 grup (G15) sebelum tukar: QF1 = J1–WC1, QF2 = R(J2)–R(J3), QF3 = J2–WC2, QF4 = J3–R(J1); pasangan
  /// sesudah tukar dari [threeGroupQuarterfinals].
  static (SideSource, SideSource) sources(KnockoutPhase phase, {required int groupCount}) {
    const seeds = [(0, 1, 1, 2), (2, 1, 3, 2), (1, 1, 0, 2), (3, 1, 2, 2)];
    (SideSource, SideSource) seeded(int i) =>
        (SeedSource(seeds[i].$1, seeds[i].$2), SeedSource(seeds[i].$3, seeds[i].$4));
    const threeGroups = <(SideSource, SideSource)>[
      (ChampionSource(1), WildcardSource(1)),
      (RunnerUpSource(2), RunnerUpSource(3)),
      (ChampionSource(2), WildcardSource(2)),
      (ChampionSource(3), RunnerUpSource(1)),
    ];
    (SideSource, SideSource) fromSemis({required bool winner}) => (
      ResultSource(const KnockoutPhase(KnockoutRound.semifinal, 1), winner: winner),
      ResultSource(const KnockoutPhase(KnockoutRound.semifinal, 2), winner: winner),
    );
    return switch (phase.round) {
      KnockoutRound.quarterfinal when groupCount == 3 => threeGroups[(phase.slot - 1).clamp(0, 3)],
      KnockoutRound.quarterfinal => seeded((phase.slot - 1).clamp(0, 3)),
      KnockoutRound.semifinal when groupCount >= 3 => (
        ResultSource(KnockoutPhase(KnockoutRound.quarterfinal, phase.slot == 2 ? 3 : 1), winner: true),
        ResultSource(KnockoutPhase(KnockoutRound.quarterfinal, phase.slot == 2 ? 4 : 2), winner: true),
      ),
      // 2 grup: SF1 = A1–B2 (= baris QF1), SF2 = B1–A2 (= baris QF3).
      KnockoutRound.semifinal => seeded(phase.slot == 2 ? 2 : 0),
      KnockoutRound.thirdPlace => fromSemis(winner: false),
      KnockoutRound.finalRound => fromSemis(winner: true),
    };
  }

  /// Dua sumber sisi match [m] kalau dia match gugur di turnamen Grup + Gugur; null untuk match lain. Satu pintu untuk
  /// layar/teks yang menulis sisi belum diketahui dari asalnya ("Pemenang SF1"), bukan dari pasangan kosong.
  static (SideSource, SideSource)? sourcesOf(TournamentConfig config, MatchGame m) {
    final phase = m.phase;
    final gk = config.groupKnockout;
    return phase is KnockoutPhase && gk != null ? sources(phase, groupCount: gk.groupCount) : null;
  }

  /// Topologi Perempat final 3 grup (G15) **sesudah tukar**: QF1–QF4 sebagai (pair1, pair2) id pasangan. Tukar iff
  /// grup WC1 = grup J1 atau grup WC2 = grup J2 → QF1 = J1–WC2, QF3 = J2–WC1; satu tukar selalu cukup karena WC1 dan
  /// WC2 beda grup. Satu-satunya sumber aturan ini: dipakai [build] **dan** validator GR19 codec (security W2), jangan
  /// disalin. [groups] = `GroupKnockout.groups`. Total: [seeding] yang tidak berbentuk 3 grup sah → null.
  static List<(String, String)>? threeGroupQuarterfinals(Seeding seeding, List<List<String>> groups) {
    final slots = seeding.groupSlots, champions = seeding.champions, wildcards = seeding.wildcards;
    if (groups.length != 3 || slots.length != 3 || champions.length != 3 || wildcards.length != 2) return null;
    if ({...champions}.length != 3 || champions.any((g) => g < 0 || g > 2)) return null;
    int? groupOf(String id) {
      for (final (g, ids) in groups.indexed) {
        if (ids.contains(id)) return g;
      }
      return null;
    }

    final seeded = <String>{};
    for (final (g, s) in slots.indexed) {
      if (s.length != 2 || s.any((id) => groupOf(id) != g) || !seeded.add(s[0]) || !seeded.add(s[1])) return null;
    }
    final wcGroups = [for (final id in wildcards) groupOf(id)];
    if (wcGroups.contains(null) || wcGroups[0] == wcGroups[1] || wildcards.any(seeded.contains)) return null;
    final swap = wcGroups[0] == champions[0] || wcGroups[1] == champions[1];
    final (toJ1, toJ2) = swap ? (wildcards[1], wildcards[0]) : (wildcards[0], wildcards[1]);
    String j(int rank) => slots[champions[rank - 1]][0];
    String r(int rank) => slots[champions[rank - 1]][1];
    return [(j(1), toJ1), (r(2), r(3)), (j(2), toJ2), (j(3), r(1))];
  }

  /// "SF1", "QF2", "Juara 3", "Final": kode baris match dan isi tab yang memecah satu babak (21a, 21s).
  static String code(KnockoutPhase phase) => switch (phase.round.codePrefix) {
    final prefix? => '$prefix${phase.slot}',
    null => phase.round.shortLabel,
  };

  /// Teks sisi yang belum diketahui (21a, 23t): "A1", "J1", "WC1", "#2 grup J2", "Pemenang SF1", "Kalah SF1".
  static String sourceLabel(SideSource source) => switch (source) {
    SeedSource() => source.code,
    ChampionSource(:final rank) => 'J$rank',
    RunnerUpSource(:final rank) => '#2 grup J$rank',
    WildcardSource(:final index) => 'WC$index',
    ResultSource(:final match, winner: true) => 'Pemenang ${code(match)}',
    ResultSource(:final match, winner: false) => 'Kalah ${code(match)}',
  };

  /// Kode slot lolos pasangan ini dari sisi babak pertama: "A1", "C2", "WC1" (Klasemen Fase grup 22b/23j, kode di depan
  /// nama 21b). WC dari `gk.wildcards`, bukan dari sisi sesudah tukar. Null kalau belum ada bagan atau tidak lolos.
  static String? seedCode(ActiveTournament active, String pairId) => _seed(active, pairId, origin: false);

  /// Seperti [seedCode], wildcard dengan asalnya: "WC2 · B3" (kartu bagan 23h, dialog 23d).
  static String? seedLabel(ActiveTournament active, String pairId) => _seed(active, pairId, origin: true);

  static String? _seed(ActiveTournament active, String pairId, {required bool origin}) {
    final gk = active.config.groupKnockout;
    if (gk == null || pairId.isEmpty) return null;
    for (final m in active.matches) {
      final phase = m.phase;
      if (phase is! KnockoutPhase || !_isFirstRound(phase, gk.groupCount)) continue;
      final (s1, s2) = sources(phase, groupCount: gk.groupCount);
      final source = m.pair1.id == pairId ? s1 : (m.pair2.id == pairId ? s2 : null);
      if (source == null) continue;
      final group = gk.groupOfPair(pairId);
      final letter = group == null ? null : GroupKnockout.letter(group);
      return switch (source) {
        SeedSource() => source.code,
        ChampionSource() => letter == null ? null : '${letter}1',
        RunnerUpSource() => letter == null ? null : '${letter}2',
        WildcardSource() => switch (gk.wildcards.indexOf(pairId)) {
          final i when i < 0 || letter == null => null,
          final i => origin ? 'WC${i + 1} · ${letter}3' : 'WC${i + 1}',
        },
        ResultSource() => null,
      };
    }
    return null;
  }

  static KnockoutRound _firstRound(int groupCount) =>
      groupCount >= 3 ? KnockoutRound.quarterfinal : KnockoutRound.semifinal;

  static bool _isFirstRound(KnockoutPhase phase, int groupCount) => phase.round == _firstRound(groupCount);

  /// Susunan round dan court (GU10): babak urut main, match satu babak urut slot diisi ke round baru per [courts] court
  /// (Court 1 dulu; court kunci grup tidak berlaku), babak berikutnya di round sesudahnya. Round terakhir: Final di
  /// Court 1 + Juara 3 di Court 2; 1 court → Juara 3 satu round lebih dulu, Final terakhir.
  static List<KnockoutSlot> layout({
    required int groupCount,
    required bool thirdPlace,
    required int courts,
    required int firstRound,
  }) {
    if (courts <= 0) return const [];
    final result = <KnockoutSlot>[];
    var round = firstRound;
    void place(List<KnockoutPhase> batch) {
      for (var i = 0; i < batch.length; i++) {
        if (i > 0 && i % courts == 0) round++;
        result.add((phase: batch[i], round: round, matchNumber: i % courts + 1, court: i % courts));
      }
      round++;
    }

    const f = KnockoutPhase(KnockoutRound.finalRound, 1);
    const j3 = KnockoutPhase(KnockoutRound.thirdPlace, 1);
    if (groupCount >= 3) place([for (var s = 1; s <= 4; s++) KnockoutPhase(KnockoutRound.quarterfinal, s)]);
    place(const [KnockoutPhase(KnockoutRound.semifinal, 1), KnockoutPhase(KnockoutRound.semifinal, 2)]);
    if (!thirdPlace) {
      place(const [f]);
    } else if (courts == 1) {
      place(const [j3]);
      place(const [f]);
    } else {
      place(const [f, j3]);
    }
    return result;
  }

  /// Buat bagan (G9): semua match gugur sekaligus, sesudah round terakhir fase grup. [seeding] = hasil langkah Buat
  /// bagan (`groupSlots` per grup [slot 1, slot 2]; 3 grup juga `champions` + `wildcards`). Sisi yang belum diketahui =
  /// [Pair.tbd]. Pemanggil menambahkan `matches` dan memasang `config` (3 grup: `wildcards` = `Seeding.wildcards`, urutan
  /// WC1, WC2 sebelum tukar) dalam satu `state =` (security W3). Seeding yang salah bentuk → [ArgumentError].
  static KnockoutBuild build(ActiveTournament active, Seeding seeding) {
    final config = active.config;
    final gk = config.groupKnockout;
    if (gk == null) throw ArgumentError('Bukan turnamen Grup + Gugur');
    final qualifiers = seeding.groupSlots;
    if (qualifiers.length != gk.groupCount || qualifiers.any((q) => q.length != 2)) {
      throw ArgumentError.value(qualifiers, 'seeding', 'harus 2 pasangan per grup');
    }
    final threeGroups = gk.groupCount == 3;
    final quarterfinals = threeGroups ? threeGroupQuarterfinals(seeding, gk.groups) : null;
    if (threeGroups && quarterfinals == null) {
      throw ArgumentError.value(seeding, 'seeding', 'juara/wildcard 3 grup tidak sah');
    }
    if (!threeGroups && (seeding.champions.isNotEmpty || seeding.wildcards.isNotEmpty)) {
      throw ArgumentError.value(seeding, 'seeding', 'juara/wildcard hanya untuk 3 grup');
    }
    Pair pairOf(String id) {
      final pair = config.fixedPairs?.where((p) => p.id == id).firstOrNull;
      if (pair == null) throw ArgumentError.value(id, 'seeding', 'pasangan tidak dikenal');
      return pair;
    }

    (Pair, Pair) sides(KnockoutPhase phase) {
      if (quarterfinals != null && phase.round == KnockoutRound.quarterfinal) {
        final (a, b) = quarterfinals[phase.slot - 1];
        return (pairOf(a), pairOf(b));
      }
      Pair side(SideSource s) => s is SeedSource ? pairOf(qualifiers[s.group][s.slot - 1]) : Pair.tbd;
      final (s1, s2) = sources(phase, groupCount: gk.groupCount);
      return (side(s1), side(s2));
    }

    final matches = [
      for (final slot in layout(
        groupCount: gk.groupCount,
        thirdPlace: gk.thirdPlace,
        courts: config.courts.length,
        firstRound: _lastGroupRound(active) + 1,
      ))
        if (sides(slot.phase) case (final pair1, final pair2))
          MatchGame(
            id: 'm-r${slot.round}-${slot.matchNumber}',
            roundNumber: slot.round,
            matchNumberInRound: slot.matchNumber,
            courtId: config.courts[slot.court].id,
            pair1: pair1,
            pair2: pair2,
            phase: slot.phase,
          ),
    ];
    // 2/4 grup: config apa adanya (`startIfNeeded` membandingkan dengan `identical`).
    final next = threeGroups
        ? config.copyWith(groupKnockout: gk.copyWith(wildcards: List.unmodifiable(seeding.wildcards)))
        : config;
    return (config: next, matches: matches);
  }

  static int _lastGroupRound(ActiveTournament active) =>
      active.matches.where((m) => m.phase is GroupPhase).fold(0, (r, m) => m.roundNumber > r ? m.roundNumber : r);

  /// Pratinjau bagan (keputusan 153–154): susunan [layout] sesudah round grup terakhir + asal kedua sisi, untuk tab Bagan
  /// sebelum Buat bagan. Bukan match: tidak disimpan (jebakan 21.12 #9); Juara 3 nyala/mati hanya mengubah daftar ini.
  static List<KnockoutPreviewSlot> preview(ActiveTournament active) {
    final gk = active.config.groupKnockout;
    if (gk == null) return const [];
    return [
      for (final s in layout(
        groupCount: gk.groupCount,
        thirdPlace: gk.thirdPlace,
        courts: active.config.courts.length,
        firstRound: _lastGroupRound(active) + 1,
      ))
        if (sources(s.phase, groupCount: gk.groupCount) case (final side1, final side2))
          (phase: s.phase, round: s.round, matchNumber: s.matchNumber, court: s.court, side1: side1, side2: side2),
    ];
  }

  /// Ujung tab Bagan "terisi/semua" (23s "0/4", 23v "5/8"): match gugur Selesai/WO dari semua match gugur; sebelum bagan
  /// `total` = jumlah [phases].
  static ({int done, int total}) progress(ActiveTournament active) {
    final gk = active.config.groupKnockout;
    if (gk == null) return (done: 0, total: 0);
    final knockout = [
      for (final m in active.matches)
        if (m.phase is KnockoutPhase) m,
    ];
    if (knockout.isEmpty) return (done: 0, total: phases(groupCount: gk.groupCount, thirdPlace: gk.thirdPlace).length);
    return (done: knockout.where(_hasResult).length, total: knockout.length);
  }

  /// Kolom geser awal bagan (21j, 23v, 23w): babak pertama (urut main) yang punya match tanpa hasil (belum ada bagan =
  /// tanpa hasil); semua terisi → babak terakhir. Bisa [KnockoutRound.thirdPlace] (urut main sebelum Final, juga saat
  /// Final belum ada hasil): bagan tidak punya kolom Juara 3, pemanggil memetakannya ke kolom Final (21t).
  static KnockoutRound firstOpenColumn(ActiveTournament active) {
    final gk = active.config.groupKnockout;
    if (gk == null) return KnockoutRound.finalRound;
    final byPhase = _byPhase(active.matches);
    for (final round in gk.rounds) {
      final open = phases(
        groupCount: gk.groupCount,
        thirdPlace: gk.thirdPlace,
      ).any((p) => p.round == round && !(byPhase[p] != null && _hasResult(byPhase[p]!)));
      if (open) return round;
    }
    return gk.rounds.last;
  }

  /// Warna alur (keputusan 154): indeks match babak pertama (0..3) yang dibawa sisi [side] (1 = atas, 2 = bawah) match
  /// [phase], atau null (abu). Match babak pertama → indeksnya sendiri; sisi dari match babak pertama → indeks match itu
  /// (juga sebelum ada pemenang, 23s); sisi dari match lanjutan → indeks asal pemenangnya kalau sudah ada; Juara 3 null.
  static int? flowIndex(ActiveTournament active, KnockoutPhase phase, int side) {
    assert(side == 1 || side == 2);
    final gk = active.config.groupKnockout;
    if (gk == null || phase.round == KnockoutRound.thirdPlace) return null;
    final first = _firstRound(gk.groupCount);
    if (phase.round == first) return phase.slot - 1;
    final (s1, s2) = sources(phase, groupCount: gk.groupCount);
    final source = side == 1 ? s1 : s2;
    if (source is! ResultSource || !source.winner) return null;
    if (source.match.round == first) return source.match.slot - 1;
    final from = _byPhase(active.matches)[source.match];
    final w = from?.winnerPairId;
    if (from == null || w == null) return null;
    return flowIndex(active, source.match, from.pair1.id == w ? 1 : 2);
  }

  static Map<KnockoutPhase, MatchGame> _byPhase(List<MatchGame> matches) {
    final byPhase = <KnockoutPhase, MatchGame>{};
    for (final m in matches) {
      if (m.phase case final KnockoutPhase p) byPhase.putIfAbsent(p, () => m);
    }
    return byPhase;
  }

  /// Pemenang maju (G12): sisi tiap match gugur yang berasal dari match lain diisi ulang dari `winnerPairId` sumbernya
  /// (belum ada hasil → [Pair.tbd]). Hanya match tanpa hasil yang berubah; match dengan hasil yang sisinya berbeda
  /// adalah pelanggaran yang harus ditolak lebih dulu lewat [flipCheck]. Dipanggil di setiap mutasi skor/WO gugur.
  static List<MatchGame> resolve(TournamentConfig config, List<MatchGame> matches) {
    final gk = config.groupKnockout;
    if (gk == null) return matches;
    final result = [...matches];
    final indexOf = <KnockoutPhase, int>{};
    for (final (i, m) in result.indexed) {
      if (m.phase case final KnockoutPhase p) indexOf.putIfAbsent(p, () => i);
    }
    for (final phase in phases(groupCount: gk.groupCount, thirdPlace: gk.thirdPlace)) {
      final i = indexOf[phase];
      if (i == null) continue;
      final m = result[i];
      final (want1, want2) = _expectedSides(
        phase,
        m,
        gk.groupCount,
        (p) => indexOf[p] == null ? null : result[indexOf[p]!],
      );
      if (want1.id == m.pair1.id && want2.id == m.pair2.id) continue;
      if (_hasResult(m)) {
        assert(false, 'resolve: ${phase.code} sudah ada hasil, sisinya tidak boleh berganti (flipCheck dulu)');
        continue;
      }
      result[i] = _withSides(m, want1, want2);
    }
    return result;
  }

  /// Sisi semua match gugur sama dengan [resolve] atas match apa adanya (GR15). Tidak meng-`assert`: untuk decoder.
  static bool isResolved(TournamentConfig config, List<MatchGame> matches) {
    final gk = config.groupKnockout;
    if (gk == null) return true;
    final byPhase = <KnockoutPhase, MatchGame>{};
    for (final m in matches) {
      if (m.phase case final KnockoutPhase p) byPhase.putIfAbsent(p, () => m);
    }
    for (final MapEntry(key: phase, value: m) in byPhase.entries) {
      final (want1, want2) = _expectedSides(phase, m, gk.groupCount, (p) => byPhase[p]);
      if (want1.id != m.pair1.id || want2.id != m.pair2.id) return false;
    }
    return true;
  }

  /// Sisi yang seharusnya: sisi seed (juga J/R/WC 3 grup) tetap apa adanya (hanya Buat bagan yang mengisinya), sisi
  /// hasil dari sumbernya.
  static (Pair, Pair) _expectedSides(
    KnockoutPhase phase,
    MatchGame m,
    int groupCount,
    MatchGame? Function(KnockoutPhase) matchOf,
  ) {
    final (s1, s2) = sources(phase, groupCount: groupCount);
    Pair side(SideSource s, Pair current) => switch (s) {
      SeedSource() || ChampionSource() || RunnerUpSource() || WildcardSource() => current,
      ResultSource(:final match, :final winner) => _outcome(matchOf(match), winner: winner),
    };
    return (side(s1, m.pair1), side(s2, m.pair2));
  }

  /// Pemenang atau yang kalah di [m]; [Pair.tbd] kalau belum ada hasil.
  static Pair _outcome(MatchGame? m, {required bool winner}) {
    final w = m?.winnerPairId;
    if (m == null || w == null) return Pair.tbd;
    final won = m.pair1.id == w ? m.pair1 : m.pair2;
    final lost = m.pair1.id == w ? m.pair2 : m.pair1;
    return winner ? won : lost;
  }

  /// Done/WO = ada hasil; cancelled (diakhiri) dihitung tanpa hasil.
  static bool _hasResult(MatchGame m) => m.status == MatchStatus.done || m.status == MatchStatus.wo;

  static MatchGame _withSides(MatchGame m, Pair pair1, Pair pair2) => m.copyWith(pair1: pair1, pair2: pair2);

  /// Match yang sisinya diisi oleh [phase]: QF → SF-nya; SF → Final dan Juara 3 (kalau ada); Final dan Juara 3 →
  /// tidak ada. Urutan = urutan pesan 21l ("Final dan Juara 3 sudah ada skor").
  static List<KnockoutPhase> dependents(GroupKnockout gk, KnockoutPhase phase) {
    final next = advancesTo(phase);
    return [
      if (next != null) next,
      if (phase.round == KnockoutRound.semifinal && gk.thirdPlace) const KnockoutPhase(KnockoutRound.thirdPlace, 1),
    ];
  }

  /// Match tempat pemenang [phase] maju: QF → SF-nya, SF → Final; Final dan Juara 3 → null (pemenang = juara / juara 3).
  /// Tidak butuh config, jadi bisa dipakai teks yang hanya punya fase.
  static KnockoutPhase? advancesTo(KnockoutPhase phase) => switch (phase.round) {
    KnockoutRound.quarterfinal => KnockoutPhase(KnockoutRound.semifinal, phase.slot <= 2 ? 1 : 2),
    KnockoutRound.semifinal => const KnockoutPhase(KnockoutRound.finalRound, 1),
    KnockoutRound.thirdPlace || KnockoutRound.finalRound => null,
  };

  /// Ubah skor gugur (GU11) sebelum disimpan. Pemenang sama, atau match belum punya pemenang → selalu boleh, tanpa
  /// dialog. Pemenang berganti → ditolak kalau ada match yang diisinya sudah ada hasil (done/WO; cancelled = tanpa
  /// hasil); kalau tidak, boleh dengan pratinjau susunan baru match itu (21k). Match bukan gugur → boleh.
  /// [newWinnerPairId] null = match jadi tanpa pemenang (Kosongkan skor / Hapus WO tanpa skor lama, logic.md §19.2):
  /// dihitung sebagai pemenang berganti, sama aturannya.
  static FlipCheck flipCheck(ActiveTournament active, String matchId, String? newWinnerPairId) {
    final gk = active.config.groupKnockout;
    final m = active.matchById(matchId);
    final phase = m?.phase;
    if (gk == null || m == null || phase is! KnockoutPhase) return const FlipAllowed();
    final old = m.winnerPairId;
    if (old == null || old == newWinnerPairId) return const FlipAllowed();
    final deps = dependents(gk, phase);
    MatchGame? depMatch(KnockoutPhase p) => active.matches.where((x) => x.phase == p).firstOrNull;
    final blocked = [
      for (final p in deps)
        if (depMatch(p) case final d? when _hasResult(d)) p.round,
    ];
    if (blocked.isNotEmpty) return FlipBlocked(blocked);
    // Pratinjau: pemenang baru sebagai WO sementara (cukup untuk `winnerPairId`), atau match dikosongkan kalau tanpa
    // pemenang, lalu pemenang maju.
    MatchGame hypothesis(MatchGame x) {
      if (newWinnerPairId == null) return x.cleared(finished: active.tournament.isFinished);
      return x.asWalkover(loserPairId: m.pair1.id == newWinnerPairId ? m.pair2.id : m.pair1.id);
    }

    final hypothetical = [for (final x in active.matches) x.id == matchId ? hypothesis(x) : x];
    final resolved = resolve(active.config, hypothetical);
    return FlipAllowed([
      for (final p in deps)
        if (resolved.where((x) => x.phase == p).firstOrNull case final d?) d,
    ]);
  }

  /// Tab round (21b, 21s, 21v, 23v; keputusan 152): round fase grup "R{n}"; round berisi Final → "Final"; seluruh satu
  /// babak → `tabLabel` ("QF", "SF", "Juara 3"); sebagian babak → kode ("SF1", "QF1–2", "QF4").
  static String roundTab(ActiveTournament active, int round) {
    final inRound = _knockoutOf(active, round);
    if (inRound.isEmpty) return 'R$round';
    if (inRound.any((p) => p.round == KnockoutRound.finalRound)) return KnockoutRound.finalRound.tabLabel;
    final babak = inRound.first.round;
    final mine = [
      for (final p in inRound)
        if (p.round == babak) p,
    ];
    final all = active.matches.where((m) => m.phase is KnockoutPhase && (m.phase! as KnockoutPhase).round == babak);
    if (all.length == mine.length) return babak.tabLabel;
    final slots = [for (final p in mine) p.slot]..sort();
    final first = code(KnockoutPhase(babak, slots.first));
    return slots.length == 1 ? first : '$first–${slots.last}';
  }

  /// Judul round: fase grup "Round {n}"; round gugur = nama babak lengkap ("Semifinal", "Perebutan juara 3", "Final").
  static String roundTitle(ActiveTournament active, int round) {
    final inRound = _knockoutOf(active, round);
    if (inRound.isEmpty) return 'Round $round';
    if (inRound.any((p) => p.round == KnockoutRound.finalRound)) return KnockoutRound.finalRound.label;
    return inRound.first.round.label;
  }

  /// Label di atas nama baris match gugur (21b): "SF1 · Race to 6", "Juara 3 · Race to 4". Null untuk match lain.
  static String? matchLabel(TournamentConfig config, MatchGame m) => switch (m.phase) {
    final KnockoutPhase p => '${code(p)} · ${config.formatFor(m).label}',
    _ => null,
  };

  static List<KnockoutPhase> _knockoutOf(ActiveTournament active, int round) => [
    for (final m in active.matches)
      if (m.roundNumber == round && m.phase is KnockoutPhase) m.phase! as KnockoutPhase,
  ];
}
