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

/// [partnerMap] = peta partner data itu (16G dan 32 pemain memakai peta sendiri).
Pair pairOf(String name, [Map<String, String> partnerMap = partners]) =>
    Pair(id: name, player1Id: name, player2Id: partnerMap[name] ?? '$name-2');

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
  Map<String, String> partnerMap = partners,
}) {
  final names = [for (final g in groups) ...g];
  final pairs = [for (final n in names) pairOf(n, partnerMap)];
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
          if (e.key != KnockoutRound.quarterfinal || groups.length >= 3) e.key: e.value,
      },
      thirdPlace: thirdPlace,
    ),
  );
  final matches = GroupStage.schedule(
    groups: [
      for (final g in groups) [for (final n in g) pairOf(n, partnerMap)],
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

  /// Bagan 2/4 grup dibuat dari [qualifiers] (per grup [slot 1, slot 2]); config 2/4 grup tidak berubah.
  ActiveTournament bracket(List<List<String>> qualifiers) =>
      withMatches([...matches, ...KnockoutBracket.build(this, Seeding(groupSlots: qualifiers)).matches]);

  /// Buat bagan dari [seeding] (juga 3 grup): match gugur + config hasil build (`wildcards`) sekaligus, seperti
  /// `createBracket` di controller.
  ActiveTournament withBracket(Seeding seeding) {
    final built = KnockoutBracket.build(this, seeding);
    return ActiveTournament(
      tournament: tournament.copyWith(config: built.config, matches: [...matches, ...built.matches]),
    );
  }

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

// ---------------------------------------------------------------------------------------------------------------
// 3.10.0 Group - Playoff (logic.md §21): 16G, 16G-iii, 16G-akhir, 16H, 32 pemain × 4 grup, simpanan 3.9.x.

/// Partner PRD 16G (berbeda dari [partners] untuk Qori, Sari, Umar, Wawan).
const partners16G = {
  'Andi': 'Budi',
  'Citra': 'Dewi',
  'Eko': 'Fajar',
  'Gita': 'Hadi',
  'Indra': 'Joko',
  'Kiki': 'Lina',
  'Maya': 'Nanda',
  'Oki': 'Putri',
  'Qori': 'Rina',
  'Sari': 'Tono',
  'Umar': 'Vina',
  'Wawan': 'Yuni',
};

const g16G = [
  ['Andi', 'Citra', 'Eko', 'Gita'],
  ['Indra', 'Kiki', 'Maya', 'Oki'],
  ['Qori', 'Sari', 'Umar', 'Wawan'],
];

/// 16G: Perempat final Race to 4, Semifinal Race to 5, Juara 3 Race to 5, Final Race to 6.
const formats16G = {
  KnockoutRound.quarterfinal: ScoreFormat(ScoringMethod.raceTo, 4),
  KnockoutRound.semifinal: ScoreFormat(ScoringMethod.raceTo, 5),
  KnockoutRound.thirdPlace: ScoreFormat(ScoringMethod.raceTo, 5),
  KnockoutRound.finalRound: ScoreFormat(ScoringMethod.raceTo, 6),
};

/// 16G jadwal baru (fase grup R1–R12 di 2 court; 1 court R1–R18).
ActiveTournament t16G({int courts = 2, bool thirdPlace = true}) =>
    gkTournament(groups: g16G, courts: courts, thirdPlace: thirdPlace, formats: formats16G, partnerMap: partners16G);

/// Hasil fase grup 16G (PRD 16.3), 18 match terisi. Varian: [mayaKiki] 2 = 16G-ii, [qoriUmar] 3 = 16G-iii;
/// [andiEko] 1 + [qoriUmar] 3 = seri tiga kandidat (Eko, Kiki, Umar semua 1–2 −6 → `WildcardPick(2, …)`).
ActiveTournament groups16G({
  int courts = 2,
  bool thirdPlace = true,
  int mayaKiki = 1,
  int qoriUmar = 1,
  int andiEko = 2,
}) => t16G(courts: courts, thirdPlace: thirdPlace)
    .play('Andi', 'Citra', 6, 4)
    .play('Andi', 'Eko', 6, andiEko)
    .play('Andi', 'Gita', 6, 1)
    .play('Citra', 'Eko', 6, 3)
    .play('Citra', 'Gita', 6, 2)
    .play('Eko', 'Gita', 6, 4)
    .play('Indra', 'Maya', 6, 5)
    .play('Indra', 'Kiki', 6, 4)
    .play('Indra', 'Oki', 6, 3)
    .play('Maya', 'Kiki', 6, mayaKiki)
    .play('Maya', 'Oki', 6, 2)
    .play('Kiki', 'Oki', 6, 5)
    .play('Qori', 'Sari', 6, 3)
    .play('Qori', 'Umar', 6, qoriUmar)
    .play('Qori', 'Wawan', 6, 4)
    .play('Sari', 'Umar', 6, 2)
    .play('Sari', 'Wawan', 6, 3)
    .play('Umar', 'Wawan', 6, 5);

/// AC-G24 16G: J1 Andi (A), J2 Qori (C), J3 Indra (B); WC1 Eko (A3), WC2 Kiki (B3) → tukar.
const seeding16G = Seeding(
  groupSlots: [
    ['Andi', 'Citra'],
    ['Indra', 'Maya'],
    ['Qori', 'Sari'],
  ],
  champions: [0, 2, 1],
  wildcards: ['Eko', 'Kiki'],
);

/// AC-G25 16G-iii, host memilih Umar sebagai WC2: WC1 Eko, WC2 Umar → tukar (QF1 Andi–Umar, QF3 Qori–Eko).
const seeding16GIII = Seeding(
  groupSlots: [
    ['Andi', 'Citra'],
    ['Indra', 'Maya'],
    ['Qori', 'Sari'],
  ],
  champions: [0, 2, 1],
  wildcards: ['Eko', 'Umar'],
);

/// 23h/16H: bagan 16G baru dibuat (R13 QF1 + QF2, R14 QF3 + QF4, R15 SF, R16 Final C1 + Juara 3 C2).
ActiveTournament bracket16G({int courts = 2, bool thirdPlace = true}) =>
    groups16G(courts: courts, thirdPlace: thirdPlace).withBracket(seeding16G);

/// 16G-akhir sampai R15 Court 1 (23v, "5/8"): QF1 4–2, QF2 3–4, QF3 4–1, QF4 3–4, SF1 Andi 5–3 Maya; SF2 Belum.
ActiveTournament semis16G() =>
    bracket16G().ko('PF1', 4, 2).ko('PF2', 3, 4).ko('PF3', 4, 1).ko('PF4', 3, 4).ko('SF1', 5, 3);

/// 23q/23r: 16G-akhir dengan Final Andi 6–4 Qori tersimpan, Juara 3 Maya–Citra Belum.
ActiveTournament final16G() => semis16G().ko('SF2', 5, 4).ko('F', 6, 4);

/// 16G-akhir (23w, AC-G27): Juara 3 Maya 5–2 Citra → Final.
ActiveTournament akhir16G() => final16G().ko('J3', 5, 2);

/// 32 pemain (16 pasangan), 4 grup × 4 (23a, 23i, 23u). Lolos persis catatan 23i; sisanya data contoh.
const partners32 = {
  'Andi': 'Budi',
  'Kiki': 'Lina',
  'Oki': 'Putri',
  'Rudi': 'Sari',
  'Citra': 'Dewant',
  'Maya': 'Nanda',
  'Tono': 'Umi',
  'Qori': 'Yuni',
  'Eko': 'Fajar',
  'Vina': 'Wulan',
  'Zaki': 'Ayu',
  'Bayu': 'Cici',
  'Indra': 'Joko',
  'Gina': 'Hana',
  'Dodi': 'Elsa',
  'Fani': 'Gilang',
};

/// Urutan dalam grup = urutan akhir tabel: slot 1, slot 2, lalu dua yang tidak lolos.
const g32 = [
  ['Andi', 'Kiki', 'Oki', 'Rudi'],
  ['Citra', 'Maya', 'Tono', 'Qori'],
  ['Eko', 'Vina', 'Zaki', 'Bayu'],
  ['Indra', 'Gina', 'Dodi', 'Fani'],
];

/// 23i: A1 Andi, A2 Kiki, B1 Citra, B2 Maya, C1 Eko, C2 Vina, D1 Indra, D2 Gina.
const q32 = [
  ['Andi', 'Kiki'],
  ['Citra', 'Maya'],
  ['Eko', 'Vina'],
  ['Indra', 'Gina'],
];

/// 23u: jadwal 32 pemain baru (R1–R12, 24 match grup), semua babak Race to 6.
ActiveTournament t32({int courts = 2}) =>
    gkTournament(groups: g32, courts: courts, formats: formats16A, partnerMap: partners32);

/// 32 pemain, semua match grup terisi: pasangan di depan selalu menang 6–(selisih urutan) → 3–0, 2–1, 1–2, 0–3.
ActiveTournament groups32({int courts = 2}) {
  var a = t32(courts: courts);
  for (final g in g32) {
    for (var i = 0; i < g.length; i++) {
      for (var j = i + 1; j < g.length; j++) {
        a = a.play(g[i], g[j], 6, j - i);
      }
    }
  }
  return a;
}

/// Simpanan 3.9.x 2 grup × 3 pasangan (P = 6, tidak ditawarkan lagi di 3.10.0, keputusan 143): semua match grup
/// terisi, sebelum Buat bagan. Encode 2/4 grup byte-sama dengan 3.9.x (`group_knockout_codec_test`), jadi simpanan
/// lewat `TournamentStore` = simpanan app lama. A1 Andi, A2 Citra, B1 Gita, B2 Indra.
ActiveTournament legacy2x3() =>
    gkTournament(
          groups: const [
            ['Andi', 'Citra', 'Eko'],
            ['Gita', 'Indra', 'Kiki'],
          ],
        )
        .play('Andi', 'Citra', 6, 3)
        .play('Andi', 'Eko', 6, 2)
        .play('Citra', 'Eko', 6, 4)
        .play('Gita', 'Indra', 6, 4)
        .play('Gita', 'Kiki', 6, 1)
        .play('Indra', 'Kiki', 6, 5);

/// Simpanan 3.9.x 4 grup × 3 pasangan (P = 12) = 16B/20o, semua match grup terisi, sebelum Buat bagan.
ActiveTournament legacy4x3() => groups20o();
