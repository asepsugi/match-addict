import '../../models/models.dart';
import '../../services/ranking/club_score.dart';
import '../../services/ranking/ranking_calculator.dart';
import '../../services/share/podium.dart';
import 'widgets/podium_poster.dart';
import 'widgets/share_poster.dart';

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'Mei', 'Jun', 'Jul', 'Agu', 'Sep', 'Okt', 'Nov', 'Des'];

String _dateOf(ActiveTournament active) {
  final created = active.tournament.createdAt;
  return '${created.day} ${_months[created.month - 1]} ${created.year}';
}

/// Kepala kedua poster (16.2 "Kepala"): bernama → nama + "Klasemen akhir|sementara · {tanggal}"; tanpa nama →
/// "Klasemen akhir|sementara" + "{olahraga} · {mode} · {tanggal}".
(String, String) _headOf(ActiveTournament active, bool isFinal) {
  final config = active.config;
  final state = isFinal ? 'akhir' : 'sementara';
  final date = _dateOf(active);
  return (
    config.name ?? 'Klasemen $state',
    config.name != null ? 'Klasemen $state · $date' : '${config.sport.label} · ${config.mode.label} · $date',
  );
}

/// Blok podium dari [Podium.of] — satu pemetaan untuk podium Ringkas dan podium mini Lengkap (logic.md §17.2):
/// anak tangga per slot, Kerumunan satu blok lebar ([wide]), dua blok skor klub, Kosong tanpa blok. [pairSize] =
/// ukuran bola (dan di Ringkas tinggi baris/blok) pasangan.
({List<PodiumBlockData> blocks, bool wide, bool pairSize}) podiumBlocks(Podium podium) {
  PodiumBlockData blockOf(PodiumBlock b) => PodiumBlockData(level: b.level, face: b.face, balls: b.balls);
  return switch (podium) {
    PodiumEmpty() => (blocks: const <PodiumBlockData>[], wide: false, pairSize: false),
    PodiumSteps() => (blocks: [for (final b in podium.blocks) blockOf(b)], wide: false, pairSize: podium.pairSize),
    PodiumCrowd() => (blocks: [blockOf(podium.block)], wide: true, pairSize: false),
    PodiumClubs() => (blocks: [for (final b in podium.blocks) blockOf(b)], wide: false, pairSize: false),
  };
}

/// Isi poster Lengkap (logic.md §17.1, 17.9) dari turnamen + baris Klasemen ([entries] = `standingEntriesProvider`,
/// jadi nomornya sama dengan Klasemen): kepala, podium mini, dan fakta lewat helper yang sama dengan
/// [podiumPosterData]; panel = semua baris bernomor, nilai metode + selisih ("42" + "poin · +12", "100%" + "· +12").
///
/// Sparing ([clubResult] + [clubEntries] = `clubScoreProvider` + `clubStandingEntriesProvider`, nomor per klub sama
/// dengan Klasemen): per klub kepala `.lclub` (nama + `ClubResult.detailLabel`, tanpa skor) lalu barisnya. Kosong
/// (`PodiumEmpty`, juga Sparing 0 – 0, keputusan 87, 89): tanpa baris dan tanpa kepala klub, panel hanya kaki.
SharePosterData sharePosterData({
  required ActiveTournament active,
  required List<StandingEntry> entries,
  required RankingMethod method,
  required bool isFinal,
  ClubResult? clubResult,
  List<ClubStandings> clubEntries = const [],
}) {
  final config = active.config;
  final unit = config.format.unit;
  final sparing = clubResult != null && clubEntries.isNotEmpty;
  final allRows = sparing ? [for (final g in clubEntries) ...g.entries] : entries;
  final podium = Podium.of(entries: entries, clubs: sparing ? clubResult : null);
  final empty = podium is PodiumEmpty;
  final (title, subtitle) = _headOf(active, isFinal);
  final mini = podiumBlocks(podium);

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

  List<SharePosterRow> ranked(List<StandingEntry> list) => [
    for (final e in list)
      if (e.position != null) row(e),
  ];

  SharePosterClub club(ClubStandings g) {
    final tally = [clubResult!.first, clubResult.second].firstWhere((t) => t.club.id == g.club.id);
    return SharePosterClub(name: g.club.name, detail: clubResult.detailLabel(tally), rows: ranked(g.entries));
  }

  return SharePosterData(
    sport: config.sport,
    title: title,
    subtitle: subtitle,
    blocks: mini.blocks,
    wide: mini.wide,
    pairBalls: mini.pairSize,
    endless: config.mode.isEndless,
    rows: sparing || empty ? const [] : ranked(entries),
    clubs: sparing && !empty ? [for (final g in clubEntries) club(g)] : null,
    facts: podiumFacts(active: active, rows: allRows, isFinal: isFinal),
  );
}

/// Isi poster podium Ringkas: hanya memetakan hasil [Podium.of] dan [podiumFacts] ke teks (logika siapa naik, nomor,
/// dan fakta ada di `services/share/podium.dart`). [entries] = `standingEntriesProvider`; Sparing ([clubResult] +
/// [clubEntries]) memakai skor klub dan fakta dari baris kedua klub digabung.
PodiumPosterData podiumPosterData({
  required ActiveTournament active,
  required List<StandingEntry> entries,
  required RankingMethod method,
  required bool isFinal,
  ClubResult? clubResult,
  List<ClubStandings> clubEntries = const [],
}) {
  final config = active.config;
  final sparing = clubResult != null && clubEntries.isNotEmpty;
  // Semua baris Klasemen (juga "Belum main"): dasar kata dan jumlah di fakta dan di baris Kerumunan.
  final allRows = sparing ? [for (final g in clubEntries) ...g.entries] : entries;
  final podium = Podium.of(entries: entries, clubs: sparing ? clubResult : null);
  final (title, subtitle) = _headOf(active, isFinal);
  final facts = podiumFacts(active: active, rows: allRows, isFinal: isFinal);
  final mini = podiumBlocks(podium);

  // Nilai metode + selisih dengan satuan (63): "42" + "poin · +12", "100%" + "· +19".
  final total = method == RankingMethod.totalGames;
  (String, String) valueOf(StandingEntry e) {
    final s = e.standing;
    return total
        ? ('${s.totalPoint}', '${config.format.unit} · ${s.diffLabel}')
        : ('${s.winPercent.round()}%', '· ${s.diffLabel}');
  }

  PodiumRowData rowOf(StandingEntry e) {
    final (value, detail) = valueOf(e);
    return PodiumRowData(
      badge: '${e.position}',
      gold: e.position == 1,
      names: [for (final p in e.players) p.name],
      value: value,
      detail: detail,
    );
  }

  // Blok, Kerumunan, dan ukuran pasangan dari [podiumBlocks]; di sini hanya baris panel per jenis podium.
  PodiumPosterData of([List<PodiumRowData> rows = const []]) => PodiumPosterData(
    sport: config.sport,
    title: title,
    subtitle: subtitle,
    blocks: mini.blocks,
    wide: mini.wide,
    rows: rows,
    pairSize: mini.pairSize,
    facts: facts,
  );

  return switch (podium) {
    PodiumEmpty() => of(),
    PodiumSteps() => of([for (final e in podium.rows) rowOf(e)]),
    PodiumCrowd() => () {
      final (value, detail) = valueOf(podium.rows.first);
      final noun = rowNoun(active, allRows);
      return of([
        PodiumRowData(
          badge: '1',
          gold: true,
          names: [
            [podium.rows.length, ?noun].join(' '),
          ],
          value: value,
          detail: detail,
        ),
      ]);
    }(),
    PodiumClubs() => of([
      for (final (i, t) in [podium.result.first, podium.result.second].indexed)
        PodiumRowData(
          badge: t.winsLabel,
          hash: false,
          gold: podium.blocks[i].gold,
          names: [t.club.name],
          value: '${t.totalPoint}',
          detail: '${podium.result.unit} · ${t.diffLabel}',
        ),
    ]),
  };
}
