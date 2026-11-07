import '../../models/models.dart';
import 'ranking_calculator.dart';

/// Sparing: siapa unggul di skor klub.
enum ClubLead { first, second, draw }

/// Angka satu klub di skor klub (PRD §13.5, logic.md §13.7).
class ClubTally {
  final Club club;

  /// Menang dalam setengah-poin: menang = 2, seri = 1. Bulat supaya tidak ada pecahan desimal ("6½" = 13).
  final int halfWins;

  /// Game/poin sisi klub di setiap match + nilai menang WO klub (K11).
  final int totalPoint;

  /// Game sendiri − game lawan; WO tidak mengubahnya (sama dengan `gameDiff` pemain).
  final int diff;

  const ClubTally({required this.club, required this.halfWins, required this.totalPoint, required this.diff});

  /// "6", "6½", "½" — bukan "6,5".
  String get winsLabel {
    final whole = halfWins ~/ 2;
    if (halfWins.isEven) return '$whole';
    return whole == 0 ? '½' : '$whole½';
  }

  /// "+13", "−13", "0" — format yang sama dengan `PlayerStanding.diffLabel`.
  String get diffLabel => signedDiffLabel(diff);
}

/// Skor klub turnamen sparing: dua klub, klub pertama = `config.clubs[0]`. Dihitung di sini sekali; Jadwal, Klasemen,
/// Beranda, poster, caption, dan Live hanya membaca (tidak menghitung ulang di widget).
class ClubResult {
  final ClubTally first;
  final ClubTally second;

  /// Satuan Total Point mengikuti format: "game" / "poin".
  final String unit;

  const ClubResult({required this.first, required this.second, required this.unit});

  /// Menang → Total Point → sama semua = seri. Selisih hanya tampil, tidak menentukan (K2).
  ClubLead get lead {
    if (first.halfWins != second.halfWins) return first.halfWins > second.halfWins ? ClubLead.first : ClubLead.second;
    if (first.totalPoint != second.totalPoint) {
      return first.totalPoint > second.totalPoint ? ClubLead.first : ClubLead.second;
    }
    return ClubLead.draw;
  }

  /// Bola di papan skor klub (`.clubscore .cs.lead .w`): klub yang unggul, seri → keduanya. Belum ada hasil (0 – 0, frame
  /// 14m) → tidak ada bola. Satu sumber untuk Jadwal, Klasemen, Beranda, dan Live supaya tidak dipetakan di tiap layar.
  bool leads(ClubTally t) {
    assert(identical(t, first) || identical(t, second), 'ClubTally bukan milik ClubResult ini');
    // Tiap match selesai/WO menambah 2 setengah-poin ke salah satu atau kedua klub, jadi jumlah 0 = belum ada hasil.
    if (first.halfWins + second.halfWins == 0) return false;
    final l = lead;
    if (l == ClubLead.draw) return true;
    return identical(t, first) ? l == ClubLead.first : l == ClubLead.second;
  }

  /// Skor klub satu teks: "6 – 4", "6½ – 3½", "0 – 0" (Beranda, 14x).
  String get scoreLabel => '${first.winsLabel} – ${second.winsLabel}';

  /// Teks kecil di samping nama klub (`.clubscore .tp`): "56 game · +13".
  String detailLabel(ClubTally t) => '${t.totalPoint} $unit · ${t.diffLabel}';

  /// Null untuk turnamen biasa.
  static ClubResult? of(ActiveTournament active) {
    final config = active.config;
    final clubs = config.clubs;
    if (clubs == null || clubs.length != 2) return null;

    final half = [0, 0];
    final points = [0, 0];
    final diff = [0, 0];

    int? sideIndex(Pair pair) {
      final club = config.clubOfPlayer(pair.player1Id);
      final i = club == null ? -1 : clubs.indexWhere((c) => c.id == club.id);
      return i < 0 ? null : i;
    }

    final woValues = RankingCalculator.woWinnerValues(
      players: config.players,
      matches: active.matches,
      format: config.format,
    );

    for (final m in active.matches) {
      if (m.status != MatchStatus.done && m.status != MatchStatus.wo) continue;
      final i1 = sideIndex(m.pair1);
      final i2 = sideIndex(m.pair2);
      // Sparing selalu klub lawan klub (PRD §13). Match yang klubnya tidak jelas berarti ada bug di generator/pasangan:
      // debug dan test harus gagal supaya skor tidak salah diam-diam; rilis tidak boleh crash, jadi dilewati.
      assert(i1 != null && i2 != null && i1 != i2, 'Match ${m.id} bukan klub lawan klub');
      if (i1 == null || i2 == null || i1 == i2) continue;

      final winnerId = m.winnerPairId;
      if (m.status == MatchStatus.done) {
        half[i1] += winnerId == null ? 1 : (winnerId == m.pair1.id ? 2 : 0);
        half[i2] += winnerId == null ? 1 : (winnerId == m.pair2.id ? 2 : 0);
        points[i1] += m.pair1TotalGames;
        points[i2] += m.pair2TotalGames;
        diff[i1] += m.pair1TotalGames - m.pair2TotalGames;
        diff[i2] += m.pair2TotalGames - m.pair1TotalGames;
      } else {
        final firstWins = winnerId == m.pair1.id;
        final winner = firstWins ? m.pair1 : m.pair2;
        final w = firstWins ? i1 : i2;
        half[w] += 2;
        // Rata-rata nilai WO kedua pemenang, dibulatkan ,5 ke atas. Di Mixed Best of/Americano nilai keduanya bisa
        // beda; Fixed dan Race to selalu sama sehingga hasilnya = nilai pasangan.
        final a = woValues[winner.player1Id] ?? 0;
        final b = woValues[winner.player2Id] ?? 0;
        points[w] += (a + b + 1) ~/ 2;
      }
    }

    ClubTally tally(int i) => ClubTally(club: clubs[i], halfWins: half[i], totalPoint: points[i], diff: diff[i]);
    return ClubResult(first: tally(0), second: tally(1), unit: config.format.unit);
  }
}

/// Satu klub dengan baris klasemennya sendiri.
class ClubStandings {
  final Club club;

  /// Nomor mulai #1 di tiap klub; "Belum main" (position null) di belakang, di tabel klubnya (14p).
  final List<StandingEntry> entries;

  const ClubStandings({required this.club, required this.entries});
}

/// Klasemen per klub (logic.md §13.8): [standings] = hasil `RankingCalculator.rank` sekali untuk semua pemain,
/// lalu `standingEntries` per klub supaya nomor tidak pernah dihitung lintas klub. Urutan hasil = `config.clubs`.
/// Kosong untuk turnamen biasa.
List<ClubStandings> clubStandings({
  required ActiveTournament active,
  required List<PlayerStanding> standings,
  required RankingMethod method,
}) {
  final clubs = active.config.clubs;
  if (clubs == null) return const [];
  final fixed = active.config.mode == PartnerMode.fixed;
  final standingPairs = fixed ? active.standingPairs : const <Pair>[];

  return [
    for (final club in clubs)
      ClubStandings(
        club: club,
        entries: standingEntries(
          standings: [
            for (final s in standings)
              if (s.player.clubId == club.id) s,
          ],
          method: method,
          fixedPairs: fixed
              ? [
                  for (final pair in standingPairs)
                    if (active.config.clubOfPair(pair)?.id == club.id) pair,
                ]
              : null,
        ),
      ),
  ];
}
