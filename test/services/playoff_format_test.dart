import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/playoff_format.dart';
import 'package:match_addict/services/scoring/score_reset.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import 'group_knockout_fixture.dart';

/// Ubah format babak setelah jadwal dibuat (PRD G16, contoh 16H; logic.md §21.10). Data = 16G (2 court dan 1 court).

const _qf = KnockoutRound.quarterfinal, _sf = KnockoutRound.semifinal;
const _j3 = KnockoutRound.thirdPlace, _f = KnockoutRound.finalRound;
const _raceTo5 = ScoreFormat(ScoringMethod.raceTo, 5);

/// "R16 F C1" per match gugur, urut daftar match.
List<String> _knockout(ActiveTournament a) => [
  for (final m in a.matches)
    if (m.phase is KnockoutPhase) 'R${m.roundNumber} ${m.phase!.code} ${m.courtId} ${m.id}',
];

ActiveTournament _clear(ActiveTournament a, String code) =>
    ScoreReset.apply(a, a.byCode(code).id, ResetAction.clearScore)!;

void main() {
  group('formatLock (AC-G28, 23p, 23q)', () {
    test('16H sebelum bagan dan bagan baru: semua babak terbuka', () {
      for (final a in [groups16G(), bracket16G()]) {
        for (final r in [_qf, _sf, _j3, _f]) {
          expect(PlayoffFormat.formatLock(a, r), isNull, reason: r.name);
        }
        expect(PlayoffFormat.thirdPlaceLock(a), isNull);
      }
    });

    test('16H 23p QF1 5–2 → "QF1 ada skor", SF/Juara 3/Final masih terbuka; Kosongkan QF1 → terbuka lagi', () {
      final a = bracket16G().ko('PF1', 5, 2);
      expect(PlayoffFormat.formatLock(a, _qf), 'QF1 ada skor');
      for (final r in [_sf, _j3, _f]) {
        expect(PlayoffFormat.formatLock(a, r), isNull);
      }
      expect(PlayoffFormat.formatLock(_clear(a, 'PF1'), _qf), isNull);
    });

    test('rentang berurutan digabung: "QF1–4", "QF1–2, QF4", "SF1–2" (23q), WO ikut mengunci', () {
      expect(PlayoffFormat.formatLock(semis16G(), _qf), 'QF1–4 ada skor');
      expect(PlayoffFormat.formatLock(semis16G(), _sf), 'SF1 ada skor');
      expect(PlayoffFormat.formatLock(final16G(), _sf), 'SF1–2 ada skor');
      final gap = bracket16G().ko('PF1', 4, 2).ko('PF2', 3, 4).koWo('PF4', 'Indra');
      expect(PlayoffFormat.formatLock(gap, _qf), 'QF1–2, QF4 ada skor');
      expect(PlayoffFormat.formatLock(bracket16G().ko('PF3', 4, 1), _qf), 'QF3 ada skor');
    });

    test('23q/23r: Final berskor → "Final ada skor"; Juara 3 masih boleh diubah formatnya', () {
      final a = final16G();
      final locks = PlayoffFormat.locks(a);
      expect(locks.formats, {_qf: 'QF1–4 ada skor', _sf: 'SF1–2 ada skor', _j3: null, _f: 'Final ada skor'});
      expect(locks.thirdPlace, 'Final ada skor');
      expect(PlayoffFormat.withFormat(a, _j3, _raceTo5), isNotNull);
    });

    test('Juara 3 berskor (Final Belum) → "Juara 3 ada skor"; keduanya → Final didahulukan', () {
      final j3Only = semis16G().ko('SF2', 5, 4).ko('J3', 5, 2);
      expect(PlayoffFormat.thirdPlaceLock(j3Only), 'Juara 3 ada skor');
      expect(PlayoffFormat.thirdPlaceLock(akhir16G()), 'Final ada skor');
    });

    test('diakhiri → semua terkunci, juga sebelum bagan', () {
      for (final a in [groups16G().finish(), bracket16G().finish()]) {
        final locks = PlayoffFormat.locks(a);
        expect(locks.formats.values, everyElement(PlayoffFormat.finished));
        expect(locks.thirdPlace, PlayoffFormat.finished);
        expect(PlayoffFormat.withFormat(a, _sf, _raceTo5), isNull);
        expect(PlayoffFormat.withThirdPlace(a, false), isNull);
      }
    });

    test('locks hanya babak yang dimainkan: 2 grup tanpa QF, Juara 3 mati tanpa Juara 3', () {
      expect(PlayoffFormat.locks(groups16E()).formats.keys, [_sf, _j3, _f]);
      expect(PlayoffFormat.locks(groups16G(thirdPlace: false)).formats.keys, [_qf, _sf, _f]);
    });
  });

  group('withFormat (AC-G28)', () {
    test('16H QF Race to 4 → 5: match tidak berubah, formatFor memakai yang baru, wildcards tetap (21.12 #1)', () {
      final a = bracket16G();
      final b = PlayoffFormat.withFormat(a, _qf, _raceTo5)!;
      expect(b.config.groupKnockout!.formats[_qf], _raceTo5);
      expect(b.config.groupKnockout!.formats[_sf], formats16G[_sf]);
      expect(b.config.groupKnockout!.wildcards, ['Eko', 'Kiki']);
      expect(b.config.groupKnockout!.groups, g16G);
      expect(b.config.groupKnockout!.thirdPlace, isTrue);
      expect(b.config.format, a.config.format);
      expect(b.config.formatFor(b.byCode('PF1')).label, 'Race to 5');
      expect(_knockout(b), _knockout(a));
      expect([for (final m in b.matches) m.phase?.code], [for (final m in a.matches) m.phase?.code]);
      expect(TournamentCodec.canEncode(b), isTrue);
    });

    test('16H ditolak: babak berskor, Best of 4 (bisa seri), QF di 2 grup', () {
      expect(PlayoffFormat.withFormat(bracket16G().ko('PF1', 5, 2), _qf, _raceTo5), isNull);
      expect(PlayoffFormat.withFormat(bracket16G(), _sf, const ScoreFormat(ScoringMethod.bestOf, 4)), isNull);
      expect(PlayoffFormat.withFormat(bracket16G(), _sf, const ScoreFormat(ScoringMethod.bestOf, 5)), isNotNull);
      expect(PlayoffFormat.withFormat(groups16E(), _qf, _raceTo5), isNull);
    });

    test('sebelum bagan: config saja, juga format Juara 3 yang sedang mati (19g)', () {
      final a = groups16G(thirdPlace: false);
      final b = PlayoffFormat.withFormat(a, _j3, _raceTo5)!;
      expect(b.config.groupKnockout!.formats[_j3], _raceTo5);
      expect(b.matches, a.matches);
    });
  });

  group('withThirdPlace + relayout (AC-G28, 16H, 23r)', () {
    test('16H 2 court: mati → R16 hanya Final C1, 16 round, 25 match; nyala lagi = bagan semula', () {
      final a = bracket16G();
      final off = PlayoffFormat.withThirdPlace(a, false)!;
      expect(off.config.groupKnockout!.thirdPlace, isFalse);
      expect(off.config.groupKnockout!.wildcards, ['Eko', 'Kiki']);
      expect(off.matchesOfRound(16).map((m) => '${m.phase?.code} ${m.courtId}'), ['F c1']);
      expect(off.roundCount, 16);
      expect(off.matches, hasLength(25));
      expect(TournamentCodec.canEncode(off), isTrue);
      final on = PlayoffFormat.withThirdPlace(off, true)!;
      expect(_knockout(on), _knockout(a));
      expect(TournamentCodec.encode(on), TournamentCodec.encode(a));
    });

    test('16H 1 court: grup R1–R18, QF R19–R22, SF R23–R24, J3 R25, F R26; mati → Final R25, 25 round', () {
      final a = bracket16G(courts: 1);
      expect(_knockout(a), [
        'R19 PF1 c1 m-r19-1',
        'R20 PF2 c1 m-r20-1',
        'R21 PF3 c1 m-r21-1',
        'R22 PF4 c1 m-r22-1',
        'R23 SF1 c1 m-r23-1',
        'R24 SF2 c1 m-r24-1',
        'R25 J3 c1 m-r25-1',
        'R26 F c1 m-r26-1',
      ]);
      final off = PlayoffFormat.withThirdPlace(a, false)!;
      expect(_knockout(off).last, 'R25 F c1 m-r25-1');
      expect(off.roundCount, 25);
      expect(TournamentCodec.canEncode(off), isTrue);
      final on = PlayoffFormat.withThirdPlace(off, true)!;
      expect(_knockout(on), _knockout(a));
    });

    test('SF terisi lalu Juara 3 nyala: sisi Juara 3 baru dari yang kalah SF (resolve di langkah yang sama)', () {
      final a = PlayoffFormat.withThirdPlace(bracket16G(thirdPlace: false), true);
      expect(a, isNotNull, reason: 'bagan tanpa Juara 3 boleh dinyalakan');
      final played = PlayoffFormat.withThirdPlace(
        PlayoffFormat.withThirdPlace(semis16G(), false)!.ko('SF2', 5, 4),
        true,
      )!;
      expect(played.sides('J3'), 'Maya–Citra');
      expect(played.sides('F'), 'Andi–Qori');
      expect(played.byCode('J3').status, MatchStatus.pending);
      expect(TournamentCodec.canEncode(played), isTrue);
    });

    test('match ber-hasil tidak berpindah (1 court, SF terisi)', () {
      final a = bracket16G(courts: 1).ko('PF1', 4, 2).ko('PF2', 3, 4).ko('PF3', 4, 1).ko('PF4', 3, 4).ko('SF1', 5, 3);
      final off = PlayoffFormat.withThirdPlace(a, false)!;
      for (final code in ['PF1', 'PF2', 'PF3', 'PF4', 'SF1']) {
        expect(off.byCode(code).id, a.byCode(code).id);
        expect(off.byCode(code).sets, a.byCode(code).sets);
      }
    });

    test('ditolak setelah Final atau Juara 3 berskor; nilai sama = tidak berubah', () {
      expect(PlayoffFormat.withThirdPlace(final16G(), false), isNull);
      expect(PlayoffFormat.withThirdPlace(semis16G().ko('SF2', 5, 4).ko('J3', 5, 2), false), isNull);
      final a = bracket16G();
      expect(identical(PlayoffFormat.withThirdPlace(a, true), a), isTrue);
    });

    test('sebelum bagan: config saja, pratinjau ikut', () {
      final a = groups16G();
      final off = PlayoffFormat.withThirdPlace(a, false)!;
      expect(off.config.groupKnockout!.thirdPlace, isFalse);
      expect(off.matches, a.matches);
    });

    test('2 grup 16A: Juara 3 mati di bagan 21a = fixture 21q (R8 hanya Final)', () {
      final off = PlayoffFormat.withThirdPlace(groups16E().bracket(q16E), false)!;
      expect(_knockout(off), _knockout(groups16E(thirdPlace: false).bracket(q16E)));
    });
  });
}
