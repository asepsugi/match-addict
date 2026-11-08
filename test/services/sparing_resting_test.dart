import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';

import '../hifi/screens/schedule_fixture.dart' show mixedR1, mixedTournament;
import '../hifi/screens/sparing_fixture.dart';
import '../hifi/screens/sparing_mixed_fixture.dart' show mixedSparing13m, mixedSparingConfig, mixedSparingEmpty;

/// Istirahat per klub dan klub pembatas di `ActiveTournament` (docs/tasks.md SP-18a): data 13A (Fixed setelah R5) dan
/// 13B (Mixed R3, 8 / 3).
void main() {
  List<String> pairNames(ActiveTournament a, Pair p) => [a.playerName(p.player1Id), a.playerName(p.player2Id)];

  /// Per klub: "klub: nama, nama".
  List<String> pairsByClub(ActiveTournament a, int round) => [
    for (final c in a.restingPairsByClub(round))
      '${c.club.name}: ${[for (final p in c.pairs) pairNames(a, p).join(' · ')].join(', ')}',
  ];
  List<String> playersByClub(ActiveTournament a, int round) => [
    for (final c in a.restingPlayersByClub(round)) '${c.club.name}: ${[for (final p in c.players) p.name].join(', ')}',
  ];

  group('restingPairsByClub (Fixed sparing)', () {
    test('13A setelah R5: tabel 13.11, klub pertama dulu', () {
      final a = sparingAfterR5();
      expect(pairsByClub(a, 1), ['PB Garuda: Eko · Fajar, Gita · Hadi', 'Matcha Club: Maya · Nanda']);
      expect(pairsByClub(a, 2), ['PB Garuda: Andi · Budi, Citra · Dewi', 'Matcha Club: Kiki · Lina']);
      expect(pairsByClub(a, 3), ['PB Garuda: Eko · Fajar, Gita · Hadi', 'Matcha Club: Indra · Joko']);
      expect(pairsByClub(a, 5), ['PB Garuda: Eko · Fajar, Gita · Hadi', 'Matcha Club: Kiki · Lina']);
    });

    test('klub tanpa yang istirahat → daftar kosong (kolom "–"); round tanpa catatan → dua klub kosong', () {
      final small = sparingSmall();
      // 14m (8 / 4, 3 court): R1 G1–M1, G2–M2 → semua pasangan Matcha main.
      expect(pairsByClub(small, 1), ['PB Garuda: Eko · Fajar, Gita · Hadi', 'Matcha Club: ']);
      expect(pairsByClub(sparingAfterR5(), 99), ['PB Garuda: ', 'Matcha Club: ']);
    });

    test('pasangan lama yang sudah diatur ulang tetap ketemu; id tak dikenal dilewati, tidak melempar', () {
      final replaced = sparingReplaced();
      expect(pairsByClub(replaced, 2), ['PB Garuda: Andi · Budi, Citra · Dewi', 'Matcha Club: Kiki · Lina']);
      final odd = sparingAfterR5().copyWith(
        restingPairs: {
          1: ['tidak-ada', 'pair-g3'],
        },
      );
      expect(pairsByClub(odd, 1), ['PB Garuda: Eko · Fajar', 'Matcha Club: ']);
    });

    test('turnamen biasa → kosong', () {
      expect(mixedTournament([mixedR1]).restingPairsByClub(1), isEmpty);
    });
  });

  group('restingPlayersByClub (Mixed sparing, round lewat)', () {
    test('13B R1–R3: catatan generator per klub, urut daftar pemain', () {
      final a = mixedSparing13m().active;
      expect(playersByClub(a, 1), ['PB Garuda: Andi, Budi, Dewi, Hadi', 'Matcha Club: Indra, Lina']);
      expect(playersByClub(a, 2), ['PB Garuda: Citra, Eko, Fajar, Gita', 'Matcha Club: Joko, Maya']);
      expect(playersByClub(a, 3), ['PB Garuda: Andi, Budi, Dewi, Hadi', 'Matcha Club: Kiki, Nanda']);
      expect(playersByClub(a, 4), ['PB Garuda: ', 'Matcha Club: ']);
    });

    test('id tak dikenal dilewati; turnamen biasa → kosong', () {
      final a = mixedSparing13m().active;
      final odd = a.copyWith(
        resting: {
          1: ['tidak-ada', 'm06', 'g02'],
        },
      );
      expect(playersByClub(odd, 1), ['PB Garuda: Budi', 'Matcha Club: Nanda']);
      expect(mixedTournament([mixedR1]).restingPlayersByClub(1), isEmpty);
    });
  });

  group('sparingLimitingClub (15j)', () {
    Club? limiting(int n1, int n2, {Set<String> withdrawn = const {}}) {
      final g = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko', 'Fajar', 'Gita', 'Hadi'].take(n1).toList();
      final m = ['Indra', 'Joko', 'Kiki', 'Lina', 'Maya', 'Nanda', 'Oki'].take(n2).toList();
      return mixedSparingEmpty(
        mixedSparingConfig(garudaPlayers: g, matchaPlayers: m),
      ).copyWith(withdrawn: withdrawn).sparingLimitingClub;
    }

    test('⌊aktif ÷ 2⌋ terkecil: 8 / 6 dan 8 / 3 → Matcha Club; 4 / 7 → PB Garuda', () {
      expect(limiting(8, 6), matcha);
      expect(limiting(8, 3), matcha);
      expect(limiting(4, 7), garuda);
    });

    test('⌊÷ 2⌋ sama → yang pemainnya lebih sedikit; masih sama → klub pertama', () {
      expect(limiting(7, 6), matcha, reason: '3 = 3, 6 < 7');
      expect(limiting(6, 7), garuda, reason: '3 = 3, 6 < 7');
      expect(limiting(6, 6), garuda);
    });

    test('pemain keluar tidak dihitung; turnamen biasa → null', () {
      expect(limiting(8, 6, withdrawn: {'g01', 'g02', 'g03'}), garuda, reason: '5 aktif: ⌊5 ÷ 2⌋ = 2 < 3');
      expect(mixedTournament([mixedR1]).sparingLimitingClub, isNull);
    });
  });
}
