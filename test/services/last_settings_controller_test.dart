import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/last_settings.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

/// Pengaturan terakhir ditulis sekali per turnamen baru (logic.md §14.7 jebakan 9, docs/data.md → Mexicano):
/// `startIfNeeded` dengan config yang sama dan resume tidak menulis ulang.
void main() {
  final now = DateTime(2026, 11, 12, 19);

  TournamentConfig config(int target) => TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.mixed,
    matchDurationMinutes: 15,
    courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120)],
    players: [for (var i = 0; i < 8; i++) Player(id: 'p$i', name: 'Pemain $i')],
    format: ScoreFormat(ScoringMethod.americano, target),
  );

  ProviderContainer open(TournamentStore store) {
    final container = ProviderContainer(
      overrides: [tournamentStoreProvider.overrideWithValue(store), clockProvider.overrideWithValue(() => now)],
    );
    addTearDown(container.dispose);
    return container;
  }

  test('ditulis saat turnamen baru dimulai; config yang sama dan resume tidak menulis', () async {
    final store = TournamentStore.memory();
    final first = config(24);
    final container = open(store);
    container.read(tournamentProvider.notifier).startIfNeeded(first);
    await pumpEventQueue();
    expect(store.loadLastSettings(SportType.padel)!.format.label, 'Americano 24');
    expect(store.loadLastSettings(SportType.tennis), isNull);

    // Penanda: kalau ada yang menulis ulang, entri kembali ke Americano 24.
    await store.saveLastSettings(SportType.padel, LastSettings.fromConfig(config(32)));
    container.read(tournamentProvider.notifier).startIfNeeded(first);
    await pumpEventQueue();
    expect(store.loadLastSettings(SportType.padel)!.format.label, 'Americano 32');

    final reopened = open(store);
    expect(reopened.read(tournamentProvider), isNotNull, reason: 'turnamen aktif dilanjutkan');
    await pumpEventQueue();
    expect(store.loadLastSettings(SportType.padel)!.format.label, 'Americano 32');
  });
}
