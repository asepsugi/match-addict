import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

/// Tambah/keluarkan pemain di tengah turnamen Mixed.

TournamentConfig _mixedConfig(int players, {int courts = 2}) => TournamentConfig(
      sport: SportType.padel,
      mode: PartnerMode.mixed,
      matchDurationMinutes: 10,
      courts: [
        for (var i = 1; i <= courts; i++)
          Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: 300),
      ],
      players: [for (var i = 0; i < players; i++) Player(id: 'p$i', name: 'Pemain $i')],
    );

/// Isi skor semua match round berjalan lalu generate round berikutnya.
void _playRound(TournamentController c, ActiveTournament Function() read) {
  for (final m in read().matchesOfRound(read().roundCount)) {
    c.submitScore(m.id, const [SetScore(side1: 6, side2: 4)]);
  }
  c.generateNextRound();
}

Map<String, int> _scheduledCounts(ActiveTournament a) {
  final counts = <String, int>{};
  for (final m in a.matches) {
    for (final id in [...m.pair1.playerIds, ...m.pair2.playerIds]) {
      counts[id] = (counts[id] ?? 0) + 1;
    }
  }
  return counts;
}

void main() {
  late ProviderContainer container;
  late TournamentController controller;
  ActiveTournament read() => container.read(tournamentProvider)!;

  setUp(() {
    container = ProviderContainer();
    controller = container.read(tournamentProvider.notifier);
  });
  tearDown(() => container.dispose());

  test('pemain baru ikut round berikutnya tanpa mengulang turnamen', () {
    final config = _mixedConfig(9);
    controller.startIfNeeded(config);
    for (var i = 0; i < 3; i++) {
      _playRound(controller, read);
    }
    final before = read();

    expect(controller.addPlayer('  Zaki  '), isNull);

    final after = read();
    expect(after.tournament.id, before.tournament.id);
    expect(after.matches, hasLength(before.matches.length), reason: 'match lama utuh');
    final zaki = after.config.players.last;
    expect(zaki.name, 'Zaki');
    expect(after.activePlayers, hasLength(10));

    // Layar Konfigurasi masih memegang config awal; masuk lagi lewat sana
    // tidak boleh membuat turnamen baru.
    controller.startIfNeeded(config);
    expect(read().tournament.id, before.tournament.id);
    expect(read().config.players, contains(zaki));
  });

  /// Pola main [id] sejak round [from]: "M" main, "-" istirahat.
  String pattern(ActiveTournament a, String id, int from) => [
        for (var r = from; r <= a.roundCount; r++)
          a.matchesOfRound(r).any((m) => m.pair1.contains(id) || m.pair2.contains(id)) ? 'M' : '-',
      ].join();

  /// Kasus host (2026-10-25): 10 pemain, 2 pemain baru setelah R3. Dulu kredit menyejajarkan mereka dengan yang
  /// paling jarang main, jadi selisihnya tetap selamanya.
  test('pemain telat menyusul: 12 pemain / 2 court → main 3, istirahat 1', () {
    controller.startIfNeeded(_mixedConfig(10));
    for (var i = 0; i < 2; i++) {
      _playRound(controller, read);
    }
    controller.addPlayer('Zaki');
    controller.addPlayer('Yoga');
    final late = read().config.players.skip(10).map((p) => p.id).toList();
    double gap() {
      final counts = _scheduledCounts(read());
      double avg(Iterable<String> ids) => ids.map((id) => counts[id] ?? 0).reduce((a, b) => a + b) / ids.length;
      return avg(read().activePlayers.map((p) => p.id).where((id) => !late.contains(id))) - avg(late);
    }

    _playRound(controller, read);
    final start = gap();
    for (var i = 0; i < 11; i++) {
      _playRound(controller, read);
    }
    for (final id in late) {
      expect(pattern(read(), id, 4), 'MMM-MMM-MMM-');
    }
    expect(gap(), lessThan(start), reason: 'selisih turun, bukan tetap');
  });

  test('1 court: pemain telat langsung menyusul, selisih main ≤ 1', () {
    controller.startIfNeeded(_mixedConfig(10, courts: 1));
    for (var i = 0; i < 2; i++) {
      _playRound(controller, read);
    }
    controller.addPlayer('Zaki');
    controller.addPlayer('Yoga');
    for (var i = 0; i < 12; i++) {
      _playRound(controller, read);
      final counts = _scheduledCounts(read());
      final played = [for (final p in read().activePlayers) counts[p.id] ?? 0]..sort();
      expect(played.last - played.first, lessThanOrEqualTo(1), reason: 'setelah R${read().roundCount}');
    }
  });

  test('pemain keluar tidak dijadwalkan lagi tapi tetap ada di peringkat', () {
    controller.startIfNeeded(_mixedConfig(10));
    _playRound(controller, read);
    final playedP0 = _scheduledCounts(read())['p0'] ?? 0;

    expect(controller.withdrawPlayer('p0'), isTrue);
    for (var i = 0; i < 4; i++) {
      _playRound(controller, read);
    }

    expect(_scheduledCounts(read())['p0'] ?? 0, playedP0);
    expect(container.read(standingsProvider).map((s) => s.player.id), contains('p0'));
  });

  test('tidak bisa mengeluarkan pemain kalau sisa kurang dari 4', () {
    controller.startIfNeeded(_mixedConfig(5));
    expect(controller.withdrawPlayer('p0'), isTrue);
    expect(controller.withdrawPlayer('p1'), isFalse);
    expect(read().activePlayers, hasLength(4));
  });

  test('pemain yang kembali menyusul seperti pemain baru', () {
    controller.startIfNeeded(_mixedConfig(9));
    controller.withdrawPlayer('p0');
    for (var i = 0; i < 4; i++) {
      _playRound(controller, read);
    }

    expect(controller.reinstatePlayer('p0'), isNull);
    expect(read().withdrawnPlayerIds, isNot(contains('p0')));
    expect(read().latePlayerIds, contains('p0'));
    _playRound(controller, read);
    expect(pattern(read(), 'p0', read().roundCount), 'M', reason: 'paling sedikit main → langsung main');
  });

  test('nama duplikat ditolak, termasuk milik pemain yang sudah keluar', () {
    controller.startIfNeeded(_mixedConfig(6));
    expect(controller.addPlayer('pemain 1'), 'Pemain 1 sudah ada di daftar');
    controller.withdrawPlayer('p2');
    expect(controller.addPlayer('Pemain 2'), contains('Kembalikan'));
    expect(controller.addPlayer('   '), isNotNull);
    expect(read().config.players, hasLength(6));
  });

  test('maksimal 30 pemain aktif, juga saat Kembalikan', () {
    controller.startIfNeeded(_mixedConfig(29));
    expect(controller.addPlayer('Zaki'), isNull);
    expect(controller.addPlayer('Yoga'), 'Maksimal 30 pemain aktif');
    controller.withdrawPlayer('p0');
    expect(controller.addPlayer('Yoga'), isNull);
    expect(controller.reinstatePlayer('p0'), 'Maksimal 30 pemain aktif');
  });

  test('daftar keluar ikut tersimpan; payload lama (tanpa daftar, atau dengan kredit 2.6) tetap terbaca', () {
    controller.startIfNeeded(_mixedConfig(9));
    _playRound(controller, read);
    controller.addPlayer('Zaki');
    controller.withdrawPlayer('p3');

    final encoded = TournamentCodec.encode(read());
    final decoded = TournamentCodec.decode(encoded)!;
    expect(decoded.withdrawnPlayerIds, {'p3'});
    expect(decoded.config.players.last.name, 'Zaki');
    expect(decoded.latePlayerIds, read().latePlayerIds);

    // Simpanan dari versi sebelum fitur keluar/masuk tidak punya daftar keluar.
    final legacy = encoded.replaceFirst(RegExp(r',"withdrawn":\[[^\]]*\]'), '');
    expect(legacy, isNot(contains('withdrawn')));
    expect(TournamentCodec.decode(legacy)!.withdrawnPlayerIds, isEmpty);

    // Sampai 2.6 pemain telat dapat kredit; kuncinya diabaikan.
    final withCredits = encoded.replaceFirst(RegExp(r'\}$'), ',"credits":{"p0":2}}');
    expect(TournamentCodec.decode(withCredits)!.config.players, hasLength(10));
  });

  bool plays(MatchGame m, String id) => m.pair1.contains(id) || m.pair2.contains(id);

  test('batalkan round tanpa skor: round dihapus, pemain baru main di round penggantinya', () {
    controller.startIfNeeded(_mixedConfig(12));
    for (var i = 0; i < 2; i++) {
      _playRound(controller, read);
    }
    final before = read();
    expect(before.roundCount, 3);
    expect(before.canCancelLastRound, isTrue);

    controller.addPlayer('Zaki');
    final zakiId = read().config.players.last.id;
    controller.cancelLastRound();

    final cancelled = read();
    expect(cancelled.roundCount, 2, reason: 'R3 dihapus, tidak dibuat ulang');
    expect(cancelled.restingPlayerIdsByRound.containsKey(3), isFalse);
    for (var r = 1; r <= 2; r++) {
      expect(cancelled.matchesOfRound(r), before.matchesOfRound(r), reason: 'R$r utuh');
    }
    expect(cancelled.canGenerateNextRound(DateTime.now()), isTrue);

    controller.generateNextRound();
    expect(read().matchesOfRound(3).any((m) => plays(m, zakiId)), isTrue);
  });

  test('R1 tidak bisa dibatalkan', () {
    controller.startIfNeeded(_mixedConfig(8));
    expect(read().canCancelLastRound, isFalse);

    final before = read();
    controller.cancelLastRound();
    expect(read(), same(before));
  });

  test('pemain yang keluar tidak ikut di round yang dibuat setelah pembatalan', () {
    controller.startIfNeeded(_mixedConfig(9));
    _playRound(controller, read);
    final inRound = read().matchesOfRound(2).first.pair1.playerIds.first;
    controller.withdrawPlayer(inRound);
    controller.cancelLastRound();
    controller.generateNextRound();
    expect(read().matchesOfRound(2).any((m) => plays(m, inRound)), isFalse);
  });

  test('round yang sudah ada skornya tidak bisa dibatalkan', () {
    controller.startIfNeeded(_mixedConfig(9));
    _playRound(controller, read);
    final first = read().matchesOfRound(2).first;
    controller.submitScore(first.id, const [SetScore(side1: 6, side2: 4)]);
    expect(read().canCancelLastRound, isFalse);

    final before = read();
    controller.cancelLastRound();
    expect(read(), same(before));
  });
}
