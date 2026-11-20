import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:flutter_test/flutter_test.dart';

import 'group_knockout_fixture.dart';
import 'player_swap_fixture.dart';

/// Fixture Kosongkan skor / Hapus WO (logic.md §19.6). 17A = `fixedSparing(c13)` (sparing_score_fixture), 17D/17E =
/// group_knockout_fixture; di sini hanya data yang belum ada: 17B Mixed, 17C Mexicano 14A, Sparing Mixed, 17D 20b.

const resetNames = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'];

/// Jam di tengah booking (sisa waktu masih ada), supaya `canGenerateNextRound` tidak mati karena waktu.
final resetNow = swapAt(40);

/// 17B: R1–R2 lengkap (isi bebas), R3 Court 1 Andi · Eko 13–8 Budi · Fajar, R3 Court 2 Citra · Gita 11–10 Dewi · Hadi.
List<MatchGame> mixed17bRounds() => [
  swapMatch(1, 1, ('Andi', 'Budi'), ('Citra', 'Dewi'), (12, 9)),
  swapMatch(1, 2, ('Eko', 'Fajar'), ('Gita', 'Hadi'), (11, 10)),
  swapMatch(2, 1, ('Andi', 'Citra'), ('Eko', 'Gita'), (13, 8)),
  swapMatch(2, 2, ('Budi', 'Dewi'), ('Fajar', 'Hadi'), (11, 6)),
  swapMatch(3, 1, ('Andi', 'Eko'), ('Budi', 'Fajar'), (13, 8)),
  swapMatch(3, 2, ('Citra', 'Gita'), ('Dewi', 'Hadi'), (11, 10)),
];

/// R4 tanpa skor (17B "R4 dibuat").
List<MatchGame> mixed17bR4() => [
  swapMatch(4, 1, ('Andi', 'Fajar'), ('Budi', 'Eko')),
  swapMatch(4, 2, ('Citra', 'Hadi'), ('Dewi', 'Gita')),
];

/// 17B Mixed (atau Mexicano lewat [mode]): Padel, Americano 21, 2 court × 2 jam, 8 pemain, tanpa istirahat.
ActiveTournament mixed17b({List<MatchGame>? matches, PartnerMode mode = PartnerMode.mixed, bool finished = false}) =>
    swapActive(
      matches ?? mixed17bRounds(),
      config: swapConfig(names: resetNames, mode: mode),
      id: 't-reset',
      finished: finished,
    );

/// 17C Mexicano 14A: R1 dan R2 tabel 14.6 (R2 Court 2 Gita · Budi 8–13 Eko · Dewi), R2 round terakhir.
List<MatchGame> mexicano14aRounds() => [
  swapMatch(1, 1, ('Andi', 'Citra'), ('Budi', 'Dewi'), (15, 6)),
  swapMatch(1, 2, ('Eko', 'Gita'), ('Fajar', 'Hadi'), (9, 12)),
  swapMatch(2, 1, ('Citra', 'Fajar'), ('Andi', 'Hadi'), (11, 10)),
  swapMatch(2, 2, ('Gita', 'Budi'), ('Eko', 'Dewi'), (8, 13)),
];

/// R3 Mexicano 14A ditulis literal (bukan dari generator): yang diuji hanya bahwa round lama terkunci.
List<MatchGame> mexicano14aR3() => [
  swapMatch(3, 1, ('Citra', 'Eko'), ('Andi', 'Dewi')),
  swapMatch(3, 2, ('Fajar', 'Gita'), ('Hadi', 'Budi')),
];

ActiveTournament mexicano14a({List<MatchGame>? matches}) =>
    mixed17b(matches: matches ?? mexicano14aRounds(), mode: PartnerMode.mexicano);

const resetGaruda = Club(id: 'club-1', name: 'PB Garuda');
const resetMatcha = Club(id: 'club-2', name: 'Matcha Club');

/// Sparing Mixed (U-2): Andi–Dewi PB Garuda, Eko–Hadi Matcha Club; partner sesama klub, lawan klub lain. R2 terakhir.
ActiveTournament sparingMixed() {
  final config = TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.mixed,
    matchDurationMinutes: 15,
    format: const ScoreFormat(ScoringMethod.americano, 21),
    courts: const [
      Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
      Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
    ],
    players: [
      for (final (i, n) in resetNames.indexed) Player(id: n, name: n, clubId: i < 4 ? resetGaruda.id : resetMatcha.id),
    ],
    clubs: const [resetGaruda, resetMatcha],
  );
  return swapActive(
    [
      swapMatch(1, 1, ('Andi', 'Budi'), ('Eko', 'Fajar'), (12, 9)),
      swapMatch(1, 2, ('Citra', 'Dewi'), ('Gita', 'Hadi'), (11, 10)),
      swapMatch(2, 1, ('Andi', 'Citra'), ('Eko', 'Gita'), (13, 8)),
      swapMatch(2, 2, ('Budi', 'Dewi'), ('Fajar', 'Hadi'), (6, 11)),
    ],
    config: config,
    id: 't-reset-sparing',
  );
}

/// 17D = data 16A / 20b: R1, R2, R3 Court 1 terisi (5 dari 12 match grup), sama dengan `gg20b` golden.
ActiveTournament gk20b() => gkTournament()
    .play('Andi', 'Gita', 4, 6)
    .play('Indra', 'Oki', 6, 1)
    .play('Citra', 'Eko', 6, 3)
    .play('Kiki', 'Maya', 3, 6)
    .play('Andi', 'Eko', 6, 3);

/// Match di round [round] court [court] ("c1").
MatchGame matchAt(ActiveTournament a, int round, int court) =>
    a.matches.firstWhere((m) => m.roundNumber == round && m.courtId == 'c$court');

/// Ringkasan match untuk membandingkan keadaan (R1, R7): semua field yang disimpan.
String matchSig(MatchGame m) =>
    '${m.id} R${m.roundNumber}#${m.matchNumberInRound} ${m.courtId} ${m.phase?.code} ${m.pair1.id}–${m.pair2.id} '
    '${m.sets.map((s) => '${s.side1}-${s.side2}').join(',')} ${m.status.name} ${m.woLoserPairId} ${m.woReason?.name}';

/// R7 / §19.9: simpanan terbaca lagi dan sama persis (tanpa kunci baru, `schemaVersion` tetap).
void expectRoundtrip(ActiveTournament a, {String reason = ''}) {
  final raw = TournamentCodec.encode(a);
  final back = TournamentCodec.decode(raw);
  expect(back, isNotNull, reason: '$reason: decode null');
  expect(TournamentCodec.encode(back!), raw, reason: '$reason: roundtrip berbeda');
}
