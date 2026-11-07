import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/pair_draft.dart';
import 'package:match_addict/services/pairing/pair_generator.dart';
import 'package:match_addict/services/schedule/sparing_fixed_generator.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi/screens/sparing_fixture.dart';

/// Controller Fixed sparing, pasangan per klub, dan fixture golden bersama (SP-5; logic.md §13.1–13.5, §13.11).

/// `pair-g1` → G1: label tabel 13.11.
String _label(String pairId) => pairId.substring(5).toUpperCase();

/// Per round: "G1–M1 G2–M2" (Court 1, Court 2, …).
List<String> _rounds(ActiveTournament a, {int from = 1}) => [
  for (var r = from; r <= a.roundCount; r++)
    a.matchesOfRound(r).map((m) => '${_label(m.pair1.id)}–${_label(m.pair2.id)}').join(' '),
];

Map<String, int> _playedPerPair(ActiveTournament a, {int from = 1}) {
  final count = <String, int>{};
  for (final m in a.matches.where((m) => m.roundNumber >= from)) {
    for (final p in [m.pair1, m.pair2]) {
      count[p.id] = (count[p.id] ?? 0) + 1;
    }
  }
  return count;
}

/// S2 + S4: tiap match pasangan klub pertama di atas, tidak pernah sesama klub, tidak ada pasangan dua kali per round.
void _expectSparingMatches(ActiveTournament a) {
  for (final m in a.matches) {
    expect(a.clubOfPairId(m.pair1.id)?.id, garuda.id, reason: m.id);
    expect(a.clubOfPairId(m.pair2.id)?.id, matcha.id, reason: m.id);
  }
  for (var r = 1; r <= a.roundCount; r++) {
    final ids = a.matchesOfRound(r).expand((m) => [m.pair1.id, m.pair2.id]).toList();
    expect(ids.toSet(), hasLength(ids.length), reason: 'R$r');
  }
}

/// Simpanan tidak boleh terbaca null (turnamen hilang saat resume) dan bentuk sparingnya utuh.
void _expectRoundTrip(ActiveTournament a) {
  final restored = TournamentCodec.decode(TournamentCodec.encode(a));
  expect(restored, isNotNull);
  expect(restored!.config.isSparing, isTrue);
  expect(restored.restingPairIdsByRound, a.restingPairIdsByRound);
  expect(restored.extraPutaran, a.extraPutaran);
  expect(TournamentCodec.encode(restored), TournamentCodec.encode(a));
}

/// `Random` yang membuat `List.shuffle` (dari belakang) tidak mengubah urutan.
class _KeepOrder implements Random {
  @override
  int nextInt(int max) => max - 1;
  @override
  bool nextBool() => false;
  @override
  double nextDouble() => 0;
}

void main() {
  late ProviderContainer container;
  late TournamentController controller;
  late TournamentStore store;
  late DateTime now;
  ActiveTournament read() => container.read(tournamentProvider)!;

  setUp(() {
    now = sparingStart;
    store = TournamentStore.memory();
    container = ProviderContainer(
      overrides: [tournamentStoreProvider.overrideWithValue(store), clockProvider.overrideWithValue(() => now)],
    );
    controller = container.read(tournamentProvider.notifier);
  });
  tearDown(() => container.dispose());

  /// Isi match yang belum diisi dengan [scores] (urut round, court) lewat controller.
  void play(List<SparingScore> scores) {
    for (final (i, m) in read().matches.indexed) {
      if (m.status != MatchStatus.pending || i >= scores.length) continue;
      final s = scores[i];
      if (s == wo) {
        controller.markWalkover(m.id, loserPairId: m.pair1.id, reason: WoReason.absent);
      } else {
        controller.submitScore(m.id, [SetScore(side1: s.$1, side2: s.$2)]);
      }
    }
  }

  /// Auto-save sudah menulis keadaan terakhir, dan yang tertulis terbaca lagi (jalur resume).
  Future<void> expectSaved() async {
    await pumpEventQueue();
    final loaded = store.loadActive();
    expect(loaded, isNotNull);
    expect(TournamentCodec.encode(loaded!), TournamentCodec.encode(read()));
  }

  group('startIfNeeded sparing', () {
    test('AC-S5 13A: 12 match, 6 round, tabel 13.11, istirahat per round per klub', () async {
      controller.startIfNeeded(sparingConfig());
      final a = read();
      expect(a.matches, hasLength(12));
      expect(a.roundCount, 6);
      expect(_rounds(a), ['G1–M1 G2–M2', 'G3–M3 G4–M1', 'G1–M2 G2–M3', 'G3–M1 G4–M2', 'G1–M3 G2–M1', 'G3–M2 G4–M3']);
      expect(a.matchesOfRound(1).map((m) => m.courtId), ['c1', 'c2']);
      expect(
        {for (final e in a.restingPairIdsByRound.entries) e.key: e.value.map(_label).join(' ')},
        {1: 'G3 G4 M3', 2: 'G1 G2 M2', 3: 'G3 G4 M1', 4: 'G1 G2 M3', 5: 'G3 G4 M2', 6: 'G1 G2 M1'},
      );
      expect(a.byePairIdByRound, isEmpty);
      final played = _playedPerPair(a);
      expect(
        [
          for (final id in ['pair-g1', 'pair-g2', 'pair-g3', 'pair-g4']) played[id],
        ],
        [3, 3, 3, 3],
      );
      expect(
        [
          for (final id in ['pair-m1', 'pair-m2', 'pair-m3']) played[id],
        ],
        [4, 4, 4],
      );
      // Tiap pasangan Garuda bertemu tiap pasangan Matcha tepat sekali.
      final meetings = a.matches.map((m) => '${m.pair1.id}|${m.pair2.id}').toSet();
      expect(meetings, hasLength(12));
      _expectSparingMatches(a);
      _expectRoundTrip(a);
      await expectSaved();

      // Fixture golden = jalur controller.
      final fixture = sparingSchedule();
      expect(_rounds(fixture), _rounds(a));
      expect(fixture.restingPairIdsByRound, a.restingPairIdsByRound);
    });

    test('AC-S5 selisih main antar pasangan satu klub ≤ 1 setelah setiap round', () {
      controller.startIfNeeded(sparingConfig());
      final a = read();
      final count = <String, int>{for (final p in a.config.fixedPairs!) p.id: 0};
      for (var r = 1; r <= a.roundCount; r++) {
        for (final m in a.matchesOfRound(r)) {
          count[m.pair1.id] = count[m.pair1.id]! + 1;
          count[m.pair2.id] = count[m.pair2.id]! + 1;
        }
        for (final club in [garuda, matcha]) {
          final n = [for (final p in a.config.pairsOfClub(club.id)) count[p.id]!];
          expect(n.reduce(max) - n.reduce(min), lessThanOrEqualTo(1), reason: 'R$r ${club.name}');
        }
      }
    });

    test('AC-S6 14m: 8 / 4 pemain di 3 court → Court 3 tanpa match', () {
      controller.startIfNeeded(sparingConfig(matchaPlayers: matchaNames.take(4).toList(), courts: 3));
      final a = read();
      expect(_rounds(a), ['G1–M1 G2–M2', 'G3–M1 G4–M2', 'G1–M2 G2–M1', 'G3–M2 G4–M1']);
      expect(a.matches.map((m) => m.courtId).toSet(), {'c1', 'c2'});
      expect(a.restingPairIdsByRound[1]!.map(_label), ['G3', 'G4']);
      expect(_rounds(sparingSmall()), _rounds(a));
      _expectRoundTrip(a);
    });

    test('config identical tidak membuat jadwal baru; config lain = turnamen baru', () {
      final config = sparingConfig();
      controller.startIfNeeded(config);
      final id = read().tournament.id;
      play(scores13c.take(2).toList());
      controller.startIfNeeded(config);
      expect(read().tournament.id, id);
      expect(read().matches.take(2).every((m) => m.status == MatchStatus.done), isTrue);
      // Config di state juga dianggap turnamen yang sama (resume).
      controller.startIfNeeded(read().config);
      expect(read().tournament.id, id);

      controller.startIfNeeded(sparingConfig());
      expect(read().tournament.id, isNot(id));
      expect(read().matches.every((m) => m.status == MatchStatus.pending), isTrue);
    });

    test('Fixed biasa tetap memakai circle method dan bye per round', () {
      final config = sparingConfig();
      final plain = TournamentConfig(
        sport: config.sport,
        mode: PartnerMode.fixed,
        matchDurationMinutes: 15,
        courts: config.courts,
        players: [for (final p in config.players) Player(id: p.id, name: p.name)],
        fixedPairs: config.fixedPairs,
      );
      controller.startIfNeeded(plain);
      expect(read().matches, hasLength(21)); // 7 pasangan round-robin, sesama "klub" ikut bertemu
      expect(read().restingPairIdsByRound, isEmpty);
      expect(read().byePairIdByRound, isNotEmpty);
    });
  });

  group('addRounds sparing', () {
    setUp(() {
      controller.startIfNeeded(sparingConfig());
      play(scores13c);
      now = sparingAt(6); // sisa 00:30 = 2 round
    });

    test('AC-S18 13A setelah R6: 1 satuan = 12 match R7–R12, Garuda +3, Matcha +4', () async {
      expect(read().canAddRounds, isTrue);
      controller.addRounds(const {});
      final a = read();
      expect(a.roundCount, 12);
      expect(a.extraPutaran, 1);
      expect(_rounds(a, from: 7), [
        'G1–M2 G2–M3',
        'G3–M1 G4–M2',
        'G1–M3 G2–M1',
        'G3–M2 G4–M3',
        'G1–M1 G2–M2',
        'G3–M3 G4–M1',
      ]);
      final extra = _playedPerPair(a, from: 7);
      expect(
        [
          for (final id in ['pair-g1', 'pair-g2', 'pair-g3', 'pair-g4']) extra[id],
        ],
        [3, 3, 3, 3],
      );
      expect(
        [
          for (final id in ['pair-m1', 'pair-m2', 'pair-m3']) extra[id],
        ],
        [4, 4, 4],
      );
      expect(a.restingPairIdsByRound[7]!.map(_label), ['G3', 'G4', 'M1']);
      expect(a.restingPairIdsByRound.keys, [for (var r = 1; r <= 12; r++) r]);
      expect(a.canAddRounds, isFalse);
      _expectSparingMatches(a);
      _expectRoundTrip(a);
      await expectSaved();
    });

    test('AC-S18 sheet: lewat booking 01:00; 1 jam di kedua court → tetap 1 satuan tanpa lewat booking', () {
      final a = read();
      final club1 = a.config.pairsOfClub(garuda.id), club2 = a.config.pairsOfClub(matcha.id);
      final plan = SparingFixedGenerator.extraRounds(a, now, club1: club1, club2: club2);
      expect(plan.overMinutes, 60);
      expect(plan.perPair, (club1: 3, club2: 4));
      final more = SparingFixedGenerator.extraRounds(
        a,
        now,
        club1: club1,
        club2: club2,
        extraMinutes: const {'c1': 60, 'c2': 60},
      );
      expect(more.units, 1);
      expect(more.overMinutes, 0);

      controller.addRounds(const {'c1': 60, 'c2': 60});
      expect(read().roundCount, 12);
      expect(read().extraPutaran, 1);
      _expectRoundTrip(read());
    });

    test('satuan kedua melanjutkan blok berikutnya (extraPutaran naik)', () {
      controller.addRounds(const {});
      play(List.filled(24, (6, 4)));
      now = now.add(const Duration(minutes: 90));
      controller.addRounds(const {'c1': 60, 'c2': 60});
      final a = read();
      expect(a.extraPutaran, 2);
      expect(a.roundCount, 18);
      // Satuan kedua = blok K = g + 1 = 2 (g = FPB(4, 3) = 1): lawan klub kedua bergeser satu lagi dari R7.
      expect(_rounds(a, from: 13).first, 'G1–M3 G2–M1');
      _expectSparingMatches(a);
      _expectRoundTrip(a);
    });

    test('Atur pasangan 14o/14p: Citra · Gilang di slot G2, Maya · Oki di slot M3 = fixture', () async {
      final original = read().config.fixedPairs!;
      var draft = PairDraft.of(read().config);
      expect(draft.isSparing, isTrue);
      expect(draft.pairsOf(garuda.id), hasLength(4));
      expect(draft.pairsOf(matcha.id), hasLength(3));

      draft = draft.split(original[1]); // Citra · Dewi → Ubah
      expect(draft.unpairedOf(garuda.id).map((p) => p.name), ['Citra', 'Dewi']);
      expect(draft.unpairedOf(matcha.id), isEmpty);
      // Nama unik terhadap kedua klub, tidak peka huruf besar.
      expect(draft.add('indra', id: 'x', clubId: garuda.id).error, 'Indra sudah ada di daftar');
      expect(() => draft.add('Gilang', id: gilang.id), throwsArgumentError);
      draft = draft.add('Gilang', id: gilang.id, clubId: garuda.id).draft!;
      expect(draft.unpairedOf(garuda.id).last.clubId, garuda.id);
      final citra = draft.unpairedOf(garuda.id).first;
      final g = draft.unpairedOf(garuda.id).last;

      draft = draft.split(original[6]); // Maya · Nanda → Ubah
      draft = draft.add('Oki', id: oki.id, clubId: matcha.id).draft!;
      final maya = draft.unpairedOf(matcha.id).first;
      final o = draft.unpairedOf(matcha.id).last;
      // AC-S4 di Atur pasangan: beda klub tidak bisa dipasangkan.
      expect(draft.canPair(citra, o), isFalse);
      expect(draft.canPair(citra, g), isTrue);
      expect(() => draft.pair(citra, o, id: 'x'), throwsA(isA<AssertionError>()));

      // Matcha dulu: slot kosong yang diisi tetap slot klubnya (M3), bukan slot kosong pertama (G2).
      draft = draft.pair(maya, o, id: mayaOki.id);
      draft = draft.pair(citra, g, id: citraGilang.id);
      expect(draft.pairs.map((p) => p.id), [
        'pair-g1',
        'pair-g2b',
        'pair-g3',
        'pair-g4',
        'pair-m1',
        'pair-m2',
        'pair-m3b',
      ]);
      expect(draft.unpaired.map((p) => p.name), ['Dewi', 'Nanda']);
      expect(draft.addedInPairs.map((p) => p.clubId), [garuda.id, matcha.id]);
      expect(draft.hasPairEachClub, isTrue);

      controller.addRounds(const {}, pairs: draft.pairs, newPlayers: draft.addedInPairs);
      final a = read();
      expect(a.config.playerById(gilang.id)?.clubId, garuda.id);
      expect(a.config.playerById(oki.id)?.clubId, matcha.id);
      // R7: Andi · Budi vs Kiki · Lina, Citra · Gilang vs Maya · Oki (14n), lawan pasangan lain tetap.
      expect(_rounds(a, from: 7).first, 'G1–M2 G2B–M3B');
      _expectSparingMatches(a);
      _expectRoundTrip(a);
      await expectSaved();

      final fixture = sparingReplaced();
      expect(_rounds(fixture), _rounds(a));
      expect(fixture.restingPairIdsByRound, a.restingPairIdsByRound);
      expect(fixture.extraPutaran, a.extraPutaran);
      expect(fixture.config.fixedPairs!.map((p) => p.id), a.config.fixedPairs!.map((p) => p.id));
      expect(fixture.config.players.map((p) => p.id), a.config.players.map((p) => p.id));
      // Atur berikutnya: Dewi dan Nanda (tidak ikut lagi) langsung di chip klubnya.
      final next = PairDraft.of(TournamentCodec.decode(TournamentCodec.encode(a))!.config);
      expect(next.unpairedOf(garuda.id).map((p) => p.name), ['Dewi']);
      expect(next.unpairedOf(matcha.id).map((p) => p.name), ['Nanda']);
    });

    test('jumlah pasangan berubah: satuan dihitung dari jumlah baru (4 / 2 → 4 match per satuan)', () {
      final pairs = read().config.fixedPairs!;
      final draft = PairDraft.of(read().config).split(pairs[6]);
      expect(draft.pairsOf(matcha.id), hasLength(2));
      controller.addRounds(const {}, pairs: draft.pairs);
      final a = read();
      // fit 2, 2 court: round 1 = 2 slot < 4 → 1 satuan = 4 match, 2 round.
      expect(a.matches.length - 12, SparingFixedGenerator.unitMatches(4, 2));
      expect(a.roundCount, 8);
      expect(a.extraPutaran, 1);
      _expectSparingMatches(a);
      _expectRoundTrip(a);
    });

    test('Simpan mati "minimal 1 pasangan tiap klub"; pasangan/pemain tanpa klub = assert, turnamen tidak berubah', () {
      final pairs = read().config.fixedPairs!;
      var draft = PairDraft.of(read().config);
      for (final p in pairs.skip(4)) {
        draft = draft.split(p);
      }
      expect(draft.hasPairEachClub, isFalse);

      final before = TournamentCodec.encode(read());
      // Pemain baru tanpa klub (S1).
      expect(
        () => controller.addRounds(
          const {},
          pairs: [
            ...pairs,
            const Pair(id: 'x', player1Id: 'p-x', player2Id: 'p-y'),
          ],
          newPlayers: const [
            Player(id: 'p-x', name: 'X'),
            Player(id: 'p-y', name: 'Y'),
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
      // Pasangan beda klub (S2).
      expect(
        () => controller.addRounds(
          const {},
          pairs: [
            ...pairs,
            const Pair(id: 'x', player1Id: 'p-dewi', player2Id: 'p-nanda'),
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
      // Anggota yang tidak dikenal.
      expect(
        () => controller.addRounds(
          const {},
          pairs: [
            ...pairs,
            const Pair(id: 'x', player1Id: 'p-andi', player2Id: '?'),
          ],
        ),
        throwsA(isA<AssertionError>()),
      );
      // Satu klub tanpa pasangan.
      expect(() => controller.addRounds(const {}, pairs: draft.pairs), throwsA(isA<AssertionError>()));
      expect(TournamentCodec.encode(read()), before);
    });

    test('waktu habis tanpa tambahan jam (fit 0): tidak ada yang dibuat, tanpa assert', () {
      now = sparingAt(8);
      final before = TournamentCodec.encode(read());
      controller.addRounds(const {});
      expect(TournamentCodec.encode(read()), before);
    });
  });

  group('PairGenerator per klub', () {
    List<Player> players(int g, int m) => sparingConfig(
      garudaPlayers: [...garudaNames, 'Gilang'].take(g).toList(),
      matchaPlayers: [...matchaNames, 'Oki', 'Putri'].take(m).toList(),
      paired: false,
    ).players;

    test('AC-S3 acak per klub: Garuda 9 → 4 pasangan + 1 sisa, Matcha 6 → 3 pasangan', () {
      final config = sparingConfig();
      for (var seed = 0; seed < 20; seed++) {
        final draft = PairGenerator.randomByClub(players(9, 6), config.clubs!, random: Random(seed));
        expect(draft.pairs, hasLength(7));
        expect(draft.unpaired.single.clubId, garuda.id);
        final withPairs = config.copyWith(players: players(9, 6), fixedPairs: draft.pairs);
        expect(
          [for (final p in draft.pairs) withPairs.clubOfPair(p)?.id],
          [...List.filled(4, garuda.id), ...List.filled(3, matcha.id)],
        );
      }
      // Garuda 9 / Matcha 7: dua sisa beda klub, tidak dipasangkan.
      final odd = PairGenerator.randomByClub(players(9, 7), config.clubs!, random: Random(1));
      expect(odd.pairs, hasLength(7));
      expect(odd.unpaired.map((p) => p.clubId), [garuda.id, matcha.id]);
    });

    test('14a: acak yang tidak mengubah urutan = G1–G4 / M1–M3, klub pertama dulu', () {
      final config = sparingConfig();
      final draft = PairGenerator.randomByClub(config.players, config.clubs!, random: _KeepOrder());
      String names(Pair p) => '${config.playerById(p.player1Id)!.name} · ${config.playerById(p.player2Id)!.name}';
      expect(draft.pairs.map(names), [
        'Andi · Budi',
        'Citra · Dewi',
        'Eko · Fajar',
        'Gita · Hadi',
        'Indra · Joko',
        'Kiki · Lina',
        'Maya · Nanda',
      ]);
      // Jadwal dari pasangan ini = 13A.
      controller.startIfNeeded(config.copyWith(fixedPairs: draft.pairs));
      expect(read().matches, hasLength(12));
      _expectSparingMatches(read());
      _expectRoundTrip(read());
    });

    test('AC-S4 manual: Andi lalu Indra tidak membentuk pasangan; sesama klub jadi', () {
      final config = sparingConfig(paired: false);
      Player p(String name) => config.players.firstWhere((x) => x.name == name);
      expect(PairGenerator.manual(p('Andi'), p('Indra')), isNull);
      final pair = PairGenerator.manual(p('Andi'), p('Budi'))!;
      expect(pair.playerIds, ['p-andi', 'p-budi']);
      // Turnamen biasa (tanpa klub) tetap bebas.
      expect(PairGenerator.manual(const Player(id: 'a', name: 'A'), const Player(id: 'b', name: 'B')), isNotNull);
    });
  });

  group('fixture golden sparing', () {
    int sum(List<SparingScore> s, int Function(SparingScore) side) =>
        s.where((x) => x != wo).map(side).fold(0, (a, b) => a + b);

    test('skor = angka 13.11 (Total Point klub tanpa nilai WO)', () {
      expect((sum(scores13c, (s) => s.$1), sum(scores13c, (s) => s.$2)), (56, 43)); // + 6 nilai WO = 49
      expect((sum(scores14s, (s) => s.$1), sum(scores14s, (s) => s.$2)), (56, 60));
      expect((sum(scores14t, (s) => s.$1), sum(scores14t, (s) => s.$2)), (58, 58));
      expect((sum(scores14u, (s) => s.$1), sum(scores14u, (s) => s.$2)), (122, 118));
    });

    test('semua keadaan terbaca lagi dari simpanan', () {
      final states = {
        'R3': sparingR3(),
        'R5': sparingAfterR5(),
        'full': sparingFull(),
        'ended': sparingEnded(),
        '14s': sparing14s(),
        '14t': sparing14t(),
        '14u': sparing14u(),
        '14m': sparingSmall(),
        '14p': sparingReplaced(),
      };
      for (final MapEntry(key: name, value: a) in states.entries) {
        expect(TournamentCodec.decode(TournamentCodec.encode(a)), isNotNull, reason: name);
        _expectSparingMatches(a);
      }
      final r3 = sparingR3();
      expect(r3.matches.where((m) => m.status == MatchStatus.pending).map((m) => m.id), [
        'm-r3-2',
        ...['m-r4-1', 'm-r4-2', 'm-r5-1', 'm-r5-2', 'm-r6-1', 'm-r6-2'],
      ]);
      // R3 Court 2 WO: Citra · Dewi absen.
      final w = sparingFull().matches.firstWhere((m) => m.id == 'm-r3-2');
      expect((w.status, w.woLoserPairId, w.woReason), (MatchStatus.wo, 'pair-g2', WoReason.absent));
      final ended = sparingEnded();
      expect(ended.tournament.isFinished, isTrue);
      expect(ended.matchesOfRound(6).map((m) => m.status), [MatchStatus.cancelled, MatchStatus.cancelled]);
      expect(sparing14u().config.format, americano20);
      expect(sparingReplaced().matches.where((m) => m.status == MatchStatus.pending), hasLength(12));
    });
  });
}
