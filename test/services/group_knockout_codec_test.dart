import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/app_version.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/ranking/group_knockout_ranking.dart';
import 'package:match_addict/services/schedule/group_stage.dart';
import 'package:match_addict/services/schedule/knockout_bracket.dart';
import 'package:match_addict/services/storage/tournament_codec.dart';

import 'group_knockout_fixture.dart';

// Codec Grup + Gugur (GG-3, docs/data.md → Grup + Gugur): round trip, aturan baca GR1–GR17, penanda GU15.

typedef Json = Map<String, dynamic>;

Json _json(ActiveTournament a) => jsonDecode(TournamentCodec.encode(a)) as Json;
Json _config(Json j) => (j['tournament'] as Json)['config'] as Json;
Json _gk(Json j) => _config(j)['groupKnockout'] as Json;
Json _formats(Json j) => _gk(j)['formats'] as Json;
List<Json> _matches(Json j) => [for (final m in (j['tournament'] as Json)['matches'] as List) m as Json];
Json _match(Json j, String code) => _matches(j).firstWhere((m) => m['phase'] == code);

/// Payload sah dari [a], diubah satu bagian oleh [change], dibaca lagi.
ActiveTournament? _decodeMutated(ActiveTournament a, void Function(Json j) change) {
  final j = _json(a);
  change(j);
  return TournamentCodec.decode(jsonEncode(j));
}

// 16E + bagan + SF1 dan SF2 selesai (Final Andi–Indra, Juara 3 Maya–Citra terisi).
ActiveTournament _afterSemis() => groups16E().bracket(q16E).ko('SF1', 6, 3).ko('SF2', 6, 2);

void _roundTrips(String name, ActiveTournament a) {
  test(name, () {
    final raw = TournamentCodec.encode(a);
    final back = TournamentCodec.decode(raw);
    expect(back, isNotNull);
    expect(TournamentCodec.encode(back!), raw);
    expect(back.matches.map((m) => (m.phase?.code, m.pair1.id, m.pair2.id, m.status)).toList(), [
      for (final m in a.matches) (m.phase?.code, m.pair1.id, m.pair2.id, m.status),
    ]);
    expect(back.config.groupKnockout!.groups, a.config.groupKnockout!.groups);
    expect(back.config.groupKnockout!.formats, a.config.groupKnockout!.formats);
    expect(back.config.groupKnockout!.thirdPlace, a.config.groupKnockout!.thirdPlace);
  });
}

// Simpanan 3.7.x literal (round-robin Fixed dan Mixed), ditulis seperti keluaran encoder 3.7.1.
const _pa = '{"id":"A","player1Id":"p1","player2Id":"p2"}';
const _pb = '{"id":"B","player1Id":"p3","player2Id":"p4"}';
const _players4 =
    '[{"id":"p1","name":"Andi"},{"id":"p2","name":"Budi"},{"id":"p3","name":"Citra"},{"id":"p4","name":"Dewi"}]';

String _lit(String mode, String bye, String resting, String withdrawn, int extra) =>
    '{"schema":2,"appVersion":"3.7.1","tournament":{"id":"t-1","createdAt":"2026-11-13T19:00:00.000",'
    '"isFinished":false,"config":{"sport":"padel","mode":"$mode","matchDurationMinutes":15,"scoring":"raceTo",'
    '"target":6,"courts":[{"id":"c1","name":"Court 1","colorIndex":0,"bookingDurationMinutes":120}],'
    '"players":$_players4,"fixedPairs":${mode == 'fixed' ? '[$_pa,$_pb]' : 'null'}},"matches":['
    '{"id":"m1","roundNumber":1,"matchNumberInRound":1,"courtId":"c1","pair1":$_pa,"pair2":$_pb,'
    '"sets":[{"side1":6,"side2":3}],"status":"done","woLoserPairId":null,"woReason":null}'
    ']},"bye":$bye,"resting":$resting,"withdrawn":$withdrawn,"extraPutaran":$extra}';

String _stamped(String payload) => payload.replaceFirst(RegExp(r'"appVersion":"[^"]*"'), '"appVersion":"$appVersion"');

/// Persis aturan baca bye decoder 3.7.1 (tournament_codec.dart:83-96): buang `sparing`, `int.parse` tiap kunci.
bool _decoder371ReadsBye(String raw) {
  try {
    final json = jsonDecode(raw) as Json;
    final bye = Map<String, dynamic>.of(json['bye'] as Json)..remove('sparing');
    <int, String>{for (final e in bye.entries) int.parse(e.key): e.value as String};
    return true;
  } catch (_) {
    return false;
  }
}

void main() {
  group('AC-G16 simpanan 3.7.x byte-sama', () {
    for (final (name, raw) in [
      ('Fixed + extraPutaran + bye', _lit('fixed', '{"1":"A","2":"B"}', '{}', '[]', 1)),
      ('Mixed + resting + withdrawn', _lit('mixed', '{}', '{"1":["p1"]}', '["p2"]', 0)),
      // Mexicano 3.4–3.7.x: Americano 21, resting terisi, satu withdrawn (review GG-3).
      (
        'Mexicano + resting + withdrawn',
        _lit('mixed', '{}', '{"1":["p1"]}', '["p2"]', 0)
            .replaceFirst('"mode":"mixed"', '"mode":"mexicano"')
            .replaceFirst('"scoring":"raceTo","target":6', '"scoring":"americano","target":21')
            .replaceFirst('{"side1":6,"side2":3}', '{"side1":12,"side2":9}'),
      ),
    ]) {
      test(name, () {
        final a = TournamentCodec.decode(raw)!;
        final out = TournamentCodec.encode(a);
        expect(out, _stamped(raw));
        for (final k in ['groupKnockout', '"phase"', '"gg"', '"pair1":null', '"pair2":null']) {
          expect(out, isNot(contains(k)));
        }
      });
    }
  });

  group('AC-G15 round trip encode(decode(x)) == x', () {
    _roundTrips('fase grup kosong (20b)', gkTournament());
    _roundTrips('fase grup sebagian', gkTournament().play('Andi', 'Citra', 6, 4).play('Eko', 'Gita', 2, 6));
    _roundTrips('setelah Buat bagan (21a)', groups16E().bracket(q16E));
    _roundTrips('tengah gugur SF1 selesai (21c)', groups16E().bracket(q16E).ko('SF1', 6, 3));
    _roundTrips('semifinal selesai, Final dan Juara 3 terisi', _afterSemis());
    _roundTrips(
      'diakhiri, match gugur cancelled bersisi null (21t)',
      groups16E().bracket(q16E).ko('SF1', 6, 3).finish(),
    );
    _roundTrips('4 grup, bagan baru (21w)', groups20o().bracket(q20o));
    _roundTrips('4 grup, PF1 selesai (21x)', groups20o().bracket(q20o).ko('PF1', 6, 2));
    _roundTrips('4 grup 3 court', groups20o(courts: 3).bracket(q20o));
    _roundTrips('tanpa juara 3 (21q)', groups16E(thirdPlace: false).bracket(q16E).ko('SF1', 6, 3));
    _roundTrips('1 court (21s)', groups16E(courts: 1).bracket(q16E));
    _roundTrips('WO di semifinal (21o)', groups16E().bracket(q16E).koWo('SF1', 'Maya'));

    test('sisi belum diketahui ditulis null, urutan kunci tetap', () {
      final j = _json(groups16E().bracket(q16E));
      expect(_match(j, 'F')['pair1'], isNull);
      expect(_match(j, 'J3')['pair2'], isNull);
      expect(_match(j, 'SF1')['pair1'], isNotNull);
      expect((j['bye'] as Json).keys.first, 'gg');
      expect(_gk(j).keys, ['groups', 'formats', 'thirdPlace']);
      expect(_formats(j).keys, ['SF', 'J3', 'F']);
      expect(_matches(j).first.keys.last, 'phase');
    });

    test('model dibaca: sisi null jadi Pair.tbd', () {
      final back = TournamentCodec.decode(TournamentCodec.encode(groups16E().bracket(q16E)))!;
      expect(back.matches.firstWhere((m) => m.phase?.code == 'F').pair1.isTbd, isTrue);
    });

    test('ukuran: 15 pasangan (30 pemain), 2 grup + bagan lengkap < 256 KB', () {
      final names = [for (var i = 0; i < 15; i++) 'P${i.toString().padLeft(2, '0')}'];
      final a = gkTournament(groups: [names.sublist(0, 8), names.sublist(8)], courts: 3).bracket([
        [names[0], names[1]],
        [names[8], names[9]],
      ]);
      final raw = TournamentCodec.encode(a);
      // ignore: avoid_print
      print('GG-3 ukuran 15 pasangan, ${a.matches.length} match: ${utf8.encode(raw).length} B');
      expect(a.matches.length, 28 + 21 + 4);
      expect(utf8.encode(raw).length, lessThan(256 * 1024));
      expect(TournamentCodec.decode(raw), isNotNull);
    });
  });

  group('aturan baca: satu bagian diubah → decode null', () {
    final base = groups16E().bracket(q16E).ko('SF1', 6, 3);
    final semis = _afterSemis();
    final four = groups20o().bracket(q20o);

    void rejects(String name, ActiveTournament a, void Function(Json j) change) {
      test(name, () {
        // Kontrol: payload sebelum diubah terbaca.
        expect(TournamentCodec.decode(TournamentCodec.encode(a)), isNotNull);
        expect(() => _decodeMutated(a, change), returnsNormally);
        expect(_decodeMutated(a, change), isNull);
      });
    }

    rejects('GR1 bye.gg = "2"', base, (j) => (j['bye'] as Json)['gg'] = '2');
    rejects('GR1 bye.gg = 1 (angka)', base, (j) => (j['bye'] as Json)['gg'] = 1);
    rejects('GR2 groupKnockout tanpa bye.gg', base, (j) => (j['bye'] as Json).remove('gg'));
    test('GR2 bye.gg pada round-robin', () {
      expect(TournamentCodec.decode(_lit('fixed', '{"gg":"1"}', '{}', '[]', 0)), isNull);
    });
    test('GR2/GR3 bye.gg bersama bye.sparing', () {
      expect(TournamentCodec.decode(_lit('fixed', '{"sparing":"1","gg":"1"}', '{}', '[]', 0)), isNull);
    });
    rejects('GR3 mode mixed', base, (j) => _config(j)['mode'] = 'mixed');
    rejects(
      'GR3 clubs',
      base,
      (j) => _config(j)['clubs'] = [
        {'id': 'k1', 'name': 'A'},
        {'id': 'k2', 'name': 'B'},
      ],
    );
    rejects('GR3 club di pemain', base, (j) => ((_config(j)['players'] as List).first as Json)['club'] = 'k1');
    rejects(
      'GR3 restingPairs',
      base,
      (j) => j['restingPairs'] = {
        '1': ['Andi'],
      },
    );
    rejects('GR4 groupKnockout bukan map', base, (j) => _config(j)['groupKnockout'] = 'x');
    rejects('GR4 groupKnockout null', base, (j) => _config(j)['groupKnockout'] = null);
    rejects('GR4 groups satu grup', base, (j) => _gk(j)['groups'] = [(_gk(j)['groups'] as List).first]);
    rejects('GR4 groups 3 grup', base, (j) {
      final g = _gk(j)['groups'] as List;
      _gk(j)['groups'] = [g[0], (g[1] as List).sublist(0, 2), (g[1] as List).sublist(2)];
    });
    rejects(
      'GR4 groups bukan list of String',
      base,
      (j) => _gk(j)['groups'] = [
        [1, 2],
        [3],
      ],
    );
    rejects('GR4 thirdPlace "true"', base, (j) => _gk(j)['thirdPlace'] = 'true');
    rejects('GR4 formats list', base, (j) => _gk(j)['formats'] = []);
    rejects('GR5 8 pasangan dalam 4 grup', base, (j) {
      final flat = [for (final g in _gk(j)['groups'] as List) ...(g as List)];
      _gk(j)['groups'] = [for (var i = 0; i < 8; i += 2) flat.sublist(i, i + 2)];
    });
    rejects('GR5 fixedPairs kosong', base, (j) => _config(j)['fixedPairs'] = []);
    rejects('GR5 fixedPairs null', base, (j) => _config(j)['fixedPairs'] = null);
    rejects('GR6 pasangan di dua grup', base, (j) {
      final g = _gk(j)['groups'] as List;
      (g[1] as List)[3] = (g[0] as List)[0];
    });
    rejects('GR6 id bukan fixedPairs', base, (j) => ((_gk(j)['groups'] as List)[0] as List)[0] = 'Zed');
    rejects('GR6 pasangan tanpa grup', base, (j) {
      final g = _gk(j)['groups'] as List;
      (g[1] as List).removeLast();
      (g[0] as List).add('Andi');
    });
    rejects('GR6 duplikat dalam satu grup', base, (j) => ((_gk(j)['groups'] as List)[0] as List)[1] = 'Andi');
    rejects('GR6 id fixedPairs kembar', base, (j) {
      final pairs = _config(j)['fixedPairs'] as List;
      (pairs[1] as Json)['id'] = (pairs[0] as Json)['id'];
    });
    rejects('GR7 ukuran grup [3, 5]', base, (j) {
      final g = _gk(j)['groups'] as List;
      (g[1] as List).add((g[0] as List).removeLast());
    });
    rejects('GR8 PF di 2 grup', base, (j) => _formats(j)['PF'] = {'scoring': 'raceTo', 'target': 6});
    rejects('GR8 SF tanpa J3', base, (j) => _formats(j).remove('J3'));
    rejects('GR8 kode format tak dikenal', base, (j) => _formats(j)['X'] = {'scoring': 'raceTo', 'target': 6});
    rejects('GR8 SF Best of 6', base, (j) => _formats(j)['SF'] = {'scoring': 'bestOf', 'target': 6});
    rejects('GR8 F Americano 24', base, (j) => _formats(j)['F'] = {'scoring': 'americano', 'target': 24});
    rejects('GR8 F Race to 10', base, (j) => _formats(j)['F'] = {'scoring': 'raceTo', 'target': 10});
    rejects('GR8 scoring bukan nama metode', base, (j) => _formats(j)['F'] = {'scoring': 'x', 'target': 6});
    rejects('GR8 4 grup tanpa PF', four, (j) => _formats(j).remove('PF'));
    rejects('GR9 id pemain kembar', base, (j) {
      final players = _config(j)['players'] as List;
      (players[1] as Json)['id'] = (players[0] as Json)['id'];
    });
    rejects('GR9 anggota pasangan tak ada di players', base, (j) {
      ((_config(j)['fixedPairs'] as List)[0] as Json)['player2Id'] = 'p99';
    });
    rejects('GR9 satu pemain di dua pasangan', base, (j) {
      final pairs = _config(j)['fixedPairs'] as List;
      (pairs[1] as Json)['player1Id'] = (pairs[0] as Json)['player1Id'];
    });
    rejects('GR10 match tanpa phase', base, (j) => _matches(j).first.remove('phase'));
    rejects('GR10 phase "E"', base, (j) => _matches(j).first['phase'] = 'E');
    rejects('GR10 phase "C" di 2 grup', base, (j) => _matches(j).first['phase'] = 'C');
    rejects('GR10 phase PF1 di 2 grup', base, (j) => _match(j, 'SF2')['phase'] = 'PF1');
    rejects('GR10/GR12 phase SF3 (slot tak dikenal)', base, (j) => _match(j, 'SF2')['phase'] = 'SF3');
    rejects('GR10 phase bukan String', base, (j) => _matches(j).first['phase'] = 5);
    test('GR10 phase di round-robin', () {
      final j = jsonDecode(_lit('fixed', '{}', '{}', '[]', 0)) as Json;
      _matches(j).first['phase'] = 'A';
      expect(TournamentCodec.decode(jsonEncode(j)), isNull);
    });
    test('GR10 sisi null di round-robin', () {
      final j = jsonDecode(_lit('fixed', '{}', '{}', '[]', 0)) as Json;
      _matches(j).first['pair2'] = null;
      expect(TournamentCodec.decode(jsonEncode(j)), isNull);
    });
    rejects('GR11 sisi match grup null', base, (j) => _matches(j).first['pair1'] = null);
    rejects('GR11 pasangan dari grup lain', base, (j) {
      _matches(j).firstWhere((m) => m['phase'] == 'A')['pair1'] = _match(j, 'SF1')['pair2'];
    });
    rejects('GR11 dua sisi sama', base, (j) {
      final m = _matches(j).firstWhere((m) => m['phase'] == 'A');
      m['pair2'] = m['pair1'];
    });
    rejects('GR11 pertemuan dua kali di grup', base, (j) {
      final list = (j['tournament'] as Json)['matches'] as List;
      list.add({...(list.first as Json), 'id': 'dup', 'roundNumber': 40});
    });
    rejects('GR11 sisi berid kosong (bukan null)', base, (j) {
      _match(j, 'F')['pair1'] = {'id': '', 'player1Id': '', 'player2Id': ''};
    });
    rejects('GR12 J3 padahal thirdPlace false', base, (j) => _gk(j)['thirdPlace'] = false);
    rejects('GR12 PF4 hilang', four, (j) {
      ((j['tournament'] as Json)['matches'] as List).removeWhere((m) => (m as Json)['phase'] == 'PF4');
    });
    rejects('GR12 dua Final', base, (j) {
      final list = (j['tournament'] as Json)['matches'] as List;
      list.add({..._match(j, 'F'), 'id': 'f2'});
    });
    rejects('GR13 Final di round yang sama dengan SF', base, (j) {
      _match(j, 'F')['roundNumber'] = _match(j, 'SF1')['roundNumber'];
    });
    rejects('GR13 gugur di round fase grup', base, (j) => _match(j, 'SF1')['roundNumber'] = 1);
    rejects('GR14 SF1 bersisi null', base, (j) => _match(j, 'SF1')['pair1'] = null);
    rejects('GR14 seed salah grup (A1 di slot B1)', base, (j) {
      _match(j, 'SF2')['pair1'] = _match(j, 'SF1')['pair1'];
    });
    rejects('GR14 seed pasangan dari grup lain di slot A1', base, (j) {
      _match(j, 'SF1')['pair1'] = _match(j, 'SF2')['pair1'];
    });
    rejects('GR14 A1 dan A2 pasangan yang sama', base, (j) {
      _match(j, 'SF2')['pair2'] = _match(j, 'SF1')['pair1'];
    });
    rejects('GR14 4 grup PF bersisi null', four, (j) => _match(j, 'PF2')['pair2'] = null);
    rejects('GR15 Final berisi pemenang SF yang salah', semis, (j) {
      final f = _match(j, 'F');
      f['pair1'] = f['pair2'];
      f['pair2'] = _match(j, 'SF1')['pair2'];
    });
    rejects('GR15 Final bersisi null padahal SF selesai', semis, (j) => _match(j, 'F')['pair2'] = null);
    rejects('GR15 Final berisi pasangan padahal SF belum ada hasil', base, (j) {
      _match(j, 'F')['pair2'] = _match(j, 'SF1')['pair1'];
    });
    rejects('GR15 match done bersisi null', base, (j) => _match(j, 'SF1')['pair2'] = null);
    rejects('GR16 Final done tanpa pemenang (seri)', semis, (j) {
      final f = _match(j, 'F');
      f['status'] = 'done';
      f['sets'] = [
        {'side1': 6, 'side2': 6},
      ];
    });
    rejects('GR17 bye berisi round', base, (j) => (j['bye'] as Json)['3'] = 'Andi');
    rejects('GR17 resting tidak kosong', base, (j) => (j['resting'] as Json)['1'] = ['Andi']);
    rejects('GR17 withdrawn tidak kosong', base, (j) => j['withdrawn'] = ['Andi']);
    rejects('GR17 extraPutaran 1', base, (j) => j['extraPutaran'] = 1);
    rejects('GR17 restingPairs', base, (j) => j['restingPairs'] = {});
  });

  group('payload rusak → null tanpa melempar', () {
    final base = groups16E().bracket(q16E);
    final raw = TournamentCodec.encode(base);

    test('terpotong', () {
      expect(TournamentCodec.decode(raw.substring(0, raw.length ~/ 2)), isNull);
    });
    test('phase: 5 dan pair1: "x"', () {
      expect(_decodeMutated(base, (j) => _matches(j).first['phase'] = 5), isNull);
      expect(_decodeMutated(base, (j) => _match(j, 'SF1')['pair1'] = 'x'), isNull);
    });
    test('groups bertipe salah', () {
      expect(_decodeMutated(base, (j) => _gk(j)['groups'] = 'x'), isNull);
      expect(_decodeMutated(base, (j) => _gk(j)['groups'] = [1, 2]), isNull);
    });
    test('target format bukan int', () {
      expect(_decodeMutated(base, (j) => (_formats(j)['F'] as Json)['target'] = 9.5), isNull);
    });
  });

  group('encode menolak bentuk yang tidak bisa dibaca kembali (canEncode, UnreadableTournamentError)', () {
    final base = groups16E().bracket(q16E);

    ActiveTournament withGk(GroupKnockout Function(GroupKnockout) f, {List<MatchGame>? matches}) => ActiveTournament(
      tournament: base.tournament.copyWith(
        matches: matches,
        config: TournamentConfig(
          sport: base.config.sport,
          mode: base.config.mode,
          matchDurationMinutes: base.config.matchDurationMinutes,
          courts: base.config.courts,
          players: base.config.players,
          fixedPairs: base.config.fixedPairs,
          format: base.config.format,
          groupKnockout: f(base.config.groupKnockout!),
        ),
      ),
    );

    void unwritable(String name, ActiveTournament a) {
      test(name, () {
        expect(TournamentCodec.canEncode(a), isFalse);
        expect(() => TournamentCodec.encode(a), throwsA(isA<UnreadableTournamentError>()));
      });
    }

    test('kontrol: turnamen sah bisa ditulis', () => expect(TournamentCodec.canEncode(base), isTrue));
    unwritable(
      'GR6 pasangan di dua grup',
      withGk(
        (g) => g.copyWith(
          groups: [
            g.groups[0],
            [...g.groups[1].take(3), 'Andi'],
          ],
        ),
      ),
    );
    unwritable(
      'GR7 ukuran grup [3, 5]',
      withGk(
        (g) => g.copyWith(
          groups: [
            g.groups[0].take(3).toList(),
            [...g.groups[1], g.groups[0][3]],
          ],
        ),
      ),
    );
    unwritable(
      'GR8 format Best of 6',
      withGk(
        (g) => g.copyWith(formats: {...g.formats, KnockoutRound.semifinal: const ScoreFormat(ScoringMethod.bestOf, 6)}),
      ),
    );
    unwritable('GR12 J3 padahal thirdPlace false', withGk((g) => g.copyWith(thirdPlace: false)));
    unwritable(
      'GR12 slot SF3 (dipetakan ke sumber SF1 oleh bagan)',
      withGk(
        (g) => g,
        matches: [
          for (final m in base.matches)
            m.phase?.code == 'SF2'
                ? MatchGame(
                    id: m.id,
                    roundNumber: m.roundNumber,
                    matchNumberInRound: m.matchNumberInRound,
                    courtId: m.courtId,
                    pair1: m.pair1,
                    pair2: m.pair2,
                    phase: const KnockoutPhase(KnockoutRound.semifinal, 3),
                  )
                : m,
        ],
      ),
    );
    unwritable('GR17 extraPutaran 1', ActiveTournament(tournament: base.tournament, extraPutaran: 1));
    unwritable('GR17 bye tidak kosong', ActiveTournament(tournament: base.tournament, byePairIdByRound: {1: 'Andi'}));
    unwritable(
      'GR10 phase di turnamen lain',
      ActiveTournament(
        tournament: base.tournament.copyWith(
          config: TournamentConfig(
            sport: SportType.padel,
            mode: PartnerMode.fixed,
            matchDurationMinutes: 15,
            courts: base.config.courts,
            players: base.config.players,
            fixedPairs: base.config.fixedPairs,
          ),
        ),
      ),
    );
  });

  group('penanda GU15 bye.gg = "1"', () {
    final a = groups16E().bracket(q16E);
    final raw = TournamentCodec.encode(a);

    test('decoder 3.7.1 (aturan bye) menolak payload Grup + Gugur', () {
      expect(_decoder371ReadsBye(raw), isFalse);
    });
    test('payload sama tanpa bye.gg terbaca decoder 3.7.1: penandalah yang menolaknya', () {
      final j = jsonDecode(raw) as Json;
      (j['bye'] as Json).remove('gg');
      expect(_decoder371ReadsBye(jsonEncode(j)), isTrue);
    });
    test('decoder 3.8.0 membuang gg sebelum nomor round, menolak kunci non-angka lain', () {
      expect(TournamentCodec.decode(raw), isNotNull);
      expect(_decodeMutated(a, (j) => (j['bye'] as Json)['x'] = '1'), isNull);
    });
    test('turnamen non-Grup + Gugur terbaca decoder 3.7.1', () {
      expect(_decoder371ReadsBye(_stamped(_lit('fixed', '{"1":"A"}', '{}', '[]', 0))), isTrue);
    });
  });

  threeGroupTests();
}

// --- 3 grup (GP-4): GR4/GR5/GR8/GR10/GR12/GR18/GR19, AC-G29, AC-B8, W4 ----------------------------------------------

const _extraNames = ['Zed', 'Yan', 'Xia', 'Wim'];

/// 3 grup dari [pairs] pasangan (12..16), id = nama: P = 12 → A Andi–Gita, B Indra–Oki, C Rudi–Vina.
List<List<String>> _groups3(int pairs) {
  final names = [...partners.keys, ..._extraNames];
  var at = 0;
  return [
    for (final size in GroupStage.sizes(pairs, 3)) [for (var i = 0; i < size; i++) names[at++]],
  ];
}

/// J1–J3 = juara grup [champions] (default A, B, C), runner-up slot 2, WC1/WC2 = peringkat 3 grup [wc1]/[wc2].
Seeding _seeding3(List<List<String>> g, {List<int> champions = const [0, 1, 2], required int wc1, required int wc2}) =>
    Seeding(
      groupSlots: [
        for (final x in g) [x[0], x[1]],
      ],
      champions: champions,
      wildcards: [g[wc1][2], g[wc2][2]],
    );

/// Bagan 3 grup lewat `KnockoutBracket.build` (config ikut membawa `wildcards`).
ActiveTournament _bracket3(ActiveTournament a, Seeding seeding) {
  final built = KnockoutBracket.build(a, seeding);
  return ActiveTournament(
    tournament: a.tournament.copyWith(config: built.config, matches: [...a.matches, ...built.matches]),
  );
}

ActiveTournament _tournament3(int pairs, {bool thirdPlace = true, int courts = 2}) =>
    gkTournament(groups: _groups3(pairs), courts: courts, thirdPlace: thirdPlace);

// Empat bentuk aturan tukar (G15) pada 16G: (wc1, wc2) = grup asal WC1/WC2; J1 = grup A, J2 = grup B.
const _noSwap = (wc1: 1, wc2: 2), _swapJ1 = (wc1: 0, wc2: 2), _swapJ2 = (wc1: 2, wc2: 1), _swapBoth = (wc1: 0, wc2: 1);

ActiveTournament _b3({({int wc1, int wc2}) wc = _noSwap, int pairs = 12, bool thirdPlace = true}) =>
    _bracket3(_tournament3(pairs, thirdPlace: thirdPlace), _seeding3(_groups3(pairs), wc1: wc.wc1, wc2: wc.wc2));

List<String> _wildcards(Json j) => [for (final id in _gk(j)['wildcards'] as List) id as String];

Json _pairJson(Json j, String id) =>
    ((_config(j)['fixedPairs'] as List).firstWhere((p) => (p as Json)['id'] == id) as Json);

void threeGroupTests() {
  group('3 grup: GR4/GR5 P 12–16 terbaca sebelum dan sesudah bagan', () {
    for (final p in [12, 13, 14, 15, 16]) {
      _roundTrips('P = $p, sebelum bagan', _tournament3(p));
      test('P = $p, sesudah bagan: wildcards ditulis dan terbaca', () {
        final a = _b3(pairs: p);
        final back = TournamentCodec.decode(TournamentCodec.encode(a))!;
        expect(back.config.groupKnockout!.wildcards, a.config.groupKnockout!.wildcards);
        expect(back.config.groupKnockout!.groupCount, 3);
      });
    }
  });

  group('GR18 round trip encode(decode(x)) == x', () {
    final allPf = ['PF1', 'PF2', 'PF3', 'PF4'];
    ActiveTournament played(ActiveTournament a, List<String> codes) {
      for (final (i, c) in codes.indexed) {
        a = a.ko(c, 6, i % 5);
      }
      return a;
    }

    _roundTrips('16G tanpa tukar', _b3());
    _roundTrips('tukar: WC1 segrup J1', _b3(wc: _swapJ1));
    _roundTrips('tukar: WC2 segrup J2', _b3(wc: _swapJ2));
    _roundTrips('tukar keduanya', _b3(wc: _swapBoth));
    _roundTrips('juara 3 mati', _b3(thirdPlace: false));
    _roundTrips('PF1 selesai (di tengah gugur)', played(_b3(), ['PF1']));
    _roundTrips('semua PF selesai, SF terisi', played(_b3(wc: _swapBoth), allPf));
    _roundTrips('WO di PF2', _b3(wc: _swapBoth).koWo('PF2', 'Kiki'));
    _roundTrips('sampai Final selesai', played(_b3(), [...allPf, 'SF1', 'SF2', 'F', 'J3']));
    _roundTrips('diakhiri, match gugur cancelled bersisi null', played(_b3(), ['PF1']).finish());
    _roundTrips(
      '16G-iii: urutan juara [C, A, B] (pilihan host)',
      _bracket3(_tournament3(12), _seeding3(_groups3(12), champions: const [2, 0, 1], wc1: 1, wc2: 2)),
    );

    test('premis fixture: susunan QF memang berbeda per bentuk tukar', () {
      expect([for (final c in allPf) _b3().sides(c)], ['Andi–Maya', 'Kiki–Tono', 'Indra–Qori', 'Rudi–Citra']);
      expect(_b3(wc: _swapJ1).sides('PF1'), 'Andi–Qori');
      expect(_b3(wc: _swapJ1).sides('PF3'), 'Indra–Eko');
    });

    test('16G lewat qualifierPlan → seedingPlan → build', () {
      var a = _tournament3(12);
      for (final (g, ids) in a.config.groupKnockout!.groups.indexed) {
        for (var i = 0; i < ids.length; i++) {
          for (var j = i + 1; j < ids.length; j++) {
            a = a.play(ids[i], ids[j], 6, (i + j + g) % 5);
          }
        }
      }
      final qualifiers = GroupKnockoutRanking.qualifierPlan(a);
      expect(qualifiers.picks, isEmpty);
      final plan = GroupKnockoutRanking.seedingPlan(a, [
        for (final row in qualifiers.slots) [for (final id in row) id!],
      ]);
      final seeding = plan.seeding;
      expect(seeding, isNotNull, reason: 'tanpa seri, tanpa pilihan host');
      final withBracket = _bracket3(a, seeding!);
      expect(TournamentCodec.canEncode(withBracket), isTrue);
      final raw = TournamentCodec.encode(withBracket);
      expect(TournamentCodec.encode(TournamentCodec.decode(raw)!), raw);
    });
  });

  group('encode 3 grup: bentuk', () {
    test('wildcards setelah thirdPlace, PF1..PF4, kunci formats PF, tanpa teks "QF"', () {
      final raw = TournamentCodec.encode(_b3());
      final j = jsonDecode(raw) as Json;
      expect(_gk(j).keys.toList(), ['groups', 'formats', 'thirdPlace', 'wildcards']);
      expect(_wildcards(j), ['Maya', 'Qori']);
      expect(_formats(j).keys.toList(), ['PF', 'SF', 'J3', 'F']);
      final codes = {for (final m in _matches(j)) '${m['phase']}'};
      expect(codes.where((c) => c.startsWith('PF')), {'PF1', 'PF2', 'PF3', 'PF4'});
      expect(raw, isNot(contains('QF')));
      expect((j['bye'] as Json)['gg'], '1');
    });

    test('3 grup sebelum bagan, 2 grup, dan 4 grup tidak memuat wildcards (byte-sama 3.9.x)', () {
      for (final a in [_tournament3(12), groups16E().bracket(q16E), groups20o().bracket(q20o)]) {
        final raw = TournamentCodec.encode(a);
        expect(raw, isNot(contains('wildcards')));
        expect(raw, isNot(contains('QF')));
      }
    });
  });

  group('GR4/GR5/GR8/GR10/GR12 untuk 3 grup', () {
    final pre = _tournament3(12);
    final bracket = _b3();

    void rejects(String name, ActiveTournament a, void Function(Json j) change) {
      test(name, () {
        expect(TournamentCodec.decode(TournamentCodec.encode(a)), isNotNull, reason: 'kontrol');
        expect(_decodeMutated(a, change), isNull);
      });
    }

    test('GR5 P = 11 dengan 3 grup (ukuran 4, 4, 3) tidak bisa ditulis', () {
      final a = _tournament3(11);
      expect(TournamentCodec.canEncode(a), isFalse);
      expect(() => TournamentCodec.encode(a), throwsA(isA<UnreadableTournamentError>()));
    });

    test('GR5 P = 17 (batas 32 pemain terlampaui, W4) ditolak untuk 2, 3, dan 4 grup', () {
      final names = [for (var i = 0; i < 17; i++) 'P${i.toString().padLeft(2, '0')}'];
      for (final groups in [2, 3, 4]) {
        var at = 0;
        final a = gkTournament(
          groups: [
            for (final size in GroupStage.sizes(17, groups)) [for (var i = 0; i < size; i++) names[at++]],
          ],
        );
        expect(TournamentCodec.canEncode(a), isFalse, reason: '$groups grup');
      }
      expect(GroupStage.decodableGroupCounts(17), isEmpty);
      expect(GroupStage.decodableGroupCounts(16), [2, 3, 4]);
    });

    rejects('GR8 3 grup tanpa PF (sebelum bagan)', pre, (j) => _formats(j).remove('PF'));
    rejects('GR8 3 grup tanpa PF (sesudah bagan)', bracket, (j) => _formats(j).remove('PF'));
    rejects(
      'GR8 PF salah (Race to 10 bukan format gugur)',
      bracket,
      (j) => _formats(j)['PF'] = {'scoring': 'raceTo', 'target': 10},
    );
    rejects('GR8 kunci QF menggantikan PF', bracket, (j) => _formats(j)['QF'] = _formats(j).remove('PF'));
    rejects(
      'GR10 huruf grup "D" di 3 grup',
      pre,
      (j) => _matches(j).firstWhere((m) => m['phase'] == 'A')['phase'] = 'D',
    );
    rejects('GR10 phase QF1 (bukan kode simpanan)', bracket, (j) => _match(j, 'PF1')['phase'] = 'QF1');
    rejects('GR12 PF4 hilang', bracket, (j) {
      ((j['tournament'] as Json)['matches'] as List).removeWhere((m) => (m as Json)['phase'] == 'PF4');
    });
    rejects('GR12 PF3 ganda', bracket, (j) => _match(j, 'PF4')['phase'] = 'PF3');
    rejects('GR12 hanya PF yang ada (SF dan Final hilang)', bracket, (j) {
      ((j['tournament'] as Json)['matches'] as List).removeWhere(
        (m) => ['SF1', 'SF2', 'F', 'J3'].contains((m as Json)['phase']),
      );
    });
  });

  group('GR18 wildcards: satu kalimat aturan, satu test ditolak', () {
    final bracket = _b3();
    final pre = _tournament3(12);
    final two = groups16E().bracket(q16E);
    final four = groups20o().bracket(q20o);

    void rejects(String name, ActiveTournament a, void Function(Json j) change) {
      test(name, () {
        expect(TournamentCodec.decode(TournamentCodec.encode(a)), isNotNull, reason: 'kontrol');
        expect(() => _decodeMutated(a, change), returnsNormally);
        expect(_decodeMutated(a, change), isNull);
      });
    }

    rejects('di 2 grup', two, (j) => _gk(j)['wildcards'] = ['Andi', 'Indra']);
    rejects('di 4 grup', four, (j) => _gk(j)['wildcards'] = ['Andi', 'Indra']);
    rejects('[] di 2 grup', two, (j) => _gk(j)['wildcards'] = []);
    rejects('[] di 3 grup dengan bagan', bracket, (j) => _gk(j)['wildcards'] = []);
    rejects('3 grup dengan bagan tanpa kunci', bracket, (j) => _gk(j).remove('wildcards'));
    rejects('3 grup tanpa bagan dengan kunci', pre, (j) => _gk(j)['wildcards'] = ['Maya', 'Qori']);
    rejects('3 grup tanpa bagan dengan []', pre, (j) => _gk(j)['wildcards'] = []);
    rejects('satu id', bracket, (j) => _gk(j)['wildcards'] = ['Maya']);
    rejects('tiga id', bracket, (j) => _gk(j)['wildcards'] = ['Maya', 'Qori', 'Eko']);
    rejects('dua id sama', bracket, (j) => _gk(j)['wildcards'] = ['Maya', 'Maya']);
    rejects('id bukan anggota grup', bracket, (j) => _gk(j)['wildcards'] = ['Maya', 'Nobody']);
    rejects('dua WC satu grup', bracket, (j) => _gk(j)['wildcards'] = ['Maya', 'Oki']);
    rejects('WC = runner-up (bukan slot 3)', bracket, (j) {
      _gk(j)['wildcards'] = ['Citra', 'Qori'];
      _match(j, 'PF1')['pair2'] = _pairJson(j, 'Citra');
    });
    rejects('wildcards bertipe string', bracket, (j) => _gk(j)['wildcards'] = 'Maya');
    rejects('wildcards berisi angka', bracket, (j) => _gk(j)['wildcards'] = [1, 2]);
    rejects('wildcards null', bracket, (j) => _gk(j)['wildcards'] = null);
    rejects('wildcards map', bracket, (j) => _gk(j)['wildcards'] = {'a': 'b'});
    test(
      'urutan WC terbalik tetap sah: dua urutan menghasilkan QF yang sama (urutan hanya bisa dibaca dari kunci)',
      () {
        final j = _json(bracket);
        _gk(j)['wildcards'] = ['Qori', 'Maya'];
        final back = TournamentCodec.decode(jsonEncode(j));
        expect(back, isNotNull);
        expect(back!.config.groupKnockout!.wildcards, ['Qori', 'Maya']);
      },
    );
  });

  group('GR19 bagan 3 grup: satu kalimat aturan, satu test ditolak', () {
    final noSwap = _b3();
    final swapped = _b3(wc: _swapJ1);

    void rejects(String name, ActiveTournament a, void Function(Json j) change) {
      test(name, () {
        expect(TournamentCodec.decode(TournamentCodec.encode(a)), isNotNull, reason: 'kontrol');
        expect(() => _decodeMutated(a, change), returnsNormally);
        expect(_decodeMutated(a, change), isNull);
      });
    }

    void swapSides(Json j, String a, String b) {
      final ma = _match(j, a), mb = _match(j, b);
      final tmp = ma['pair2'];
      ma['pair2'] = mb['pair2'];
      mb['pair2'] = tmp;
    }

    void set(Json j, String code, String side, String? id) =>
        _match(j, code)[side] = id == null ? null : _pairJson(j, id);

    rejects('J1 dan J2 satu grup', noSwap, (j) => set(j, 'PF3', 'pair1', 'Citra'));
    rejects('J3 dan J1 satu grup', noSwap, (j) => set(j, 'PF4', 'pair1', 'Citra'));
    rejects('runner-up J1 (PF4.pair2) tidak segrup J1', noSwap, (j) => set(j, 'PF4', 'pair2', 'Oki'));
    rejects('runner-up J2 (PF2.pair1) tidak segrup J2', noSwap, (j) => set(j, 'PF2', 'pair1', 'Vina'));
    rejects('runner-up J3 (PF2.pair2) tidak segrup J3', noSwap, (j) => set(j, 'PF2', 'pair2', 'Gita'));
    rejects('pasangan ganda di QF1–QF4 (runner-up J3 = J3)', noSwap, (j) => set(j, 'PF2', 'pair2', 'Rudi'));
    rejects('WC sama dengan juara (WC bukan J atau R)', noSwap, (j) {
      _gk(j)['wildcards'] = ['Andi', 'Qori'];
      set(j, 'PF1', 'pair2', 'Andi');
    });
    rejects('tanpa tukar, tapi WC1/WC2 tertukar di QF1/QF3', noSwap, (j) => swapSides(j, 'PF1', 'PF3'));
    rejects('perlu tukar (WC1 segrup J1), tapi QF tidak tertukar', swapped, (j) => swapSides(j, 'PF1', 'PF3'));
    rejects('QF1 mempertemukan dua pasangan segrup (A1–A3)', noSwap, (j) {
      _gk(j)['wildcards'] = ['Eko', 'Qori'];
      set(j, 'PF1', 'pair2', 'Eko');
    });
    rejects('perlu tukar (WC2 segrup J2), tapi QF tidak tertukar', _b3(wc: _swapJ2), (j) => swapSides(j, 'PF1', 'PF3'));
    rejects('sisi QF1 null', noSwap, (j) => set(j, 'PF1', 'pair2', null));
    rejects('sisi QF2 null', noSwap, (j) => set(j, 'PF2', 'pair2', null));
    rejects('sisi QF4 pair1 null', noSwap, (j) => set(j, 'PF4', 'pair1', null));
    rejects('SF yang sisinya bukan pemenang QF (GR15 tetap berlaku)', noSwap, (j) => set(j, 'SF1', 'pair1', 'Andi'));
  });

  group('canEncode 3 grup konsisten dengan decoder', () {
    void unwritable(String name, ActiveTournament a) {
      test(name, () {
        expect(TournamentCodec.canEncode(a), isFalse);
        expect(() => TournamentCodec.encode(a), throwsA(isA<UnreadableTournamentError>()));
      });
    }

    ActiveTournament withGk(ActiveTournament a, GroupKnockout Function(GroupKnockout) f) => ActiveTournament(
      tournament: a.tournament.copyWith(config: a.config.copyWith(groupKnockout: f(a.config.groupKnockout!))),
    );

    test('kontrol: bagan 3 grup bisa ditulis', () => expect(TournamentCodec.canEncode(_b3()), isTrue));
    unwritable('3 grup dengan bagan tanpa wildcards', withGk(_b3(), (g) => g.copyWith(wildcards: const [])));
    unwritable('wildcards satu id', withGk(_b3(), (g) => g.copyWith(wildcards: [g.wildcards.first])));
    unwritable(
      '3 grup tanpa bagan dengan wildcards',
      withGk(_tournament3(12), (g) => g.copyWith(wildcards: ['Maya', 'Qori'])),
    );
    unwritable(
      '2 grup dengan wildcards',
      withGk(groups16E().bracket(q16E), (g) => g.copyWith(wildcards: ['Andi', 'Indra'])),
    );
    unwritable(
      '4 grup dengan wildcards',
      withGk(groups20o().bracket(q20o), (g) => g.copyWith(wildcards: ['Andi', 'Indra'])),
    );
    unwritable(
      '3 grup tanpa PF di formats',
      withGk(_b3(), (g) => g.copyWith(formats: {...g.formats}..remove(KnockoutRound.quarterfinal))),
    );

    test('ubah format babak (G16) mempertahankan wildcards dan tetap bisa ditulis', () {
      final a = _b3(wc: _swapBoth);
      const raceTo4 = ScoreFormat(ScoringMethod.raceTo, 4);
      final changed = withGk(a, (g) => g.copyWith(formats: {...g.formats, KnockoutRound.quarterfinal: raceTo4}));
      expect(changed.config.groupKnockout!.wildcards, a.config.groupKnockout!.wildcards);
      final back = TournamentCodec.decode(TournamentCodec.encode(changed))!;
      expect(back.config.groupKnockout!.formats[KnockoutRound.quarterfinal], raceTo4);
      expect(back.config.groupKnockout!.wildcards, ['Eko', 'Maya']);
    });
  });

  group('AC-G29 simpanan 3.9.x (2 × 3 dan 4 × 3 pasangan) tetap terbaca sampai Final', () {
    void toFinal(String name, ActiveTournament start, List<String> codes) {
      test(name, () {
        var a = start;
        for (final code in codes) {
          a = a.ko(code, 6, 3);
          final raw = TournamentCodec.encode(a);
          expect(raw, isNot(contains('wildcards')));
          expect(raw, isNot(contains('QF')));
          final back = TournamentCodec.decode(raw);
          expect(back, isNotNull, reason: code);
          expect(TournamentCodec.encode(back!), raw);
        }
      });
    }

    final two =
        gkTournament(
          groups: const [
            ['Andi', 'Citra', 'Eko'],
            ['Gita', 'Indra', 'Kiki'],
          ],
        ).bracket(const [
          ['Andi', 'Citra'],
          ['Gita', 'Indra'],
        ]);
    toFinal('2 grup × 3 (P = 6)', two, ['SF1', 'SF2', 'J3', 'F']);
    toFinal('4 grup × 3 (P = 12)', groups20o().bracket(q20o), ['PF1', 'PF2', 'PF3', 'PF4', 'SF1', 'SF2', 'J3', 'F']);
    test('P = 6 dan P = 12 dibaca lewat decodableGroupCounts', () {
      expect(GroupStage.decodableGroupCounts(6), [2]);
      expect(GroupStage.decodableGroupCounts(12), [2, 3, 4]);
      expect(GroupStage.groupCountsFor(6), isEmpty, reason: 'turnamen baru tidak menawarkannya');
    });
  });

  group('AC-B8 pembaca 3.9.1 terhadap payload 3.10.0 (aturan 3.9.1 disalin di test)', () {
    // `groupCountsFor` 3.9.1 (group_stage.dart): < 6 → [], < 12 → [2], selain itu [2, 4].
    List<int> old391(int p) => p < 6 ? const [] : (p < 12 ? const [2] : const [2, 4]);
    // `_readPhase` 3.9.1: A–D, PF1–PF4, SF1, SF2, F, J3.
    final oldCodes = {'A', 'B', 'C', 'D', 'PF1', 'PF2', 'PF3', 'PF4', 'SF1', 'SF2', 'F', 'J3'};

    bool oldReads(ActiveTournament a) {
      final j = _json(a);
      final groups = (_gk(j)['groups'] as List).length;
      final pairs = (_config(j)['fixedPairs'] as List).length;
      final codes = {for (final m in _matches(j)) m['phase'] as String};
      return old391(pairs).contains(groups) && codes.every(oldCodes.contains);
    }

    test('3 grup (P 12–16) ditolak, sebelum dan sesudah bagan', () {
      for (final p in [12, 13, 14, 15, 16]) {
        expect(oldReads(_tournament3(p)), isFalse, reason: 'P = $p sebelum bagan');
        expect(oldReads(_b3(pairs: p)), isFalse, reason: 'P = $p sesudah bagan');
      }
    });

    test('2 × 8 dan 4 × 4 (16 pasangan) tetap terbaca dan tampil dengan kode lama', () {
      final names = [for (var i = 0; i < 16; i++) 'P${i.toString().padLeft(2, '0')}'];
      final two = gkTournament(groups: [names.sublist(0, 8), names.sublist(8)]).bracket([
        [names[0], names[1]],
        [names[8], names[9]],
      ]);
      final four = gkTournament(groups: [for (var g = 0; g < 4; g++) names.sublist(g * 4, g * 4 + 4)]).bracket([
        for (var g = 0; g < 4; g++) [names[g * 4], names[g * 4 + 1]],
      ]);
      for (final a in [two, four]) {
        expect(oldReads(a), isTrue);
        expect(TournamentCodec.decode(TournamentCodec.encode(a)), isNotNull);
      }
    });
  });
}
