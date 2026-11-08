import '../../models/models.dart';
import '../../services/ranking/club_score.dart';
import '../../services/ranking/ranking_calculator.dart';
import '../../services/share/result_text_builder.dart';
import 'widgets/share_poster.dart';

/// Jumlah baris poster Ringkas.
const shareSummaryCount = 5;

/// Jumlah baris tiap klub di poster Ringkas sparing (13q, dikonfirmasi host).
const shareClubSummaryCount = 3;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Kata untuk baris klasemen: "pasangan" (Fixed), "pemain" (Mixed), atau null kalau Klasemen Fixed campuran karena
/// pasangan diatur ulang sebelum round tambahan (09g) — "+5 lainnya", "Semua 10".
String? shareRowNoun(ActiveTournament active, List<StandingEntry> entries) {
  if (active.config.mode == PartnerMode.mixed) return 'pemain';
  return entries.every((e) => e.players.length == 2) ? 'pasangan' : null;
}

/// Isi poster Bagikan dari turnamen + baris Klasemen ([entries] = `standingEntriesProvider`, jadi nomornya
/// sama dengan Klasemen). Ringkas = 5 teratas + "+n lainnya"; Lengkap = semua yang bernomor. Fixed
/// menghitung "pasangan". Tiap baris = nilai metode + selisih, dua angka penentu nomornya ("42 poin · +12",
/// "100% · +12"). Turnamen bernama: nama menggantikan baris kecil
/// "olahraga · mode · tanggal" dan tanggalnya pindah ke ringkasan, sama dengan baris akhir caption.
///
/// Sparing ([clubResult] + [clubEntries] = `clubScoreProvider` + `clubStandingEntriesProvider`, nomor per klub sama
/// dengan Klasemen): skor klub di bawah judul, lalu daftar per klub; Ringkas = 3 teratas tiap klub dengan "+n
/// pasangan lainnya" di label klubnya, bukan di kaki (13q–13w).
SharePosterData sharePosterData({
  required ActiveTournament active,
  required List<StandingEntry> entries,
  required RankingMethod method,
  required ShareFormat format,
  required bool isFinal,
  ClubResult? clubResult,
  List<ClubStandings> clubEntries = const [],
}) {
  final config = active.config;
  final unit = config.format.unit;
  final ranked = [for (final e in entries) if (e.position != null) e];
  final rows = format == ShareFormat.ringkas ? ranked.take(shareSummaryCount).toList() : ranked;
  final hidden = entries.length - rows.length;
  final created = active.tournament.createdAt;
  final date = '${created.day} ${_months[created.month - 1]} ${created.year}';
  final wo = active.matches.where((m) => m.status == MatchStatus.wo).length;

  SharePosterRow row(StandingEntry e) {
    final s = e.standing;
    final total = method == RankingMethod.totalGames;
    return SharePosterRow(
      position: e.position!,
      names: [for (final p in e.players) p.name],
      value: total ? '${s.totalPoint}' : '${s.winPercent.round()}%',
      detail: total ? unit : null,
      diff: s.diffLabel,
    );
  }

  final sparing = clubResult != null && clubEntries.isNotEmpty;
  SharePosterClub club(ClubStandings g) {
    final ranked = [for (final e in g.entries) if (e.position != null) e];
    final shown = format == ShareFormat.ringkas ? ranked.take(shareClubSummaryCount).toList() : ranked;
    final hidden = g.entries.length - shown.length;
    return SharePosterClub(
      name: g.club.name,
      rows: [for (final e in shown) row(e)],
      more: format == ShareFormat.ringkas && hidden > 0
          ? ['+$hidden', ?shareRowNoun(active, g.entries), 'lainnya'].join(' ')
          : null,
    );
  }

  return SharePosterData(
    sport: config.sport,
    eyebrow: config.name ?? '${config.sport.label} · ${config.mode.label} · $date',
    isFinal: isFinal,
    rows: sparing ? const [] : [for (final e in rows) row(e)],
    clubScore: sparing
        ? [
            for (final t in [clubResult.first, clubResult.second])
              SharePosterClubScore(name: t.club.name, detail: clubResult.detailLabel(t), score: t.winsLabel),
          ]
        : null,
    clubs: sparing ? [for (final g in clubEntries) club(g)] : null,
    summary: [
      '${active.playedRoundCount} round',
      '${active.playedMatchCount} match',
      if (wo > 0) '$wo WO',
      if (config.name != null) date,
    ].join(' · '),
    more: !sparing && format == ShareFormat.ringkas && hidden > 0
        ? ['+$hidden', ?shareRowNoun(active, entries), 'lainnya'].join(' ')
        : null,
    complete: format == ShareFormat.lengkap,
  );
}
