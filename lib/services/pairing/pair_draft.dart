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

  /// Sparing: dua klub turnamen (null = turnamen biasa, semua aturan klub di bawah tidak berlaku).
  final List<Club>? clubs;

  /// Sparing: klub tiap slot, sejajar [slots]. Slot yang dikosongkan tetap milik klubnya, supaya pasangan baru klub itu
  /// mengisi slot klubnya sendiri: urutan pasangan per klub = indeks generator, jadi lawan pasangan lain tidak bergeser
  /// (14o). Kosong di turnamen biasa.
  final List<String?> _slotClubs;

  const PairDraft._(this.slots, this.unpaired, this.added, this.roster, [this.clubs, this._slotClubs = const []]);

  factory PairDraft.of(TournamentConfig config) {
    final pairs = config.fixedPairs ?? const <Pair>[];
    final paired = {for (final p in pairs) ...p.playerIds};
    return PairDraft._(
      pairs,
      [
        for (final p in config.players)
          if (!paired.contains(p.id)) p,
      ],
      const [],
      config.players,
      config.clubs,
      config.isSparing ? [for (final p in pairs) config.clubOfPair(p)?.id] : const [],
    );
  }

  bool get isSparing => clubs != null;

  Player? _player(String id) => [...roster, ...added].where((p) => p.id == id).firstOrNull;

  /// Sparing: pasangan klub [clubId] urut slot (= urutan yang dioper ke generator, 14o).
  List<Pair> pairsOf(String clubId) => [
    for (final p in pairs)
      if (_player(p.player1Id)?.clubId == clubId) p,
  ];

  /// Sparing: pemain klub [clubId] yang belum berpasangan (chip bagian klub itu).
  List<Player> unpairedOf(String clubId) => [
    for (final p in unpaired)
      if (p.clubId == clubId) p,
  ];

  /// Simpan Atur pasangan sparing mati "· minimal 1 pasangan tiap klub" selama ini false (logic.md §13.5). Selalu true
  /// di turnamen biasa.
  bool get hasPairEachClub => clubs?.every((c) => pairsOf(c.id).isNotEmpty) ?? true;

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
    clubs,
    _slotClubs,
  );

  /// [a] dan [b] (dua-duanya belum berpasangan) jadi pasangan baru dengan [id]. Sparing: hanya sesama klub (S2; layar
  /// mencegahnya, 14b), dan slot yang diisi = slot kosong pertama klub itu; tanpa slot kosong, pasangan masuk paling
  /// belakang (= pasangan terakhir klubnya).
  PairDraft pair(Player a, Player b, {required String id}) {
    if (isSparing && a.clubId != b.clubId) throw ArgumentError('Pasangan sparing harus sesama klub');
    final pair = Pair(id: id, player1Id: a.id, player2Id: b.id);
    final free = isSparing
        ? [for (final (i, p) in slots.indexed) p == null && _slotClubs[i] == a.clubId].indexOf(true)
        : slots.indexOf(null);
    return PairDraft._(
      free < 0 ? [...slots, pair] : [for (final (i, p) in slots.indexed) i == free ? pair : p],
      [
        for (final p in unpaired)
          if (p.id != a.id && p.id != b.id) p,
      ],
      added,
      roster,
      clubs,
      isSparing && free < 0 ? [..._slotClubs, a.clubId] : _slotClubs,
    );
  }

  /// Pemain pengganti dari ketikan [raw] dengan [id]: draft baru, atau pesan error (nama kosong, sudah ada, lewat batas).
  /// Sparing: [clubId] = klub bagian tempat nama diketik, wajib (S1, K8: pemain tidak pernah pindah klub); nama unik
  /// terhadap kedua klub karena [roster] memuat semuanya.
  ({PairDraft? draft, String? error}) add(String raw, {required String id, String? clubId}) {
    // Pemain sparing tanpa klub (atau pemain biasa berklub) membuat simpanan tidak terbaca: kesalahan pemanggil.
    if (isSparing ? !clubs!.any((c) => c.id == clubId) : clubId != null) {
      throw ArgumentError.value(clubId, 'clubId', 'Klub tidak dikenal');
    }
    final name = PlayerNameParser.parse(raw).names.firstOrNull;
    if (name == null) return (draft: null, error: 'Nama tidak boleh kosong');
    final existing = [...roster, ...added].where((p) => p.name.toLowerCase() == name.toLowerCase()).firstOrNull;
    // Nama yang tertulis di daftar, bukan ketikan host ("andi p" → "Andi P sudah ada"), sama dengan Kelola pemain.
    if (existing != null) return (draft: null, error: '${existing.name} sudah ada di daftar');
    const limit = TournamentConfig.maxPlayers;
    if (playerCount >= limit) return (draft: null, error: 'Maksimal $limit pemain');
    final player = Player(id: id, name: name, clubId: clubId);
    return (
      draft: PairDraft._(slots, [...unpaired, player], [...added, player], roster, clubs, _slotClubs),
      error: null,
    );
  }
}
