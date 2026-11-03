import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/round_robin_generator.dart';

import 'schedule_fixture.dart';

/// Fixture round tambahan Fixed (06v–06z, 04f–04h, 09g, 10d): kasus live TBNE36 — Padel, Americano 21, 16 pemain
/// (8 pasangan), 2 court 4 jam, 15 mnt. Round-robin R1–R14 dari generator; Budi S pulang, Rizky H masuk menggantikannya
/// sebagai pasangan Andi P untuk R15–R16.
final extraStart = DateTime(2026, 11, 3, 19);
final extraPlayers = [for (var i = 0; i < 16; i++) Player(id: 'p$i', name: fixtureNames[i])];
final extraPairs = [for (var i = 0; i < 8; i++) Pair(id: 'pair$i', player1Id: 'p${2 * i}', player2Id: 'p${2 * i + 1}')];
final rizky = Player(id: 'p16', name: fixtureNames[16]);
final andiRizky = Pair(id: 'pair-new', player1Id: 'p0', player2Id: rizky.id);

final extraConfig = TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.fixed,
  matchDurationMinutes: 15,
  format: const ScoreFormat(ScoringMethod.americano, 21),
  courts: const [
    Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 240),
    Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 240),
  ],
  players: extraPlayers,
  fixedPairs: extraPairs,
);

/// Kekuatan per pasangan (urutan [extraPairs], lalu Andi + Rizky) supaya klasemennya bertingkat.
const _strength = {'pair0': 7, 'pair1': 3, 'pair2': 5, 'pair3': 2, 'pair4': 6, 'pair5': 4, 'pair6': 5, 'pair7': 1, 'pair-new': 4};

/// Skor Americano 21 ke-[i]: yang lebih kuat menang 11–15 poin, tiap match ke-5 kejutan. R14 sama dengan frame 06v.
MatchGame _scored(MatchGame m, int i) {
  const r14 = {'m-r14-1': (13, 8), 'm-r14-2': (9, 12)};
  final fixed = r14[m.id];
  if (fixed != null) return m.withScore([SetScore(side1: fixed.$1, side2: fixed.$2)]);
  final a = _strength[m.pair1.id]!, b = _strength[m.pair2.id]!;
  final w = 11 + (i * 7 + a * 3 + b) % 5;
  final firstWins = (a > b || (a == b && i.isEven)) != (i % 5 == 3);
  return m.withScore([firstWins ? SetScore(side1: w, side2: 21 - w) : SetScore(side1: 21 - w, side2: w)]);
}

/// R1–R14 terisi semua (06v). [scored] = match yang skornya sudah masuk.
ActiveTournament extraRoundRobin() {
  final rr = RoundRobinGenerator.generate(pairs: extraPairs, courts: extraConfig.courts);
  return ActiveTournament(
    tournament: Tournament(
      id: 't-tbne36',
      createdAt: extraStart,
      config: extraConfig,
      matches: [for (final (i, m) in rr.matches.indexed) _scored(m, i)],
    ),
  );
}

/// R15–R16 dengan Andi P + Rizky H, semua skor terisi (09g, 10d).
ActiveTournament extraPlayed() {
  final base = extraRoundRobin();
  final pairs = [andiRizky, ...extraPairs.skip(1)];
  final extra = RoundRobinGenerator.extend(
    pairs: pairs,
    courts: extraConfig.courts,
    roundsLeft: const [2, 2],
    putaranDone: 0,
    firstRound: 15,
  );
  final n = base.matches.length;
  return base.copyWith(
    tournament: base.tournament.copyWith(
      config: extraConfig.copyWith(players: [...extraPlayers, rizky], fixedPairs: pairs),
      matches: [...base.matches, for (final (i, m) in extra.schedule.matches.indexed) _scored(m, n + i)],
    ),
    extraPutaran: 1,
  );
}
