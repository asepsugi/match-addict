import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';

import '../../services/player_swap_fixture.dart';
import 'sparing_mixed_fixture.dart';

export '../../services/player_swap_fixture.dart';

/// Fixture golden Tukar pemain (frame 17a–17r). 17a–17i memakai fixture TP-1 (15A/15B) apa adanya; 17j dari
/// `courtTournament` (= 06p) dan 17k–17m dari `mixedSparing15b()` (13B) dipakai langsung di test. Di sini hanya keadaan
/// literal yang tidak ada di fixture lain: 17n (15C) dan 17o–17r.

/// Pasangan dengan id seperti buatan generator, supaya cocok dengan fixture TP-1.
Pair _pair(String a, String b) => Pair(id: EndlessRoundGenerator.pairId(a, b), player1Id: a, player2Id: b);

MatchGame _match(int round, int court, Pair p1, Pair p2, {(int, int)? score}) {
  final m = MatchGame(
    id: 'm-r$round-$court',
    roundNumber: round,
    matchNumberInRound: court,
    courtId: 'c$court',
    pair1: p1,
    pair2: p2,
  );
  return score == null ? m : m.withScore([SetScore(side1: score.$1, side2: score.$2)]);
}

/// 17n (contoh PRD 15C): PB Garuda 4 / Matcha Club 6, Padel, Race to 6, 2 court. R1 susunan contoh designer: semua
/// pemain Garuda main, Maya dan Nanda istirahat, jadi tim Garuda tanpa ikon. Id pemain = `mixedClubPlayers` (g01…, m01…).
ActiveTournament swap15C() {
  final config = mixedSparingConfig(garudaPlayers: const ['Andi', 'Budi', 'Citra', 'Dewi'], matchaPlayers: matchaNames);
  return ActiveTournament(
    tournament: Tournament(
      id: mixedSparingId,
      createdAt: mixedSparingStart,
      config: config,
      matches: [
        _match(1, 1, _pair('g01', 'g03'), _pair('m01', 'm03')),
        _match(1, 2, _pair('g02', 'g04'), _pair('m02', 'm04')),
      ],
    ),
    restingPlayerIdsByRound: const {
      1: ['m05', 'm06'],
    },
  );
}

/// 17o: 9 pemain / 2 court, R1 dibuat (Indra istirahat). Joko datang lewat Kelola pemain (ditambah di akhir daftar) dan
/// Hadi dikeluarkan, tapi namanya masih di R1 Court 2.
ActiveTournament swap17o() {
  final base = swapActive([
    swapMatch(1, 1, ('Andi', 'Citra'), ('Budi', 'Dewi')),
    swapMatch(1, 2, ('Eko', 'Gita'), ('Fajar', 'Hadi')),
  ], config: swapConfig(names: swapNames.take(9).toList()));
  return base.copyWith(
    tournament: base.tournament.copyWith(
      config: base.config.copyWith(
        players: [
          ...base.config.players,
          const Player(id: 'Joko', name: 'Joko'),
        ],
      ),
    ),
    withdrawn: {'Hadi'},
  );
}

/// 17r: Mixed 8 pemain / 2 court, R2 belum ada skor: semua main, tidak ada yang istirahat. R1 contoh (skor sah apa pun).
ActiveTournament swap17r() => swapActive([
  swapMatch(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewi'), (12, 9)),
  swapMatch(1, 2, ('Eko', 'Fajar'), ('Gita', 'Hadi'), (11, 10)),
  swapMatch(2, 1, ('Andi', 'Eko'), ('Citra', 'Gita')),
  swapMatch(2, 2, ('Budi', 'Fajar'), ('Dewi', 'Hadi')),
], config: swapConfig(names: swapNames.take(8).toList()));
