import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/config_summary.dart';
import 'package:match_addict/services/storage/last_settings.dart';
import 'package:match_addict/services/storage/tournament_store.dart';

/// Pengaturan terakhir per olahraga (logic.md §14.5, docs/data.md → `settings.<olahraga>`).
void main() {
  Court court(int n, {String? name, int color = 0, int minutes = 120}) =>
      Court(id: 'c$n', name: name ?? 'Court $n', colorIndex: color, bookingDurationMinutes: minutes);

  TournamentConfig config({
    SportType sport = SportType.padel,
    PartnerMode mode = PartnerMode.mixed,
    ScoreFormat format = const ScoreFormat(ScoringMethod.americano, 24),
    List<Court>? courts,
    String? name = 'Mabar Jumat',
  }) => TournamentConfig(
    sport: sport,
    mode: mode,
    matchDurationMinutes: 15,
    courts: courts ?? [court(1), court(2, color: 1), court(3, color: 2)],
    players: const [],
    format: format,
    name: name,
  );

  Map<String, dynamic> valid() => {
    'v': 1,
    'mode': 'mixed',
    'scoring': 'americano',
    'target': 24,
    'duration': 15,
    'courts': [
      {'name': null, 'colorIndex': 0, 'bookingMinutes': 120},
      {'name': 'Court Timur', 'colorIndex': 1, 'bookingMinutes': 120},
    ],
  };

  LastSettings? read(Map<String, dynamic> j) => LastSettings.read(jsonEncode(j));

  group('fromConfig', () {
    test('03q (tanpa Mexicano): Padel Americano 24, 15 menit, 3 court × 2 jam tersimpan dan terbaca', () {
      final saved = LastSettings.fromConfig(config());
      expect(saved.mode, PartnerMode.mixed);
      expect(saved.format, const ScoreFormat(ScoringMethod.americano, 24));
      expect(saved.matchDurationMinutes, 15);
      expect(saved.courts, [
        const LastCourt(colorIndex: 0, bookingMinutes: 120),
        const LastCourt(colorIndex: 1, bookingMinutes: 120),
        const LastCourt(colorIndex: 2, bookingMinutes: 120),
      ]);
      final again = LastSettings.read(saved.toJson())!;
      expect(again.format, saved.format);
      expect(again.courts, saved.courts);
      expect(again.mode, saved.mode);
      expect(again.matchDurationMinutes, 15);
    });

    test('03q: Padel Mexicano Americano 24, 15 menit, 3 court × 2 jam tersimpan dan terbaca', () {
      final saved = LastSettings.fromConfig(config(mode: PartnerMode.mexicano));
      final again = LastSettings.read(saved.toJson())!;
      expect(again.mode, PartnerMode.mexicano);
      expect(again.format, const ScoreFormat(ScoringMethod.americano, 24));
      expect(again.matchDurationMinutes, 15);
      expect(again.courts, saved.courts);
      expect(again.courts, hasLength(3));
    });

    test('nama turnamen tidak ikut', () {
      final json = LastSettings.fromConfig(config(name: 'Mabar Jumat')).toJson();
      expect(json, isNot(contains('Mabar Jumat')));
      expect(jsonDecode(json).keys, unorderedEquals(['v', 'mode', 'scoring', 'target', 'duration', 'courts']));
    });

    test('nama "Court n" (label bawaan sesuai urutan) → null; nama lain dan label urutan salah tetap', () {
      final saved = LastSettings.fromConfig(
        config(
          courts: [
            court(1),
            court(2, name: 'Court VIP'),
            court(3, name: 'Court 5'),
            court(4, name: '  '),
          ],
        ),
      );
      expect([for (final c in saved.courts) c.name], [null, 'Court VIP', 'Court 5', null]);
    });

    test('booking dan warna court ikut', () {
      final saved = LastSettings.fromConfig(config(courts: [court(1, color: 4, minutes: 60), court(2, minutes: 180)]));
      expect([for (final c in saved.courts) (c.colorIndex, c.bookingMinutes)], [(4, 60), (0, 180)]);
    });
  });

  group('forSparing', () {
    test('Fixed dan Mixed tetap, format dan court sama', () {
      final saved = LastSettings.fromConfig(config(mode: PartnerMode.fixed));
      final sparing = saved.forSparing();
      expect(sparing.mode, PartnerMode.fixed);
      expect(sparing.format, saved.format);
      expect(sparing.courts, saved.courts);
    });

    test('03q: Mexicano → Mixed, format dan court sama', () {
      final saved = LastSettings.fromConfig(config(mode: PartnerMode.mexicano));
      final sparing = saved.forSparing();
      expect(sparing.mode, PartnerMode.mixed);
      expect(sparing.format, const ScoreFormat(ScoringMethod.americano, 24));
      expect(sparing.matchDurationMinutes, 15);
      expect(sparing.courts, saved.courts);
    });
  });

  group('read', () {
    test('entri sah terbaca penuh', () {
      final s = read(valid())!;
      expect(s.mode, PartnerMode.mixed);
      expect(s.format.label, 'Americano 24');
      expect(s.courts[1].name, 'Court Timur');
    });

    test('tidak ada, bukan JSON, bukan map → null tanpa melempar', () {
      expect(LastSettings.read(null), isNull);
      expect(LastSettings.read('{rusak'), isNull);
      expect(LastSettings.read('[1,2]'), isNull);
      expect(LastSettings.read('"x"'), isNull);
    });

    test('mode mexicano dengan scoring bukan americano → null (seluruh entri default); americano terbaca', () {
      expect(read({...valid(), 'mode': 'mexicano'})!.mode, PartnerMode.mexicano);
      expect(read({...valid(), 'mode': 'mexicano', 'scoring': 'raceTo', 'target': 6}), isNull);
      expect(read({...valid(), 'mode': 'mexicano', 'scoring': 'bestOf', 'target': 5}), isNull);
      // Mixed dengan Race to tetap sah.
      expect(read({...valid(), 'scoring': 'raceTo', 'target': 6})!.format.method, ScoringMethod.raceTo);
    });

    test('v selain 1, mode/scoring tak dikenal → null', () {
      expect(read({...valid(), 'v': 2}), isNull);
      expect(read({...valid(), 'v': '1'}), isNull);
      expect(read({...valid(), 'mode': 'zzz'}), isNull);
      expect(read({...valid(), 'scoring': 'zzz'}), isNull);
    });

    test('format di luar batas → null (Race to 2–9, Best of 1–15, Americano 2–99)', () {
      expect(read({...valid(), 'scoring': 'raceTo', 'target': 10}), isNull);
      expect(read({...valid(), 'scoring': 'raceTo', 'target': 1}), isNull);
      expect(read({...valid(), 'scoring': 'bestOf', 'target': 16}), isNull);
      expect(read({...valid(), 'scoring': 'bestOf', 'target': 0}), isNull);
      expect(read({...valid(), 'target': 100}), isNull);
      expect(read({...valid(), 'scoring': 'raceTo', 'target': 9}), isNotNull);
      expect(read({...valid(), 'target': '24'}), isNull);
    });

    test('durasi: kelipatan 5 dalam 5–180', () {
      for (final d in [0, 4, 7, 185, 181, -5]) {
        expect(read({...valid(), 'duration': d}), isNull, reason: '$d');
      }
      expect(read({...valid(), 'duration': 5}), isNotNull);
      expect(read({...valid(), 'duration': 180}), isNotNull);
    });

    test('court: 1–10, warna 0–9, booking kelipatan 60 dalam 60–720', () {
      Map<String, dynamic> c({int color = 0, int minutes = 120}) => {
        'name': null,
        'colorIndex': color,
        'bookingMinutes': minutes,
      };
      expect(read({...valid(), 'courts': []}), isNull);
      expect(
        read({
          ...valid(),
          'courts': [for (var i = 0; i < 11; i++) c()],
        }),
        isNull,
      );
      expect(
        read({
          ...valid(),
          'courts': [for (var i = 0; i < 10; i++) c()],
        }),
        isNotNull,
      );
      expect(
        read({
          ...valid(),
          'courts': [c(color: 10)],
        }),
        isNull,
      );
      expect(
        read({
          ...valid(),
          'courts': [c(color: -1)],
        }),
        isNull,
      );
      for (final m in [0, 30, 90, 780, 721]) {
        expect(
          read({
            ...valid(),
            'courts': [c(minutes: m)],
          }),
          isNull,
          reason: '$m',
        );
      }
      expect(
        read({
          ...valid(),
          'courts': [c(minutes: 60)],
        }),
        isNotNull,
      );
      expect(
        read({
          ...valid(),
          'courts': [c(minutes: 720)],
        }),
        isNotNull,
      );
      expect(
        read({
          ...valid(),
          'courts': ['x'],
        }),
        isNull,
      );
    });

    test('nama court kosong/spasi dibaca null, panjang tidak dibatasi, bukan String → null', () {
      Map<String, dynamic> withName(Object? n) => {
        ...valid(),
        'courts': [
          {'name': n, 'colorIndex': 0, 'bookingMinutes': 120},
        ],
      };
      expect(read(withName(''))!.courts.single.name, isNull);
      expect(read(withName('   '))!.courts.single.name, isNull);
      expect(read(withName('A' * 200))!.courts.single.name, 'A' * 200);
      expect(read(withName(5)), isNull);
    });

    test('satu pelanggaran = seluruh entri tak terbaca, tanpa perbaikan sebagian', () {
      final j = valid();
      (j['courts'] as List).add({'name': 'x', 'colorIndex': 99, 'bookingMinutes': 120});
      expect(read(j), isNull);
    });

    test('JSON lebih dari 16 KB → null', () {
      final j = valid();
      (j['courts'] as List)[1]['name'] = 'A' * (16 * 1024);
      expect(read(j), isNull);
    });
  });

  group('TournamentStore', () {
    test('per olahraga: Padel tersimpan, Tennis tetap kosong; menimpa seluruh entri olahraga itu', () async {
      final store = TournamentStore.memory();
      expect(store.loadLastSettings(SportType.padel), isNull);
      await store.saveLastSettings(SportType.padel, LastSettings.fromConfig(config()));
      expect(store.loadLastSettings(SportType.tennis), isNull);
      expect(store.loadLastSettings(SportType.padel)!.format.label, 'Americano 24');
      await store.saveLastSettings(
        SportType.padel,
        LastSettings.fromConfig(config(format: const ScoreFormat(ScoringMethod.bestOf, 3), courts: [court(1)])),
      );
      final padel = store.loadLastSettings(SportType.padel)!;
      expect(padel.format.label, 'Best of 3');
      expect(padel.courts, hasLength(1));
    });
  });

  group('ConfigSummary (03a, 03h, 03l, 03p)', () {
    test('baris Skor: format + durasi; durasi kosong → "– menit"', () {
      expect(ConfigSummary.score(ScoreFormat.standard, 20), 'Race to 6 · 20 menit');
      expect(ConfigSummary.score(const ScoreFormat(ScoringMethod.americano, 21), 15), 'Americano 21 · 15 menit');
      expect(ConfigSummary.score(ScoreFormat.standard, null), 'Race to 6 · – menit');
      expect(ConfigSummary.scoreParts(ScoreFormat.standard, 90), ('Race to 6', '90 menit'));
    });

    test('baris Court: booking sama → satu angka; berbeda → rentang terpendek–terpanjang', () {
      expect(ConfigSummary.courts([120, 120]), '2 court · 2 jam');
      expect(ConfigSummary.courts([120, 120, 120, 120, 60, 60]), '6 court · 1–2 jam');
      expect(ConfigSummary.courts([180, 60, 120]), '3 court · 1–3 jam');
      expect(ConfigSummary.courts([for (var i = 0; i < 10; i++) 120]), '10 court · 2 jam');
    });
  });
}
