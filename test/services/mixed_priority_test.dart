import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';

/// Jadwal Mixed desain v2 (design/spec/logic.md §5–§7): undian pemain seri dikunci per round, jeda pemain telat,
/// daftar Istirahat sama persis dengan hasil "Buat R…", estimasi Lanjutkan, dan WO/skor yang menimpa.

TournamentConfig _config({int players = 10, int courts = 2, int booking = 120}) => TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.mixed,
  matchDurationMinutes: 15,
  courts: [
    for (var i = 0; i < courts; i++)
      Court(id: 'c$i', name: i == 1 ? 'Court VIP' : 'Court ${i + 1}', colorIndex: i, bookingDurationMinutes: booking),
  ],
  players: [for (var i = 0; i < players; i++) Player(id: 'p${i.toString().padLeft(2, '0')}', name: 'Pemain $i')],
);

void main() {
  late ProviderContainer container;
  late TournamentController controller;
  late DateTime now;
  ActiveTournament read() => container.read(tournamentProvider)!;

  setUp(() {
    now = DateTime(2026, 10, 22, 19);
    container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
    controller = container.read(tournamentProvider.notifier);
  });
  tearDown(() => container.dispose());

  /// Isi skor round terakhir; round dianggap makan satu durasi match (15 menit) jam sungguhan.
  void scoreRound() {
    for (final m in read().matchesOfRound(read().roundCount)) {
      controller.submitScore(m.id, const [SetScore(side1: 6, side2: 4)]);
    }
    now = now.add(const Duration(minutes: 15));
  }

  List<String> order(ActiveTournament a, int round, {int? seed}) => EndlessRoundGenerator.priorityOrder(
    players: a.activePlayers,
    history: a.matches,
    roundNumber: round,
    seed: seed ?? a.drawSeed,
    slots: EndlessRoundGenerator.slotsFor(players: a.activePlayers.length, courts: a.config.courts.length),
    latePlayerIds: a.latePlayerIds,
  ).map((p) => p.id).toList();

  group('undian dikunci per round', () {
    test('seed turunan id turnamen: tetap, beda tiap turnamen, sama di VM dan web (FNV-1a)', () {
      ActiveTournament withId(String id) =>
          ActiveTournament(tournament: Tournament(id: id, createdAt: DateTime(2026), config: _config()));
      expect(withId('t1').drawSeed, 138734806);
      expect(withId('t1').drawSeed, withId('t1').drawSeed);
      expect(withId('t2').drawSeed, isNot(withId('t1').drawSeed));
    });

    test('dua kali dihitung untuk round yang sama → urutan identik; round lain → undian lain', () {
      controller.startIfNeeded(_config(players: 20, courts: 1));
      final a = read();
      // Semua pemain seri di awal (0 main), jadi urutannya murni undian.
      expect(order(a, 1), order(a, 1));
      expect(order(a, 2), isNot(order(a, 1)));
      expect(order(a, 1, seed: a.drawSeed + 1000), isNot(order(a, 1)));
    });

    test('urutan tidak bergantung urutan daftar pemain', () {
      controller.startIfNeeded(_config(players: 12, courts: 2));
      final a = read();
      final reversed = EndlessRoundGenerator.priorityOrder(
        players: a.activePlayers.reversed.toList(),
        history: a.matches,
        roundNumber: 2,
        seed: a.drawSeed,
        slots: 8,
      ).map((p) => p.id).toList();
      expect(reversed, order(a, 2));
    });
  });

  group('pemain telat menyusul dengan jeda', () {
    /// Posisi Zaki di urutan R(top + 1): [players] pemain aktif, [courts] court. Pemain lain main di R1–R[top]
    /// (lawannya pengisi di luar daftar), Zaki main di [run] round terakhir saja.
    int position({required int players, required int courts, required int run, required int top, bool late = true}) {
      final others = [for (var i = 0; i < players - 1; i++) Player(id: 'p${i.toString().padLeft(2, '0')}', name: 'P$i')];
      const zaki = Player(id: 'z', name: 'Zaki');
      MatchGame match(int round, String id) => MatchGame(
        id: 'm-$round-$id',
        roundNumber: round,
        matchNumberInRound: 1,
        courtId: 'c0',
        pair1: Pair(id: '$id+x1', player1Id: id, player2Id: 'x1'),
        pair2: const Pair(id: 'x2+x3', player1Id: 'x2', player2Id: 'x3'),
      );
      final order = EndlessRoundGenerator.priorityOrder(
        players: [...others, zaki],
        history: [
          for (var r = 1; r <= top; r++) ...[
            for (final p in others) match(r, p.id),
            if (r > top - run) match(r, zaki.id),
          ],
        ],
        roundNumber: top + 1,
        seed: 1,
        slots: EndlessRoundGenerator.slotsFor(players: players, courts: courts),
        latePlayerIds: late ? {zaki.id} : const {},
      );
      return order.indexWhere((p) => p.id == zaki.id);
    }

    // Jeda setelah k round beruntun: k = 2, atau satu lebih dari slot ÷ yang istirahat (12 pemain / 2 court → 3).
    for (final (players, courts, k) in [(12, 1, 2), (14, 2, 2), (12, 2, 3), (14, 3, 7)]) {
      test('$players pemain, $courts court: istirahat setelah $k round beruntun', () {
        expect(position(players: players, courts: courts, run: k, top: k + 1), players - 1);
        expect(position(players: players, courts: courts, run: k - 1, top: k + 1), 0);
      });
    }

    test('hanya pemain telat yang masih tertinggal', () {
      // Hadir sejak awal: undian seri kadang memberi k round beruntun, tidak dipotong.
      expect(position(players: 12, courts: 2, run: 3, top: 4, late: false), 0);
      // Sudah menyusul (sama dengan yang paling banyak main): ikut urutan biasa.
      expect(
        position(players: 12, courts: 2, run: 3, top: 3),
        position(players: 12, courts: 2, run: 3, top: 3, late: false),
      );
    });

    test('semua main tiap round (12 pemain, 3 court): tidak ada yang bisa diistirahatkan', () {
      expect(position(players: 12, courts: 3, run: 9, top: 11), 0);
    });

    test('pemain telat = absen di round yang sudah dibuat, termasuk yang kembali', () {
      controller.startIfNeeded(_config(players: 12));
      scoreRound();
      controller.generateNextRound();
      expect(read().latePlayerIds, isEmpty);

      controller.withdrawPlayer('p00');
      expect(controller.addPlayer('Zaki'), isNull);
      final zaki = read().config.players.last.id;
      expect(read().latePlayerIds, {zaki}, reason: 'p00 keluar, tidak aktif');

      scoreRound();
      controller.generateNextRound();
      controller.reinstatePlayer('p00');
      expect(read().latePlayerIds, {zaki, 'p00'});
    });
  });

  group('daftar istirahat round terakhir', () {
    test('06o: 20 pemain 2 court — 12 istirahat, 8 prioritas main di R2, 4 istirahat lagi', () {
      controller.startIfNeeded(_config(players: 20, courts: 2));
      final rest = EndlessRoundGenerator.restingAfterLastRound(read(), now);
      expect((rest.priority.length, rest.later.length), (8, 4));
      // Urut seperti daftar pemain, bukan urutan prioritas.
      final ids = [for (final p in rest.priority) p.id];
      expect(ids, [...ids]..sort());
    });

    test('hasil "Buat R2" sama persis dengan daftar yang tampil sebelumnya', () {
      controller.startIfNeeded(_config(players: 20, courts: 2));
      scoreRound();
      final rest = EndlessRoundGenerator.restingAfterLastRound(read(), now);
      controller.generateNextRound();
      final playing = {
        for (final m in read().matchesOfRound(2)) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
      };
      expect(playing.containsAll(rest.priority.map((p) => p.id)), isTrue);
      expect(playing.intersection(rest.later.map((p) => p.id).toSet()), isEmpty);
    });

    test('semua kebagian slot → hanya daftar pertama (10 pemain, 2 court)', () {
      controller.startIfNeeded(_config());
      final rest = EndlessRoundGenerator.restingAfterLastRound(read(), now);
      expect((rest.priority.length, rest.later.length), (2, 0));
    });

    test('dihitung dari pemain aktif sekarang: yang keluar hilang, yang baru langsung masuk', () {
      controller.startIfNeeded(_config());
      final resting = EndlessRoundGenerator.restingAfterLastRound(read(), now).priority.map((p) => p.id).toList();
      controller.withdrawPlayer(resting.first);
      expect(controller.addPlayer('Gilang'), isNull);
      final rest = EndlessRoundGenerator.restingAfterLastRound(read(), now);
      final names = [...rest.priority, ...rest.later].map((p) => p.name);
      expect(names, contains('Gilang'));
      expect([...rest.priority, ...rest.later].map((p) => p.id), isNot(contains(resting.first)));
    });

    test('06l: waktu habis tetap menampilkan prioritas (slot dari semua court)', () {
      // Booking 15 menit = cuma R1.
      controller.startIfNeeded(_config(booking: 15));
      scoreRound();
      expect(read().courtsAvailableAt(now), isEmpty);
      expect(EndlessRoundGenerator.restingAfterLastRound(read(), now).priority, hasLength(2));
    });
  });

  test('08c: Court 1 +1 jam, Court VIP +0, 10 pemain → 4 round (R9–R12), 1 court, 4 match, tidak "berkurang"', () {
    controller.startIfNeeded(_config());
    for (var r = 1; r <= 8; r++) {
      scoreRound();
      controller.generateNextRound();
    }
    scoreRound();
    expect(read().roundCount, 8);
    expect(
      read().capacityAhead(now, {'c0': 60}),
      (rounds: 4, matches: 4, courts: 1, fewerCourtsFrom: null, matchesPerRound: 2),
    );
  });

  group('skor & WO menimpa match', () {
    test('alasan WO yang dilepas benar-benar hilang', () {
      controller.startIfNeeded(_config());
      final m = read().matchesOfRound(1).first;
      controller.markWalkover(m.id, loserPairId: m.pair1.id, reason: WoReason.injury);
      expect(read().matchById(m.id)!.woReason, WoReason.injury);
      controller.markWalkover(m.id, loserPairId: m.pair2.id);
      final wo = read().matchById(m.id)!;
      expect((wo.status, wo.woLoserPairId, wo.woReason), (MatchStatus.wo, m.pair2.id, null));
    });

    test('menyimpan skor di match WO mengubahnya jadi match biasa', () {
      controller.startIfNeeded(_config());
      final m = read().matchesOfRound(1).first;
      controller.markWalkover(m.id, loserPairId: m.pair1.id, reason: WoReason.absent);
      controller.submitScore(m.id, const [SetScore(side1: 6, side2: 4)]);
      final done = read().matchById(m.id)!;
      expect((done.status, done.woLoserPairId, done.woReason), (MatchStatus.done, null, null));
      expect(done.winnerPairId, m.pair1.id);
    });
  });
}
