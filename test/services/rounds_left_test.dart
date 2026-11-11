import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';

/// Satu rumus sisa round per court (`roundsLeftPerCourt`) dan baris "n court, berkurang mulai R…" (`courtsAhead`) yang
/// dipakai Lanjutkan Mixed (08c) dan Tambah round Fixed (06w, 14n). SP-19: tiga salinan disatukan.
void main() {
  group('roundsLeftPerCourt', () {
    final start = DateTime(2026, 11, 3, 19);
    final active = ActiveTournament(
      tournament: Tournament(
        id: 't',
        createdAt: start,
        config: TournamentConfig(
          sport: SportType.padel,
          mode: PartnerMode.mixed,
          matchDurationMinutes: 15,
          courts: const [
            Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 60),
            Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
          ],
          players: [for (var i = 0; i < 8; i++) Player(id: 'p$i', name: 'P$i')],
        ),
      ),
    );

    test('⌊(sisa booking + tambahan) ÷ durasi⌋ per court, urutan config', () {
      // 40 menit berjalan: sisa 20 dan 80 menit.
      final now = start.add(const Duration(minutes: 40));
      expect(active.roundsLeftPerCourt(now), [1, 5]);
      expect(active.roundsLeftPerCourt(now, {'c1': 30}), [3, 5]);
    });

    test('booking habis = 0, tidak negatif', () {
      expect(active.roundsLeftPerCourt(start.add(const Duration(hours: 3))), [0, 0]);
    });

    test('capacityAhead memakai angka yang sama', () {
      final now = start.add(const Duration(minutes: 40));
      final ahead = active.capacityAhead(now, {'c1': 30});
      expect(ahead.rounds, 5);
      expect(ahead.courts, 2);
      expect(ahead.fewerCourtsFrom, 4);
    });
  });

  group('courtsAhead', () {
    test('semua court muat sampai akhir: tanpa "berkurang"', () {
      expect(ActiveTournament.courtsAhead([4, 4], 4), (courts: 2, fewerFrom: null));
    });

    test('court terpendek habis di tengah: berkurang mulai round sesudahnya', () {
      expect(ActiveTournament.courtsAhead([2, 4], 4), (courts: 2, fewerFrom: 3));
    });

    test('hanya round dalam booking yang dihitung: berkurang sesudah semua habis = lewat booking, bukan berkurang', () {
      expect(ActiveTournament.courtsAhead([2, 2], 4), (courts: 2, fewerFrom: null));
      // Court pertama habis di R3, tapi round tambahan cuma 2.
      expect(ActiveTournament.courtsAhead([2, 4], 2), (courts: 2, fewerFrom: null));
    });

    test('court yang sejak awal tidak muat tidak dihitung', () {
      expect(ActiveTournament.courtsAhead([0, 3, 3], 3), (courts: 2, fewerFrom: null));
    });

    test('sparing: C\' membatasi court, jadi court habis tanpa mengurangi C\' bukan "berkurang"', () {
      // 3 court muat, tapi C' = 2 (klub dengan 2 pasangan); Court 1 habis di R3 → masih 2 court dipakai.
      int c(int n) => n < 2 ? n : 2;
      expect(ActiveTournament.courtsAhead([2, 4, 4], 4, c), (courts: 2, fewerFrom: null));
      expect(ActiveTournament.courtsAhead([2, 2, 4], 4, c), (courts: 2, fewerFrom: 3));
    });
  });
}
