import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/club_score.dart';
import 'package:match_addict/services/ranking/ranking_calculator.dart';
import 'package:match_addict/services/share/podium.dart';

StandingEntry row(String names, int? position) => StandingEntry(
  players: [for (final n in names.split('+')) Player(id: 'p-$n', name: n)],
  standing: PlayerStanding(
    player: Player(id: 'p-$names', name: names),
  ),
  position: position,
);

/// Baris dari daftar nomor; nama dibuat unik ("A0", "A1", …).
List<StandingEntry> rowsOf(List<int?> positions, {bool pairs = false}) => [
  for (var i = 0; i < positions.length; i++) row(pairs ? 'A$i+B$i' : 'A$i', positions[i]),
];

PodiumSteps steps(List<int?> positions, {bool pairs = false}) {
  final p = Podium.of(entries: rowsOf(positions, pairs: pairs));
  expect(p, isA<PodiumSteps>());
  return p as PodiumSteps;
}

List<int> levels(PodiumSteps s) => [for (final b in s.blocks) b.level];

ClubTally tally(String id, int half, int tp) => ClubTally(
  club: Club(id: id, name: id),
  halfWins: half,
  totalPoint: tp,
  diff: 0,
);

ClubResult clubs(int h1, int tp1, int h2, int tp2) =>
    ClubResult(first: tally('g', h1, tp1), second: tally('m', h2, tp2), unit: 'game');

/// Turnamen kerangka untuk baris fakta: [rounds] × [perRound] match, [played] match pertama selesai (sisanya
/// menunggu), [wo] di antaranya WO.
ActiveTournament tournament({
  PartnerMode mode = PartnerMode.mixed,
  String? name,
  required int rounds,
  required int perRound,
  int? played,
  int wo = 0,
}) {
  const pair = Pair(id: 'x', player1Id: 'a', player2Id: 'b');
  final total = rounds * perRound;
  final done = played ?? total;
  final matches = [
    for (var i = 0; i < total; i++)
      MatchGame(
        id: 'm$i',
        roundNumber: i ~/ perRound + 1,
        matchNumberInRound: i % perRound + 1,
        courtId: 'c1',
        pair1: pair,
        pair2: pair,
        status: i >= done ? MatchStatus.pending : (i < wo ? MatchStatus.wo : MatchStatus.done),
      ),
  ];
  return ActiveTournament(
    tournament: Tournament(
      id: 't',
      createdAt: DateTime(2026, 11, 6),
      config: TournamentConfig(
        sport: SportType.padel,
        mode: mode,
        matchDurationMinutes: 15,
        courts: const [],
        players: const [],
        name: name,
      ),
      matches: matches,
    ),
  );
}

void main() {
  group('Podium.of · siapa naik', () {
    test('18c K64 #1 #2 #3 #4 → tiga anak tangga, slot [1,0,2], level [2,1,3], bola 3', () {
      final s = steps([1, 2, 3, 4]);
      expect(s.rows.map((e) => e.position), [1, 2, 3]);
      expect(s.blocks.map((b) => b.face), ['2', '1', '3']);
      expect(levels(s), [2, 1, 3]);
      expect(s.blocks.map((b) => b.balls).reduce((a, b) => a + b), 3);
      expect(s.pairSize, isFalse);
    });

    test('11a K65 #1 #1 #2 #3 #4 → Fajar tidak naik; level slot [1,1,2]', () {
      final s = steps([1, 1, 2, 3, 4]);
      expect(s.rows.length, 3);
      expect(levels(s), [1, 1, 2]);
    });

    test('18g K64 #1 #1 #2: urutan slot dari indeks baris, #2 di kanan', () {
      final s = steps([1, 1, 2]);
      expect(levels(s), [1, 1, 2]);
      expect(s.blocks.map((b) => b.gold), [true, true, false]);
    });

    test('18f K64 #1 #2 #2 #3 → tiga baris (#3 tidak naik); level slot [2,1,2] (dua #2 sama tinggi)', () {
      final s = steps([1, 2, 2, 3]);
      expect(s.rows.length, 3);
      expect(levels(s), [2, 1, 2]);
    });

    test('18h K65 #1 #2 #3 #3 #4 … → empat baris, slot [1,0,2,3], level [2,1,3,3]', () {
      final s = steps([1, 2, 3, 3, 4, 5, 6, 7]);
      expect(s.rows.map((e) => e.position), [1, 2, 3, 3]);
      expect(levels(s), [2, 1, 3, 3]);
    });

    test('18q-3 K65 #1 #1 #2 #2 → empat, level slot [1,1,2,2]', () {
      expect(levels(steps([1, 1, 2, 2, 3])), [1, 1, 2, 2]);
    });

    test('18q-4 K65 #1 #2 #2 #2 → empat, level slot [2,1,2,2]', () {
      expect(levels(steps([1, 2, 2, 2, 3])), [2, 1, 2, 2]);
    });

    test('18i K65 #1 #2 #3 #3 #3 → 5 calon, kelompok #3 dibuang → dua anak tangga, slot [0,1]', () {
      final s = steps([1, 2, 3, 3, 3, 4, 5, 6, 7, 8]);
      expect(s.rows.map((e) => e.position), [1, 2]);
      expect(levels(s), [1, 2]);
    });

    test('18q-1 K65 Fixed #1 ×3 #2 ×3 → tiga, semua level 1, pairSize, bola 6', () {
      final s = steps([1, 1, 1, 2, 2, 2], pairs: true);
      expect(s.rows.length, 3);
      expect(levels(s), [1, 1, 1]);
      expect(s.pairSize, isTrue);
      expect(s.blocks.fold<int>(0, (a, b) => a + b.balls), 6);
    });

    test('18q-2 K65 #1 ×4 tepat batas → empat blok emas', () {
      final s = steps([1, 1, 1, 1, 2, 2, 2, 2]);
      expect(s.rows.length, 4);
      expect(levels(s), [1, 1, 1, 1]);
    });

    test('18q-5 K65 #1 #2 ×4 → 5 calon, buang #2 → satu anak tangga, slot [0]', () {
      final s = steps([1, 2, 2, 2, 2]);
      expect(s.rows.map((e) => e.position), [1]);
      expect(levels(s), [1]);
    });

    test('18s K68 #1 ×6 → Kerumunan n = 6, satu blok emas "1" tanpa bola', () {
      final p = Podium.of(entries: rowsOf([1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2]));
      expect(p, isA<PodiumCrowd>());
      final c = p as PodiumCrowd;
      expect(c.rows.length, 6);
      expect(c.block.face, '1');
      expect(c.block.balls, 0);
      expect(c.block.gold, isTrue);
    });

    test('batas K68 #1 ×5 → Kerumunan n = 5', () {
      final p = Podium.of(entries: rowsOf([1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2]));
      expect((p as PodiumCrowd).rows.length, 5);
    });

    test('Kerumunan juga bila semua baris #1 (tidak ada yang kalah)', () {
      expect(Podium.of(entries: rowsOf([1, 1, 1, 1, 1])), isA<PodiumCrowd>());
    });

    test('K73 Kerumunan Fixed: bukan ukuran pasangan (tanpa bola, tanpa pairSize)', () {
      final p = Podium.of(entries: rowsOf([1, 1, 1, 1, 1, 1, 2], pairs: true)) as PodiumCrowd;
      expect(p.block.balls, 0);
    });

    test('dua baris saja → dua anak tangga; satu baris → satu', () {
      expect(levels(steps([1, 2])), [1, 2]);
      expect(levels(steps([1])), [1]);
      expect(levels(steps([1, 1])), [1, 1]);
    });

    test('18l K65/K64 Fixed campuran: pairSize, bola slot [1,2,2] = 5', () {
      final p = Podium.of(entries: [row('Indra+Joko', 1), row('Andi', 2), row('Eko+Fajar', 3)]) as PodiumSteps;
      expect(p.pairSize, isTrue);
      expect(p.blocks.map((b) => b.balls), [1, 2, 2]);
      expect(p.blocks.map((b) => b.balls).reduce((a, b) => a + b), 5);
    });

    test('18j Fixed #1 #2 → pairSize, level [1,2]', () {
      final s = steps([1, 2], pairs: true);
      expect(s.pairSize, isTrue);
      expect(levels(s), [1, 2]);
    });

    test('18t K69 semua position null → Kosong; entries kosong juga', () {
      expect(Podium.of(entries: rowsOf([null, null, null])), isA<PodiumEmpty>());
      expect(Podium.of(entries: const []), isA<PodiumEmpty>());
    });

    test('baris "Belum main" (null) di belakang tidak ikut naik', () {
      expect(steps([1, 2, null, null]).rows.length, 2);
    });
  });

  group('Podium.of · Sparing', () {
    test('13q K62 Garuda 7 – 5 Matcha → [L1 emas "7", L2 "5"]', () {
      final p = Podium.of(entries: const [], clubs: clubs(14, 100, 10, 90)) as PodiumClubs;
      expect(p.blocks.map((b) => b.level), [1, 2]);
      expect(p.blocks.map((b) => b.face), ['7', '5']);
      expect(p.blocks.map((b) => b.balls), [0, 0]);
    });

    test('18n klub pertama tetap kiri walau kalah: 5 – 7 → [L2 "5", L1 emas "7"]', () {
      final p = Podium.of(entries: const [], clubs: clubs(10, 56, 14, 60)) as PodiumClubs;
      expect(p.blocks.map((b) => b.level), [2, 1]);
      expect(p.blocks.map((b) => b.face), ['5', '7']);
      expect(p.blocks.map((b) => b.gold), [false, true]);
    });

    test('18o 6 – 6, TP 58 – 58 → dua emas', () {
      final p = Podium.of(entries: const [], clubs: clubs(12, 58, 12, 58)) as PodiumClubs;
      expect(p.blocks.map((b) => b.level), [1, 1]);
      expect(p.blocks.map((b) => b.face), ['6', '6']);
    });

    test('18o-b 6 – 6, TP 50 – 48 → yang 50 emas, lainnya level 2', () {
      final p = Podium.of(entries: const [], clubs: clubs(12, 50, 12, 48)) as PodiumClubs;
      expect(p.blocks.map((b) => b.level), [1, 2]);
      expect(p.blocks.map((b) => b.face), ['6', '6']);
    });

    test('18p 6½ – 5½', () {
      final p = Podium.of(entries: const [], clubs: clubs(13, 60, 11, 55)) as PodiumClubs;
      expect(p.blocks.map((b) => b.face), ['6½', '5½']);
      expect(p.blocks.map((b) => b.level), [1, 2]);
    });

    test('K72 0 – 0 (belum ada match selesai) → Kosong', () {
      expect(Podium.of(entries: const [], clubs: clubs(0, 0, 0, 0)), isA<PodiumEmpty>());
    });

    test('Sparing mengabaikan entries', () {
      final p = Podium.of(entries: rowsOf([1, 2, 3]), clubs: clubs(14, 100, 10, 90));
      expect(p, isA<PodiumClubs>());
    });
  });

  group('invariant I1–I4 (semua nomor rapat panjang 1–8)', () {
    // Semua deret nomor rapat: mulai 1, tiap baris sama dengan sebelumnya atau naik 1.
    Iterable<List<int>> dense(int length) sync* {
      Iterable<List<int>> go(List<int> acc) sync* {
        if (acc.length == length) {
          yield acc;
          return;
        }
        yield* go([...acc, acc.last]);
        yield* go([...acc, acc.last + 1]);
      }

      yield* go([1]);
    }

    test('I1–I4 + hasil hanya Steps/Crowd', () {
      var count = 0;
      for (var n = 1; n <= 8; n++) {
        for (final positions in dense(n)) {
          count++;
          for (final pairs in [false, true]) {
            final rows = rowsOf(positions, pairs: pairs);
            final p = Podium.of(entries: rows);
            final tag = '$positions pairs=$pairs';
            final ones = positions.where((x) => x == 1).length;
            // I6: Kerumunan ⇔ #1 lebih dari empat.
            expect(p is PodiumCrowd, ones > 4, reason: tag);
            if (p is PodiumCrowd) {
              expect(p.rows.length, greaterThan(4), reason: tag);
              expect(p.rows.every((e) => e.position == 1), isTrue, reason: tag);
              expect(p.rows.length, positions.where((x) => x == 1).length, reason: tag);
              expect(p.block.gold && p.block.balls == 0, isTrue, reason: tag);
              continue;
            }
            final s = p as PodiumSteps;
            // I1: 1–4 baris, awalan, tidak ada nomor terpotong.
            expect(s.rows.length, inInclusiveRange(1, 4), reason: tag);
            expect(s.rows, rows.take(s.rows.length).toList(), reason: tag);
            for (final n in s.rows.map((e) => e.position).toSet()) {
              expect(
                s.rows.where((e) => e.position == n).length,
                rows.where((e) => e.position == n).length,
                reason: tag,
              );
            }
            // I6: maksimal — minimal min(3, |R|) baris, atau satu kelompok nomor berikutnya membuat > 4 baris.
            final nextGroup = s.rows.length < rows.length
                ? positions.where((x) => x == positions[s.rows.length]).length
                : 0;
            expect(
              s.rows.length >= (rows.length < 3 ? rows.length : 3) || s.rows.length + nextGroup > 4,
              isTrue,
              reason: tag,
            );
            // I2: nomor sama → level sama; nomor beda → level beda.
            final byPos = <int, Set<int>>{};
            for (final b in s.blocks) {
              byPos.putIfAbsent(int.parse(b.face), () => {}).add(b.level);
            }
            expect(byPos.values.every((l) => l.length == 1), isTrue, reason: tag);
            expect(byPos.values.map((l) => l.single).toSet().length, byPos.length, reason: tag);
            // I3: emas ⇔ level 1, dan ada minimal satu emas.
            expect(s.blocks.every((b) => b.gold == (b.level == 1)), isTrue, reason: tag);
            expect(s.blocks.any((b) => b.gold), isTrue, reason: tag);
            // I4: jumlah bola = jumlah nama di baris yang naik.
            expect(
              s.blocks.fold<int>(0, (a, b) => a + b.balls),
              s.rows.fold<int>(0, (a, e) => a + e.players.length),
              reason: tag,
            );
          }
        }
      }
      expect(count, 255); // 2^0 + … + 2^7
    });
  });

  group('rowNoun', () {
    test('Mixed/Mexicano "pemain"; Fixed semua pasangan "pasangan"; Fixed campuran null', () {
      expect(rowNoun(tournament(rounds: 1, perRound: 1), [row('A', 1)]), 'pemain');
      expect(rowNoun(tournament(mode: PartnerMode.mexicano, rounds: 1, perRound: 1), [row('A', 1)]), 'pemain');
      final fixed = tournament(mode: PartnerMode.fixed, rounds: 1, perRound: 1);
      expect(rowNoun(fixed, [row('A+B', 1), row('C+D', 2)]), 'pasangan');
      expect(rowNoun(fixed, [row('A+B', 1), row('C', 2)]), isNull);
    });
  });

  group('podiumFacts', () {
    List<StandingEntry> n(int count, {bool pairs = false}) =>
        rowsOf([for (var i = 0; i < count; i++) i + 1], pairs: pairs);

    test('18c bernama, Final, Mixed 12, 6 round, 18 match', () {
      final a = tournament(name: 'Mabar Jumat', rounds: 6, perRound: 3);
      expect(podiumFacts(active: a, rows: n(12), isFinal: true), 'Padel · 12 pemain · 6 round · 18 match');
    });

    test('18d tanpa nama', () {
      final a = tournament(rounds: 6, perRound: 3);
      expect(podiumFacts(active: a, rows: n(12), isFinal: true), '12 pemain · 6 round · 18 match');
    });

    test('18e Fixed 6 pasangan, 15 match', () {
      final a = tournament(mode: PartnerMode.fixed, rounds: 5, perRound: 3);
      expect(podiumFacts(active: a, rows: n(6, pairs: true), isFinal: true), '6 pasangan · 5 round · 15 match');
    });

    test('11d bernama, Final, 1 WO', () {
      final a = tournament(name: 'X', rounds: 4, perRound: 2, wo: 1);
      expect(podiumFacts(active: a, rows: n(10), isFinal: true), 'Padel · 10 pemain · 4 round · 8 match · 1 WO');
    });

    test('11a / 11c Sementara R3 lengkap', () {
      final named = tournament(name: 'X', rounds: 3, perRound: 2);
      expect(podiumFacts(active: named, rows: n(11), isFinal: false), 'Padel · 11 pemain · R3 · 6 dari 6 match');
      final plain = tournament(rounds: 3, perRound: 2);
      expect(podiumFacts(active: plain, rows: n(11), isFinal: false), '11 pemain · R3 · 6 dari 6 match');
    });

    test('18k Sementara R3, 7 dari 9', () {
      final a = tournament(name: 'X', rounds: 3, perRound: 3, played: 7);
      expect(podiumFacts(active: a, rows: n(12), isFinal: false), 'Padel · 12 pemain · R3 · 7 dari 9 match');
    });

    test('18l Fixed campuran: bagian jumlah hilang', () {
      final a = tournament(mode: PartnerMode.fixed, rounds: 16, perRound: 2);
      final rows = [row('A+B', 1), row('C', 2), row('D+E', 3)];
      expect(podiumFacts(active: a, rows: rows, isFinal: true), '16 round · 32 match');
    });

    test('18t R1 belum ada skor', () {
      final a = tournament(name: 'X', rounds: 1, perRound: 3, played: 0);
      expect(podiumFacts(active: a, rows: n(12), isFinal: false), 'Padel · 12 pemain · R1 · 0 dari 3 match');
    });

    test('18s R1 tiga skor', () {
      final a = tournament(name: 'X', rounds: 1, perRound: 3);
      expect(podiumFacts(active: a, rows: n(12), isFinal: false), 'Padel · 12 pemain · R1 · 3 dari 3 match');
    });

    test('18q-1 / 18q-2 tanpa nama, Sementara R1', () {
      final fixed = tournament(mode: PartnerMode.fixed, rounds: 1, perRound: 3);
      expect(podiumFacts(active: fixed, rows: n(6, pairs: true), isFinal: false), '6 pasangan · R1 · 3 dari 3 match');
      final mixed = tournament(rounds: 1, perRound: 2);
      expect(podiumFacts(active: mixed, rows: n(8), isFinal: false), '8 pemain · R1 · 2 dari 2 match');
    });

    test('13q Sparing Fixed tanpa nama, 1 WO', () {
      final a = tournament(mode: PartnerMode.fixed, rounds: 6, perRound: 2, wo: 1);
      expect(podiumFacts(active: a, rows: n(7, pairs: true), isFinal: true), '7 pasangan · 6 round · 12 match · 1 WO');
    });

    test('WO juga tampil di Sementara', () {
      final a = tournament(rounds: 2, perRound: 2, played: 3, wo: 2);
      expect(podiumFacts(active: a, rows: n(8), isFinal: false), '8 pemain · R2 · 3 dari 4 match · 2 WO');
    });

    test('K72 Sparing 0 – 0: "7 pasangan · R1 · 0 dari 6 match"', () {
      final a = tournament(mode: PartnerMode.fixed, rounds: 1, perRound: 6, played: 0);
      expect(podiumFacts(active: a, rows: n(7, pairs: true), isFinal: false), '7 pasangan · R1 · 0 dari 6 match');
    });
  });
}
