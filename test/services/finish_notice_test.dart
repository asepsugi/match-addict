import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/finish_notice.dart';

import 'group_knockout_fixture.dart';

/// Config yang sama dengan [a] tapi mode/Grup + Gugur diganti (copyWith tidak membuka keduanya).
ActiveTournament _reconfig(ActiveTournament a, {PartnerMode? mode, bool keepGroups = true}) {
  final c = a.config;
  return ActiveTournament(
    tournament: a.tournament.copyWith(
      config: TournamentConfig(
        sport: c.sport,
        mode: mode ?? c.mode,
        matchDurationMinutes: c.matchDurationMinutes,
        courts: c.courts,
        players: c.players,
        fixedPairs: c.fixedPairs,
        format: c.format,
        groupKnockout: keepGroups ? c.groupKnockout : null,
      ),
    ),
  );
}

void main() {
  const base = 'Match yang belum main tidak dihitung.';
  final q = [
    ['Andi', 'Citra'],
    ['Indra', 'Maya'],
  ];

  test('Fixed round-robin: turnamen tidak bisa dilanjutkan (06e, 14k)', () {
    final fixed = _reconfig(gkTournament(), keepGroups: false);
    expect(FinishNotice.message(fixed), '$base Turnamen tidak bisa dilanjutkan.');
  });

  test('Mixed dan Mexicano: tetap kalimat dasar (06i, 15h)', () {
    final a = gkTournament();
    expect(FinishNotice.message(_reconfig(a, mode: PartnerMode.mixed)), base);
    expect(FinishNotice.message(_reconfig(a, mode: PartnerMode.mexicano)), base);
  });

  test('Grup + Gugur fase grup: bagan tidak dibuat (20r)', () {
    expect(FinishNotice.message(gkTournament()), '$base Bagan tidak dibuat; peringkat dari posisi grup.');
  });

  test('Gugur, Semifinal lengkap sebelum Final: babak batal + pemenang SF berbagi #1 (21z)', () {
    final a = groups16E().bracket(q).ko('SF1', 6, 3).koWo('SF2', 'Indra');
    // SF1 = Andi–Maya (Andi menang), SF2 = Indra–Citra (Indra WO, Citra menang).
    expect(FinishNotice.message(a), 'Final dan Juara 3 tidak dimainkan. Andi · Budi dan Citra · Dewi sama-sama #1.');
  });

  test('tanpa Juara 3: hanya Final yang batal', () {
    final a = groups16E(thirdPlace: false).bracket(q).ko('SF1', 6, 3).ko('SF2', 6, 2);
    expect(FinishNotice.message(a), 'Final tidak dimainkan. Andi · Budi dan Indra · Joko sama-sama #1.');
  });

  test('Semifinal belum lengkap: babak batal saja, tanpa #1', () {
    final a = groups16E().bracket(q).ko('SF1', 6, 3);
    expect(FinishNotice.message(a), 'Semifinal, Final, dan Juara 3 tidak dimainkan.');
  });

  test('Perempat final: semua babak disebut berurutan', () {
    final a = groups20o().bracket([
      ['Andi', 'Citra'],
      ['Indra', 'Gita'],
      ['Rudi', 'Maya'],
      ['Tono', 'Vina'],
    ]);
    expect(FinishNotice.message(a), 'Perempat final, Semifinal, Final, dan Juara 3 tidak dimainkan.');
  });

  test('Final sudah main, Juara 3 belum: tanpa #1', () {
    final a = groups16E().bracket(q).ko('SF1', 6, 3).ko('SF2', 6, 2).ko('F', 9, 5);
    expect(FinishNotice.message(a), 'Juara 3 tidak dimainkan.');
  });
}
