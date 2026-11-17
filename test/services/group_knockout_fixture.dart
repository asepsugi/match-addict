import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/group_stage.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';

/// Data Grup + Gugur PRD 16A/16B/16D/16E (logic.md §18.6–18.9). Id pasangan = nama pemain pertama; pemain kedua =
/// nama partner PRD, jadi label baris "Andi + Budi".

const partners = {
  'Andi': 'Budi',
  'Citra': 'Dewi',
  'Eko': 'Fajar',
  'Gita': 'Hadi',
  'Indra': 'Joko',
  'Kiki': 'Lina',
  'Maya': 'Nanda',
  'Oki': 'Putri',
  'Rudi': 'Sari',
  'Tono': 'Umi',
  'Qori': 'Yuni',
  'Vina': 'Wawan',
};

const g16A = [
  ['Andi', 'Citra', 'Eko', 'Gita'],
  ['Indra', 'Kiki', 'Maya', 'Oki'],
];

const g16B = [
  ['Andi', 'Citra', 'Eko'],
  ['Gita', 'Indra', 'Kiki'],
  ['Maya', 'Rudi', 'Oki'],
  ['Tono', 'Qori', 'Vina'],
];

const raceTo6 = ScoreFormat(ScoringMethod.raceTo, 6);

/// 16A: Semifinal Race to 6, Juara 3 Race to 4, Final Race to 9 (4 grup: Perempat final Race to 6).
const formats16A = {
  KnockoutRound.quarterfinal: raceTo6,
  KnockoutRound.semifinal: raceTo6,
  KnockoutRound.thirdPlace: ScoreFormat(ScoringMethod.raceTo, 4),
  KnockoutRound.finalRound: ScoreFormat(ScoringMethod.raceTo, 9),
};

Pair pairOf(String name) => Pair(id: name, player1Id: name, player2Id: partners[name] ?? '$name-2');

List<Court> courtsOf(int n) => [
  for (var i = 0; i < n; i++)
    Court(id: 'c${i + 1}', name: 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: 120),
];

/// Turnamen Grup + Gugur baru, jadwal fase grup dari [GroupStage.schedule].
ActiveTournament gkTournament({
  List<List<String>> groups = g16A,
  int courts = 2,
  bool thirdPlace = true,
  ScoreFormat format = raceTo6,
  Map<KnockoutRound, ScoreFormat> formats = formats16A,
}) {
  final names = [for (final g in groups) ...g];
  final pairs = [for (final n in names) pairOf(n)];
  final config = TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.fixed,
    matchDurationMinutes: 15,
    courts: courtsOf(courts),
    players: [
      for (final p in pairs) ...[
        Player(id: p.player1Id, name: p.player1Id),
        Player(id: p.player2Id, name: p.player2Id),
      ],
    ],
    fixedPairs: pairs,
    format: format,
    groupKnockout: GroupKnockout(
      groupCount: groups.length,
      groups: groups,
      formats: {
        for (final e in formats.entries)
          if (e.key != KnockoutRound.quarterfinal || groups.length == 4) e.key: e.value,
      },
      thirdPlace: thirdPlace,
    ),
  );
  final matches = GroupStage.schedule(
    groups: [
      for (final g in groups) [for (final n in g) pairOf(n)],
    ],
    courts: config.courts,
  );
  return ActiveTournament(
    tournament: Tournament(id: 't', createdAt: DateTime(2026, 11, 17), config: config, matches: matches),
  );
}

extension GkFixture on ActiveTournament {
  ActiveTournament withMatches(List<MatchGame> matches) =>
      ActiveTournament(tournament: tournament.copyWith(matches: matches));

  ActiveTournament _replace(bool Function(MatchGame) where, MatchGame Function(MatchGame) change) {
    final i = matches.indexWhere(where);
    if (i < 0) throw StateError('match tidak ada');
    final next = [...matches]..[i] = change(matches[i]);
    return withMatches(KnockoutBracket.resolve(config, next));
  }

  /// Skor match grup [a]–[b] ([sa] milik [a]), urutan sisi di jadwal tidak penting.
  ActiveTournament play(String a, String b, int sa, int sb) => _replace(
    (m) => m.phase is GroupPhase && {m.pair1.id, m.pair2.id}.containsAll([a, b]),
    (m) => m.withScore([m.pair1.id == a ? SetScore(side1: sa, side2: sb) : SetScore(side1: sb, side2: sa)]),
  );

  /// Skor match gugur ber-kode [code] ('SF1', 'F', 'J3'), sisi pair1 dulu; pemenang maju (resolve).
  ActiveTournament ko(String code, int s1, int s2) =>
      _replace((m) => m.phase?.code == code, (m) => m.withScore([SetScore(side1: s1, side2: s2)]));

  /// WO di match gugur [code]: [loser] kalah.
  ActiveTournament koWo(String code, String loser) =>
      _replace((m) => m.phase?.code == code, (m) => m.asWalkover(loserPairId: loser));

  /// Bagan dibuat dari [qualifiers] (per grup [slot 1, slot 2]).
  ActiveTournament bracket(List<List<String>> qualifiers) =>
      withMatches([...matches, ...KnockoutBracket.build(this, qualifiers)]);

  /// Akhiri: match pending → cancelled.
  ActiveTournament finish() => ActiveTournament(
    tournament: tournament.copyWith(
      isFinished: true,
      matches: [
        for (final m in matches) m.status == MatchStatus.pending ? m.copyWith(status: MatchStatus.cancelled) : m,
      ],
    ),
  );

  MatchGame byCode(String code) => matches.firstWhere((m) => m.phase?.code == code);

  /// "Andi–Maya", sisi tbd = "?".
  String sides(String code) {
    final m = byCode(code);
    String n(Pair p) => p.isTbd ? '?' : p.id;
    return '${n(m.pair1)}–${n(m.pair2)}';
  }
}

/// 16D-ii (A1 Andi, A2 Citra) + Grup B 16E (B1 Indra, B2 Maya): 12 match grup terisi.
ActiveTournament groups16E({int courts = 2, bool thirdPlace = true}) =>
    gkTournament(courts: courts, thirdPlace: thirdPlace)
        .play('Andi', 'Citra', 6, 4)
        .play('Andi', 'Eko', 6, 3)
        .play('Gita', 'Andi', 6, 4)
        .play('Citra', 'Eko', 6, 3)
        .play('Citra', 'Gita', 6, 4)
        .play('Eko', 'Gita', 6, 2)
        .play('Indra', 'Maya', 6, 4)
        .play('Indra', 'Kiki', 6, 2)
        .play('Indra', 'Oki', 6, 1)
        .play('Maya', 'Kiki', 6, 3)
        .play('Maya', 'Oki', 6, 2)
        .play('Kiki', 'Oki', 6, 4);

/// 16B / 20o: 12 match grup 4 grup terisi (data 20m + 20o).
ActiveTournament groups20o({int courts = 2, bool thirdPlace = true}) =>
    gkTournament(groups: g16B, courts: courts, thirdPlace: thirdPlace)
        .play('Citra', 'Eko', 6, 4)
        .play('Andi', 'Eko', 6, 1)
        .play('Andi', 'Citra', 6, 4)
        .play('Indra', 'Kiki', 6, 2)
        .play('Gita', 'Kiki', 6, 4)
        .play('Gita', 'Indra', 3, 6)
        .play('Rudi', 'Oki', 6, 3)
        .play('Maya', 'Oki', 6, 3)
        .play('Maya', 'Rudi', 6, 4)
        .play('Qori', 'Vina', 4, 6)
        .play('Tono', 'Vina', 6, 2)
        .play('Tono', 'Qori', 6, 3);

const q16E = [
  ['Andi', 'Citra'],
  ['Indra', 'Maya'],
];

const q20o = [
  ['Andi', 'Citra'],
  ['Indra', 'Gita'],
  ['Maya', 'Rudi'],
  ['Tono', 'Vina'],
];
