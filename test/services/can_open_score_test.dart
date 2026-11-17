import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';

import '../hifi/screens/grup_gugur_fixture.dart';

/// `ActiveTournament.canOpenScore`: satu aturan "match boleh dibuka ke Input Skor" untuk tab round dan Bagan.
/// Data = fixture Grup + Gugur 16E (gg21c: SF1 selesai, R7 berjalan, Final/Juara 3 di R8 menunggu SF2).
void main() {
  test('sisi tbd: tidak bisa dibuka', () {
    final a = gg21c();
    final m = a.byCode('F');
    expect(m.pair2.isTbd, isTrue);
    expect(a.canOpenScore(m), isFalse);
  });

  test('cancelled ("Tidak dimainkan"): tidak bisa dibuka', () {
    final a = gg21c().finish();
    final m = a.byCode('SF2');
    expect(m.status, MatchStatus.cancelled);
    expect(a.canOpenScore(m), isFalse);
  });

  test('round berjalan dengan sisi lengkap: bisa dibuka', () {
    final a = gg21c();
    expect(a.currentRound, 7);
    expect(a.canOpenScore(a.byCode('SF2')), isTrue);
  });

  test('match yang sudah ada skor di round berjalan: tetap bisa dibuka (ubah skor)', () {
    final a = gg21c();
    expect(a.canOpenScore(a.byCode('SF1')), isTrue);
  });

  test('round depan terkunci selama belum diakhiri; sisi lengkap pun tidak bisa dibuka', () {
    final a = gkTournament();
    final next = a.matches.firstWhere((m) => m.roundNumber == a.currentRound + 1);
    expect(next.pair1.isTbd || next.pair2.isTbd, isFalse);
    expect(a.canOpenScore(next), isFalse);
  });

  test('round depan terbuka setelah turnamen diakhiri (match tidak dibatalkan)', () {
    final a = gkTournament();
    final next = a.matches.firstWhere((m) => m.roundNumber == a.currentRound + 1);
    final done = ActiveTournament(tournament: a.tournament.copyWith(isFinished: true));
    expect(done.canOpenScore(next), isTrue);
  });

  test('match grup di round berjalan: bisa dibuka', () {
    final a = gkTournament();
    expect(a.canOpenScore(a.matches.firstWhere((m) => m.roundNumber == a.currentRound)), isTrue);
  });

  test('MatchGame.isScorable: cancelled atau tbd = false', () {
    final a = gg21c();
    expect(a.byCode('SF2').isScorable, isTrue);
    expect(a.byCode('F').isScorable, isFalse);
    expect(a.byCode('SF2').copyWith(status: MatchStatus.cancelled).isScorable, isFalse);
  });

  test('KnockoutBracket.sourcesOf: gugur = sumber sisi, grup = null', () {
    final a = gg21c();
    final (s1, s2) = KnockoutBracket.sourcesOf(a.config, a.byCode('F'))!;
    expect([KnockoutBracket.sourceLabel(s1), KnockoutBracket.sourceLabel(s2)], ['Pemenang SF1', 'Pemenang SF2']);
    expect(KnockoutBracket.sourcesOf(a.config, a.matches.first), isNull);
  });

  test('KnockoutBracket.advancesTo: PF → SF, SF → Final, Final/Juara 3 → null', () {
    expect(
      KnockoutBracket.advancesTo(const KnockoutPhase(KnockoutRound.quarterfinal, 3)),
      const KnockoutPhase(KnockoutRound.semifinal, 2),
    );
    expect(
      KnockoutBracket.advancesTo(const KnockoutPhase(KnockoutRound.semifinal, 1)),
      const KnockoutPhase(KnockoutRound.finalRound, 1),
    );
    expect(KnockoutBracket.advancesTo(const KnockoutPhase(KnockoutRound.finalRound, 1)), isNull);
    expect(KnockoutBracket.advancesTo(const KnockoutPhase(KnockoutRound.thirdPlace, 1)), isNull);
  });
}
