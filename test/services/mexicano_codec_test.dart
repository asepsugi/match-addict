import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/app_version.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

// Simpanan Mexicano (logic.md §14.6, AC-M20 bagian codec). Literal 3.3.x di bawah ditulis persis seperti keluaran
// encoder 3.3.2 (dicek dengan encoder c97cd15 sebelum kode Mexicano masuk), jadi `encode(decode(x)) == x` membuktikan
// Fixed, Mixed, dan Sparing tetap byte-sama.

String _match(String id, int round, String court, String pair1, String pair2, String sets, String status) =>
    '{"id":"$id","roundNumber":$round,"matchNumberInRound":1,"courtId":"$court","pair1":$pair1,"pair2":$pair2,'
    '"sets":$sets,"status":"$status","woLoserPairId":null,"woReason":null}';

String _pair(String id, String a, String b) => '{"id":"$id","player1Id":"$a","player2Id":"$b"}';

const _players4 =
    '[{"id":"p1","name":"Andi"},{"id":"p2","name":"Budi"},{"id":"p3","name":"Citra"},{"id":"p4","name":"Dewi"}]';

String _config(String mode, String scoring, int target, {String extra = '', String players = _players4}) =>
    '{"sport":"padel","mode":"$mode","matchDurationMinutes":15,"scoring":"$scoring","target":$target$extra,'
    '"courts":[{"id":"c1","name":"Court 1","colorIndex":0,"bookingDurationMinutes":120}],'
    '"players":$players,"fixedPairs":${mode == 'fixed' ? '[${_pair('A', 'p1', 'p2')},${_pair('B', 'p3', 'p4')}]' : 'null'}}';

String _payload(String config, String matches, {String bye = '{}', String resting = '{}', String withdrawn = '[]'}) =>
    '{"schema":2,"appVersion":"3.3.2","tournament":{"id":"t-1","createdAt":"2026-11-11T19:00:00.000",'
    '"isFinished":false,"config":$config,"matches":[$matches]},"bye":$bye,"resting":$resting,'
    '"withdrawn":$withdrawn,"extraPutaran":0}';

final _fixed33 = _payload(
  _config('fixed', 'raceTo', 6, extra: ',"name":"Mabar Jumat"'),
  _match('m1', 1, 'c1', _pair('A', 'p1', 'p2'), _pair('B', 'p3', 'p4'), '[{"side1":6,"side2":3}]', 'done'),
);

final _mixed33 = _payload(
  _config('mixed', 'americano', 21),
  _match('m-r1-1', 1, 'c1', _pair('p1+p3', 'p1', 'p3'), _pair('p2+p4', 'p2', 'p4'), '[{"side1":12,"side2":9}]', 'done'),
  resting: '{"1":[]}',
);

final _sparing33 = _payload(
  _config(
    'mixed',
    'americano',
    21,
    extra: ',"name":"PB Garuda x Matcha","clubs":[{"id":"k1","name":"PB Garuda"},{"id":"k2","name":"Matcha Club"}]',
    players:
        '[{"id":"p1","name":"Andi","club":"k1"},{"id":"p2","name":"Budi","club":"k1"},'
        '{"id":"p3","name":"Citra","club":"k2"},{"id":"p4","name":"Dewi","club":"k2"}]',
  ),
  _match('m-r1-1', 1, 'c1', _pair('p1+p2', 'p1', 'p2'), _pair('p3+p4', 'p3', 'p4'), '[]', 'pending'),
  bye: '{"sparing":"1"}',
  resting: '{"1":[]}',
);

/// Encoder selalu mencap versi app yang menulis, jadi pembanding byte memakai cap versi sekarang.
String _stamped(String payload) => payload.replaceFirst(RegExp(r'"appVersion":"[^"]*"'), '"appVersion":"$appVersion"');

const _names = ['Andi', 'Budi', 'Citra', 'Dewi', 'Eko'];

ActiveTournament _mexicano({ScoreFormat format = const ScoreFormat(ScoringMethod.americano, 21), List<Club>? clubs}) {
  Pair pair(String a, String b) => Pair(id: '$a+$b', player1Id: a, player2Id: b);
  return ActiveTournament(
    tournament: Tournament(
      id: 't-mx',
      createdAt: DateTime(2026, 11, 11, 19),
      config: TournamentConfig(
        sport: SportType.padel,
        mode: PartnerMode.mexicano,
        matchDurationMinutes: 15,
        courts: const [Court(id: 'c1', name: 'Court 1', colorIndex: 0, bookingDurationMinutes: 120)],
        players: [for (final n in _names) Player(id: n, name: n)],
        format: format,
        clubs: clubs,
      ),
      matches: [
        MatchGame(
          id: 'm-r1-1',
          roundNumber: 1,
          matchNumberInRound: 1,
          courtId: 'c1',
          pair1: pair('Andi', 'Citra'),
          pair2: pair('Budi', 'Dewi'),
        ).withScore(const [SetScore(side1: 15, side2: 6)]),
        MatchGame(
          id: 'm-r2-1',
          roundNumber: 2,
          matchNumberInRound: 1,
          courtId: 'c1',
          pair1: pair('Andi', 'Eko'),
          pair2: pair('Budi', 'Citra'),
        ),
      ],
    ),
    restingPlayerIdsByRound: const {
      1: ['Eko'],
      2: ['Dewi'],
    },
    withdrawnPlayerIds: const {'Dewi'},
  );
}

void main() {
  group('AC-M20 simpanan 3.3.x', () {
    for (final (name, payload) in [('Fixed', _fixed33), ('Mixed', _mixed33), ('Sparing', _sparing33)]) {
      test('AC-M20 $name 3.3.x terbaca dan ter-encode byte-sama', () {
        final active = TournamentCodec.decode(payload);
        expect(active, isNotNull);
        expect(TournamentCodec.encode(active!), _stamped(payload));
      });
    }
  });

  group('AC-M20 Mexicano', () {
    test(
      'AC-M20 round trip Mexicano dengan pemain keluar: mode, format, istirahat, keluar tetap; tanpa kunci baru',
      () {
        final active = _mexicano();
        final raw = TournamentCodec.encode(active);
        expect(raw, contains('"mode":"mexicano"'));
        expect(raw, isNot(contains('sparing')));
        final back = TournamentCodec.decode(raw)!;
        expect(back.config.mode, PartnerMode.mexicano);
        expect(back.config.format, const ScoreFormat(ScoringMethod.americano, 21));
        expect(back.withdrawnPlayerIds, {'Dewi'});
        expect(back.restingPlayerIdsByRound, {
          1: ['Eko'],
          2: ['Dewi'],
        });
        expect(back.matches.first.sets.single.side1, 15);
        expect(TournamentCodec.encode(back), raw);
      },
    );

    test('AC-M20 aturan baca: mexicano + clubs → null, dan canEncode false', () {
      // Simpanan sparing yang sah (penanda, klub, Americano 21) dengan mode saja yang diganti: yang menolak hanya
      // aturan Mexicano, bukan aturan sparing.
      final sparing = TournamentCodec.decode(_sparing33)!;
      expect(TournamentCodec.canEncode(sparing), isTrue);
      final c = sparing.config;
      final active = sparing.copyWith(
        tournament: sparing.tournament.copyWith(
          config: TournamentConfig(
            sport: c.sport,
            mode: PartnerMode.mexicano,
            matchDurationMinutes: c.matchDurationMinutes,
            courts: c.courts,
            players: c.players,
            format: c.format,
            clubs: c.clubs,
            name: c.name,
          ),
        ),
      );
      expect(TournamentCodec.canEncode(active), isFalse);
      expect(() => TournamentCodec.encode(active), throwsA(isA<UnreadableTournamentError>()));
      final raw = _sparing33.replaceFirst('"mode":"mixed"', '"mode":"mexicano"');
      expect(raw, isNot(_sparing33));
      expect(TournamentCodec.decode(raw), isNull);
    });

    for (final format in const [ScoreFormat(ScoringMethod.raceTo, 6), ScoreFormat(ScoringMethod.bestOf, 5)]) {
      test('AC-M20 aturan baca: mexicano + $format → null, dan canEncode false', () {
        final active = _mexicano(format: format);
        expect(TournamentCodec.canEncode(active), isFalse);
        final raw = TournamentCodec.encode(_mexicano()).replaceFirst(
          '"scoring":"americano","target":21',
          '"scoring":"${format.method.name}","target":${format.target}',
        );
        expect(raw, contains('"scoring":"${format.method.name}"'));
        expect(TournamentCodec.decode(raw), isNull);
      });
    }

    test('AC-M20 mode tak dikenal ("zzz") → null, tanpa fallback ke Mixed', () {
      final raw = TournamentCodec.encode(_mexicano()).replaceFirst('"mode":"mexicano"', '"mode":"zzz"');
      expect(TournamentCodec.decode(raw), isNull);
    });
  });
}
