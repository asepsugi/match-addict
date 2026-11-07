import 'dart:math';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import '../hifi/screens/schedule_fixture.dart' show LoadedTournament;
import 'sparing_mixed_property.dart';

/// Mixed sparing per klub (logic.md §13.6, contoh 13B §13.11, PRD 13.4): court aktif C', prioritas per klub,
/// pasangan sesama klub, daftar istirahat per klub = hasil Buat, Kelola pemain/court, estimasi.

const _garuda = Club(id: 'club-1', name: 'PB Garuda');
const _matcha = Club(id: 'club-2', name: 'Matcha Club');

/// Id pemain sama dengan fixture designer (15-sparing-mixed.md): Garuda g01–g08, Matcha m01–m06, Oki m07.
List<Player> _club(String tag, Club club, List<String> names) => [
  for (final (i, n) in names.indexed) Player(id: '$tag${(i + 1).toString().padLeft(2, '0')}', name: n, clubId: club.id),
];

final _garudaPlayers = _club('g', _garuda, ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi']);
final _matchaPlayers = _club('m', _matcha, ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda']);
final _oki = Player(id: 'm07', name: 'Oki', clubId: _matcha.id);

List<Court> _courts(int n, [int minutes = 120]) => [
  for (var i = 1; i <= n; i++) Court(id: 'c$i', name: 'Court $i', colorIndex: i - 1, bookingDurationMinutes: minutes),
];

TournamentConfig _config(List<Player> club1, List<Player> club2, {int courts = 2}) => TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.mixed,
  matchDurationMinutes: 15,
  courts: _courts(courts),
  players: [...club1, ...club2],
  format: const ScoreFormat(ScoringMethod.raceTo, 6),
  clubs: const [_garuda, _matcha],
);

/// Seed undian frame 13m/15* (dipanggil langsung, bukan FNV-1a dari id turnamen).
const _frameSeed = 0x5eed;

Map<String, String> _names = {
  for (final p in [..._garudaPlayers, ..._matchaPlayers, _oki]) p.id: p.name,
};
String _pair(Pair p) => '${_names[p.player1Id]} · ${_names[p.player2Id]}';
String _match(MatchGame m) => '${_pair(m.pair1)} vs ${_pair(m.pair2)}';
List<String> _sortedNames(Iterable<Player> ps) => [for (final p in ps) p.name]..sort();

Set<String> _playersOf(Iterable<MatchGame> ms) => {
  for (final m in ms) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
};

int _played(List<MatchGame> h, String id) => h.where((m) => m.pair1.contains(id) || m.pair2.contains(id)).length;

/// Jalankan generator murni seperti fixture designer: [random] bersambung antar round.
List<MatchGame> _run(
  int rounds, {
  List<Player>? club1,
  List<Player>? club2,
  int courts = 2,
  required Random random,
  List<MatchGame> start = const [],
  int from = 1,
  Set<String> late = const {},
}) {
  final h = [...start];
  for (var n = from; n < from + rounds; n++) {
    h.addAll(
      EndlessRoundGenerator.generateSparingRound(
        club1: club1 ?? _garudaPlayers,
        club2: club2 ?? _matchaPlayers,
        courts: _courts(courts),
        history: h,
        roundNumber: n,
        seed: _frameSeed,
        latePlayerIds: late,
        random: random,
      )!.matches,
    );
  }
  return h;
}

/// Prioritas R[round] satu klub dengan seed frame (yang tampil di daftar istirahat).
List<Player> _priority(List<Player> club, List<MatchGame> h, int round, int slots, [Set<String> late = const {}]) =>
    EndlessRoundGenerator.priorityOrder(
      players: club,
      history: h,
      roundNumber: round,
      seed: _frameSeed,
      slots: slots,
      latePlayerIds: late,
    );

List<String> _restingTop(List<Player> club, List<MatchGame> h, int round, int slots) {
  final playing = _playersOf(h.where((m) => m.roundNumber == round - 1));
  return _sortedNames(_priority(club, h, round, slots).take(slots).where((p) => !playing.contains(p.id)));
}

void _expectSaves(ActiveTournament active) =>
    expect(TournamentCodec.decode(TournamentCodec.encode(active)), isNotNull, reason: 'simpanan sparing terbaca');

void main() {
  group('C\' (satu rumus)', () {
    test('AC-S10 min(court, ⌊n1 ÷ 2⌋, ⌊n2 ÷ 2⌋): 8/6 2 court → 2, 8/3 → 1, 15/15 4 court → 4, 2/2 → 1', () {
      int c(int courts, int n1, int n2) => ActiveTournament.sparingActiveCourts(courts: courts, club1: n1, club2: n2);
      expect(c(2, 8, 6), 2);
      expect(c(2, 8, 3), 1);
      expect(c(2, 8, 5), 2);
      expect(c(3, 8, 6), 3);
      expect(c(4, 15, 15), 4);
      expect(c(1, 2, 2), 1);
      expect(ActiveTournament.sparingActiveCourts(club1: 8, club2: 6), 3, reason: 'tanpa batas court');
    });

    test('estimasi Konfigurasi / Cara kerja: 13i 8/6 → ±8 round, 2 court, 16 match, ±4 / ±5; 13j 8/3 → 1 court', () {
      final config = _config(_garudaPlayers, _matchaPlayers);
      expect(EndlessRoundGenerator.sparingEstimate(maxRounds: config.maxRounds, courts: 2, club1: 8, club2: 6), (
        rounds: 8,
        activeCourts: 2,
        matches: 16,
        perPlayer1: 4,
        perPlayer2: 5,
      ));
      expect(EndlessRoundGenerator.sparingEstimate(maxRounds: 8, courts: 2, club1: 8, club2: 3), (
        rounds: 8,
        activeCourts: 1,
        matches: 8,
        perPlayer1: 2,
        perPlayer2: 5,
      ));
    });
  });

  group('frame 13m / 15* (sama dengan prototipe designer, seed 0x5eed)', () {
    test('13m, 15a, 15b, 15k: R1–R4 dan Prioritas per klub', () {
      final h = _run(4, random: Random(1));
      List<String> round(int r) => [for (final m in h.where((m) => m.roundNumber == r)) _match(m)];
      expect(round(1), ['Eko · Gita vs Nanda · Kiki', 'Citra · Fajar vs Maya · Joko']);
      expect(round(2), ['Budi · Andi vs Lina · Kiki', 'Dewi · Hadi vs Nanda · Indra']);
      expect(round(3), ['Fajar · Eko vs Joko · Indra', 'Citra · Gita vs Lina · Maya']);
      expect(round(4), ['Budi · Hadi vs Lina · Nanda', 'Andi · Dewi vs Indra · Kiki']);
      expect([for (final m in h.where((m) => m.roundNumber == 1)) m.courtId], ['c1', 'c2']);

      List<MatchGame> upTo(int r) => h.where((m) => m.roundNumber <= r).toList();
      // 15k: Prioritas R2; 15a: Prioritas R4; 15b: Prioritas R5.
      expect(_restingTop(_garudaPlayers, upTo(1), 2, 4), ['Andi', 'Budi', 'Dewi', 'Hadi']);
      expect(_restingTop(_matchaPlayers, upTo(1), 2, 4), ['Indra', 'Lina']);
      expect(_restingTop(_garudaPlayers, upTo(3), 4, 4), ['Andi', 'Budi', 'Dewi', 'Hadi']);
      expect(_restingTop(_matchaPlayers, upTo(3), 4, 4), ['Kiki', 'Nanda']);
      expect(_restingTop(_garudaPlayers, upTo(4), 5, 4), ['Citra', 'Eko', 'Fajar', 'Gita']);
      expect(_restingTop(_matchaPlayers, upTo(4), 5, 4), ['Joko', 'Maya']);
    });

    test(
      'AC-S8 13B: tiap round 2 match Garuda vs Matcha; R6 Garuda 3 · Matcha 4; R8 Garuda 4 · Matcha 6,6,5,5,5,5 (15f)',
      () {
        final h = _run(8, random: Random(1));
        for (var r = 1; r <= 8; r++) {
          final round = h.where((m) => m.roundNumber == r).toList();
          expect(round.length, 2);
          for (final m in round) {
            expect(m.pair1.playerIds.every((id) => id.startsWith('g')), isTrue);
            expect(m.pair2.playerIds.every((id) => id.startsWith('m')), isTrue);
          }
        }
        final r6 = h.where((m) => m.roundNumber <= 6).toList();
        expect({for (final p in _garudaPlayers) _played(r6, p.id)}, {3});
        expect({for (final p in _matchaPlayers) _played(r6, p.id)}, {4});
        expect({for (final p in _garudaPlayers) _played(h, p.id)}, {4});
        expect(
          {for (final p in _matchaPlayers) p.name: _played(h, p.id)},
          {'Indra': 5, 'Joko': 5, 'Kiki': 5, 'Lina': 6, 'Maya': 5, 'Nanda': 6},
        );
      },
    );

    test('AC-S13 15o/15p: Court 3 saat R4 berjalan = Fajar, Gita · Joko, Maya → Gita · Fajar vs Maya · Joko', () {
      final h = _run(4, random: Random(1));
      final playing = _playersOf(h.where((m) => m.roundNumber == 4));
      // Slot klub R5 dengan Court 3: C' = min(3, 4, 3) = 3.
      final g = _priority(_garudaPlayers, h, 5, 6).where((p) => !playing.contains(p.id)).take(2).toList();
      final mt = _priority(_matchaPlayers, h, 5, 6).where((p) => !playing.contains(p.id)).take(2).toList();
      expect(_sortedNames(g), ['Fajar', 'Gita']);
      expect(_sortedNames(mt), ['Joko', 'Maya']);

      final active = ActiveTournament(
        tournament: Tournament(
          id: 't-15o',
          createdAt: DateTime(2026, 11, 7, 19),
          config: _config(_garudaPlayers, _matchaPlayers, courts: 3),
          matches: h,
        ),
      );
      final match = EndlessRoundGenerator.courtMatch(active, 'c3', [...g, ...mt], random: Random(2));
      expect(_match(match), 'Gita · Fajar vs Maya · Joko');
      expect((match.roundNumber, match.matchNumberInRound, match.courtId), (4, 3, 'c3'));

      final r5 = _run(1, courts: 3, random: Random(1), start: [...h, match], from: 5);
      final round5 = r5.where((m) => m.roundNumber == 5).toList();
      expect(round5.length, 3);
      expect({for (final m in round5) ...m.pair2.playerIds}.length, 6);
    });

    test('15n Oki masuk Matcha setelah R3: R4 Oki · Nanda, R5 Maya · Oki, istirahat R6 (k = 2)', () {
      final h = _run(3, random: Random(1));
      final matcha7 = [..._matchaPlayers, _oki];
      final rng = Random(3);
      final r4to6 = _run(3, club2: matcha7, random: rng, start: h, from: 4, late: {_oki.id});
      List<String> okiPairs(int r) => [
        for (final m in r4to6.where((m) => m.roundNumber == r))
          if (m.pair2.contains(_oki.id)) _pair(m.pair2),
      ];
      expect(okiPairs(4), ['Oki · Nanda']);
      expect(okiPairs(5), ['Maya · Oki']);
      expect(okiPairs(6), isEmpty);
      // PB Garuda sama dengan 15b.
      expect([for (final m in r4to6.where((m) => m.roundNumber == 4)) _pair(m.pair1)], ['Budi · Hadi', 'Andi · Dewi']);
    });

    test('15e 8/3: R1 Gita · Fajar vs Kiki · Joko di Court 1, Court 2 tidak dapat match (AC-S10)', () {
      final matcha3 = _matchaPlayers.take(3).toList();
      final h = _run(8, club2: matcha3, random: Random(1));
      expect(_match(h.first), 'Gita · Fajar vs Kiki · Joko');
      expect({for (final m in h) m.courtId}, {'c1'});
      expect(h.length, 8);
    });
  });

  test('tabel 8 round PRD 13.4: court aktif, match, main per pemain klub 1 / 2', () {
    String span(List<MatchGame> h, List<Player> ps) {
      final x = ps.map((p) => _played(h, p.id));
      final lo = x.reduce(min), hi = x.reduce(max);
      return lo == hi ? '$lo' : '$lo–$hi';
    }

    for (final (n1, n2, c, active, matches, per) in [
      (8, 6, 2, 2, 16, '4 / 5–6'),
      (7, 6, 2, 2, 16, '4–5 / 5–6'),
      (8, 3, 2, 1, 8, '2 / 5–6'),
      (15, 15, 4, 4, 32, '4–5 / 4–5'),
      (2, 2, 1, 1, 8, '8 / 8'),
    ]) {
      final c1 = sizedClub('g', _garuda, n1), c2 = sizedClub('m', _matcha, n2);
      final h = _run(8, club1: c1, club2: c2, courts: c, random: Random(1));
      expect(
        ActiveTournament.sparingActiveCourts(courts: c, club1: n1, club2: n2),
        active,
        reason: '$n1/$n2',
      );
      expect(h.length, matches, reason: '$n1/$n2');
      expect('${span(h, c1)} / ${span(h, c2)}', per, reason: '$n1/$n2');
      expect({for (final m in h) m.courtId}, {for (var i = 1; i <= active; i++) 'c$i'}, reason: '$n1/$n2');
    }
  });

  group('AC-S9 test properti (ringkas; sweep penuh bertag slow)', () {
    test('ukuran AC-S9 30 round + pemain telat R4 + keluar R7: selisih per klub ≤ 1, nol match sesama klub', () {
      for (final (n1, n2, c) in [(8, 6, 2), (7, 6, 2), (8, 3, 2), (15, 15, 4), (2, 2, 1)]) {
        checkLateAndWithdrawn(n1, n2, c);
      }
    });

    test('sampel acak berseed: 12 ukuran 2–28 per klub × court 1/2/3/4/7/10 × 30 round', () {
      final rng = Random(13);
      for (var i = 0; i < 12; i++) {
        final n1 = 2 + rng.nextInt(27);
        final n2 = 2 + rng.nextInt(29 - n1);
        final c = const [1, 2, 3, 4, 7, 10][rng.nextInt(6)];
        checkSize(n1, n2, c);
      }
    });
  });

  group('controller (jalur menyimpan)', () {
    late ProviderContainer container;
    late TournamentController controller;
    var now = DateTime(2026, 11, 7, 19);
    ActiveTournament read() => container.read(tournamentProvider)!;

    setUp(() {
      now = DateTime(2026, 11, 7, 19);
      container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
      controller = container.read(tournamentProvider.notifier);
    });
    tearDown(() => container.dispose());

    void scoreRound() {
      for (final m in read().matchesOfRound(read().roundCount)) {
        controller.submitScore(m.id, const [SetScore(side1: 6, side2: 4)]);
      }
    }

    /// AC-S11: per klub, "Prioritas main di R(n+1)" = yang istirahat di Rn lalu main di hasil Buat R(n+1); "Istirahat
    /// lagi" tidak main.
    void buildAndCheckPriority() {
      final before = read();
      final split = EndlessRoundGenerator.restingByClubAfterLastRound(before, now);
      final combined = EndlessRoundGenerator.restingAfterLastRound(before, now);
      controller.generateNextRound();
      final after = read();
      expect(after.roundCount, before.roundCount + 1);
      final playing = _playersOf(after.matchesOfRound(after.roundCount));
      for (final club in split) {
        expect(
          club.priority.every((p) => playing.contains(p.id)),
          isTrue,
          reason: '${club.club.name} R${after.roundCount}',
        );
        expect(
          club.later.any((p) => playing.contains(p.id)),
          isFalse,
          reason: '${club.club.name} R${after.roundCount}',
        );
        expect(club.priority.followedBy(club.later).every((p) => p.clubId == club.club.id), isTrue);
      }
      expect(
        [for (final p in combined.priority) p.id]..sort(),
        [for (final c in split) ...c.priority.map((p) => p.id)]..sort(),
      );
    }

    test('AC-S8 + AC-S11 13B lewat Buat: 2 match per round, pair1 Garuda, prioritas per klub = hasil Buat', () {
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
      for (var r = 2; r <= 8; r++) {
        scoreRound();
        buildAndCheckPriority();
      }
      final active = read();
      for (final m in active.matches) {
        expect(active.config.clubOfPair(m.pair1), _garuda);
        expect(active.config.clubOfPair(m.pair2), _matcha);
      }
      expect({for (final p in _garudaPlayers) _played(active.matches, p.id)}, {4});
      expect([for (final p in _matchaPlayers) _played(active.matches, p.id)]..sort(), [5, 5, 5, 5, 6, 6]);
      _expectSaves(active);
    });

    test('AC-S11 30 pemain (16/14, 2 court): ada "Istirahat lagi" per klub, tetap sama dengan hasil Buat', () {
      controller.startIfNeeded(_config(sizedClub('g', _garuda, 16), sizedClub('m', _matcha, 14)));
      for (var r = 2; r <= 6; r++) {
        scoreRound();
        final split = EndlessRoundGenerator.restingByClubAfterLastRound(read(), now);
        expect([for (final c in split) (c.priority.length, c.later.length)], [(4, 8), (4, 6)]);
        buildAndCheckPriority();
      }
    });

    test('waktu habis: slot per klub dari semua court (06l), seperti Buat setelah Lanjutkan', () {
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
      scoreRound();
      now = now.add(const Duration(hours: 2));
      final split = EndlessRoundGenerator.restingByClubAfterLastRound(read(), now);
      expect([for (final c in split) c.priority.length], [4, 2]);
    });

    test('AC-S10 8/3: satu match per round di Court 1, Lanjutkan maks 1 match per round', () {
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers.take(3).toList()));
      for (var r = 2; r <= 4; r++) {
        scoreRound();
        buildAndCheckPriority();
      }
      expect({for (final m in read().matches) m.courtId}, {'c1'});
      expect(read().matches.length, 4);
      expect(read().capacityAhead(now).matchesPerRound, 1);
      _expectSaves(read());
    });

    test('15j Lanjutkan: 8/6 waktu habis setelah R8, Court 1 +1 jam → 4 round, 4 match, maks 3 per round', () {
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
      now = now.add(const Duration(hours: 2));
      expect(read().capacityAhead(now, {'c1': 60}), (
        rounds: 4,
        matches: 4,
        courts: 1,
        fewerCourtsFrom: null,
        matchesPerRound: 3,
      ));
    });

    test('Oki ditambah ke Matcha setelah R3: main R4, R5, istirahat R6 (k = 2); Garuda tidak terpengaruh', () {
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
      for (var r = 2; r <= 3; r++) {
        scoreRound();
        controller.generateNextRound();
      }
      scoreRound();
      expect(controller.addPlayer('Oki', clubId: _matcha.id), isNull);
      final oki = read().config.players.last;
      expect((oki.name, oki.clubId), ('Oki', _matcha.id));
      _expectSaves(read());
      final plays = <bool>[];
      for (var r = 4; r <= 6; r++) {
        buildAndCheckPriority();
        plays.add(read().matchesOfRound(r).any((m) => m.pair2.contains(oki.id)));
        scoreRound();
      }
      expect(plays, [true, true, false]);
      expect(read().matches.every((m) => !m.pair1.contains(oki.id)), isTrue);
      final garuda = [for (final p in _garudaPlayers) _played(read().matches, p.id)];
      expect(garuda.reduce(max) - garuda.reduce(min), lessThanOrEqualTo(1));
      _expectSaves(read());
    });

    test('Nanda keluar setelah R3: 4 dari 5 Matcha main tiap round, C\' tetap 2', () {
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
      for (var r = 2; r <= 3; r++) {
        scoreRound();
        controller.generateNextRound();
      }
      expect(controller.withdrawPlayer('m06'), isTrue);
      for (var r = 4; r <= 8; r++) {
        scoreRound();
        buildAndCheckPriority();
        final round = read().matchesOfRound(r);
        expect(round.length, 2);
        expect({for (final m in round) ...m.pair2.playerIds}.length, 4);
        expect(round.any((m) => m.pair2.contains('m06')), isFalse);
      }
      _expectSaves(read());
    });

    test(
      'AC-S12 Kelola pemain: tambah wajib klub, nama dicek ke kedua klub, Keluarkan mati di klub tinggal 2, Kembalikan ke klubnya',
      () {
        controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers.take(3).toList()));
        final start = read();

        expect(() => controller.addPlayer('Zaki'), throwsA(isA<AssertionError>()));
        expect(() => controller.addPlayer('Zaki', clubId: 'club-x'), throwsA(isA<AssertionError>()));
        expect(identical(read(), start), isTrue);
        expect(controller.addPlayer('andi', clubId: _matcha.id), 'Andi sudah ada di PB Garuda');

        // Kiki keluar → Matcha tinggal Indra dan Joko (15m).
        expect(controller.withdrawPlayer('m03'), isTrue);
        expect(read().canWithdraw('m01'), isFalse);
        expect(controller.withdrawPlayer('m01'), isFalse);
        expect(read().activePlayersOfClub(_matcha.id).length, 2);
        expect(read().canWithdraw('g01'), isTrue, reason: 'PB Garuda tetap bisa dikeluarkan');
        expect(controller.addPlayer('kiki', clubId: _garuda.id), 'Kiki sudah ada — pakai "Kembalikan" di bawah');

        expect(controller.reinstatePlayer('m03'), isNull);
        expect(read().activePlayersOfClub(_matcha.id).map((p) => p.name), ['Indra', 'Joko', 'Kiki']);
        _expectSaves(read());

        expect(controller.addPlayer('Zaki', clubId: _garuda.id), isNull);
        expect(read().config.players.last.clubId, _garuda.id);
        expect(read().activePlayersOfClub(_garuda.id).length, 9);
        _expectSaves(read());
      },
    );

    test('AC-S12 batas total: 30 aktif → tambah dan Kembalikan ditolak; minimal total 4 tetap berlaku', () {
      controller.startIfNeeded(_config(sizedClub('g', _garuda, 16), sizedClub('m', _matcha, 14)));
      expect(controller.addPlayer('Zaki', clubId: _matcha.id), 'Maksimal 30 pemain aktif');
      expect(controller.withdrawPlayer('m01'), isTrue);
      expect(controller.addPlayer('Zaki', clubId: _matcha.id), isNull);
      expect(controller.reinstatePlayer('m01'), 'Maksimal 30 pemain aktif');
      _expectSaves(read());

      container.dispose();
      container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
      controller = container.read(tournamentProvider.notifier);
      controller.startIfNeeded(_config(sizedClub('g', _garuda, 2), sizedClub('m', _matcha, 3)));
      expect(read().canWithdraw('g01'), isFalse, reason: 'PB Garuda tinggal 2');
      expect(controller.withdrawPlayer('m01'), isTrue);
      expect(read().canWithdraw('m02'), isFalse, reason: 'total tinggal 4');
      expect(controller.withdrawPlayer('m02'), isFalse);
    });

    test(
      'AC-S13 Kelola court 13B saat R4 berjalan: Court 3 langsung 2 Garuda + 2 Matcha yang istirahat, R5 3 match semua Matcha',
      () {
        controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
        for (var r = 2; r <= 4; r++) {
          scoreRound();
          controller.generateNextRound();
        }
        now = now.add(const Duration(minutes: 47));
        final before = read();
        final resting4 = before.restingPlayerIdsByRound[4]!.toSet();
        controller.addCourt(name: '', colorIndex: 2, bookingMinutes: 120);
        final after = read();
        final round4 = after.matchesOfRound(4);
        expect(round4.length, 3);
        final court3 = round4.last;
        expect((court3.courtId, court3.matchNumberInRound), (after.config.courts.last.id, 3));
        expect(after.config.clubOfPair(court3.pair1), _garuda);
        expect(after.config.clubOfPair(court3.pair2), _matcha);
        final four = [...court3.pair1.playerIds, ...court3.pair2.playerIds];
        expect(four.every(resting4.contains), isTrue);
        expect(after.restingPlayerIdsByRound[4]!.any(four.contains), isFalse);
        _expectSaves(after);

        scoreRound();
        buildAndCheckPriority();
        final round5 = read().matchesOfRound(5);
        expect(round5.length, 3);
        expect({for (final m in round5) ...m.pair2.playerIds}.length, 6);
        _expectSaves(read());
      },
    );

    test(
      'Kelola court: Matcha tinggal 1 yang istirahat saat round berjalan → court belum terpakai, round tetap 2 match',
      () {
        controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
        scoreRound();
        expect(controller.withdrawPlayer('m06'), isTrue);
        controller.generateNextRound();
        final before = read();
        expect(before.matchesOfRound(2).length, 2);
        final draft = before.newCourt(id: 'baru', name: '', colorIndex: 2, bookingMinutes: 120, now: now);
        // Garuda 4 istirahat, Matcha 5 aktif − 4 main = 1; C' dengan Court 3 tetap min(3, 4, 2) = 2.
        expect(EndlessRoundGenerator.courtUse(before.withCourt(draft), 'baru', now).use, CourtUse.unused);
        controller.addCourt(name: '', colorIndex: 2, bookingMinutes: 120);
        expect(read().config.courts.length, 3);
        expect(read().matchesOfRound(2).length, 2);
        _expectSaves(read());
      },
    );

    test('Kelola court: round lengkap → mulai round berikutnya; 8/3 → belum terpakai (C\' dibatasi Matcha)', () {
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
      scoreRound();
      final full = read();
      final draft = full.newCourt(id: 'baru', name: '', colorIndex: 2, bookingMinutes: 120, now: now);
      expect(EndlessRoundGenerator.courtUse(full.withCourt(draft), 'baru', now).use, CourtUse.nextRound);

      container.dispose();
      container = ProviderContainer(overrides: [clockProvider.overrideWithValue(() => now)]);
      controller = container.read(tournamentProvider.notifier);
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers.take(3).toList()));
      final small = read();
      final extra = small.newCourt(id: 'baru', name: '', colorIndex: 2, bookingMinutes: 120, now: now);
      expect(EndlessRoundGenerator.courtUse(small.withCourt(extra), 'baru', now).use, CourtUse.unused);
    });

    test('Kembalikan pemain sparing tanpa klub turnamen ditolak (assert, S1)', () {
      container.dispose();
      final broken = ActiveTournament(
        tournament: Tournament(
          id: 't-rusak',
          createdAt: now,
          config: _config(_garudaPlayers, [..._matchaPlayers, const Player(id: 'x', name: 'Tanpa klub')]),
        ),
        withdrawnPlayerIds: const {'x'},
      );
      container = ProviderContainer(
        overrides: [
          tournamentProvider.overrideWith(() => LoadedTournament(broken)),
          clockProvider.overrideWithValue(() => now),
        ],
      );
      controller = container.read(tournamentProvider.notifier);
      expect(() => controller.reinstatePlayer('x'), throwsA(isA<AssertionError>()));
      expect(read().withdrawnPlayerIds, {'x'});
    });

    test('Batalkan Rn lalu Buat lagi: tetap per klub, simpanan sah', () {
      controller.startIfNeeded(_config(_garudaPlayers, _matchaPlayers));
      scoreRound();
      controller.generateNextRound();
      controller.cancelLastRound();
      expect(read().roundCount, 1);
      buildAndCheckPriority();
      _expectSaves(read());
    });
  });
}
