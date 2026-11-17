import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi/screens/grup_gugur_fixture.dart';
import '../hifi/screens/schedule_fixture.dart' show LoadedTournament;

/// Controller + provider Grup + Gugur (GG-4; logic.md §18.8, 18.10, 18.12 #2 #6 #7) dan fixture golden bersama.

/// Ringkasan match untuk dibandingkan antar jalur: round, court, kode fase, sisi, skor, status.
List<String> _shape(ActiveTournament a) => [
  for (final m in a.matches)
    '${m.id} R${m.roundNumber} ${m.courtId} ${m.phase?.code} ${m.pair1.id}–${m.pair2.id} '
        '${m.sets.map((s) => '${s.side1}-${s.side2}').join(',')} ${m.status.name} ${m.woLoserPairId}',
];

void main() {
  late ProviderContainer container;
  late TournamentStore store;
  ActiveTournament read() => container.read(tournamentProvider)!;
  TournamentController controller() => container.read(tournamentProvider.notifier);

  ProviderContainer open({ActiveTournament? loaded, DateTime? now}) => ProviderContainer(
    overrides: [
      tournamentStoreProvider.overrideWithValue(store),
      clockProvider.overrideWithValue(() => now ?? ggStart),
      if (loaded != null) tournamentProvider.overrideWith(() => LoadedTournament(loaded)),
    ],
  );

  /// Ganti container (layar lain / app dibuka lagi); yang lama dibuang.
  void reopen({ActiveTournament? loaded, DateTime? now}) {
    container.dispose();
    container = open(loaded: loaded, now: now);
  }

  setUp(() {
    store = TournamentStore.memory();
    container = open();
  });
  tearDown(() => container.dispose());

  /// Skor match grup [a]–[b] lewat controller ([sa] milik [a]).
  void play(String a, String b, int sa, int sb) {
    final m = read().matches.firstWhere((m) => m.phase is GroupPhase && {m.pair1.id, m.pair2.id}.containsAll([a, b]));
    controller().submitScore(m.id, [m.pair1.id == a ? SetScore(side1: sa, side2: sb) : SetScore(side1: sb, side2: sa)]);
  }

  String idOf(String code) => read().byCode(code).id;
  void ko(String code, int s1, int s2) => controller().submitScore(idOf(code), [SetScore(side1: s1, side2: s2)]);

  /// 12 match grup 16D-ii + 16E (= `groups16E`).
  void playGroups16E() {
    play('Andi', 'Citra', 6, 4);
    play('Andi', 'Eko', 6, 3);
    play('Gita', 'Andi', 6, 4);
    play('Citra', 'Eko', 6, 3);
    play('Citra', 'Gita', 6, 4);
    play('Indra', 'Maya', 6, 4);
    play('Indra', 'Kiki', 6, 2);
    play('Indra', 'Oki', 6, 1);
    play('Maya', 'Kiki', 6, 3);
    play('Maya', 'Oki', 6, 2);
    play('Kiki', 'Oki', 6, 4);
    expect(read().canCreateBracket, isFalse, reason: 'R6 Court 1 masih Belum');
    play('Eko', 'Gita', 6, 2);
  }

  test('20a startIfNeeded: jadwal fase grup = fixture, tanpa bye, tanpa Tambah round', () {
    final config = gg20a().config;
    controller().startIfNeeded(config);
    expect(_shape(read()), _shape(gg20a()));
    expect(read().byePairIdByRound, isEmpty);
    expect(read().restingPairIdsByRound, isEmpty);
    expect(read().roundCount, 6);
    expect(read().canAddRounds, isFalse);
    // R1: Andi–Gita (Court 1, Grup A), Indra–Oki (Court 2, Grup B).
    expect(read().matchesOfRound(1).map((m) => '${m.phase?.code} ${m.pair1.id}–${m.pair2.id}'), [
      'A Andi–Gita',
      'B Indra–Oki',
    ]);
  });

  test('AC-G6 AC-G9 AC-G12 AC-G14 alur penuh 16A lewat controller = fixture golden', () {
    controller().startIfNeeded(gg20a().config);
    playGroups16E();
    expect(_shape(read()), _shape(gg20e()));
    // 20e/20f: semua grup terisi tetap Sementara, Buat bagan tersedia, tanpa Tambah round.
    expect(read().canCreateBracket, isTrue);
    expect(read().isFinal(ggStart), isFalse);
    expect(read().canAddRounds, isFalse);

    expect(controller().createBracket(), isTrue);
    expect(_shape(read()), _shape(gg21a()));
    expect(read().canCreateBracket, isFalse);
    expect(controller().createBracket(), isFalse, reason: 'bagan hanya sekali');
    expect(read().sides('SF1'), 'Andi–Maya');
    expect(read().sides('SF2'), 'Indra–Citra');
    expect(read().sides('F'), '?–?');

    // AC-G12: skor grup terkunci setelah bagan — skor maupun WO.
    final locked = read();
    final group = locked.matches.first;
    controller().submitScore(group.id, [const SetScore(side1: 6, side2: 0)]);
    controller().markWalkover(group.id, loserPairId: group.pair1.id);
    expect(identical(read(), locked), isTrue);

    // Sisi tbd belum bisa diisi (Final sebelum SF ada hasil).
    ko('F', 9, 7);
    expect(identical(read(), locked), isTrue);

    ko('SF1', 6, 4);
    expect(_shape(read()), _shape(gg21c()));
    expect(read().sides('F'), 'Andi–?');
    expect(read().sides('J3'), 'Maya–?');

    ko('SF2', 4, 6);
    expect(_shape(read()), _shape(gg21f()));
    expect(read().sides('F'), 'Andi–Citra');
    expect(read().sides('J3'), 'Maya–Indra');

    // AC-G9: SF1 jadi 4–6 sebelum R8 ada skor → boleh, Final dan Juara 3 ikut berganti di state yang sama.
    ko('SF1', 4, 6);
    expect(read().sides('F'), 'Maya–Citra');
    expect(read().sides('J3'), 'Andi–Indra');
    ko('SF1', 6, 4);
    expect(_shape(read()), _shape(gg21f()));

    // Final 7–9 tersimpan → membalik SF1 ditolak; pemenang sama boleh.
    ko('F', 7, 9);
    final withFinal = read();
    ko('SF1', 4, 6);
    expect(identical(read(), withFinal), isTrue);
    controller().markWalkover(idOf('SF1'), loserPairId: 'Andi');
    expect(identical(read(), withFinal), isTrue, reason: 'WO yang membalik pemenang juga ditolak');
    ko('SF1', 6, 5);
    expect(read().byCode('SF1').sets.single.side2, 5);
    expect(read().sides('F'), 'Andi–Citra');
    ko('SF1', 6, 4);

    // Final tanpa dependent: ganti pemenang selalu boleh.
    ko('F', 9, 7);
    expect(read().byCode('F').winnerPairId, 'Andi');
    ko('F', 7, 9);

    expect(read().isFinal(ggStart), isFalse, reason: 'Juara 3 masih Belum (AC-G14)');
    ko('J3', 4, 2);
    expect(read().isFinal(ggStart), isTrue);
    expect(_shape(read()), _shape(gg21i()));

    // 16F lewat standingEntriesProvider (nomor = finalEntries, bukan standingsProvider).
    final entries = container.read(standingEntriesProvider);
    expect(
      [for (final e in entries) '${e.position} ${e.label.split(' ').first} ${e.stage}'],
      [
        '1 Citra Juara',
        '2 Andi Final',
        '3 Maya Juara 3',
        '4 Indra Semifinal',
        '5 Eko Grup A · 3',
        '5 Kiki Grup B · 3',
        '6 Gita Grup A · 4',
        '6 Oki Grup B · 4',
      ],
    );
  });

  test('skor gugur seri / tanpa pemenang ditolak (I9)', () {
    reopen(loaded: gg21a());
    final before = read();
    ko('SF1', 5, 5);
    expect(identical(read(), before), isTrue);
  });

  test('AC-G11 SF2 WO Indra → Citra ke Final, Indra ke Juara 3; tabel grup tetap', () {
    reopen(loaded: gg21c());
    final tables = container.read(groupTablesProvider);
    controller().markWalkover(idOf('SF2'), loserPairId: 'Indra', reason: WoReason.injury);
    expect(read().sides('F'), 'Andi–Citra');
    expect(read().sides('J3'), 'Maya–Indra');
    final after = container.read(groupTablesProvider);
    expect([for (final t in after) t.pairIds], [for (final t in tables) t.pairIds]);
  });

  test('AC-G7 16D-iii: tanpa pilihan host state tidak berubah; dengan pilihan A2 = Eko', () {
    reopen(loaded: gg20h(), now: at20e);
    final before = read();
    expect(before.canCreateBracket, isTrue);
    expect(controller().createBracket(), isFalse);
    expect(
      controller().createBracket({
        0: ['Andi'],
      }),
      isFalse,
      reason: 'bukan kandidat',
    );
    expect(identical(read(), before), isTrue);

    expect(
      controller().createBracket({
        0: ['Eko'],
      }),
      isTrue,
    );
    expect(read().sides('SF1'), 'Andi–Maya');
    expect(read().sides('SF2'), 'Indra–Eko');
  });

  test('20l: seri tiga di #1 → host memilih A1 lalu A2', () {
    reopen(loaded: gg20l(), now: at20e);
    expect(
      controller().createBracket({
        0: ['Eko'],
      }),
      isFalse,
      reason: 'perlu dua ketukan',
    );
    expect(
      controller().createBracket({
        0: ['Eko', 'Andi'],
      }),
      isTrue,
    );
    expect(read().sides('SF1'), 'Eko–Maya');
    expect(read().sides('SF2'), 'Indra–Andi');
  });

  test('finishNow di fase grup (20q): bagan tidak dibuat, Final; di gugur: Final/Juara 3 tbd → cancelled', () {
    reopen(loaded: gg20b(), now: at20b);
    play('Indra', 'Maya', 6, 4);
    play('Gita', 'Citra', 4, 6);
    controller().finishNow();
    expect(_shape(read()), _shape(gg20q()));
    expect(read().hasBracket, isFalse);
    expect(read().canCreateBracket, isFalse);
    expect(read().isFinal(at20b), isTrue);
    reopen(loaded: gg21c(), now: at21b);
    controller().finishNow();
    expect(read().byCode('F').status, MatchStatus.cancelled);
    expect(read().byCode('SF2').status, MatchStatus.cancelled);
    expect(read().sides('F'), 'Andi–?', reason: 'sisi tbd tetap, hanya status berubah');
    expect(read().isFinal(at21b), isTrue);
  });

  test('groupTablesProvider: satu tabel per grup di Grup + Gugur, kosong di turnamen lain', () {
    reopen(loaded: gg20b(), now: at20b);
    final tables = container.read(groupTablesProvider);
    expect([for (final t in tables) t.group], [0, 1]);
    expect(tables.first.pairIds.toSet(), {'Andi', 'Citra', 'Eko', 'Gita'});
    reopen();
    controller().startIfNeeded(
      TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.fixed,
        matchDurationMinutes: 15,
        courts: courtsOf(1),
        players: [
          for (final n in ['Andi', 'Budi', 'Citra', 'Dewi']) Player(id: n, name: n),
        ],
        fixedPairs: [pairOf('Andi'), pairOf('Citra')],
      ),
    );
    expect(container.read(groupTablesProvider), isEmpty);
    expect(container.read(standingEntriesProvider), isNotEmpty);
  });

  test('jebakan #6: pairById(\'\') = null walau ada sisi tbd', () {
    final a = gg21a();
    expect(a.matches.any((m) => m.pair1.isTbd), isTrue);
    expect(a.pairById(''), isNull);
    expect(a.pairById('Andi')?.player2Id, 'Budi');
  });

  test('MatchGame.copyWith(pair1, pair2) membawa fase, skor, dan WO', () {
    final m = gg21c().byCode('F');
    final next = m.copyWith(pair2: pairOf('Citra'));
    expect(next.phase, m.phase);
    expect(next.pair1.id, 'Andi');
    expect(next.pair2.id, 'Citra');
    expect(KnockoutBracket.isResolved(gg21f().config, gg21f().matches), isTrue);
  });

  group('fixture golden', () {
    test('20b 5 dari 12 match, 20m 7 dari 12 (Tono belum main), 20o semua terisi', () {
      int done(ActiveTournament a) => a.matches.where((m) => m.status == MatchStatus.done).length;
      expect(done(gg20b()), 5);
      expect(done(gg20m()), 7);
      expect(gg20m().matches.where((m) => m.status == MatchStatus.done).any((m) => m.pair1.contains('Tono')), isFalse);
      expect(gg20o().canCreateBracket, isTrue);
      expect(gg20m().config.sport, SportType.tennis);
      expect(gg20m().config.courts.first.bookingDurationMinutes, 180);
    });

    test('20p R1 = catatan frame, 14 round, Qori bye R1–R2', () {
      final a = gg20p();
      expect(a.roundCount, 14);
      expect(a.matchesOfRound(1).map((m) => '${m.courtId} ${m.pair1.id}–${m.pair2.id}'), [
        'c1 Andi–Oki',
        'c2 Sari–Dodi',
        'c3 Citra–Maya',
        'c4 Umar–Bayu',
      ]);
      for (final r in [1, 2]) {
        expect(a.matchesOfRound(r).any((m) => m.pair1.id == 'Qori' || m.pair2.id == 'Qori'), isFalse);
      }
    });

    test('21s 1 court: R13 SF1, R14 SF2, R15 Juara 3 Maya–Indra, R16 Final', () {
      final a = gg21s();
      expect(
        [
          for (final c in ['SF1', 'SF2', 'J3', 'F']) a.byCode(c).roundNumber,
        ],
        [13, 14, 15, 16],
      );
      expect(a.sides('J3'), 'Maya–Indra');
    });

    test('21q tanpa Juara 3: 15 match, R8 hanya Final, Final', () {
      final a = gg21q();
      expect(a.matches, hasLength(15));
      expect(a.matchesOfRound(8).map((m) => m.phase?.code), ['F']);
      expect(a.isFinal(ggStart), isTrue);
    });

    test('21y 4 grup: Final Andi–Tono, Juara 3 Vina–Indra, Final', () {
      final a = gg21y();
      expect(a.sides('F'), 'Andi–Tono');
      expect(a.sides('J3'), 'Vina–Indra');
      expect(a.isFinal(ggStart), isTrue);
      expect(gg21w().sides('SF2'), 'Indra–?');
    });

    test('semua keadaan fixture bisa disimpan', () {
      for (final a in [gg20a(), gg20b(), gg20e(), gg20h(), gg20l(), gg20q(), gg21a(), gg21c(), gg21f(), gg21i()]) {
        expect(TournamentCodec.canEncode(a), isTrue);
      }
      for (final a in [gg21q(), gg21t(), gg21s(), gg20m(), gg20o(), gg21u(), gg21w(), gg21x(), gg21y(), gg20p()]) {
        expect(TournamentCodec.canEncode(a), isTrue);
      }
    });
  });

  test('AC-G15 kill + buka lagi: fase grup 20b, setelah Buat bagan 21a, tengah gugur 21c sama persis', () async {
    for (final state in [gg20b(), gg21a(), gg21c()]) {
      // Simpanan seperti yang ditulis listener `state =` controller.
      await store.saveActive(state);
      reopen();
      final reopened = container.read(tournamentProvider);
      expect(reopened, isNotNull);
      expect(_shape(reopened!), _shape(state));
      expect(reopened.config.groupKnockout?.groups, state.config.groupKnockout?.groups);
      expect(reopened.config.groupKnockout?.formats, state.config.groupKnockout?.formats);
      expect(TournamentCodec.encode(reopened), TournamentCodec.encode(state));
    }
  }, skip: 'menunggu GG-3 (codec Grup + Gugur)');
}
