import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/pair_draft.dart';
import 'package:match_addict/services/schedule/round_robin_generator.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

/// Round tambahan Fixed lewat controller (logic.md §12): TBNE36 = 16 pemain, 2 court 4 jam, 15 menit.
final _players = [for (var i = 0; i < 16; i++) Player(id: 'p$i', name: 'Pemain $i')];
final _pairs = [for (var i = 0; i < 8; i++) Pair(id: 'pair$i', player1Id: 'p${2 * i}', player2Id: 'p${2 * i + 1}')];

TournamentConfig _config() => TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.fixed,
  matchDurationMinutes: 15,
  courts: const [
    Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 240),
    Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 240),
  ],
  players: _players,
  fixedPairs: _pairs,
);

void main() {
  late ProviderContainer container;
  late TournamentController controller;
  late DateTime now;
  final start = DateTime(2026, 11, 3, 19);
  ActiveTournament read() => container.read(tournamentProvider)!;

  setUp(() {
    now = start;
    container = ProviderContainer(
      overrides: [
        tournamentStoreProvider.overrideWithValue(TournamentStore.memory()),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    controller = container.read(tournamentProvider.notifier);
    controller.startIfNeeded(_config());
  });
  tearDown(() => container.dispose());

  void playAll() {
    for (final m in read().matches.where((m) => m.status == MatchStatus.pending)) {
      controller.submitScore(m.id, const [SetScore(side1: 6, side2: 4)]);
    }
  }

  test('baru bisa setelah semua match terisi, dan tidak setelah diakhiri', () {
    expect(read().roundCount, 14);
    expect(read().canAddRounds, isFalse);
    playAll();
    expect(read().canAddRounds, isTrue);
    expect(read().isFinal(now), isTrue);

    controller.finishNow();
    expect(read().canAddRounds, isFalse);
  });

  test('sisa 30 menit: R15–R16, turnamen kembali Sementara, tambahan berikutnya melanjutkan putaran', () {
    playAll();
    now = start.add(const Duration(minutes: 210));
    controller.addRounds(const {});
    expect(read().roundCount, 16);
    expect(read().extraPutaran, 1);
    expect(read().currentRound, 15);
    expect(read().isFinal(now), isFalse);
    expect(read().canAddRounds, isFalse);

    // Putaran berikutnya = circle round kedua (lawan R3–R4), dengan 1 jam tambahan di Court 1 saja.
    playAll();
    now = now.add(const Duration(minutes: 30));
    controller.addRounds(const {'c1': 60});
    final r17 = read().matchesOfRound(17);
    final r3 = read().matchesOfRound(3);
    expect([for (final m in r17) m.pair1.id + m.pair2.id], [r3.first.pair1.id + r3.first.pair2.id]);
    expect(r17.single.courtId, 'c1');
    expect(read().roundCount, 20);
    // Booking Court 1 sudah habis di menit 240, jadi dipesan ulang dari sekarang (seperti Lanjutkan).
    expect(read().config.courts.first.endMinute, 300);
    expect(read().extraPutaran, 2);
  });

  test('waktu habis tanpa tambahan jam: tidak ada yang dibuat', () {
    playAll();
    now = start.add(const Duration(minutes: 250));
    controller.addRounds(const {});
    expect(read().roundCount, 14);
    controller.addRounds(const {'c2': 60});
    expect(read().roundCount, 18); // 4 round di Court 2 = 1 putaran
    expect(read().matchesOfRound(15).map((m) => m.courtId), ['c2']);
  });

  group('atur pasangan (04f–04h)', () {
    test('Budi pulang, Rizky masuk: pasangan baru di slot lama, Klasemen campuran', () {
      playAll();
      now = start.add(const Duration(minutes: 210));
      final active = read();
      var draft = PairDraft.of(active.config).split(_pairs[0]);
      expect(draft.unpaired.map((p) => p.id), ['p0', 'p1']);
      final added = draft.add('  rizky h ', id: 'p16');
      expect(added.error, isNull);
      draft = added.draft!;
      expect(draft.add('pemain 3', id: 'x').error, 'Pemain 3 sudah ada di daftar');
      draft = draft.pair(draft.unpaired.first, draft.unpaired.last, id: 'pair-new');
      expect(draft.pairs.first.playerIds, ['p0', 'p16']);
      expect(draft.unpaired.map((p) => p.name), ['Pemain 1']);
      expect(draft.changedFrom(_pairs), isTrue);

      controller.addRounds(const {}, pairs: draft.pairs, newPlayers: draft.added);
      final after = read();
      expect(after.config.players.last.name, 'rizky h');
      // Lawan R15 = lawan R1, dengan Andi + Rizky di tempat Andi + Budi.
      final r1 = after.matchesOfRound(1), r15 = after.matchesOfRound(15);
      expect(r15.first.pair1.id, 'pair-new');
      expect(r15.first.pair2.id, r1.first.pair2.id);
      expect(r15.expand((m) => m.pair1.playerIds + m.pair2.playerIds), isNot(contains('p1')));

      // Pasangan yang tidak berubah tetap satu baris; Andi, Budi, Rizky sendiri-sendiri.
      expect(after.standingPairs.map((p) => p.id), [for (var i = 1; i < 8; i++) 'pair$i']);
      final rows = container.read(standingEntriesProvider);
      expect(rows.where((e) => e.players.length == 2), hasLength(7));
      expect(
        rows.where((e) => e.players.length == 1).map((e) => e.players.single.id),
        unorderedEquals(['p0', 'p1', 'p16']),
      );

      // Round lama tetap menemukan pasangan istirahat/nama dari match-nya.
      expect(after.pairById('pair0')?.playerIds, ['p0', 'p1']);

      // Simpanan membawa putaran tambahan; pemain yang tidak ikut lagi muncul belum berpasangan di Atur berikutnya.
      final restored = TournamentCodec.decode(TournamentCodec.encode(after))!;
      expect(restored.extraPutaran, 1);
      expect(PairDraft.of(restored.config).unpaired.map((p) => p.id), ['p1']);
    });

    test('pasangan yang tidak diubah = sama', () {
      final draft = PairDraft.of(_config());
      expect(draft.changedFrom(_pairs), isFalse);
      final split = draft.split(_pairs[3]);
      expect(split.changedFrom(_pairs), isTrue);
      // Dipasangkan lagi seperti semula → sama, di slot yang sama.
      final back = split.pair(split.unpaired[0], split.unpaired[1], id: 'again');
      expect(back.changedFrom(_pairs), isFalse);
      expect(back.slots.indexWhere((p) => p?.id == 'again'), 3);
    });

    test('jumlah pasangan berubah: estimasi ikut daftar baru', () {
      playAll();
      now = start.add(const Duration(minutes: 210));
      var draft = PairDraft.of(read().config).split(_pairs[0]);
      // Dua pemain tidak ikut → 7 pasangan, ganjil: tiap pasangan +2, 7 match di 2 court.
      final plan = RoundRobinGenerator.extraRounds(read(), now, pairs: draft.pairs);
      expect(plan.perPair, 2);
      expect(plan.schedule.matches, hasLength(7));
      expect(draft.pairs, hasLength(7));
    });
  });
}
