import 'dart:math';

import '../../models/models.dart';
import '../schedule/group_stage.dart';

/// Draf pembagian pasangan ke grup di layar Grup (19r–19y, logic.md §18.14). Immutable seperti `PairDraft`; layar
/// menyimpannya dan menggantinya tiap ketukan. Tanpa Urungkan: tiap langkah dibalik dengan satu ketukan.
class GroupDraft {
  /// Semua pasangan turnamen, urut daftar Pasangan (urutan "belum masuk grup").
  final List<Pair> pairs;

  /// 2 atau 4.
  final int groupCount;

  /// Id pasangan per grup, urut masuk = urutan round-robin grup (19s).
  final List<List<String>> groups;

  /// Ukuran yang ditetapkan app per grup (G4).
  final List<int> targets;

  GroupDraft(this.pairs, this.groupCount, {List<List<String>>? groups})
    : groups = groups ?? [for (var g = 0; g < groupCount; g++) <String>[]],
      targets = GroupStage.sizes(pairs.length, groupCount);

  Pair pairById(String id) => pairs.firstWhere((p) => p.id == id);

  /// Pasangan yang belum masuk grup mana pun, urut daftar pasangan.
  List<Pair> get unassigned {
    final placed = {for (final g in groups) ...g};
    return [
      for (final p in pairs)
        if (!placed.contains(p.id)) p,
    ];
  }

  /// Indeks grup pasangan ini, null = belum masuk grup.
  int? groupOf(String pairId) {
    for (final (g, ids) in groups.indexed) {
      if (ids.contains(pairId)) return g;
    }
    return null;
  }

  /// Grup [g] kelebihan: angkanya clay (19v).
  bool isOver(int g) => groups[g].length > targets[g];

  /// "n dari t"; penuh = "t pasangan".
  String countLabel(int g) {
    final n = groups[g].length;
    return n == targets[g] ? '$n pasangan' : '$n dari ${targets[g]}';
  }

  /// Ketuk huruf [g] pada pasangan [pairId]: huruf yang sama mengembalikannya ke "belum masuk grup", selain itu
  /// pindah ke akhir grup [g].
  GroupDraft tap(String pairId, int g) {
    final same = groups[g].contains(pairId);
    return GroupDraft(
      pairs,
      groupCount,
      groups: [
        for (final (i, ids) in groups.indexed)
          [
            for (final id in ids)
              if (id != pairId) id,
            if (i == g && !same) pairId,
          ],
      ],
    );
  }

  /// Alasan tombol Buat jadwal menunggu, null = aktif (G4, AC-G2). Kelebihan dulu (grup pertama urut huruf), lalu
  /// yang tanpa grup. Null ⇔ semua masuk dan ukuran tiap grup sama dengan yang ditetapkan.
  String? get blockReason {
    for (var g = 0; g < groupCount; g++) {
      if (isOver(g)) return 'Grup ${GroupKnockout.letter(g)} lebih ${groups[g].length - targets[g]} pasangan';
    }
    final k = unassigned.length;
    return k > 0 ? '$k pasangan tanpa grup' : null;
  }

  /// Acak (GU2): semua pasangan diacak, A diisi sampai target, lalu B, dan seterusnya.
  GroupDraft random(Random rng) {
    final ids = [for (final p in pairs) p.id]..shuffle(rng);
    var from = 0;
    return GroupDraft(pairs, groupCount, groups: [for (final t in targets) ids.sublist(from, from += t)]);
  }

  /// Pindah ke Manual mengosongkan semua grup tanpa konfirmasi.
  GroupDraft cleared() => GroupDraft(pairs, groupCount);

  /// Kembali ke Pasangan lalu Lanjut lagi (19o): pasangan yang anggotanya sama (himpunan id pemain, bukan id pasangan)
  /// tetap di grup dan posisinya; yang berubah keluar dari grupnya. Asumsi designer.
  GroupDraft reconcile(List<Pair> newPairs) {
    String key(Pair p) => ([...p.playerIds]..sort()).join('|');
    final byKey = {for (final p in newPairs) key(p): p.id};
    return GroupDraft(
      newPairs,
      groupCount,
      groups: [
        for (final ids in groups)
          [
            for (final id in ids)
              if (byKey[key(pairById(id))] case final newId?) newId,
          ],
      ],
    );
  }
}
