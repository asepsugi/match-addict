import '../../models/models.dart';
import '../../services/ranking/ranking_calculator.dart';
import '../../services/share/result_text_builder.dart';
import 'widgets/share_poster.dart';

/// Jumlah baris poster Ringkas.
const shareSummaryCount = 5;

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

/// Isi poster Bagikan dari turnamen + baris Klasemen ([entries] = `standingEntriesProvider`, jadi nomornya
/// sama dengan Klasemen). Ringkas = 5 teratas + "+n lainnya"; Lengkap = semua yang bernomor. Fixed
/// menghitung "pasangan". Tiap baris = nilai metode + selisih, dua angka penentu nomornya ("42 poin · +12",
/// "100% · +12"). Turnamen bernama: nama menggantikan baris kecil
/// "olahraga · mode · tanggal" dan tanggalnya pindah ke ringkasan, sama dengan baris akhir caption.
SharePosterData sharePosterData({
  required ActiveTournament active,
  required List<StandingEntry> entries,
  required RankingMethod method,
  required ShareFormat format,
  required bool isFinal,
}) {
  final config = active.config;
  final fixed = config.mode == PartnerMode.fixed;
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

  return SharePosterData(
    sport: config.sport,
    eyebrow: config.name ?? '${config.sport.label} · ${config.mode.label} · $date',
    isFinal: isFinal,
    rows: [for (final e in rows) row(e)],
    summary: [
      '${active.playedRoundCount} round',
      '${active.playedMatchCount} match',
      if (wo > 0) '$wo WO',
      if (config.name != null) date,
    ].join(' · '),
    more: format == ShareFormat.ringkas && hidden > 0 ? '+$hidden ${fixed ? 'pasangan' : 'pemain'} lainnya' : null,
    complete: format == ShareFormat.lengkap,
  );
}
