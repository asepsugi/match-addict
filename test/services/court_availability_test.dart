import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';

/// Court yang habis duluan atau tinggal beberapa menit (kurang dari satu match) tidak ikut round berikutnya, dan
/// daftar "Prioritas main di R…" dihitung dengan court yang tersisa, jadi sama dengan hasil Buat (logic.md §6, §10).
void main() {
  late DateTime now;
  late ProviderContainer container;
  late TournamentController controller;
  ActiveTournament read() => container.read(tournamentProvider)!;

  final config = TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.mixed,
    matchDurationMinutes: 15,
    courts: const [
      Court(id: 'c0', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 60),
      Court(id: 'c1', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
    ],
    players: [for (var i = 0; i < 10; i++) Player(id: 'p$i', name: 'Pemain $i')],
  );

  setUp(() {
    now = DateTime(2026, 10, 22, 19);
    container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
    controller = container.read(tournamentProvider.notifier);
    controller.startIfNeeded(config);
  });
  tearDown(() => container.dispose());

  void finishRound() {
    for (final m in read().matchesOfRound(read().roundCount)) {
      controller.submitScore(m.id, const [SetScore(side1: 6, side2: 4)]);
    }
  }

  /// Daftar prioritas yang tampil, lalu Buat → yang benar-benar main di round baru.
  ({Set<String> shown, Set<String> played, List<String> courts}) next() {
    final shown = EndlessRoundGenerator.restingAfterLastRound(read(), now).priority.map((p) => p.id).toSet();
    final restingBefore = {
      for (final p in read().activePlayers)
        if (!read()
            .matchesOfRound(read().roundCount)
            .any((m) => [...m.pair1.playerIds, ...m.pair2.playerIds].contains(p.id)))
          p.id,
    };
    controller.generateNextRound();
    final round = read().matchesOfRound(read().roundCount);
    final played = <String>{
      for (final m in round) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
    };
    return (shown: shown, played: played.intersection(restingBefore), courts: [for (final m in round) m.courtId]);
  }

  for (final (label, minutes, courts) in [
    ('Court 1 sisa 16 mnt (≥ 15): dua court', 44, ['c0', 'c1']),
    ('Court 1 sisa tepat 15 mnt: dua court', 45, ['c0', 'c1']),
    ('Court 1 sisa 10 mnt (< 15): hanya Court 2', 50, ['c1']),
    ('Court 1 sudah habis: hanya Court 2', 75, ['c1']),
  ]) {
    test(label, () {
      finishRound();
      now = now.add(Duration(minutes: minutes));
      expect(read().courtsAvailableAt(now).map((c) => c.id), courts);
      final r = next();
      expect(r.courts, courts, reason: 'round baru hanya di court yang masih muat satu match');
      expect(r.played, r.shown, reason: '"Prioritas main di R2" = yang benar-benar main dari yang istirahat');
      expect(r.played.length, 2, reason: '10 pemain, R1 dua court: 2 istirahat, keduanya main di R2');
    });
  }

  test('Court 1 habis → slot R berikutnya 4, jadi daftar dibagi Prioritas / Istirahat lagi', () {
    finishRound();
    now = now.add(const Duration(minutes: 50));
    controller.generateNextRound(); // R2 hanya di Court 2: 6 istirahat
    finishRound();
    final split = EndlessRoundGenerator.restingAfterLastRound(read(), now);
    expect(split.priority.length, 4);
    expect(split.later.length, 2);
    final shown = split.priority.map((p) => p.id).toSet();
    controller.generateNextRound();
    final r3 = read().matchesOfRound(3);
    expect(r3.map((m) => m.courtId), ['c1']);
    expect(<String>{
      for (final m in r3) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
    }, shown);
  });
}
