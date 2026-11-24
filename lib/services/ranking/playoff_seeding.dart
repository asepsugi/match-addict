import '../../models/models.dart';
import 'ranking_calculator.dart';

/// Satu baris sheet Buat bagan 3 grup (23c, 23e): juara grup atau kandidat wildcard.
class SeedRow {
  final String pairId;

  /// Indeks grup asal, 0 = Grup A.
  final int group;

  /// Nilai metode Playoff seperti kolom tabel ("100", "33"; Point % "41"), tanpa "%" (judul kolom yang menulisnya).
  final String value;

  /// Selisih per match ("+3,67", "−1,67").
  final String perMatch;

  /// Pasti lolos tanpa pilihan host. Juara selalu true; false = menunggu [WildcardPick] atau tidak lolos (UI membedakan
  /// lewat `pick?.candidates`).
  final bool qualified;

  const SeedRow({
    required this.pairId,
    required this.group,
    required this.value,
    required this.perMatch,
    required this.qualified,
  });
}

/// Seri kandidat wildcard yang memotong batas lolos (G14, GP3): host memilih [need] dari [candidates] (urut huruf grup).
class WildcardPick {
  final int need;
  final List<String> candidates;

  const WildcardPick({required this.need, required this.candidates});
}

/// Isi langkah Buat bagan (logic.md §21.5). 2/4 grup: [champions]/[candidates] kosong, [seeding] langsung.
class SeedingPlan {
  final List<SeedRow> champions;

  /// Kandidat wildcard (slot 3 tiap grup), urut pembanding Playoff, seri → huruf grup.
  final List<SeedRow> candidates;
  final WildcardPick? pick;

  final List<List<String>> _groupSlots;
  final List<int> _championGroups;

  /// Wildcard pasti (urut), sebelum pilihan host.
  final List<String> _sureWildcards;

  const SeedingPlan._(
    this._groupSlots,
    this._championGroups,
    this._sureWildcards,
    this.champions,
    this.candidates,
    this.pick,
  );

  /// Null selama [pick] belum dijawab: tombol Buat bagan mati (AC-G25).
  Seeding? get seeding => pick == null ? _seeding(const []) : null;

  /// [chosen] = tepat [WildcardPick.need] kandidat berbeda dari [pick]. Urutan terpilih = huruf grup, bukan urutan
  /// ketukan (GP3). Null kalau pilihan tidak sah atau tidak ada [pick].
  Seeding? withWildcardPick(List<String> chosen) {
    final p = pick;
    if (p == null || chosen.length != p.need || chosen.toSet().length != chosen.length) return null;
    if (chosen.any((id) => !p.candidates.contains(id))) return null;
    return _seeding([
      for (final id in p.candidates)
        if (chosen.contains(id)) id,
    ]);
  }

  Seeding _seeding(List<String> chosen) =>
      Seeding(groupSlots: _groupSlots, champions: _championGroups, wildcards: [..._sureWildcards, ...chosen]);
}

/// Juara J1–J3 dan wildcard lintas grup (PRD §16 G14, GP3–GP4; logic.md §21.3, 21.5). Dart murni.
class PlayoffSeeding {
  /// Lintas grup: nilai metode (sama dengan [RankingCalculator.compareValue]) lalu selisih per match. Negatif = [a] di
  /// atas; 0 = seri (pemutusnya huruf grup atau host, §21.5).
  static int comparePlayoffSeed(PlayerStanding a, PlayerStanding b, RankingMethod method) {
    final byValue = RankingCalculator.compareValue(a, b, method);
    if (byValue != 0) return byValue;
    // Perkalian silang bilangan bulat, bukan double: −5 ÷ 3 dan −10 ÷ 6 harus seri (§21.12 #8).
    return (b.gameDiff * a.matchesPlayed).compareTo(a.gameDiff * b.matchesPlayed);
  }

  /// "+3,67" / "−1,67" / "0,00": selisih ÷ match, dua desimal (setengah menjauhi nol), koma, minus "−" (23c).
  static String perMatchLabel(int diff, int played) {
    if (played <= 0) return '0,00';
    final hundredths = (diff.abs() * 200 + played) ~/ (2 * played);
    if (hundredths == 0) return '0,00';
    final sign = diff > 0 ? '+' : '−';
    return '$sign${hundredths ~/ 100},${(hundredths % 100).toString().padLeft(2, '0')}';
  }

  /// [perGroup] = hasil `QualifierPlan.withPicks`: 2 id per grup (2/4 grup) atau 3 (3 grup, slot 3 = kandidat).
  /// [standings] = baris tabel grup per id pasangan, dihitung dengan [method].
  static SeedingPlan plan({
    required List<List<String>> perGroup,
    required Map<String, PlayerStanding> standings,
    required RankingMethod method,
  }) {
    final groupSlots = [for (final ids in perGroup) ids.take(2).toList()];
    if (perGroup.length != 3) return SeedingPlan._(groupSlots, const [], const [], const [], const [], null);

    int bySeed(int g1, int g2, int slot) {
      final c = comparePlayoffSeed(standings[perGroup[g1][slot]]!, standings[perGroup[g2][slot]]!, method);
      return c != 0 ? c : g1 - g2;
    }

    SeedRow row(int g, int slot, bool qualified) {
      final s = standings[perGroup[g][slot]]!;
      return SeedRow(
        pairId: perGroup[g][slot],
        group: g,
        value: switch (method) {
          RankingMethod.winPercent => '${s.winPercent.round()}',
          RankingMethod.pointPercent => '${s.pointPercent}',
          RankingMethod.totalGames => '${s.totalPoint}',
        },
        perMatch: perMatchLabel(s.gameDiff, s.matchesPlayed),
        qualified: qualified,
      );
    }

    // Juara: tanpa pilihan host (GP4), seri → huruf grup.
    final champions = [0, 1, 2]..sort((a, b) => bySeed(a, b, 0));

    // Kandidat: per himpunan seri, lihat posisinya terhadap batas 2 | 3.
    const slots = 2;
    final order = [0, 1, 2]..sort((a, b) => bySeed(a, b, 2));
    final rows = <SeedRow>[];
    final sure = <String>[];
    WildcardPick? pick;
    var start = 0;
    while (start < order.length) {
      var end = start + 1;
      while (end < order.length &&
          comparePlayoffSeed(standings[perGroup[order[start]][2]]!, standings[perGroup[order[end]][2]]!, method) == 0) {
        end++;
      }
      final tied = order.sublist(start, end);
      final crosses = start < slots && end > slots;
      if (crosses) {
        pick = WildcardPick(need: slots - start, candidates: [for (final g in tied) perGroup[g][2]]);
      }
      for (final g in tied) {
        final qualified = !crosses && end <= slots;
        if (qualified) sure.add(perGroup[g][2]);
        rows.add(row(g, 2, qualified));
      }
      start = end;
    }
    return SeedingPlan._(groupSlots, champions, sure, [for (final g in champions) row(g, 0, true)], rows, pick);
  }
}
