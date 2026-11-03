import '../../models/models.dart';
import 'player_name_parser.dart';

/// Atur pasangan sebelum round tambahan Fixed (04f–04h, keputusan host 2026-11-03). Mulai dari pasangan sekarang;
/// "Pisah" mengosongkan slot pasangan itu dan kedua pemainnya jadi belum berpasangan. Pasangan baru mengisi slot kosong
/// pertama, jadi pasangan lain tetap di urutannya dan round tambahan (round-robin yang diulang dari awal) tetap
/// mempertemukan lawan yang sama kecuali untuk pasangan yang berubah. Pemain yang tidak dipasangkan tidak ikut round
/// tambahan; skornya tetap. Immutable: layar menyimpan riwayatnya untuk "Urungkan".
class PairDraft {
  /// Slot pasangan berurutan; null = dipisah dan belum diisi lagi.
  final List<Pair?> slots;

  /// Belum berpasangan, urutan masuknya: pemain yang tidak ikut putaran sebelumnya, anggota pasangan yang dipisah,
  /// lalu pemain baru.
  final List<Player> unpaired;

  /// Pemain pengganti yang diketik di layar ini; baru masuk `config.players` saat round tambahan dibuat.
  final List<Player> added;

  /// `config.players` turnamen, termasuk yang tidak ikut lagi.
  final List<Player> roster;

  const PairDraft._(this.slots, this.unpaired, this.added, this.roster);

  factory PairDraft.of(TournamentConfig config) {
    final pairs = config.fixedPairs ?? const <Pair>[];
    final paired = {for (final p in pairs) ...p.playerIds};
    return PairDraft._(pairs, [
      for (final p in config.players)
        if (!paired.contains(p.id)) p,
    ], const [], config.players);
  }

  List<Pair> get pairs => [
    for (final p in slots)
      if (p != null) p,
  ];

  /// Yang dipasangkan + yang belum berpasangan; batas 30 pemain berlaku untuk mereka.
  int get playerCount => pairs.length * 2 + unpaired.length;

  String nameOf(String playerId) => [...roster, ...added].firstWhere((p) => p.id == playerId).name;

  static String _key(Pair p) => ([...p.playerIds]..sort()).join('|');

  /// Pasangan yang tidak ada di [original] (pasangan sekarang) — "1 baru" di baris Pasangan (04h).
  int newPairsFrom(List<Pair> original) {
    final before = {for (final p in original) _key(p)};
    return pairs.where((p) => !before.contains(_key(p))).length;
  }

  /// Berbeda dari [original]: ada pasangan yang dipisah atau dibentuk.
  bool changedFrom(List<Pair> original) => pairs.length != original.length || newPairsFrom(original) > 0;

  /// Pemain baru yang dipasangkan — yang diketik tapi tidak dipasangkan tidak ikut masuk turnamen.
  List<Player> get addedInPairs {
    final paired = {for (final p in pairs) ...p.playerIds};
    return [
      for (final p in added)
        if (paired.contains(p.id)) p,
    ];
  }

  PairDraft split(Pair pair) => PairDraft._(
    [for (final p in slots) p?.id == pair.id ? null : p],
    [
      ...unpaired,
      for (final id in pair.playerIds) [...roster, ...added].firstWhere((p) => p.id == id),
    ],
    added,
    roster,
  );

  /// [a] dan [b] (dua-duanya belum berpasangan) jadi pasangan baru dengan [id].
  PairDraft pair(Player a, Player b, {required String id}) {
    final pair = Pair(id: id, player1Id: a.id, player2Id: b.id);
    final free = slots.indexOf(null);
    return PairDraft._(
      free < 0 ? [...slots, pair] : [for (final (i, p) in slots.indexed) i == free ? pair : p],
      [
        for (final p in unpaired)
          if (p.id != a.id && p.id != b.id) p,
      ],
      added,
      roster,
    );
  }

  /// Pemain pengganti dari ketikan [raw] dengan [id]: draft baru, atau pesan error (nama kosong, sudah ada, lewat batas).
  ({PairDraft? draft, String? error}) add(String raw, {required String id}) {
    final name = PlayerNameParser.parse(raw).names.firstOrNull;
    if (name == null) return (draft: null, error: 'Nama tidak boleh kosong');
    final existing = [...roster, ...added].where((p) => p.name.toLowerCase() == name.toLowerCase()).firstOrNull;
    // Nama yang tertulis di daftar, bukan ketikan host ("andi p" → "Andi P sudah ada"), sama dengan Kelola pemain.
    if (existing != null) return (draft: null, error: '${existing.name} sudah ada di daftar');
    const limit = TournamentConfig.maxPlayers;
    if (playerCount >= limit) return (draft: null, error: 'Maksimal $limit pemain');
    final player = Player(id: id, name: name);
    return (draft: PairDraft._(slots, [...unpaired, player], [...added, player], roster), error: null);
  }
}
