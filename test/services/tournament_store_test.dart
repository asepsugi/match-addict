import 'dart:convert';
import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

/// Turnamen Fixed dengan satu match selesai, satu WO, satu belum dimain —
/// cukup untuk menyentuh semua cabang serialisasi.
ActiveTournament _sample({String? name}) {
  const players = [
    Player(id: 'p1', name: 'Andi'),
    Player(id: 'p2', name: 'Budi'),
    Player(id: 'p3', name: 'Citra'),
    Player(id: 'p4', name: 'Dewi'),
  ];
  const pairA = Pair(id: 'pairA', player1Id: 'p1', player2Id: 'p2');
  const pairB = Pair(id: 'pairB', player1Id: 'p3', player2Id: 'p4');

  return ActiveTournament(
    tournament: Tournament(
      id: 't1',
      createdAt: DateTime(2026, 9, 18, 7, 30),
      config: TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.fixed,
        matchDurationMinutes: 15,
        courts: const [
          Court(id: 'c1', name: 'Merah', colorIndex: 2, bookingDurationMinutes: 120),
        ],
        players: players,
        fixedPairs: const [pairA, pairB],
        name: name,
      ),
      matches: const [
        MatchGame(
          id: 'm1',
          roundNumber: 1,
          matchNumberInRound: 1,
          courtId: 'c1',
          pair1: pairA,
          pair2: pairB,
          sets: [SetScore(side1: 6, side2: 4), SetScore(side1: 3, side2: 6)],
          status: MatchStatus.done,
        ),
        MatchGame(
          id: 'm2',
          roundNumber: 2,
          matchNumberInRound: 1,
          courtId: 'c1',
          pair1: pairA,
          pair2: pairB,
          status: MatchStatus.wo,
          woLoserPairId: 'pairB',
          woReason: WoReason.injury,
        ),
        MatchGame(
          id: 'm3',
          roundNumber: 3,
          matchNumberInRound: 1,
          courtId: 'c1',
          pair1: pairA,
          pair2: pairB,
        ),
      ],
    ),
    byePairIdByRound: const {2: 'pairA'},
    restingPlayerIdsByRound: const {3: ['p3', 'p4']},
  );
}

void main() {
  group('TournamentCodec', () {
    test('round-trip mempertahankan seluruh isi turnamen', () {
      final original = _sample();
      final restored = TournamentCodec.decode(TournamentCodec.encode(original))!;

      // Perbandingan menyeluruh: model tidak punya `==`, jadi hasil encode ulang
      // yang dibandingkan.
      expect(TournamentCodec.encode(restored), TournamentCodec.encode(original));
    });

    test('skor, WO, bye, dan resting kembali utuh', () {
      final restored = TournamentCodec.decode(TournamentCodec.encode(_sample()))!;

      expect(restored.config.sport, SportType.padel);
      expect(restored.config.fixedPairs!.map((p) => p.id), ['pairA', 'pairB']);
      expect(restored.tournament.createdAt, DateTime(2026, 9, 18, 7, 30));

      final done = restored.matchById('m1')!;
      expect(done.sets.map((s) => '${s.side1}-${s.side2}'), ['6-4', '3-6']);

      final wo = restored.matchById('m2')!;
      expect(wo.status, MatchStatus.wo);
      expect(wo.woLoserPairId, 'pairB');
      expect(wo.woReason, WoReason.injury);
      expect(wo.winnerPairId, 'pairA');

      expect(restored.matchById('m3')!.status, MatchStatus.pending);
      expect(restored.byePairIdByRound, {2: 'pairA'});
      expect(restored.restingPlayerIdsByRound, {
        3: ['p3', 'p4'],
      });
    });

    test('nama turnamen ikut tersimpan; tanpa nama tidak menulis kuncinya (simpanan sebelum 2.3 terbaca null)', () {
      final named = TournamentCodec.decode(TournamentCodec.encode(_sample(name: 'PB Garuda x Matcha Club')))!;
      expect(named.config.name, 'PB Garuda x Matcha Club');
      final config = (jsonDecode(TournamentCodec.encode(_sample())) as Map)['tournament']['config'] as Map;
      expect(config.containsKey('name'), isFalse);
      expect(TournamentCodec.decode(TournamentCodec.encode(_sample()))!.config.name, isNull);
    });

    test('payload kosong, rusak, atau beda skema dibuang, bukan melempar', () {
      expect(TournamentCodec.decode(null), isNull);
      expect(TournamentCodec.decode(''), isNull);
      expect(TournamentCodec.decode('{bukan json'), isNull);
      expect(TournamentCodec.decode('{"schema":999,"tournament":{}}'), isNull);
      // Terpotong di tengah tulis.
      final half = TournamentCodec.encode(_sample());
      expect(TournamentCodec.decode(half.substring(0, half.length ~/ 2)), isNull);
    });

    test('roundNumber di luar 1..maxRoundNumber ditolak (security #4: tab penonton membeku)', () {
      String withRound(int round) {
        final json = jsonDecode(TournamentCodec.encode(_sample())) as Map<String, dynamic>;
        (json['tournament']['matches'] as List).last['roundNumber'] = round;
        return jsonEncode(json);
      }

      expect(TournamentCodec.decode(withRound(TournamentCodec.maxRoundNumber)), isNotNull);
      expect(TournamentCodec.decode(withRound(TournamentCodec.maxRoundNumber + 1)), isNull);
      expect(TournamentCodec.decode(withRound(1000000000)), isNull);
      expect(TournamentCodec.decode(withRound(0)), isNull);
      expect(TournamentCodec.decode(withRound(-1)), isNull);
    });

    test('encode menolak roundNumber di luar batas, simetris dengan decode', () {
      final sample = _sample();
      final last = sample.matches.last;
      final far = MatchGame(
        id: last.id,
        roundNumber: TournamentCodec.maxRoundNumber + 1,
        matchNumberInRound: last.matchNumberInRound,
        courtId: last.courtId,
        pair1: last.pair1,
        pair2: last.pair2,
      );
      final broken = sample.copyWith(
        tournament: sample.tournament.copyWith(matches: [...sample.matches.take(sample.matches.length - 1), far]),
      );
      expect(TournamentCodec.canEncode(broken), isFalse);
      expect(() => TournamentCodec.encode(broken), throwsA(isA<UnreadableTournamentError>()));
    });
  });

  group('TournamentStore (Hive)', () {
    late Directory dir;
    late Box<String> box;

    setUp(() async {
      dir = await Directory.systemTemp.createTemp('mabar_store_test');
      Hive.init(dir.path);
      box = await Hive.openBox<String>(TournamentStore.boxName);
    });

    tearDown(() async {
      await Hive.deleteFromDisk();
      await Hive.close();
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    test('turnamen aktif bertahan lintas instance store', () async {
      await TournamentStore(box).saveActive(_sample());

      // Store baru di atas box yang sama = app dibuka ulang.
      final resumed = TournamentStore(box).loadActive();
      expect(resumed, isNotNull);
      expect(resumed!.tournament.id, 't1');
      expect(resumed.playedMatchCount, 2);
    });

    test('menutup turnamen memindahkannya ke slot terakhir selesai', () async {
      final store = TournamentStore(box);
      await store.saveActive(_sample());
      await store.archiveActive(_sample());

      expect(store.loadActive(), isNull);
      expect(store.loadLastFinished()!.tournament.id, 't1');
    });
  });

  group('TournamentController', () {
    ProviderContainer containerWith(TournamentStore store) {
      final container = ProviderContainer(
        overrides: [tournamentStoreProvider.overrideWithValue(store)],
      );
      addTearDown(container.dispose);
      return container;
    }

    test('setiap perubahan skor langsung tersimpan', () {
      final store = TournamentStore.memory();
      final container = containerWith(store);

      container.read(tournamentProvider.notifier).startIfNeeded(_sample().config);
      expect(store.loadActive(), isNotNull);

      final matchId = container.read(tournamentProvider)!.matches.first.id;
      container
          .read(tournamentProvider.notifier)
          .submitScore(matchId, const [SetScore(side1: 6, side2: 2)]);

      expect(store.loadActive()!.matchById(matchId)!.status, MatchStatus.done);
    });

    test('app dibuka ulang melanjutkan turnamen yang tersimpan', () {
      final store = TournamentStore.memory();
      final first = containerWith(store);
      first.read(tournamentProvider.notifier).startIfNeeded(_sample().config);
      final id = first.read(tournamentProvider)!.tournament.id;

      // Container kedua = proses baru setelah app di-kill.
      final resumed = containerWith(store).read(tournamentProvider);
      expect(resumed!.tournament.id, id);
    });

    test('menutup turnamen mengosongkan slot aktif tanpa membuang hasilnya', () async {
      final store = TournamentStore.memory();
      final container = containerWith(store);
      container.read(tournamentProvider.notifier).startIfNeeded(_sample().config);
      await container.read(tournamentProvider.notifier).close();

      expect(container.read(tournamentProvider), isNull);
      expect(store.loadActive(), isNull);
      expect(store.loadLastFinished(), isNotNull);
    });
  });
}
