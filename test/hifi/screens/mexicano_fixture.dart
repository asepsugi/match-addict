import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';

/// Turnamen Mexicano frame 16a–16g = contoh PRD 14B (logic.md §14.4): Padel, Americano 21, 15 menit, 10 pemain,
/// 2 court × 2 jam; id pemain = nama. Round dibuat oleh `generateMexicanoRound` dengan undian disuntik per round
/// (urutan daftar = urutan undian), bukan ditulis tangan, jadi fixture ikut menguji generatornya.
const mexicanoNames = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi', 'Indra', 'Joko'];

const _format = ScoreFormat(ScoringMethod.americano, 21);

/// Undian R1–R3 (id pemain urut undian). R3 tanpa Gita (keluar sebelum R3 dibuat, 16g).
const _draws = [
  mexicanoNames,
  ['Budi', 'Gita', 'Andi', 'Eko', 'Indra', 'Dewi', 'Fajar', 'Joko', 'Citra', 'Hadi'],
  ['Citra', 'Hadi', 'Indra', 'Joko', 'Andi', 'Dewi', 'Eko', 'Fajar', 'Budi'],
];

/// Skor per round, sisi atas–bawah menurut urutan court (14A R1, lanjutan 16g).
const _scores = [
  [(15, 6), (9, 12)],
  [(12, 9), (10, 11)],
];

/// Turnamen setelah [rounds] round dibuat. Semua round sebelum yang terakhir sudah berskor; yang terakhir hanya kalau
/// [lastScored] (16a). [gitaOut] = Gita dikeluarkan sesudah R2 dibuat: R3 dst dibuat tanpa dia (16f, 16g).
ActiveTournament mexicanoTournament(int rounds, {bool lastScored = false, bool gitaOut = false}) {
  const courts = [
    Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
    Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
  ];
  final players = [for (final n in mexicanoNames) Player(id: n, name: n)];
  final matches = <MatchGame>[];
  final resting = <int, List<String>>{};
  for (var n = 1; n <= rounds; n++) {
    final draw = _draws[n - 1];
    final round = EndlessRoundGenerator.generateMexicanoRound(
      players: [
        for (final p in players)
          if (!(gitaOut && n >= 3 && p.id == 'Gita')) p,
      ],
      courts: courts,
      history: matches,
      roundNumber: n,
      seed: 0,
      format: _format,
      draw: {for (final (i, id) in draw.indexed) id: i},
    )!;
    resting[n] = [for (final p in round.resting) p.id];
    final scored = n < rounds || lastScored;
    for (final (i, m) in round.matches.indexed) {
      matches.add(scored ? m.withScore([SetScore(side1: _scores[n - 1][i].$1, side2: _scores[n - 1][i].$2)]) : m);
    }
  }
  return ActiveTournament(
    tournament: Tournament(
      id: 't-mexicano',
      createdAt: DateTime(2026, 11, 11, 19),
      config: TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.mexicano,
        matchDurationMinutes: 15,
        courts: courts,
        players: players,
        format: _format,
      ),
      matches: matches,
    ),
    restingPlayerIdsByRound: resting,
    withdrawnPlayerIds: {if (gitaOut) 'Gita'},
  );
}
