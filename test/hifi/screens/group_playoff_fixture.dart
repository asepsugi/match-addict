import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/playoff_format.dart';

import 'grup_gugur_fixture.dart';

export 'grup_gugur_fixture.dart';

/// Fixture bersama golden 3.10.0 Group - Playoff (frame 23*, logic.md §21). Data dari fixture service (16G, 16G-iii,
/// 16G-akhir, 16H, 32 pemain), jadwal dan bagan lewat `GroupStage`/`KnockoutBracket`/`PlayoffFormat`, bukan ditulis
/// tangan; `group_knockout_flow_test.dart` memastikan jalur controller sama. Hanya diubah pemiliknya (GP-5): layar
/// menambah varian di file test-nya sendiri. Jam: `ggStart` (18.00) + `ggAt`, override `clockProvider` di test.

/// 16G: Padel, 15 mnt, 2 court × 3 jam (18.00–21.00).
ActiveTournament _g(ActiveTournament a) => ggStaged(a, bookingMinutes: 180);

/// 32 pemain (23a/23i/23u): Padel, 15 mnt, 2 court × 3 jam.
ActiveTournament _p32(ActiveTournament a) => ggStaged(a, bookingMinutes: 180);

/// 23b/23c/23t: 16G, 18 match grup terisi (R12 = round grup terakhir), sebelum Buat bagan.
ActiveTournament gp23b({int courts = 2}) => _g(groups16G(courts: courts));

/// 23e/23f: 16G-iii (Qori 6–3 Umar), seri Kiki/Umar di batas WC2.
ActiveTournament gp23e() => _g(groups16G(qoriUmar: 3));

/// 23h/23j/23o: bagan 16G baru dibuat (WC1 Eko, WC2 Kiki, tukar).
ActiveTournament gp23h({int courts = 2, bool thirdPlace = true}) =>
    _g(bracket16G(courts: courts, thirdPlace: thirdPlace));

/// 23p: 16H — Perempat final Race to 5, QF1 Andi 5–2 Kiki tersimpan (format QF terkunci).
ActiveTournament gp23p() => _g(
  PlayoffFormat.withFormat(
    bracket16G(),
    KnockoutRound.quarterfinal,
    const ScoreFormat(ScoringMethod.raceTo, 5),
  )!.ko('PF1', 5, 2),
);

/// 23v: 16G-akhir sampai R15 Court 1 (SF1 Andi 5–3 Maya, SF2 Belum), "5/8".
ActiveTournament gp23v() => _g(semis16G());

/// 23q/23r: Final Andi 6–4 Qori tersimpan, Juara 3 Belum.
ActiveTournament gp23q() => _g(final16G());

/// 23w/23k/23l: 16G-akhir selesai (Juara 3 Maya 5–2 Citra).
ActiveTournament gp23w() => _g(akhir16G());

/// 23u: 32 pemain × 4 grup, jadwal baru (0 dari 24 match grup).
ActiveTournament gp23u() => _p32(t32());

/// 23i: 32 pemain, bagan baru (QF1 Andi–Maya, QF2 Eko–Gina, QF3 Citra–Kiki, QF4 Indra–Vina).
ActiveTournament gp23i() => _p32(groups32().bracket(q32));
