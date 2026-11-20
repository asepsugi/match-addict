import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../../services/group_knockout_fixture.dart';
import '../../services/score_reset_fixture.dart';
import '../../services/sparing_score_fixture.dart';

/// Controller Kosongkan skor / Hapus WO (logic.md §19.2, AC-K13): satu `state =`, tersimpan lewat auto-save (tanpa
/// `saveActive` manual), false + state identik kalau ditolak.
void main() {
  late TournamentStore store;
  ProviderContainer? current;
  var notified = 0;

  /// Buka app dengan [saved] di simpanan: `build()` memuatnya dan memasang listener auto-save.
  ProviderContainer open() {
    final c = ProviderContainer(
      overrides: [tournamentStoreProvider.overrideWithValue(store), clockProvider.overrideWithValue(() => resetNow)],
    );
    c.listen(tournamentProvider, (prev, next) => notified++);
    return c;
  }

  void start(ActiveTournament saved) {
    store = TournamentStore.memory();
    store.saveActive(saved);
    current?.dispose();
    current = open();
    notified = 0;
  }

  /// Tutup lalu buka lagi: yang terbaca hanya yang tersimpan.
  ActiveTournament reopen() {
    current!.dispose();
    current = open();
    return current!.read(tournamentProvider)!;
  }

  ActiveTournament read() => current!.read(tournamentProvider)!;
  TournamentController controller() => current!.read(tournamentProvider.notifier);

  tearDown(() {
    current?.dispose();
    current = null;
  });

  test('AC-K13 clearScore: satu state =, tersimpan → dibuka lagi Belum', () {
    start(fixedSparing(c13));
    read();
    expect(controller().clearScore('m12'), isTrue);
    expect(notified, 1);
    expect(read().matchById('m12')!.status, MatchStatus.pending);
    final back = reopen().matchById('m12')!;
    expect((back.status, back.sets.length), (MatchStatus.pending, 0));
  });

  test('AC-K13 removeWalkover: dibuka lagi Belum (tanpa skor lama) / skor lama', () {
    start(fixedSparing(c13));
    read();
    expect(controller().removeWalkover('m6'), isTrue);
    final back = reopen().matchById('m6')!;
    expect((back.status, back.woLoserPairId), (MatchStatus.pending, null));

    final withOld = fixedSparing(c13);
    final m4 = withOld.matchById('m4')!;
    start(
      withOld.copyWith(
        tournament: withOld.tournament.copyWith(
          matches: [
            for (final x in withOld.matches)
              x.id == m4.id ? x.asWalkover(loserPairId: m4.pair2.id, reason: WoReason.injury) : x,
          ],
        ),
      ),
    );
    read();
    expect(controller().removeWalkover('m4'), isTrue);
    final restored = reopen().matchById('m4')!;
    expect((restored.status, restored.sets.single.side1, restored.sets.single.side2), (MatchStatus.done, 6, 4));
    expect((restored.woLoserPairId, restored.woReason), (null, null));
  });

  test('ditolak → false, state identik, tidak ada notifikasi', () {
    start(fixedSparing(c13));
    final before = read();
    expect(controller().removeWalkover('m12'), isFalse, reason: 'm12 bukan WO');
    expect(controller().clearScore('m6'), isFalse, reason: 'm6 WO: tanpa Kosongkan');
    expect(controller().clearScore('tidak-ada'), isFalse);
    expect(identical(read(), before), isTrue);
    expect(notified, 0);
  });

  test('gugur: Kosongkan SF1 lewat controller memajukan resolve di state = yang sama (bukan _groupKnockoutUpdate)', () {
    start(groups16E().bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6));
    final sf1 = read().byCode('SF1').id;
    expect(controller().clearScore(sf1), isTrue);
    expect(notified, 1);
    expect((read().sides('F'), read().sides('J3')), ('?–Citra', '?–Indra'));
    expect(reopen().sides('F'), '?–Citra');
  });

  test('gugur diblokir (Final + Juara 3 berskor) → false, state identik', () {
    start(groups16E().bracket(q16E).ko('SF1', 6, 4).ko('SF2', 4, 6).ko('F', 7, 9).ko('J3', 4, 2));
    final before = read();
    expect(controller().clearScore(before.byCode('SF1').id), isFalse);
    expect(identical(read(), before), isTrue);
    expect(notified, 0);
  });
}
