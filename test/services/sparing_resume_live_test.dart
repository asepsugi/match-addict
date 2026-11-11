import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:match_addict/features/live/live_host_controller.dart';
import 'package:match_addict/features/schedule/sparing_providers.dart';
import 'package:match_addict/features/schedule/tournament_controller.dart';
import 'package:match_addict/services/live/live_relay.dart';
import 'package:match_addict/services/ranking/club_score.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

import '../hifi/screens/sparing_fixture.dart';

/// AC-S20: app di-kill di tengah turnamen sparing lalu dibuka lagi (QA 3.2.0). Live sparing = relay yang sama, kode
/// yang sama, payload dibaca balik lewat codec yang sama.
List<String> labels(ClubStandings g) => [
  for (final e in g.entries) '${e.position} ${e.players.map((p) => p.name).join(' · ')}',
];

void main() {
  test(
    'AC-S20 kill saat R3 lalu buka lagi: klub, anggota, jadwal, skor klub sama; Live pakai kode yang sama',
    () async {
      final payloads = <String, String>{};
      final relay = MockClient((req) async {
        final seg = req.url.pathSegments;
        if (seg.length == 1) {
          payloads['ABC123'] = req.body;
          return http.Response('{"code":"ABC123","token":"t"}', 201);
        }
        if (req.method == 'PUT') payloads[seg[1]] = req.body;
        return http.Response('', 204);
      });
      final store = TournamentStore.memory();
      final now = sparingAt(3);

      ProviderContainer open() {
        final c = ProviderContainer(
          overrides: [
            tournamentStoreProvider.overrideWithValue(store),
            clockProvider.overrideWithValue(() => now),
            liveRelayProvider.overrideWithValue(LiveRelay(base: Uri.parse('https://relay.test'), client: relay)),
          ],
        );
        c.listen(liveHostProvider, (_, __) {});
        return c;
      }

      Future<void> settle() async {
        for (var i = 0; i < 10; i++) {
          await Future<void>.delayed(Duration.zero);
        }
      }

      // Sesi pertama: turnamen R3 tersimpan lewat state = (auto-save), Live menyala.
      var c = open();
      final r3 = sparingR3();
      c.read(tournamentProvider.notifier).state = r3;
      expect(await c.read(liveHostProvider.notifier).start(), isTrue);
      await settle();
      final before = c.read(tournamentProvider)!;
      final scoreBefore = c.read(clubScoreProvider)!;
      final standingsBefore = c.read(clubStandingEntriesProvider);
      final encoded = TournamentCodec.encode(before);
      expect(c.read(liveHostProvider)!.code, 'ABC123');
      c.dispose(); // "kill"

      // Sesi kedua: semua kembali dari simpanan.
      c = open();
      addTearDown(c.dispose);
      final after = c.read(tournamentProvider)!;
      expect(TournamentCodec.encode(after), encoded);
      expect(after.config.isSparing, isTrue);
      expect(after.config.clubs!.map((e) => e.name), ['PB Garuda', 'Matcha Club']);
      expect(
        after.config.players.map((p) => '${p.name}:${p.clubId}'),
        before.config.players.map((p) => '${p.name}:${p.clubId}'),
      );
      expect(after.matches.map((m) => m.id), before.matches.map((m) => m.id));
      expect(after.restingPairIdsByRound, before.restingPairIdsByRound);
      final scoreAfter = c.read(clubScoreProvider)!;
      expect(
        [
          scoreAfter.first.halfWins,
          scoreAfter.second.halfWins,
          scoreAfter.first.totalPoint,
          scoreAfter.second.totalPoint,
        ],
        [
          scoreBefore.first.halfWins,
          scoreBefore.second.halfWins,
          scoreBefore.first.totalPoint,
          scoreBefore.second.totalPoint,
        ],
      );
      expect(c.read(clubStandingEntriesProvider).map(labels), standingsBefore.map(labels));

      // Live: kode sama, dan payload di relay terbaca penonton sebagai sparing yang sama.
      expect(c.read(liveHostProvider)!.code, 'ABC123');
      await settle();
      final viewer = TournamentCodec.decode(payloads['ABC123'])!;
      expect(viewer.config.isSparing, isTrue);
      expect(TournamentCodec.encode(viewer), encoded);
    },
  );
}
