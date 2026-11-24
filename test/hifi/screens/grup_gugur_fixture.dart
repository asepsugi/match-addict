import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/group_stage.dart';

import '../../services/group_knockout_fixture.dart';

// Data + helper skor dipakai ulang dari fixture service (16A/16B/16D/16E), tidak disalin.
export '../../services/group_knockout_fixture.dart';

/// Fixture bersama golden Grup + Gugur (frame 20–22, logic.md §18): data, nama, dan jam persis catatan frame.
/// Jadwal fase grup dari `GroupStage.schedule` dan bagan dari `KnockoutBracket.build`/`resolve` (lewat helper
/// `play`/`ko`/`bracket`), bukan ditulis tangan; `group_knockout_flow_test.dart` memastikan jalur controller sama.
/// Jam tidak disimpan di turnamen: test meng-override `clockProvider` dengan konstanta `at…` di bawah.
///
/// Task layar menambah varian di file test-nya sendiri; file ini jangan diubah per layar (pola `sparing_fixture.dart`).

/// 16A/16E: Padel, 15 mnt, 2 court × 2 jam, 18.00–20.00 (20a). 16B dan 16C memakai jam mulai yang sama.
final ggStart = DateTime(2026, 11, 17, 18);

/// [minutes] menit setelah mulai.
DateTime ggAt(int minutes) => ggStart.add(Duration(minutes: minutes));

/// Hitung mundur frame: 20a 02:00, 20b 01:30, 20e/20h/20l 00:30 (R6), 21b/21c 00:24, 21f 00:15, 21s 00:00 (R15,
/// lewat booking).
final at20a = ggStart;
final at20b = ggAt(30);
final at20e = ggAt(90);
final at21b = ggAt(96);
final at21f = ggAt(105);
final at21s = ggAt(210);

/// 16B (Tennis, 20 mnt, 3 jam): 20m 02:00, 20o 01:00, 21v 00:58.
final at20m = ggAt(60);
final at20o = ggAt(120);
final at21v = ggAt(122);

/// Turnamen fixture service dengan olahraga, durasi, booking, id, dan jam mulai frame. Match dan status apa adanya.
ActiveTournament _staged(
  ActiveTournament a, {
  SportType sport = SportType.padel,
  int matchMinutes = 15,
  int bookingMinutes = 120,
}) {
  final c = a.config;
  return ActiveTournament(
    tournament: Tournament(
      id: 't-grup-gugur',
      createdAt: ggStart,
      config: TournamentConfig(
        sport: sport,
        mode: c.mode,
        matchDurationMinutes: matchMinutes,
        courts: [for (final court in c.courts) court.copyWith(bookingDurationMinutes: bookingMinutes)],
        players: c.players,
        fixedPairs: c.fixedPairs,
        format: c.format,
        groupKnockout: c.groupKnockout,
      ),
      matches: a.matches,
      isFinished: a.tournament.isFinished,
    ),
  );
}

/// [_staged] untuk fixture lain (`group_playoff_fixture.dart`): id, jam mulai, olahraga, durasi, dan booking frame.
ActiveTournament ggStaged(
  ActiveTournament a, {
  SportType sport = SportType.padel,
  int matchMinutes = 15,
  int bookingMinutes = 120,
}) => _staged(a, sport: sport, matchMinutes: matchMinutes, bookingMinutes: bookingMinutes);

ActiveTournament _tennis(ActiveTournament a) =>
    _staged(a, sport: SportType.tennis, matchMinutes: 20, bookingMinutes: 180);

// ---------------------------------------------------------------------------------------------------------------
// 16A · 2 grup, 2 court (Grup A Court 1, Grup B Court 2)

/// 20a: jadwal baru, R1–R6 kosong.
ActiveTournament gg20a() => _staged(gkTournament());

/// 20b/20c/20d: R1, R2, R3 Court 1 terisi (5 dari 12 match).
ActiveTournament gg20b() => _staged(_played20b());

ActiveTournament _played20b() => gkTournament()
    .play('Andi', 'Gita', 4, 6)
    .play('Indra', 'Oki', 6, 1)
    .play('Citra', 'Eko', 6, 3)
    .play('Kiki', 'Maya', 3, 6)
    .play('Andi', 'Eko', 6, 3);

/// 20e/20f/20g: 12 match grup terisi, Grup A 16D-ii (A1 Andi, A2 Citra lewat head-to-head), Grup B 16E.
ActiveTournament gg20e({int courts = 2, bool thirdPlace = true}) =>
    _staged(groups16E(courts: courts, thirdPlace: thirdPlace));

/// Grup B 16E di atas Grup A [groupA] (16D-iii, 20l).
ActiveTournament _withGroupB16E(ActiveTournament groupA) => groupA
    .play('Indra', 'Maya', 6, 4)
    .play('Indra', 'Kiki', 6, 2)
    .play('Indra', 'Oki', 6, 1)
    .play('Maya', 'Kiki', 6, 3)
    .play('Maya', 'Oki', 6, 2)
    .play('Kiki', 'Oki', 6, 4);

/// 20h/20i/20j/20k: Grup A 16D-iii — Andi 3–0, Citra/Eko/Gita 1–2 −3 33% (nomor 2, 2, 2), A2 dipilih host.
ActiveTournament gg20h() => _staged(
  _withGroupB16E(
    gkTournament()
        .play('Andi', 'Gita', 6, 3)
        .play('Citra', 'Eko', 6, 4)
        .play('Andi', 'Eko', 6, 3)
        .play('Gita', 'Citra', 6, 4)
        .play('Andi', 'Citra', 6, 3)
        .play('Eko', 'Gita', 6, 4),
  ),
);

/// 20l: Grup A Andi, Citra, Eko 2–1 +3 (nomor 1, 1, 1), Gita 0–3 — host memilih A1 dan A2.
ActiveTournament gg20l() => _staged(
  _withGroupB16E(
    gkTournament()
        .play('Andi', 'Gita', 6, 3)
        .play('Citra', 'Eko', 6, 4)
        .play('Andi', 'Eko', 4, 6)
        .play('Gita', 'Citra', 3, 6)
        .play('Andi', 'Citra', 6, 4)
        .play('Eko', 'Gita', 6, 3),
  ),
);

/// 20q/22g: data 20b + R3 Court 2 Indra 6–4 Maya + R4 Court 1 Gita 4–6 Citra, diakhiri (R4 Court 2, R5, R6 tidak
/// dimainkan; bagan tidak dibuat).
ActiveTournament gg20q() => _staged(_played20b().play('Indra', 'Maya', 6, 4).play('Gita', 'Citra', 4, 6).finish());

/// 21a/22d: bagan baru dibuat dari 20e (SF1 Andi–Maya, SF2 Indra–Citra; R7 SF, R8 Final + Juara 3).
ActiveTournament gg21a({int courts = 2, bool thirdPlace = true}) =>
    _staged(groups16E(courts: courts, thirdPlace: thirdPlace).bracket(q16E));

/// 21c/21d/21e/22e: SF1 Andi 6–4 Maya.
ActiveTournament gg21c() => gg21a().ko('SF1', 6, 4);

/// 21f: SF2 Indra 4–6 Citra → Final Andi–Citra, Juara 3 Maya–Indra (R8 berjalan).
ActiveTournament gg21f() => gg21c().ko('SF2', 4, 6);

/// 21i/21j/22a (16F): Final Andi 7–9 Citra, Juara 3 Maya 4–2 Indra → Final.
ActiveTournament gg21i() => gg21f().ko('F', 7, 9).ko('J3', 4, 2);

/// 21q/21r/22c: tanpa Perebutan juara 3, Final terisi (15 match, R8 hanya Final).
ActiveTournament gg21q() => gg21a(thirdPlace: false).ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9);

/// 21t/22f: diakhiri setelah R7 (Final dan Juara 3 tidak dimainkan).
ActiveTournament gg21t() => gg21f().finish();

/// 21s: 1 court — fase grup R1–R12, SF1 R13 + SF2 R14 terisi, R15 Juara 3 berjalan, R16 Final.
ActiveTournament gg21s() => gg21a(courts: 1).ko('SF1', 6, 4).ko('SF2', 4, 6);

// ---------------------------------------------------------------------------------------------------------------
// 16B · 4 grup × 3, Tennis, 20 mnt, 2 court × 3 jam (A, C Court 1; B, D Court 2)

/// 20m/20n: R1–R3 + R4 Court 1 terisi (7 dari 12 match; Tono belum main).
ActiveTournament gg20m() => _tennis(
  gkTournament(groups: g16B)
      .play('Citra', 'Eko', 6, 4)
      .play('Indra', 'Kiki', 6, 2)
      .play('Rudi', 'Oki', 6, 3)
      .play('Qori', 'Vina', 4, 6)
      .play('Andi', 'Eko', 6, 1)
      .play('Gita', 'Kiki', 6, 4)
      .play('Maya', 'Oki', 6, 3),
);

/// 20o: 12 match grup terisi (A1 Andi, A2 Citra, B1 Indra, B2 Gita, C1 Maya, C2 Rudi, D1 Tono, D2 Vina).
ActiveTournament gg20o() => _tennis(groups20o());

/// 21u/21v: bagan 4 grup baru dibuat (R7 PF1 + PF2, R8 PF3 + PF4, R9 SF, R10 Final + Juara 3).
ActiveTournament gg21u() => _tennis(groups20o().bracket(q20o));

/// 21w: PF1 Andi 6–3 Gita, PF2 Maya 4–6 Vina, PF3 Indra 6–5 Citra; PF4 (R8) berjalan.
ActiveTournament gg21w() => gg21u().ko('PF1', 6, 3).ko('PF2', 4, 6).ko('PF3', 6, 5);

/// 21x: PF4 Tono 6–2 Rudi, SF1 Andi 6–4 Vina; SF2 (R9) berjalan.
ActiveTournament gg21x() => gg21w().ko('PF4', 6, 2).ko('SF1', 6, 4);

/// 21y/22h/22i: SF2 Indra 3–6 Tono, Final Andi 9–6 Tono, Juara 3 Vina 4–3 Indra → Final.
ActiveTournament gg21y() => gg21x().ko('SF2', 3, 6).ko('F', 9, 6).ko('J3', 4, 3);

// ---------------------------------------------------------------------------------------------------------------
// 16C · court lebih banyak dari grup: Padel, 15 mnt, 4 court × 4 jam, 15 pasangan (A 8 di Court 1 + 3, B 7 di
// Court 2 + 4). Pasangan Grup B berbeda dari peta `partners` (Qori · Rudi, …), jadi dibangun di sini.

const _groups16C = [
  [
    ('Andi', 'Budi'),
    ('Citra', 'Dewi'),
    ('Eko', 'Fajar'),
    ('Gita', 'Hadi'),
    ('Indra', 'Joko'),
    ('Kiki', 'Lina'),
    ('Maya', 'Nanda'),
    ('Oki', 'Putri'),
  ],
  [
    ('Qori', 'Rudi'),
    ('Sari', 'Tono'),
    ('Umar', 'Vina'),
    ('Wawan', 'Yuni'),
    ('Zaki', 'Ayu'),
    ('Bayu', 'Cici'),
    ('Dodi', 'Elsa'),
  ],
];

/// 20p: jadwal baru 16C (fase grup R1–R14).
ActiveTournament gg20p() {
  final groups = [
    for (final g in _groups16C) [for (final (a, b) in g) Pair(id: a, player1Id: a, player2Id: b)],
  ];
  final pairs = [for (final g in groups) ...g];
  final config = TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.fixed,
    matchDurationMinutes: 15,
    courts: [for (final c in courtsOf(4)) c.copyWith(bookingDurationMinutes: 240)],
    players: [
      for (final p in pairs) ...[
        Player(id: p.player1Id, name: p.player1Id),
        Player(id: p.player2Id, name: p.player2Id),
      ],
    ],
    fixedPairs: pairs,
    format: raceTo6,
    groupKnockout: GroupKnockout(
      groupCount: 2,
      groups: [
        for (final g in groups) [for (final p in g) p.id],
      ],
      formats: {
        for (final e in formats16A.entries)
          if (e.key != KnockoutRound.quarterfinal) e.key: e.value,
      },
      thirdPlace: true,
    ),
  );
  return ActiveTournament(
    tournament: Tournament(
      id: 't-grup-gugur',
      createdAt: ggStart,
      config: config,
      matches: GroupStage.schedule(groups: groups, courts: config.courts),
    ),
  );
}
