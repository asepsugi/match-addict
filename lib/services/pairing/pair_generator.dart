import 'dart:math';

import '../../models/models.dart';

/// Pembuat pasangan untuk mode Fixed.
class PairGenerator {
  /// Acak pemain lalu pasangkan berurutan dua-dua.
  ///
  /// Kalau jumlah pemain ganjil, pemain terakhir tidak kebagian pasangan dan
  /// dikembalikan lewat [PairingDraft.unpaired] — host harus membereskannya
  /// sebelum pasangan bisa dikunci.
  static PairingDraft random(List<Player> players, {Random? random}) {
    final shuffled = [...players]..shuffle(random ?? Random());
    return fromOrder(shuffled);
  }

  /// Sparing (logic.md §13.5, 14a): acak di dalam tiap klub, klub pertama dulu, dengan satu [random] berurutan supaya
  /// satu "Acak ulang" mengacak keduanya. [PairingDraft.pairs] = pasangan klub pertama lalu klub kedua: urutan itu jadi
  /// `config.fixedPairs`, yaitu indeks generator (G1…, M1…). Sisa ganjil tinggal di klubnya sendiri (paling banyak satu
  /// per klub), jadi dua sisa beda klub tidak pernah dipasangkan (K12, AC-S3).
  static PairingDraft randomByClub(List<Player> players, List<Club> clubs, {Random? random}) {
    final rng = random ?? Random();
    final pairs = <Pair>[];
    final unpaired = <Player>[];
    for (final club in clubs) {
      final draft = PairGenerator.random([
        for (final p in players)
          if (p.clubId == club.id) p,
      ], random: rng);
      pairs.addAll(draft.pairs);
      unpaired.addAll(draft.unpaired);
    }
    return PairingDraft(pairs: pairs, unpaired: unpaired);
  }

  /// Manual: [a] lalu [b] jadi pasangan, atau null kalau beda klub (sparing, S2, AC-S4: layar memindah pilihan ke
  /// [b]). Turnamen biasa (dua-duanya tanpa klub) selalu jadi pasangan.
  static Pair? manual(Player a, Player b) =>
      sameClub(a, b) ? Pair(id: 'pair-${a.id}-${b.id}', player1Id: a.id, player2Id: b.id) : null;

  /// Aturan S2 (pasangan sesama klub), satu-satunya tempat ditulis; dipakai juga `PairDraft.canPair`.
  static bool sameClub(Player a, Player b) => a.clubId == b.clubId;

  /// Bentuk pasangan mengikuti urutan [players] apa adanya (dipakai mode manual).
  static PairingDraft fromOrder(List<Player> players) {
    final pairs = <Pair>[];
    for (var i = 0; i + 1 < players.length; i += 2) {
      pairs.add(
        Pair(id: 'pair-${players[i].id}-${players[i + 1].id}', player1Id: players[i].id, player2Id: players[i + 1].id),
      );
    }
    final unpaired = players.length.isOdd ? [players.last] : <Player>[];
    return PairingDraft(pairs: pairs, unpaired: unpaired);
  }
}

class PairingDraft {
  final List<Pair> pairs;
  final List<Player> unpaired;

  const PairingDraft({required this.pairs, required this.unpaired});

  static const empty = PairingDraft(pairs: [], unpaired: []);

  bool get isComplete => pairs.length >= 2 && unpaired.isEmpty;
}
