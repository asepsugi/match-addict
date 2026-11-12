import '../../models/models.dart';
import '../ranking/club_score.dart';
import '../ranking/ranking_calculator.dart';

/// Poster podium Bagikan Ringkas (PRD §5.9, keputusan 61–65, 68, 69, 72–74; logic.md §16). Dart murni: tidak
/// membaca jam, provider, atau metode Klasemen (metode sudah tercermin di `StandingEntry.position`).
sealed class Podium {
  const Podium();

  /// [entries] = `standingEntriesProvider` apa adanya. [clubs] != null → Sparing dan [entries] diabaikan.
  factory Podium.of({required List<StandingEntry> entries, ClubResult? clubs}) {
    if (clubs != null) return _ofClubs(clubs);

    final ranked = entries.where((e) => e.position != null).toList();
    if (ranked.isEmpty) return const PodiumEmpty();

    // Calon = awalan baris bernomor sampai nomor baris ke-3 (termasuk yang senomor dengannya).
    final cutoff = ranked[(ranked.length < 3 ? ranked.length : 3) - 1].position!;
    var rows = ranked.where((e) => e.position! <= cutoff).toList();
    if (rows.length > 4) {
      // Kelompok nomor yang utuh: satu nomor tidak pernah terpotong (65).
      rows = rows.where((e) => e.position! < cutoff).toList();
      if (rows.isEmpty) return PodiumCrowd(ranked.where((e) => e.position == 1).toList());
    }
    return PodiumSteps(rows);
  }

  static Podium _ofClubs(ClubResult r) {
    // Belum ada match selesai/WO: lapangan kosong, bukan dua blok emas "0" (keputusan 72).
    if (r.first.halfWins + r.second.halfWins == 0) return const PodiumEmpty();
    // `lead` sudah memutuskan seri lewat Total Point; jangan dihitung ulang di sini.
    final lead = r.lead;
    return PodiumClubs(r, [
      PodiumBlock(level: lead == ClubLead.second ? 2 : 1, face: r.first.winsLabel, balls: 0),
      PodiumBlock(level: lead == ClubLead.first ? 2 : 1, face: r.second.winsLabel, balls: 0),
    ]);
  }
}

/// 69: tidak ada yang bernomor (Sparing: skor klub 0 – 0). Panel hanya wordmark + fakta.
final class PodiumEmpty extends Podium {
  const PodiumEmpty();
}

/// 65: 1–4 baris anak tangga, urut Klasemen.
final class PodiumSteps extends Podium {
  /// Baris yang naik, urut Klasemen (baris atas panel = baris pertama).
  final List<StandingEntry> rows;

  /// Blok kiri → kanan. Tinggi/emas ikut nomor, urutan slot ikut indeks baris (64): #1 #1 #2 → slot 1 · 1 · 2.
  final List<PodiumBlock> blocks;

  PodiumSteps(this.rows)
    : assert(rows.isNotEmpty && rows.length <= 4),
      blocks = [for (final i in _slotOrder[rows.length - 1]) _blockOf(rows[i])];

  /// `.duo`: ada baris berisi dua nama; tinggi baris panel dan blok ikut untuk semua baris (18e, 18l).
  bool get pairSize => rows.any((e) => e.players.length == 2);

  static const _slotOrder = [
    [0],
    [0, 1],
    [1, 0, 2],
    [1, 0, 2, 3],
  ];

  static PodiumBlock _blockOf(StandingEntry e) =>
      PodiumBlock(level: e.position!, face: '${e.position}', balls: e.players.length);
}

/// 68: baris #1 lebih dari empat; satu blok emas lebar tanpa bola, satu baris panel.
final class PodiumCrowd extends Podium {
  /// Semua baris #1, urut Klasemen. Nilai dan selisih identik (compare = 0), jadi ambil dari baris pertama.
  final List<StandingEntry> rows;

  const PodiumCrowd(this.rows);

  PodiumBlock get block => const PodiumBlock(level: 1, face: '1', balls: 0);
}

/// Sparing: dua blok klub, klub pertama selalu kiri dan baris atas (juga kalau kalah).
final class PodiumClubs extends Podium {
  final ClubResult result;

  /// [klub pertama, klub kedua].
  final List<PodiumBlock> blocks;

  const PodiumClubs(this.result, this.blocks);
}

class PodiumBlock {
  /// 1–3; menentukan tinggi dan warna.
  final int level;

  /// Angka di muka blok.
  final String face;

  final int balls;

  const PodiumBlock({required this.level, required this.face, required this.balls});

  bool get gold => level == 1;
}

/// Kata untuk baris klasemen: "pasangan" (Fixed), "pemain" (Mixed/Mexicano), atau null kalau Klasemen Fixed campuran
/// karena pasangan diatur ulang sebelum round tambahan (09g) — "+5 lainnya", "Semua 10".
String? rowNoun(ActiveTournament active, List<StandingEntry> rows) {
  if (active.config.mode.isEndless) return 'pemain';
  return rows.every((e) => e.players.length == 2) ? 'pasangan' : null;
}

/// Baris fakta poster (63, 71): bagian digabung " · ", tanpa tanggal (tanggal ada di baris kecil kepala).
/// [rows] = semua baris Klasemen (Sparing: baris kedua klub digabung). [isFinal] dari layar
/// (`active.isFinal(clock())`); service tidak membaca jam.
String podiumFacts({required ActiveTournament active, required List<StandingEntry> rows, required bool isFinal}) {
  final config = active.config;
  final noun = rowNoun(active, rows);
  final wo = active.matches.where((m) => m.status == MatchStatus.wo).length;
  return [
    if (config.name != null) config.sport.label,
    // Fixed campuran tidak punya kata yang benar: bagian dihilangkan (71).
    if (noun != null) '${rows.length} $noun',
    if (isFinal) ...[
      '${active.playedRoundCount} round',
      '${active.playedMatchCount} match',
    ] else ...[
      'R${active.currentRound}',
      '${active.playedMatchCount} dari ${active.matches.length} match',
    ],
    if (wo > 0) '$wo WO',
  ].join(' · ');
}
