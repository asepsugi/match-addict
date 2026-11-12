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

/// Isi poster Lengkap dari turnamen + baris Klasemen ([entries] = `standingEntriesProvider`, jadi nomornya sama
/// dengan Klasemen): semua yang bernomor. Tiap baris = nilai metode + selisih, dua angka penentu nomornya ("42 poin ·
/// +12", "100% · +12"). Turnamen bernama: nama menggantikan baris kecil "olahraga · mode · tanggal" dan tanggalnya
/// pindah ke ringkasan, sama dengan baris akhir caption. Ringkas = [podiumPosterData], bukan fungsi ini.
///
/// Sparing ([clubResult] + [clubEntries] = `clubScoreProvider` + `clubStandingEntriesProvider`, nomor per klub sama
/// dengan Klasemen): skor klub di bawah judul, lalu daftar per klub (13s–13w).
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
  final rows = [
    for (final e in entries)
      if (e.position != null) e,
  ];
  final date = _dateOf(active);
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
  SharePosterClub club(ClubStandings g) => SharePosterClub(
    name: g.club.name,
    rows: [
      for (final e in g.entries)
        if (e.position != null) row(e),
    ],
  );

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
    complete: true,
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

  final state = isFinal ? 'akhir' : 'sementara';
  final date = _dateOf(active);
  final title = config.name ?? 'Klasemen $state';
  final subtitle = config.name != null
      ? 'Klasemen $state · $date'
      : '${config.sport.label} · ${config.mode.label} · $date';
  final facts = podiumFacts(active: active, rows: allRows, isFinal: isFinal);

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

  PodiumBlockData blockOf(PodiumBlock b) => PodiumBlockData(level: b.level, face: b.face, balls: b.balls);

  PodiumPosterData of({
    List<PodiumBlockData> blocks = const [],
    bool wide = false,
    List<PodiumRowData> rows = const [],
    bool pairSize = false,
  }) => PodiumPosterData(
    sport: config.sport,
    title: title,
    subtitle: subtitle,
    blocks: blocks,
    wide: wide,
    rows: rows,
    pairSize: pairSize,
    facts: facts,
  );

  return switch (podium) {
    PodiumEmpty() => of(),
    PodiumSteps() => of(
      blocks: [for (final b in podium.blocks) blockOf(b)],
      rows: [for (final e in podium.rows) rowOf(e)],
      pairSize: podium.pairSize,
    ),
    PodiumCrowd() => () {
      final (value, detail) = valueOf(podium.rows.first);
      final noun = rowNoun(active, allRows);
      return of(
        blocks: [blockOf(podium.block)],
        wide: true,
        rows: [
          PodiumRowData(
            badge: '1',
            gold: true,
            names: [
              [podium.rows.length, ?noun].join(' '),
            ],
            value: value,
            detail: detail,
          ),
        ],
      );
    }(),
    PodiumClubs() => of(
      blocks: [for (final b in podium.blocks) blockOf(b)],
      rows: [
        for (final (i, t) in [podium.result.first, podium.result.second].indexed)
          PodiumRowData(
            badge: t.winsLabel,
            hash: false,
            gold: podium.blocks[i].gold,
            names: [t.club.name],
            value: '${t.totalPoint}',
            detail: '${podium.result.unit} · ${t.diffLabel}',
          ),
      ],
    ),
  };
}
