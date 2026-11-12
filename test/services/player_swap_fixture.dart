import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/schedule/player_swap.dart';

/// Fixture tukar pemain Mixed (logic.md §15.4, contoh 15A/15B): Padel, Americano 21, 15 menit, 2 court × 2 jam, id
/// pemain = nama, ditulis literal (bukan dari generator) supaya sama dengan frame 17a/17f.
///
/// Id turnamen dicari sekali: dengan `drawSeed`-nya undian R3 menaruh Andi dan Budi di dua nilai terbesar di antara
/// Andi, Budi, Dewi, Eko, Fajar, Gita (AC-T9: Batalkan R3 lalu Buat R3 → Andi, Budi istirahat lagi), dan undian R4
/// membuat Gita, Fajar < Eko < Budi, Dewi (AC-T3, T5, T7: istirahat R4 = {Eko, Budi} / {Eko, Dewi} / {Budi, Dewi}).
/// Peluangnya ±1/450 per id; skrip pencarinya sudah dibuang.
const swapTournamentId = 't-swap-591';

const swapNames = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi', 'Indra', 'Joko'];

final swapStart = DateTime(2026, 11, 12, 19);
DateTime swapAt(int minutes) => swapStart.add(Duration(minutes: minutes));

/// Jam 17a: sisa 01:20, artinya 40 menit sejak mulai.
final swapNow = swapAt(40);

/// Match: pair1 (a, b) lawan pair2 (c, d); [score] = skor pair1–pair2, null = belum diisi.
MatchGame swapMatch(int round, int court, (String, String) p1, (String, String) p2, [(int, int)? score]) {
  // Id pasangan = kunci generator, sama dengan pasangan buatan generator Mixed (invariant tukar balik #6).
  Pair pair((String, String) p) => Pair(id: EndlessRoundGenerator.pairId(p.$1, p.$2), player1Id: p.$1, player2Id: p.$2);
  final m = MatchGame(
    id: 'm-r$round-$court',
    roundNumber: round,
    matchNumberInRound: court,
    courtId: 'c$court',
    pair1: pair(p1),
    pair2: pair(p2),
  );
  return score == null ? m : m.withScore([SetScore(side1: score.$1, side2: score.$2)]);
}

TournamentConfig swapConfig({List<String> names = swapNames, PartnerMode mode = PartnerMode.mixed, int courts = 2}) =>
    TournamentConfig(
      sport: SportType.padel,
      mode: mode,
      matchDurationMinutes: 15,
      format: const ScoreFormat(ScoringMethod.americano, 21),
      courts: [
        for (var i = 1; i <= courts; i++)
          Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: 120),
      ],
      players: [for (final n in names) Player(id: n, name: n)],
    );

/// Turnamen dari [matches] (urut round); yang istirahat per round dicatat dari pemain yang tidak main, urut daftar.
ActiveTournament swapActive(
  List<MatchGame> matches, {
  TournamentConfig? config,
  String id = swapTournamentId,
  Set<String> withdrawn = const {},
  bool finished = false,
}) {
  final cfg = config ?? swapConfig();
  final rounds = {for (final m in matches) m.roundNumber};
  return ActiveTournament(
    tournament: Tournament(id: id, createdAt: swapStart, config: cfg, matches: matches, isFinished: finished),
    restingPlayerIdsByRound: {
      for (final r in rounds)
        r: [
          for (final p in cfg.players)
            if (!withdrawn.contains(p.id) &&
                !matches.any((m) => m.roundNumber == r && (m.pair1.contains(p.id) || m.pair2.contains(p.id))))
              p.id,
        ],
    },
    withdrawnPlayerIds: withdrawn,
  );
}

/// R1 dan R2 contoh 15A/15B, terisi.
List<MatchGame> swapRounds12() => [
  swapMatch(1, 1, ('Andi', 'Citra'), ('Budi', 'Dewi'), (12, 9)),
  swapMatch(1, 2, ('Eko', 'Gita'), ('Fajar', 'Hadi'), (11, 10)),
  swapMatch(2, 1, ('Andi', 'Gita'), ('Fajar', 'Eko'), (13, 8)),
  swapMatch(2, 2, ('Budi', 'Indra'), ('Dewi', 'Joko'), (10, 11)),
];

/// 15A (17a): R3 C1 Citra·Indra vs Hadi·Joko 12–9, C2 Dewi·Eko vs Fajar·Gita belum diisi; Andi, Budi istirahat.
ActiveTournament swap15A() => swapActive([
  ...swapRounds12(),
  swapMatch(3, 1, ('Citra', 'Indra'), ('Hadi', 'Joko'), (12, 9)),
  swapMatch(3, 2, ('Dewi', 'Eko'), ('Fajar', 'Gita')),
]);

/// 15B (17f): R3 dua-duanya belum diisi.
ActiveTournament swap15B() => swapActive([
  ...swapRounds12(),
  swapMatch(3, 1, ('Citra', 'Indra'), ('Hadi', 'Joko')),
  swapMatch(3, 2, ('Dewi', 'Eko'), ('Fajar', 'Gita')),
]);

Set<String> swapPlayersOf(MatchGame m) => {...m.pair1.playerIds, ...m.pair2.playerIds};

bool _samePair(Pair a, Pair b) => a.id == b.id && a.player1Id == b.player1Id && a.player2Id == b.player2Id;

bool _sameMatch(MatchGame a, MatchGame b) =>
    a.id == b.id &&
    a.roundNumber == b.roundNumber &&
    a.matchNumberInRound == b.matchNumberInRound &&
    a.courtId == b.courtId &&
    a.status == b.status &&
    a.woLoserPairId == b.woLoserPairId &&
    a.woReason == b.woReason &&
    a.sets.length == b.sets.length &&
    _samePair(a.pair1, b.pair1) &&
    _samePair(a.pair2, b.pair2);

/// Invariant logic.md §15.3 #1–#5 untuk satu tukar sah [before] → [after] (match [matchId], [outId] → [inId]).
void expectSwapInvariants(
  ActiveTournament before,
  ActiveTournament after, {
  required String matchId,
  required String outId,
  required String inId,
}) {
  final n = before.roundCount;
  // #1 satu match berbeda, posisinya sama, Q tepat di slot P.
  expect(after.matches.length, before.matches.length);
  final changed = [
    for (var i = 0; i < before.matches.length; i++)
      if (!_sameMatch(before.matches[i], after.matches[i])) i,
  ];
  expect(changed.length, 1, reason: 'tepat satu match berubah');
  final a = before.matches[changed.single], b = after.matches[changed.single];
  expect(b.id, matchId);
  expect(a.id, matchId);
  List<String> slots(MatchGame m) => [m.pair1.player1Id, m.pair1.player2Id, m.pair2.player1Id, m.pair2.player2Id];
  expect(slots(b), [for (final id in slots(a)) id == outId ? inId : id]);
  expect(b.sets.length, a.sets.length);
  // #2 satu orang satu tempat di round n.
  final seen = <String>[for (final m in after.matchesOfRound(n)) ...slots(m), ...?after.restingPlayerIdsByRound[n]];
  expect(seen.toSet().length, seen.length, reason: 'tiap pemain paling banyak satu tempat di round $n');
  // #3 daftar istirahat.
  final was = [...?before.restingPlayerIdsByRound[n]];
  final at = was.indexOf(inId);
  if (at >= 0) {
    was[at] = outId;
  } else {
    was.add(outId);
  }
  expect(after.restingPlayerIdsByRound[n], was);
  for (final e in before.restingPlayerIdsByRound.entries) {
    if (e.key != n) expect(after.restingPlayerIdsByRound[e.key], e.value, reason: 'round lain tidak disentuh');
  }
  // #4 kehadiran.
  // Dua arah: Q keluar dari daftar telat <=> round n satu-satunya round yang dia lewatkan; yang lain tidak berubah.
  bool missed(ActiveTournament a, String id, int round) =>
      !(a.restingPlayerIdsByRound[round]?.contains(id) ?? false) &&
      !a.matchesOfRound(round).any((m) => swapPlayersOf(m).contains(id));
  final otherMissed = [
    for (var r = 1; r < n; r++)
      if (missed(before, inId, r)) r,
  ];
  expect(after.latePlayerIds.contains(inId), otherMissed.isNotEmpty);
  expect(after.latePlayerIds.difference({inId}), before.latePlayerIds.difference({inId}));
  // Tidak berubah.
  expect(after.withdrawnPlayerIds, before.withdrawnPlayerIds);
  expect(identical(after.config, before.config), isTrue);
  expect(after.tournament.isFinished, before.tournament.isFinished);
  // #5 sparing.
  if (before.config.isSparing) {
    expect(after.config.clubOfPlayer(inId)?.id, after.config.clubOfPlayer(outId)?.id);
    for (final pair in [b.pair1, b.pair2]) {
      expect(after.config.clubOfPair(pair), isNotNull, reason: 'S2: partner sesama klub');
    }
    expect(after.config.clubOfPair(b.pair1)?.id, after.config.clubs![0].id, reason: 'S4: pair1 klub pertama');
  }
}

/// Invariant #7 dan #9 pada [now]: daftar Istirahat setelah tukar = Buat R(n+1), dan ikon tim ⇔ ada kandidat.
void expectSwapListMatchesCreate(ActiveTournament active, DateTime now) {
  final n = active.roundCount;
  final round = active.config.isSparing
      ? EndlessRoundGenerator.generateSparingRound(
          club1: active.activePlayersByClub.$1,
          club2: active.activePlayersByClub.$2,
          courts: active.courtsAvailableAt(now),
          history: active.matches,
          roundNumber: n + 1,
          seed: active.drawSeed,
          latePlayerIds: active.latePlayerIds,
        )
      : EndlessRoundGenerator.generateRound(
          players: active.activePlayers,
          courts: active.courtsAvailableAt(now),
          history: active.matches,
          roundNumber: n + 1,
          seed: active.drawSeed,
          latePlayerIds: active.latePlayerIds,
        );
  if (round != null) {
    final chosen = {for (final m in round.matches) ...swapPlayersOf(m)};
    final list = EndlessRoundGenerator.restingAfterLastRound(active, now);
    expect(list.priority.every((p) => chosen.contains(p.id)), isTrue, reason: 'priority ⊆ pilihan Buat');
    expect(list.later.any((p) => chosen.contains(p.id)), isFalse, reason: 'later ∩ pilihan = ∅');
  }
  for (final m in active.matchesOfRound(n)) {
    for (final team in [m.pair1, m.pair2]) {
      final c = PlayerSwap.candidates(active, m, team, now);
      expect(
        PlayerSwap.canSwapTeam(active, m, team),
        PlayerSwap.isSwappable(active, m) && (c.priority.isNotEmpty || c.later.isNotEmpty),
        reason: 'ikon ⇔ kandidat',
      );
    }
  }
}
