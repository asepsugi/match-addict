import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';

/// Turnamen yang sudah berjalan, seperti hasil resume: layar menerima config yang sama persis (identical),
/// jadi `startIfNeeded` tidak membuat jadwal baru.
class LoadedTournament extends TournamentController {
  final ActiveTournament active;
  LoadedTournament(this.active);

  @override
  ActiveTournament? build() => active;
}

/// Satu match Mixed: (atas, bawah) nama depan — atau nama lengkap kalau nama depannya kembar (06u) — skor atas–bawah;
/// null = belum diisi.
typedef MatchSpec = (String, String, String, String, int?, int?);

/// Nama pemain contoh layar Pemain, sampai batas 30; nama depannya unik supaya fixture match cukup menulis nama depan.
const fixtureNames = [
  'Andi P', 'Budi S', 'Citra L', 'Dewant R', 'Eko M', 'Fajar K', 'Gina R', 'Hana T', 'Indra W', 'Joko S', 'Kiki A', //
  'Lina M', 'Maya P', 'Nanda R', 'Oki S', 'Putri A', 'Rizky H', 'Sari D', 'Tono B', 'Umar F', 'Vina K', //
  'Wulan S', 'Yoga P', 'Zaki M', 'Bayu S', 'Dimas A', 'Galih P', 'Rina K', 'Tari W', 'Hendra G',
];

final fixtureStart = DateTime(2026, 10, 22, 19);

/// Turnamen Mixed dari daftar round. Bawaannya Padel Americano 21, 2 court × [bookingHours], 15 menit.
/// [roster] = nama pemain urut daftar (bawaan [players] nama pertama [fixtureNames]); [withdrawn] = nama
/// depan pemain yang keluar. Yang istirahat per round dicatat dari pemain yang tidak main, seperti generator.
/// [courtStarts] = jam mulai court yang ditambah belakangan (id → menit); [courtOf] = court match ke-i di round r
/// kalau bukan court ke-(i+1) (mis. round yang hanya dimainkan di Court 2).
ActiveTournament mixedTournament(
  List<List<MatchSpec>> rounds, {
  int players = 10,
  List<String>? roster,
  SportType sport = SportType.padel,
  ScoreFormat format = const ScoreFormat(ScoringMethod.americano, 21),
  int durationMinutes = 15,
  int bookingHours = 2,
  int courtCount = 2,
  List<String> courtNames = const [],
  Set<String> withdrawn = const {},
  String id = 't-mixed',
  DateTime? createdAt,
  bool finished = false,
  MatchGame Function(MatchGame m)? adjust,
  Map<String, int> courtStarts = const {},
  String Function(int round, int index)? courtOf,
  String? name,
}) {
  final names = roster ?? fixtureNames.take(players).toList();
  final people = [for (var i = 0; i < names.length; i++) Player(id: 'p${i.toString().padLeft(2, '0')}', name: names[i])];
  String pid(String name) => people
      .firstWhere((p) => p.name == name, orElse: () => people.firstWhere((p) => p.name.split(' ').first == name))
      .id;
  Pair pair(String a, String b) => Pair(id: '${pid(a)}+${pid(b)}', player1Id: pid(a), player2Id: pid(b));
  final matches = <MatchGame>[];
  for (final (r, round) in rounds.indexed) {
    for (final (c, (a, b, x, y, s1, s2)) in round.indexed) {
      var m = MatchGame(
        id: 'r${r + 1}c${c + 1}',
        roundNumber: r + 1,
        matchNumberInRound: c + 1,
        courtId: courtOf?.call(r + 1, c) ?? 'c${c + 1}',
        pair1: pair(a, b),
        pair2: pair(x, y),
      );
      if (s1 != null) m = m.withScore([SetScore(side1: s1, side2: s2!)]);
      if (finished && s1 == null) m = m.copyWith(status: MatchStatus.cancelled);
      matches.add(adjust?.call(m) ?? m);
    }
  }
  return ActiveTournament(
    tournament: Tournament(
      id: id,
      createdAt: createdAt ?? fixtureStart,
      isFinished: finished,
      config: TournamentConfig(
        sport: sport,
        mode: PartnerMode.mixed,
        matchDurationMinutes: durationMinutes,
        courts: [
          for (var i = 0; i < courtCount; i++)
            Court(
              id: 'c${i + 1}',
              name: i < courtNames.length ? courtNames[i] : 'Court ${i + 1}',
              colorIndex: i,
              bookingDurationMinutes: bookingHours * 60,
              startMinute: courtStarts['c${i + 1}'] ?? 0,
            ),
        ],
        players: people,
        format: format,
        name: name,
      ),
      matches: matches,
    ),
    restingPlayerIdsByRound: {
      for (var r = 1; r <= rounds.length; r++)
        r: [
          for (final p in people)
            if (!withdrawn.contains(p.name.split(' ').first) &&
                !matches.any((m) => m.roundNumber == r && (m.pair1.contains(p.id) || m.pair2.contains(p.id))))
              p.id,
        ],
    },
    withdrawnPlayerIds: {for (final first in withdrawn) pid(first)},
  );
}

/// Round contoh Jadwal Mixed 06f–06j (10 pemain): R1 Gina·Hana istirahat, R2 Eko·Fajar, R3 Indra·Joko.
const mixedR1 = <MatchSpec>[('Andi', 'Budi', 'Citra', 'Dewant', 12, 9), ('Eko', 'Fajar', 'Indra', 'Joko', 10, 11)];
const mixedR2 = <MatchSpec>[('Gina', 'Andi', 'Hana', 'Citra', 11, 10), ('Indra', 'Budi', 'Joko', 'Dewant', 13, 8)];
const mixedR3Running = <MatchSpec>[('Andi', 'Dewant', 'Citra', 'Fajar', 13, 8), ('Eko', 'Budi', 'Hana', 'Gina', null, null)];

const mixedR3Done = <MatchSpec>[('Andi', 'Dewant', 'Citra', 'Fajar', 13, 8), ('Hana', 'Gina', 'Eko', 'Budi', null, null)];
const mixedR4 = <MatchSpec>[('Indra', 'Citra', 'Joko', 'Hana', null, null), ('Andi', 'Fajar', 'Budi', 'Gina', null, null)];

/// 06g/06h: match kedua R3 menang WO (pemain absen).
MatchGame mixedWo(MatchGame m) => m.id == 'r3c2' ? m.asWalkover(loserPairId: m.pair2.id, reason: WoReason.absent) : m;

/// R8 di 06l (waktu habis); R1–R7 bergantian [mixedR1]/[mixedR2].
final mixedTimeUpRounds = [
  for (var r = 0; r < 7; r++) r.isEven ? mixedR1 : mixedR2,
  const <MatchSpec>[('Citra', 'Joko', 'Andi', 'Eko', 9, 12), ('Dewant', 'Indra', 'Budi', 'Fajar', 14, 7)],
];

/// Kelola court (06p–06t, 07l, 08e–08k, logic.md §10): 10 pemain, mabar mulai 19.00 dengan Court 1 saja; Court 2
/// ditambah 20.02 (menit 62) saat R5 berjalan dan R8–R9 hanya di Court 2 karena Court 1 habis 21.00. Id turnamen
/// dipilih supaya undian seri R6, R8, R9, R10 sama dengan riwayat ini.
const courtTournamentId = 't-court-329705';
const courtR1 = <MatchSpec>[('Andi', 'Budi', 'Citra', 'Dewant', 12, 9)];
const courtR2 = <MatchSpec>[('Eko', 'Fajar', 'Gina', 'Hana', 11, 10)];
const courtR3 = <MatchSpec>[('Andi', 'Citra', 'Indra', 'Joko', 13, 8)];
const courtR4 = <MatchSpec>[('Budi', 'Dewant', 'Eko', 'Gina', 10, 11)];
const courtR5Court1 = <MatchSpec>[('Fajar', 'Indra', 'Hana', 'Joko', null, null)];
const courtR5 = <MatchSpec>[('Fajar', 'Indra', 'Hana', 'Joko', null, null), ('Andi', 'Dewant', 'Citra', 'Gina', null, null)];
const courtR5Done = <MatchSpec>[('Fajar', 'Indra', 'Hana', 'Joko', 12, 9), ('Andi', 'Dewant', 'Citra', 'Gina', 10, 11)];
const courtR6 = <MatchSpec>[('Budi', 'Fajar', 'Citra', 'Eko', 12, 9), ('Gina', 'Joko', 'Hana', 'Indra', 10, 11)];
const courtR7 = <MatchSpec>[('Budi', 'Indra', 'Eko', 'Joko', 12, 9), ('Andi', 'Hana', 'Dewant', 'Fajar', 8, 13)];
const courtR8 = <MatchSpec>[('Citra', 'Budi', 'Gina', 'Indra', 11, 10)];
const courtR9 = <MatchSpec>[('Andi', 'Eko', 'Fajar', 'Joko', null, null)];

/// Turnamen Kelola court dari daftar round; [courts] = 1 sebelum Court 2 ditambah (06p).
ActiveTournament courtTournament(List<List<MatchSpec>> rounds, {int courts = 2}) => mixedTournament(
  rounds,
  id: courtTournamentId,
  courtCount: courts,
  courtStarts: const {'c2': 62},
  courtOf: (round, index) => round >= 8 ? 'c2' : 'c${index + 1}',
);

/// Jadwal Fixed 06a–06e (dan penonton 12f, 12i). Tennis Race to 6, 10 pemain (5 pasangan), 2 court × 2 jam, mulai
/// 45 menit lalu. Jadwal round-robin sah (tiap pasangan istirahat sekali):
/// R1 A istirahat (B–C, D–E) · R2 E (A–B, C–D) · R3 D (A–C, B–E) · R4 B (A–D, C–E) · R5 C (A–E, B–D),
/// dengan A Andi·Budi, B Citra·Dewant, C Eko·Fajar, D Gina·Hana, E Indra·Joko.
const _fixedNames = ['Andi P', 'Budi S', 'Citra L', 'Dewant R', 'Eko M', 'Fajar K', 'Gina R', 'Hana T', 'Indra W', 'Joko S'];
final _fixedPlayers = [for (var i = 0; i < _fixedNames.length; i++) Player(id: 'p$i', name: _fixedNames[i])];
final _fixedPairs = [for (var i = 0; i < 5; i++) Pair(id: 'pair$i', player1Id: 'p${2 * i}', player2Id: 'p${2 * i + 1}')];
final fixedStart = DateTime(2026, 10, 22, 19);
final _fixedConfig = TournamentConfig(
  sport: SportType.tennis,
  mode: PartnerMode.fixed,
  matchDurationMinutes: 20,
  courts: const [
    Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
    Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
  ],
  players: _fixedPlayers,
  fixedPairs: _fixedPairs,
);
// (pasangan istirahat, [pair1, pair2] court 1, [pair1, pair2] court 2) per round.
const _fixedRounds = [
  (0, [1, 2], [3, 4]),
  (4, [0, 1], [2, 3]),
  (3, [0, 2], [1, 4]),
  (1, [0, 3], [2, 4]),
  (2, [0, 4], [1, 3]),
];

/// [scores] per match id ("r2c1") = skor pair1–pair2; match lain pending, atau dibatalkan kalau [finished].
ActiveTournament fixedTournament(Map<String, (int, int)> scores, {bool finished = false}) {
  MatchGame match(int round, int court, List<int> p) {
    final id = 'r${round}c$court';
    final base = MatchGame(
      id: id,
      roundNumber: round,
      matchNumberInRound: court,
      courtId: 'c$court',
      pair1: _fixedPairs[p[0]],
      pair2: _fixedPairs[p[1]],
    );
    final score = scores[id];
    if (score != null) return base.withScore([SetScore(side1: score.$1, side2: score.$2)]);
    return finished ? base.copyWith(status: MatchStatus.cancelled) : base;
  }

  return ActiveTournament(
    tournament: Tournament(
      id: 't-fixed',
      createdAt: fixedStart,
      isFinished: finished,
      config: _fixedConfig,
      matches: [
        for (final (i, (_, c1, c2)) in _fixedRounds.indexed) ...[match(i + 1, 1, c1), match(i + 1, 2, c2)],
      ],
    ),
    byePairIdByRound: {for (final (i, (bye, _, _)) in _fixedRounds.indexed) i + 1: _fixedPairs[bye].id},
  );
}

final fixedRunning = fixedTournament({'r1c1': (6, 3), 'r1c2': (4, 6), 'r2c1': (6, 4)});
final fixedEnded = fixedTournament({
  for (var r = 1; r <= 4; r++) ...{'r${r}c1': (6, 2), 'r${r}c2': (3, 6)},
  'r5c1': (6, 5),
}, finished: true);
