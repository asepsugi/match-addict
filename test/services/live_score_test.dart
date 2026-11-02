import 'dart:convert';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:match_addict/features/live/live_host_controller.dart';
import 'package:match_addict/features/live/live_view_controller.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/live/live_relay.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi/screens/schedule_fixture.dart';

/// Live score (PRD §13, logic.md §11): klien relay, pengiriman dari HP host, dan halaman penonton, di atas relay
/// tiruan yang meniru `relay/src/index.js` (diuji sendiri lewat `relay/smoke.sh`).
class FakeRelay {
  final lives = <String, ({String token, int rev, String payload})>{};
  final log = <String>[];
  bool offline = false;
  var _created = 0;

  late final client = MockClient((req) async {
    if (offline) throw http.ClientException('tidak ada internet');
    final segments = req.url.pathSegments;
    log.add([req.method, ...segments.skip(1)].join(' '));
    if (segments.length == 1) {
      final code = 'K7Q2M${'XYZ'[_created++]}';
      lives[code] = (token: 'rahasia-$code', rev: 1, payload: req.body);
      return http.Response(jsonEncode({'code': code, 'token': 'rahasia-$code'}), 201);
    }
    final code = segments[1];
    final live = lives[code];
    if (live == null) return http.Response('', req.method == 'DELETE' ? 204 : 404);
    if (req.method != 'GET' && req.headers['Authorization'] != 'Bearer ${live.token}') return http.Response('', 403);
    switch (req.method) {
      case 'GET':
        if (req.url.queryParameters['since'] == '${live.rev}') return http.Response('', 204);
        return http.Response(jsonEncode({'rev': live.rev, 'payload': live.payload}), 200);
      case 'PUT':
        lives[code] = (token: live.token, rev: live.rev + 1, payload: req.body);
      case 'DELETE':
        lives.remove(code);
    }
    return http.Response('', 204);
  });

  /// Host lain (atau HP ini) mengirim turnamen baru ke [code].
  void hostSends(String code, String payload) {
    final live = lives[code]!;
    lives[code] = (token: live.token, rev: live.rev + 1, payload: payload);
  }

  ActiveTournament? latest(String code) => TournamentCodec.decode(lives[code]?.payload);
}

TournamentConfig _config() => TournamentConfig(
  sport: SportType.padel,
  mode: PartnerMode.mixed,
  matchDurationMinutes: 15,
  courts: const [
    Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120),
    Court(id: 'c2', name: 'Court 2', colorIndex: 1, bookingDurationMinutes: 120),
  ],
  players: [for (var i = 0; i < 8; i++) Player(id: 'p$i', name: 'Pemain $i')],
);

/// Microtask dan balasan MockClient (keduanya Future biasa) selesai.
Future<void> settle() async {
  for (var i = 0; i < 10; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  group('LiveRelay', () {
    test('kode live dibaca dari fragment halaman, huruf kecil diterima', () {
      expect(LiveRelay.codeIn(Uri.parse('https://asepsugi.github.io/match-addict/#/live/k7q2mx')), 'K7Q2MX');
      // 0/O dan 1/I/L tidak pernah dibuat relay.
      expect(LiveRelay.codeIn(Uri.parse('https://asepsugi.github.io/match-addict/#/live/K7Q2M0')), isNull);
      expect(LiveRelay.codeIn(Uri.parse('https://asepsugi.github.io/match-addict/#/leaderboard')), isNull);
      expect(LiveRelay.codeIn(Uri.parse('https://asepsugi.github.io/match-addict/')), isNull);
      expect(LiveRelay.link('K7Q2MX'), 'https://asepsugi.github.io/match-addict/#/live/K7Q2MX');
    });

    test('buat, kirim, ambil sejak rev, hapus', () async {
      final fake = FakeRelay();
      final relay = LiveRelay(base: Uri.parse('https://relay.test'), client: fake.client);
      final created = await relay.create('{"schema":2}');
      expect(created.code, 'K7Q2MX');

      final first = await relay.fetch(created.code) as LiveSnapshot;
      expect((first.rev, first.payload), (1, '{"schema":2}'));
      expect(await relay.fetch(created.code, since: 1), isA<LiveUnchanged>());

      await relay.push(created.code, created.token, '{"schema":2,"x":1}');
      expect((await relay.fetch(created.code, since: 1) as LiveSnapshot).rev, 2);
      await expectLater(
        relay.push(created.code, 'token-orang-lain', '{}'),
        throwsA(isA<LiveRelayException>().having((e) => e.status, 'status', 403)),
      );

      await relay.delete(created.code, created.token);
      expect(await relay.fetch(created.code), isA<LiveGone>());
    });
  });

  group('HP host', () {
    late FakeRelay fake;
    late TournamentStore store;
    late ProviderContainer container;
    late DateTime now;
    LiveHost? live() => container.read(liveHostProvider);
    TournamentController controller() => container.read(tournamentProvider.notifier);
    ActiveTournament active() => container.read(tournamentProvider)!;

    ProviderContainer open() {
      final c = ProviderContainer(
        overrides: [
          tournamentStoreProvider.overrideWithValue(store),
          clockProvider.overrideWithValue(() => now),
          liveRelayProvider.overrideWithValue(LiveRelay(base: Uri.parse('https://relay.test'), client: fake.client)),
        ],
      );
      // Seperti MabarApp: controller hidup sepanjang app.
      c.listen(liveHostProvider, (_, __) {});
      return c;
    }

    void score() {
      final m = active().matchesOfRound(1).firstWhere((m) => m.status == MatchStatus.pending);
      controller().submitScore(m.id, const [SetScore(side1: 13, side2: 8)]);
    }

    setUp(() {
      fake = FakeRelay();
      store = TournamentStore.memory();
      now = DateTime(2026, 10, 24, 19);
      container = open();
      controller().startIfNeeded(_config());
    });
    tearDown(() => container.dispose());

    test('mulai: turnamen terkirim, kode tersimpan di device', () async {
      expect(live(), isNull);
      expect(await container.read(liveHostProvider.notifier).start(), isTrue);
      expect(live()!.code, 'K7Q2MX');
      expect(live()!.link, 'https://asepsugi.github.io/match-addict/#/live/K7Q2MX');
      expect(live()!.sentAt, now);
      expect(fake.latest('K7Q2MX')!.tournament.id, active().tournament.id);
      expect(store.loadLive()!.code, 'K7Q2MX');
    });

    test('setiap perubahan terkirim sebagai keadaan terbaru', () async {
      await container.read(liveHostProvider.notifier).start();
      now = now.add(const Duration(minutes: 14));
      score();
      await settle();
      expect(fake.latest('K7Q2MX')!.matches.where((m) => m.status == MatchStatus.done), hasLength(1));
      expect(live()!.sentAt, now);
      expect(live()!.waiting, isFalse);
    });

    test('tanpa internet: menunggu, lalu terkirim di perubahan berikutnya', () async {
      await container.read(liveHostProvider.notifier).start();
      final sent = now;
      fake.offline = true;
      now = now.add(const Duration(minutes: 14));
      score();
      await settle();
      expect(live()!.waiting, isTrue);
      expect(live()!.sentAt, sent);

      fake.offline = false;
      score();
      await settle();
      expect(live()!.waiting, isFalse);
      expect(fake.latest('K7Q2MX')!.matches.where((m) => m.status == MatchStatus.done), hasLength(2));
    });

    test('mulai gagal tanpa internet: live tidak menyala', () async {
      fake.offline = true;
      expect(await container.read(liveHostProvider.notifier).start(), isFalse);
      expect(live(), isNull);
      expect(store.loadLive(), isNull);
    });

    test('hentikan: data di relay dihapus; tanpa internet live tetap menyala', () async {
      await container.read(liveHostProvider.notifier).start();
      fake.offline = true;
      expect(await container.read(liveHostProvider.notifier).stop(), isFalse);
      expect(live(), isNotNull);

      fake.offline = false;
      expect(await container.read(liveHostProvider.notifier).stop(), isTrue);
      expect(live(), isNull);
      expect(fake.lives, isEmpty);
      expect(store.loadLive(), isNull);
    });

    test('selesai lewat Bagikan: live tetap ada dan kembali saat dilanjutkan dari Beranda', () async {
      await container.read(liveHostProvider.notifier).start();
      final finished = active();
      await controller().close();
      expect(live(), isNull);
      expect(fake.lives, contains('K7Q2MX'));

      // Turnamen baru tidak menghapus live turnamen terakhir yang masih bisa dilanjutkan.
      controller().startIfNeeded(_config());
      await settle();
      expect(fake.lives, contains('K7Q2MX'));
      expect(live(), isNull);

      controller().resume({'c1': 60}, from: finished);
      await settle();
      expect(live()!.code, 'K7Q2MX');
      expect(fake.latest('K7Q2MX')!.config.courts.first.bookingDurationMinutes, greaterThan(120));
    });

    test('Hapus & mulai baru: live turnamen yang dibuang ikut berhenti', () async {
      await container.read(liveHostProvider.notifier).start();
      controller().startIfNeeded(_config());
      await settle();
      expect(fake.lives, isEmpty);
      expect(store.loadLive(), isNull);
      expect(live(), isNull);
    });

    test('app dibuka ulang: live berlanjut dan langsung mengirim keadaan terakhir', () async {
      await container.read(liveHostProvider.notifier).start();
      fake.offline = true;
      score();
      await settle();
      container.dispose();

      fake.offline = false;
      container = open();
      expect(live()!.code, 'K7Q2MX');
      await settle();
      expect(fake.log.last, 'PUT K7Q2MX');
      expect(fake.latest('K7Q2MX')!.matches.where((m) => m.status == MatchStatus.done), hasLength(1));
    });

    test('live yang sudah terhapus di relay: menu kembali menawarkan mulai', () async {
      await container.read(liveHostProvider.notifier).start();
      fake.lives.clear();
      score();
      await settle();
      expect(live(), isNull);
      expect(store.loadLive(), isNull);
    });
  });

  testWidgets('HP host: kiriman gagal dicoba lagi 30 detik kemudian tanpa perubahan baru', (tester) async {
    final fake = FakeRelay();
    final container = ProviderContainer(
      overrides: [
        liveRelayProvider.overrideWithValue(LiveRelay(base: Uri.parse('https://relay.test'), client: fake.client)),
      ],
    );
    addTearDown(container.dispose);
    container.listen(liveHostProvider, (_, __) {});
    container.read(tournamentProvider.notifier).startIfNeeded(_config());
    await container.read(liveHostProvider.notifier).start();

    fake.offline = true;
    final m = container.read(tournamentProvider)!.matchesOfRound(1).first;
    container.read(tournamentProvider.notifier).submitScore(m.id, const [SetScore(side1: 13, side2: 8)]);
    await tester.pump();
    expect(container.read(liveHostProvider)!.waiting, isTrue);

    fake.offline = false;
    await tester.pump(LiveHostController.retryDelay);
    await tester.pump();
    expect(container.read(liveHostProvider)!.waiting, isFalse);
    expect(fake.latest('K7Q2MX')!.matches.first.status, MatchStatus.done);
  });

  group('halaman penonton', () {
    final first = mixedTournament([mixedR1, mixedR2, mixedR3Running]);
    final next = mixedTournament([
      mixedR1,
      mixedR2,
      mixedR3Running.map((m) => (m.$1, m.$2, m.$3, m.$4, 11, 10)).toList(),
    ]);

    late FakeRelay fake;
    ProviderContainer watch(WidgetTester tester) {
      final container = ProviderContainer(
        overrides: [
          liveCodeProvider.overrideWithValue('K7Q2MX'),
          tournamentProvider.overrideWith(LiveTournamentController.new),
          liveRelayProvider.overrideWithValue(LiveRelay(base: Uri.parse('https://relay.test'), client: fake.client)),
        ],
      );
      container.listen(tournamentProvider, (_, __) {});
      return container;
    }

    setUp(() {
      fake = FakeRelay();
      fake.lives['K7Q2MX'] = (token: 'rahasia', rev: 1, payload: TournamentCodec.encode(first));
    });

    LiveViewStatus? status(ProviderContainer c) => c.read(liveViewProvider)?.status;

    testWidgets('memuat, tampil, lalu ikut berubah tiap 10 detik', (tester) async {
      final c = watch(tester);
      expect(status(c), LiveViewStatus.loading);
      expect(c.read(tournamentProvider), isNull);
      await tester.pump();
      expect(status(c), LiveViewStatus.live);
      expect(c.read(tournamentProvider)!.isRoundComplete(3), isFalse);

      // Belum berubah: jawaban kosong, turnamen yang sama (layar tidak dibangun ulang).
      final shown = c.read(tournamentProvider);
      await tester.pump(LiveViewController.interval);
      expect(fake.log.last, 'GET K7Q2MX');
      expect(identical(c.read(tournamentProvider), shown), isTrue);

      fake.hostSends('K7Q2MX', TournamentCodec.encode(next));
      await tester.pump(LiveViewController.interval);
      expect(c.read(tournamentProvider)!.isRoundComplete(3), isTrue);
      c.dispose();
      // Riverpod menjadwalkan refresh provider turunan lewat timer 0 ms.
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('koneksi penonton putus: Offline setelah dua kali gagal, data tetap', (tester) async {
      final c = watch(tester);
      await tester.pump();
      fake.offline = true;
      await tester.pump(LiveViewController.interval);
      expect(status(c), LiveViewStatus.live);
      await tester.pump(LiveViewController.interval);
      expect(status(c), LiveViewStatus.offline);
      expect(c.read(tournamentProvider), isNotNull);

      fake.offline = false;
      await tester.pump(LiveViewController.interval);
      expect(status(c), LiveViewStatus.live);
      c.dispose();
      // Riverpod menjadwalkan refresh provider turunan lewat timer 0 ms.
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('live dihentikan: tidak ditemukan, berhenti mengecek', (tester) async {
      final c = watch(tester);
      await tester.pump();
      fake.lives.clear();
      await tester.pump(LiveViewController.interval);
      expect(status(c), LiveViewStatus.gone);
      expect(c.read(tournamentProvider), isNull);
      final requests = fake.log.length;
      await tester.pump(const Duration(minutes: 1));
      expect(fake.log, hasLength(requests));
      c.dispose();
      // Riverpod menjadwalkan refresh provider turunan lewat timer 0 ms.
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('data dari versi app lain: tidak bisa dibuka', (tester) async {
      fake.lives['K7Q2MX'] = (token: 'rahasia', rev: 1, payload: '{"schema":1,"tournament":{}}');
      final c = watch(tester);
      await tester.pump();
      expect(status(c), LiveViewStatus.unreadable);
      c.dispose();
      // Riverpod menjadwalkan refresh provider turunan lewat timer 0 ms.
      await tester.pump(const Duration(milliseconds: 1));
    });

    testWidgets('tab di belakang: berhenti mengecek, langsung dicek saat dibuka lagi', (tester) async {
      final c = watch(tester);
      await tester.pump();
      final requests = fake.log.length;
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
      await tester.pump(const Duration(minutes: 1));
      expect(fake.log, hasLength(requests));

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(fake.log, hasLength(requests + 1));
      c.dispose();
      // Riverpod menjadwalkan refresh provider turunan lewat timer 0 ms.
      await tester.pump(const Duration(milliseconds: 1));
    });
  });
}
