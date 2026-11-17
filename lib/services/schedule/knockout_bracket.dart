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
  /// Match gugur urut main: [PF1..PF4] SF1, SF2, [Juara 3] Final.
  static List<KnockoutPhase> phases({required int groupCount, required bool thirdPlace}) => [
    if (groupCount == 4)
      for (var s = 1; s <= 4; s++) KnockoutPhase(KnockoutRound.quarterfinal, s),
    const KnockoutPhase(KnockoutRound.semifinal, 1),
    const KnockoutPhase(KnockoutRound.semifinal, 2),
    if (thirdPlace) const KnockoutPhase(KnockoutRound.thirdPlace, 1),
    const KnockoutPhase(KnockoutRound.finalRound, 1),
  ];

  /// Dua sisi (pair1, pair2) match [phase] di bagan [groupCount] grup. 2 grup: SF1 = A1–B2, SF2 = B1–A2. 4 grup: PF1 =
  /// A1–B2, PF2 = C1–D2, PF3 = B1–A2, PF4 = D1–C2, SF dari pemenang PF. Slot 1 dan 2 satu grup selalu di paruh berbeda
  /// (AC-G8).
  static (SideSource, SideSource) sources(KnockoutPhase phase, {required int groupCount}) {
    const seeds = [(0, 1, 1, 2), (2, 1, 3, 2), (1, 1, 0, 2), (3, 1, 2, 2)];
    (SideSource, SideSource) seeded(int i) =>
        (SeedSource(seeds[i].$1, seeds[i].$2), SeedSource(seeds[i].$3, seeds[i].$4));
    (SideSource, SideSource) fromSemis({required bool winner}) => (
      ResultSource(const KnockoutPhase(KnockoutRound.semifinal, 1), winner: winner),
      ResultSource(const KnockoutPhase(KnockoutRound.semifinal, 2), winner: winner),
    );
    return switch (phase.round) {
      KnockoutRound.quarterfinal => seeded((phase.slot - 1).clamp(0, 3)),
      KnockoutRound.semifinal when groupCount == 4 => (
        ResultSource(KnockoutPhase(KnockoutRound.quarterfinal, phase.slot == 2 ? 3 : 1), winner: true),
        ResultSource(KnockoutPhase(KnockoutRound.quarterfinal, phase.slot == 2 ? 4 : 2), winner: true),
      ),
      // 2 grup: SF1 = A1–B2 (= baris PF1), SF2 = B1–A2 (= baris PF3).
      KnockoutRound.semifinal => seeded(phase.slot == 2 ? 2 : 0),
      KnockoutRound.thirdPlace => fromSemis(winner: false),
      KnockoutRound.finalRound => fromSemis(winner: true),
    };
  }

  /// "SF1", "PF2", "Juara 3", "Final": kode baris match dan isi tab yang memecah satu babak (21a, 21s).
  static String code(KnockoutPhase phase) => switch (phase.round.codePrefix) {
    final prefix? => '$prefix${phase.slot}',
    null => phase.round.shortLabel,
  };

  /// Teks sisi yang belum diketahui (21a): "A1", "Pemenang SF1", "Kalah SF1".
  static String sourceLabel(SideSource source) => switch (source) {
    SeedSource() => source.code,
    ResultSource(:final match, winner: true) => 'Pemenang ${code(match)}',
    ResultSource(:final match, winner: false) => 'Kalah ${code(match)}',
  };

  /// Kode slot lolos pasangan ini ('A1') dari sisi babak pertama (kode di depan nama, 21b, 21s). Null kalau belum ada
  /// bagan atau pasangan tidak lolos.
  static String? seedOf(ActiveTournament active, String pairId) {
    final gk = active.config.groupKnockout;
    if (gk == null || pairId.isEmpty) return null;
    for (final m in active.matches) {
      final phase = m.phase;
      if (phase is! KnockoutPhase || !_isFirstRound(phase, gk.groupCount)) continue;
      final (s1, s2) = sources(phase, groupCount: gk.groupCount);
      if (m.pair1.id == pairId && s1 is SeedSource) return s1.code;
      if (m.pair2.id == pairId && s2 is SeedSource) return s2.code;
    }
    return null;
  }

  static bool _isFirstRound(KnockoutPhase phase, int groupCount) =>
      phase.round == (groupCount == 4 ? KnockoutRound.quarterfinal : KnockoutRound.semifinal);

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
    if (groupCount == 4) place([for (var s = 1; s <= 4; s++) KnockoutPhase(KnockoutRound.quarterfinal, s)]);
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

  /// Buat bagan (G9): semua match gugur sekaligus, sesudah round terakhir fase grup. [qualifiers] = per grup [slot 1,
  /// slot 2] id pasangan (`QualifierPlan.withPicks`). Sisi yang belum diketahui = [Pair.tbd]. Hanya match baru yang
  /// dikembalikan; pemanggil menambahkannya ke `matches` dalam satu `state =`.
  static List<MatchGame> build(ActiveTournament active, List<List<String>> qualifiers) {
    final config = active.config;
    final gk = config.groupKnockout;
    if (gk == null) throw ArgumentError('Bukan turnamen Grup + Gugur');
    if (qualifiers.length != gk.groupCount || qualifiers.any((q) => q.length != 2)) {
      throw ArgumentError.value(qualifiers, 'qualifiers', 'harus 2 pasangan per grup');
    }
    Pair seed(SeedSource s) {
      final id = qualifiers[s.group][s.slot - 1];
      final pair = config.fixedPairs?.where((p) => p.id == id).firstOrNull;
      if (pair == null) throw ArgumentError.value(id, 'qualifiers', 'pasangan tidak dikenal');
      return pair;
    }

    Pair side(SideSource s) => s is SeedSource ? seed(s) : Pair.tbd;
    final lastGroupRound = active.matches
        .where((m) => m.phase is GroupPhase)
        .fold(0, (r, m) => m.roundNumber > r ? m.roundNumber : r);
    return [
      for (final slot in layout(
        groupCount: gk.groupCount,
        thirdPlace: gk.thirdPlace,
        courts: config.courts.length,
        firstRound: lastGroupRound + 1,
      ))
        MatchGame(
          id: 'm-r${slot.round}-${slot.matchNumber}',
          roundNumber: slot.round,
          matchNumberInRound: slot.matchNumber,
          courtId: config.courts[slot.court].id,
          pair1: side(sources(slot.phase, groupCount: gk.groupCount).$1),
          pair2: side(sources(slot.phase, groupCount: gk.groupCount).$2),
          phase: slot.phase,
        ),
    ];
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

  /// Sisi yang seharusnya: sisi seed tetap apa adanya (hanya Buat bagan yang mengisinya), sisi hasil dari sumbernya.
  static (Pair, Pair) _expectedSides(
    KnockoutPhase phase,
    MatchGame m,
    int groupCount,
    MatchGame? Function(KnockoutPhase) matchOf,
  ) {
    final (s1, s2) = sources(phase, groupCount: groupCount);
    Pair side(SideSource s, Pair current) => switch (s) {
      SeedSource() => current,
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

  /// Match yang sisinya diisi oleh [phase]: PF → SF-nya; SF → Final dan Juara 3 (kalau ada); Final dan Juara 3 →
  /// tidak ada. Urutan = urutan pesan 21l ("Final dan Juara 3 sudah ada skor").
  static List<KnockoutPhase> dependents(GroupKnockout gk, KnockoutPhase phase) => switch (phase.round) {
    KnockoutRound.quarterfinal => [KnockoutPhase(KnockoutRound.semifinal, phase.slot <= 2 ? 1 : 2)],
    KnockoutRound.semifinal => [
      const KnockoutPhase(KnockoutRound.finalRound, 1),
      if (gk.thirdPlace) const KnockoutPhase(KnockoutRound.thirdPlace, 1),
    ],
    KnockoutRound.thirdPlace || KnockoutRound.finalRound => const [],
  };

  /// Ubah skor gugur (GU11) sebelum disimpan. Pemenang sama, atau match belum punya pemenang → selalu boleh, tanpa
  /// dialog. Pemenang berganti → ditolak kalau ada match yang diisinya sudah ada hasil (done/WO; cancelled = tanpa
  /// hasil); kalau tidak, boleh dengan pratinjau susunan baru match itu (21k). Match bukan gugur → boleh.
  static FlipCheck flipCheck(ActiveTournament active, String matchId, String newWinnerPairId) {
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
    // Pratinjau: pemenang baru sebagai WO sementara (cukup untuk `winnerPairId`), lalu pemenang maju.
    final loser = m.pair1.id == newWinnerPairId ? m.pair2.id : m.pair1.id;
    final hypothetical = [for (final x in active.matches) x.id == matchId ? x.asWalkover(loserPairId: loser) : x];
    final resolved = resolve(active.config, hypothetical);
    return FlipAllowed([
      for (final p in deps)
        if (resolved.where((x) => x.phase == p).firstOrNull case final d?) d,
    ]);
  }

  /// Tab round (21b, 21s, 21v): round fase grup "R{n}"; round berisi Final → "Final"; seluruh satu babak → nama
  /// pendek ("Semifinal", "Juara 3"); sebagian babak → kode ("SF1", "PF1–2", "PF4").
  static String roundTab(ActiveTournament active, int round) {
    final inRound = _knockoutOf(active, round);
    if (inRound.isEmpty) return 'R$round';
    if (inRound.any((p) => p.round == KnockoutRound.finalRound)) return KnockoutRound.finalRound.shortLabel;
    final babak = inRound.first.round;
    final mine = [
      for (final p in inRound)
        if (p.round == babak) p,
    ];
    final all = active.matches.where((m) => m.phase is KnockoutPhase && (m.phase! as KnockoutPhase).round == babak);
    if (all.length == mine.length) return babak.shortLabel;
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
