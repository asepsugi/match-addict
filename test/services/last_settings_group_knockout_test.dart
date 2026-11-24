import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/group_stage.dart';
import 'package:match_addict/services/storage/last_settings.dart';

/// Pengaturan terakhir Grup + Gugur (docs/data.md → Pengaturan terakhir): kunci opsional `groupKnockout`, `v` tetap 1.
void main() {
  const raceTo6 = {'scoring': 'raceTo', 'target': 6};

  Court court(int n) => Court(id: 'c$n', name: 'Court $n', colorIndex: n - 1, bookingDurationMinutes: 120);

  Map<String, dynamic> base() => {
    'v': 1,
    'mode': 'fixed',
    'scoring': 'raceTo',
    'target': 6,
    'duration': 15,
    'courts': [
      {'name': null, 'colorIndex': 0, 'bookingMinutes': 120},
      {'name': null, 'colorIndex': 1, 'bookingMinutes': 120},
    ],
  };

  Map<String, dynamic> knockout({int groups = 2, bool third = true, Map<String, dynamic>? formats}) => {
    'groupCount': groups,
    'thirdPlace': third,
    'formats':
        formats ??
        {
          if (groups >= 3) 'PF': {'scoring': 'raceTo', 'target': 5},
          'SF': raceTo6,
          'J3': {'scoring': 'raceTo', 'target': 4},
          'F': {'scoring': 'raceTo', 'target': 9},
        },
  };

  Map<String, dynamic> withKnockout(Object? gk) => {...base(), 'groupKnockout': gk};

  LastSettings? read(Map<String, dynamic> j) => LastSettings.read(jsonEncode(j));

  GroupKnockout model({int groups = 2, bool third = true}) => GroupKnockout(
    groupCount: groups,
    thirdPlace: third,
    formats: {
      if (groups >= 3) KnockoutRound.quarterfinal: const ScoreFormat(ScoringMethod.raceTo, 5),
      KnockoutRound.semifinal: const ScoreFormat(ScoringMethod.raceTo, 6),
      KnockoutRound.thirdPlace: const ScoreFormat(ScoringMethod.raceTo, 4),
      KnockoutRound.finalRound: const ScoreFormat(ScoringMethod.raceTo, 9),
    },
  );

  LastSettings saved(GroupKnockout? g) => LastSettings.fromConfig(
    TournamentConfig(
      sport: SportType.padel,
      mode: PartnerMode.fixed,
      matchDurationMinutes: 15,
      courts: [court(1), court(2)],
      players: const [],
      format: ScoreFormat.standard,
      groupKnockout: g,
    ),
  );

  test('round trip 2, 3, 4 grup, juara 3 mati; anggota grup tidak ikut', () {
    for (final g in [
      model(),
      model(groups: 3),
      model(groups: 4),
      model(third: false),
      model(groups: 3, third: false),
    ]) {
      final withMembers = GroupKnockout(
        groupCount: g.groupCount,
        groups: const [
          ['a', 'b'],
        ],
        formats: g.formats,
        thirdPlace: g.thirdPlace,
      );
      final again = LastSettings.read(saved(withMembers).toJson())!.groupKnockout!;
      expect(again.groupCount, g.groupCount);
      expect(again.thirdPlace, g.thirdPlace);
      expect(again.formats, g.formats);
      expect(again.groups, isEmpty);
    }
  });

  test('3 grup: PF ditulis (kode tetap PF, bukan QF) dan terbaca; entri 2/4 grup byte-sama 3.9.x', () {
    final three = jsonDecode(saved(model(groups: 3)).toJson()) as Map<String, dynamic>;
    final gk = three['groupKnockout'] as Map<String, dynamic>;
    expect(gk['groupCount'], 3);
    expect((gk['formats'] as Map).keys.toList(), ['PF', 'SF', 'J3', 'F']);
    expect(three['v'], 1);
    expect(read(three)!.groupKnockout!.groupCount, 3);
    // Literal 3.9.x (urutan kunci groupCount, thirdPlace, formats): ter-encode ulang sama persis.
    for (final groups in [2, 4]) {
      final literal = jsonEncode({...base(), 'groupKnockout': knockout(groups: groups)});
      expect(LastSettings.read(literal)!.toJson(), literal);
    }
  });

  test(
    'turunan baca lewat fallbackGroupCount: 3 grup 24 → 20 pemain = 2, 4 grup 32 → 30 = 3, → 22 = 2, kosong = null',
    () {
      expect(GroupStage.fallbackGroupCount(12, 3), 3);
      expect(GroupStage.fallbackGroupCount(10, 3), 2);
      expect(GroupStage.fallbackGroupCount(16, 4), 4);
      expect(GroupStage.fallbackGroupCount(15, 4), 3);
      expect(GroupStage.fallbackGroupCount(11, 4), 2);
      expect(GroupStage.fallbackGroupCount(7, 3), isNull);
      // Entri tersimpan tidak diubah oleh turunan itu.
      expect(read(withKnockout(knockout(groups: 3)))!.groupKnockout!.groupCount, 3);
    },
  );

  test('round-robin ter-encode tanpa kunci groupKnockout (byte-sama 3.7.x); entri tanpa kunci terbaca', () {
    expect(jsonDecode(saved(null).toJson()), isNot(contains('groupKnockout')));
    expect(read(base())!.groupKnockout, isNull);
    expect(LastSettings.read(saved(null).toJson())!.groupKnockout, isNull);
  });

  test('bentuk JSON: formats urut PF, SF, J3, F; J3 tetap ditulis walau juara 3 mati', () {
    final j = jsonDecode(saved(model(groups: 4, third: false)).toJson()) as Map<String, dynamic>;
    final gk = j['groupKnockout'] as Map<String, dynamic>;
    expect(gk['groupCount'], 4);
    expect(gk['thirdPlace'], false);
    expect((gk['formats'] as Map).keys.toList(), ['PF', 'SF', 'J3', 'F']);
    expect(j['v'], 1);
  });

  test('tiap pelanggaran → seluruh entri tak terbaca', () {
    final bad = <String, Map<String, dynamic>>{
      'mode bukan fixed': {...withKnockout(knockout()), 'mode': 'mixed'},
      'groupKnockout null': withKnockout(null),
      'groupKnockout bukan map': withKnockout('x'),
      'groupCount 5': withKnockout(knockout(groups: 5)),
      'groupCount 1': withKnockout(knockout(groups: 1)),
      'PF di 2 grup (groupCount 2 dengan PF)': withKnockout(
        knockout(formats: {'PF': raceTo6, 'SF': raceTo6, 'J3': raceTo6, 'F': raceTo6}),
      ),
      'PF hilang di 3 grup': withKnockout(knockout(groups: 3, formats: {'SF': raceTo6, 'J3': raceTo6, 'F': raceTo6})),
      'groupCount string': withKnockout({...knockout(), 'groupCount': '2'}),
      'PF di 2 grup': withKnockout(knockout(formats: {'PF': raceTo6, 'SF': raceTo6, 'J3': raceTo6, 'F': raceTo6})),
      'PF hilang di 4 grup': withKnockout(knockout(groups: 4, formats: {'SF': raceTo6, 'J3': raceTo6, 'F': raceTo6})),
      'J3 hilang': withKnockout(knockout(formats: {'SF': raceTo6, 'F': raceTo6})),
      'kunci asing': withKnockout(knockout(formats: {'SF': raceTo6, 'J3': raceTo6, 'F': raceTo6, 'X': raceTo6})),
      'Best of 6': withKnockout(
        knockout(
          formats: {
            'SF': {'scoring': 'bestOf', 'target': 6},
            'J3': raceTo6,
            'F': raceTo6,
          },
        ),
      ),
      'Americano 24': withKnockout(
        knockout(
          formats: {
            'SF': raceTo6,
            'J3': {'scoring': 'americano', 'target': 24},
            'F': raceTo6,
          },
        ),
      ),
      'Race to 10': withKnockout(
        knockout(
          formats: {
            'SF': {'scoring': 'raceTo', 'target': 10},
            'J3': raceTo6,
            'F': raceTo6,
          },
        ),
      ),
      'thirdPlace bukan bool': withKnockout({...knockout(), 'thirdPlace': 1}),
      'format bukan map': withKnockout(knockout(formats: {'SF': 'x', 'J3': raceTo6, 'F': raceTo6})),
      'v 2': {...withKnockout(knockout()), 'v': 2},
    };
    for (final MapEntry(key: name, value: json) in bad.entries) {
      expect(read(json), isNull, reason: name);
    }
    expect(read(withKnockout(knockout())), isNotNull);
  });

  test('Sparing membuang Grup + Gugur (GU14); sisanya tetap', () {
    final s = saved(model());
    final sparing = s.forSparing();
    expect(sparing.groupKnockout, isNull);
    expect(sparing.mode, PartnerMode.fixed);
    expect(sparing.format, s.format);
    expect(sparing.courts, s.courts);
  });
}
