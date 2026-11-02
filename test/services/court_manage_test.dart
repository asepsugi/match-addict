import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/endless_round_generator.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import '../hifi/screens/schedule_fixture.dart';

/// Court di tengah turnamen Mixed (logic.md §10), dengan data frame 06p–06s / 08e–08k: jam mulai per court, kapan
/// court baru dipakai, tambah/ubah/hapus court, dan Lanjutkan memakai rumus yang sama.
void main() {
  DateTime at(int minutes) => fixtureStart.add(Duration(minutes: minutes));
  final p = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5Court1], courts: 1);
  final q = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5]);
  final r = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5Done, courtR6, courtR7]);
  final s = courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5Done, courtR6, courtR7, courtR8, courtR9]);
  List<String> first(Iterable<Player> players) => [for (final x in players) x.name.split(' ').first];
  Set<String> playersOf(MatchGame m) => {...m.pair1.playerIds, ...m.pair2.playerIds};

  late ProviderContainer container;
  late DateTime now;
  ActiveTournament read() => container.read(tournamentProvider)!;
  TournamentController load(ActiveTournament active, int minutes) {
    now = at(minutes);
    container = ProviderContainer(
      overrides: [
        tournamentProvider.overrideWith(() => LoadedTournament(active)),
        clockProvider.overrideWithValue(() => now),
      ],
    );
    addTearDown(container.dispose);
    return container.read(tournamentProvider.notifier);
  }

  group('jam mulai per court', () {
    test('sisa booking dari jam mulai court itu: 20.02 Court 1 00:58, Court 2 (mulai 20.02) 02:00', () {
      expect(q.remainingBookingMinutes(q.config.courts[0], at(62)), 58);
      expect(q.remainingBookingMinutes(q.config.courts[1], at(62)), 120);
      expect(s.remainingBookingMinutes(s.config.courts[0], at(124)), 0);
      expect(s.remainingBookingMinutes(s.config.courts[1], at(124)), 58);
    });

    test('simpanan: startMinute ikut tersimpan; simpanan 2.1 tanpa kuncinya terbaca sebagai 0', () {
      final back = TournamentCodec.decode(TournamentCodec.encode(q))!;
      expect([for (final c in back.config.courts) c.startMinute], [0, 62]);
      final old = TournamentCodec.encode(p);
      expect(old, isNot(contains('startMinute')));
      expect(TournamentCodec.decode(old)!.config.courts.single.startMinute, 0);
    });

    test('tambah jam: court berjalan disambung, court habis dipesan ulang dari sekarang', () {
      final c1 = s.config.courts[0];
      expect(s.extendedBy(c1, 60, at(124)).startMinute, 124, reason: 'habis 21.00, dipesan 21.04');
      expect(s.remainingBookingMinutes(s.extendedBy(c1, 60, at(124)), at(124)), 60);
      final c2 = s.config.courts[1];
      expect(s.extendedBy(c2, 60, at(124)).endMinute, c2.endMinute + 60);
      // Detail court: stepper = panjang booking; court habis mulai 0.
      expect(s.withBookingHours(c1, 0, at(124)), same(c1));
      expect(s.withBookingHours(c1, 1, at(124)).startMinute, 124);
      expect(q.withBookingHours(q.config.courts[0], 3, at(62)).endMinute, 180);
    });
  });

  group('kapan court dipakai', () {
    test('08e: round berjalan, 6 istirahat → langsung main 4 pemain = Prioritas main di R6', () {
      final draft = p.newCourt(id: 'baru', name: '', colorIndex: 1, bookingMinutes: 120, now: at(62));
      expect(draft.name, 'Court 2');
      expect(draft.startMinute, 62);
      final use = EndlessRoundGenerator.courtUse(p.withCourt(draft), 'baru', at(62));
      expect(use.use, CourtUse.now);
      final shown = EndlessRoundGenerator.restingAfterLastRound(p, at(62)).priority;
      expect(first(use.players)..sort(), first(shown)..sort());
      expect(first(shown), ['Andi', 'Citra', 'Dewant', 'Gina']);
    });

    test('08g: 10 pemain sudah mengisi 2 court → belum terpakai', () {
      final draft = q.newCourt(id: 'baru', name: '', colorIndex: 2, bookingMinutes: 120, now: at(62));
      expect(EndlessRoundGenerator.courtUse(q.withCourt(draft), 'baru', at(62)).use, CourtUse.unused);
    });

    test('08f: round lengkap, Court 1 tinggal 12 menit → court baru menambah slot R8', () {
      final draft = r.newCourt(id: 'baru', name: '', colorIndex: 2, bookingMinutes: 120, now: at(108));
      expect(r.courtsAvailableAt(at(108)).map((c) => c.id), ['c2']);
      expect(EndlessRoundGenerator.courtUse(r.withCourt(draft), 'baru', at(108)).use, CourtUse.nextRound);
    });

    test('08k: court habis dipesan ulang saat R9 berjalan → langsung main = Prioritas main di R10', () {
      final rebooked = s.withBookingHours(s.config.courts[0], 1, at(124));
      final use = EndlessRoundGenerator.courtUse(s.withCourt(rebooked), 'c1', at(124));
      expect(use.use, CourtUse.now);
      expect(first(use.players)..sort(), ['Citra', 'Dewant', 'Gina', 'Hana']);
      expect(first(EndlessRoundGenerator.restingAfterLastRound(s, at(124)).priority), [
        'Citra',
        'Dewant',
        'Gina',
        'Hana',
      ]);
    });

    test('court yang sudah muat tidak tiba-tiba dipakai saat hanya diganti nama atau jamnya', () {
      final renamed = q.config.courts[0].copyWith(name: 'Court A', bookingDurationMinutes: 180);
      final use = EndlessRoundGenerator.courtUse(q.withCourt(renamed), 'c1', at(62), wasAvailable: true);
      expect(use.use, isNot(CourtUse.now));
    });
  });

  group('controller', () {
    test('Tambah court saat R5 berjalan: match baru di Court 2, yang main dikeluarkan dari daftar istirahat', () {
      final controller = load(p, 62);
      controller.addCourt(name: '', colorIndex: 1, bookingMinutes: 120);
      final a = read();
      expect(a.config.courts.map((c) => c.name), ['Court 1', 'Court 2']);
      expect(a.config.courts[1].startMinute, 62);
      final r5 = a.matchesOfRound(5);
      expect(r5.map((m) => m.courtId), ['c1', a.config.courts[1].id]);
      expect(r5[1].matchNumberInRound, 2);
      expect(playersOf(r5[1]), {
        for (final x in a.config.players)
          if (['Andi', 'Citra', 'Dewant', 'Gina'].contains(x.name.split(' ').first)) x.id,
      });
      expect(first([for (final id in a.restingPlayerIdsByRound[5]!) a.config.players.firstWhere((x) => x.id == id)]), [
        'Budi',
        'Eko',
      ]);
      // Selisih match antar pemain tetap ≤ 1 (pending dihitung, seperti generator).
      final counts = {
        for (final x in a.activePlayers) x.id: a.matches.where((m) => playersOf(m).contains(x.id)).length,
      };
      expect(
        counts.values.reduce((x, y) => x > y ? x : y) - counts.values.reduce((x, y) => x < y ? x : y),
        lessThanOrEqualTo(1),
      );
    });

    test('Hapus court: hanya court bernomor terakhir tanpa skor; match-nya ikut dihapus, pemainnya istirahat lagi', () {
      final controller = load(q, 62);
      expect(read().canRemoveCourt('c1'), isFalse, reason: 'bukan court terakhir, dan sudah punya skor');
      expect(read().canRemoveCourt('c2'), isTrue);
      expect(controller.removeCourt('c2'), isTrue);
      expect(read().config.courts.map((c) => c.id), ['c1']);
      expect(read().matchesOfRound(5), hasLength(1));
      expect(read().restingPlayerIdsByRound[5], hasLength(6));
      expect(read().canRemoveCourt('c1'), isFalse, reason: 'satu-satunya court');
    });

    test('Hapus court ditolak kalau round berjalan hanya berisi match di court itu (pakai Batalkan R…)', () {
      load(s, 124);
      expect(read().config.courts.last.id, 'c2');
      expect(read().canRemoveCourt('c2'), isFalse);
    });

    test('Simpan detail court habis +1 jam (08k): dipesan ulang 21.04 dan langsung main di R9', () {
      final controller = load(s, 124);
      controller.updateCourt(read().withBookingHours(read().config.courts[0], 1, now));
      final c1 = read().config.courts[0];
      expect((c1.startMinute, c1.bookingDurationMinutes), (124, 60));
      final r9 = read().matchesOfRound(9);
      expect(r9.map((m) => m.courtId), ['c2', 'c1']);
      final names = {for (final id in playersOf(r9[1])) read().playerName(id).split(' ').first};
      expect(names, {'Citra', 'Dewant', 'Gina', 'Hana'});
    });

    test('Simpan detail court yang masih berjalan (+1 jam, 08i) hanya memperpanjang, tanpa match baru', () {
      final controller = load(q, 62);
      controller.updateCourt(read().withBookingHours(read().config.courts[0], 3, now));
      expect(read().config.courts[0].endMinute, 180);
      expect(read().matchesOfRound(5), hasLength(2));
    });

    test('Lanjutkan memakai rumus yang sama: court habis dipesan ulang dari sekarang', () {
      final controller = load(
        courtTournament([courtR1, courtR2, courtR3, courtR4, courtR5Done, courtR6, courtR7, courtR8]),
        200,
      );
      controller.finishNow();
      controller.resume({'c1': 60, 'c2': 60});
      expect([for (final c in read().config.courts) (c.startMinute, c.bookingDurationMinutes)], [(200, 60), (200, 60)]);
    });

    test('Batalkan R5 menghapus match court baru juga; court-nya tetap', () {
      final controller = load(p, 62);
      controller.addCourt(name: 'VIP', colorIndex: 1, bookingMinutes: 120);
      controller.cancelLastRound();
      expect(read().roundCount, 4);
      expect(read().config.courts.map((c) => c.name), ['Court 1', 'VIP']);
    });

    test('Kelola court tidak ada di Fixed atau setelah diakhiri; maksimal 10 court', () {
      final controller = load(q, 62);
      for (var i = 0; i < 12; i++) {
        controller.addCourt(name: '', colorIndex: 0, bookingMinutes: 60);
      }
      expect(read().config.courts, hasLength(TournamentConfig.maxCourts));
      controller.finishNow();
      expect(read().canManageCourts, isFalse);
    });
  });
}
