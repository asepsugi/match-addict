import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/schedule/config_summary.dart';

/// Teks ringkasan Konfigurasi Grup + Gugur (19b, 19e, 19g, 19i, 19k).
void main() {
  ScoreFormat race(int n) => ScoreFormat(ScoringMethod.raceTo, n);
  const b7 = ScoreFormat(ScoringMethod.bestOf, 7);

  Map<KnockoutRound, ScoreFormat> formats(ScoreFormat sf, ScoreFormat j3, ScoreFormat f, {ScoreFormat? pf}) => {
    if (pf != null) KnockoutRound.quarterfinal: pf,
    KnockoutRound.semifinal: sf,
    KnockoutRound.thirdPlace: j3,
    KnockoutRound.finalRound: f,
  };

  group('baris Fase grup', () {
    test('jumlah grup + format, durasi terpisah; durasi kosong → "– menit"', () {
      expect(ConfigSummary.groupPhaseParts(2, race(6), 15), ('2 grup · Race to 6', '15 menit'));
      expect(ConfigSummary.groupPhaseParts(4, const ScoreFormat(ScoringMethod.bestOf, 6), 90), (
        '4 grup · Best of 6',
        '90 menit',
      ));
      expect(ConfigSummary.groupPhaseParts(2, race(6), null).$2, '– menit');
    });
  });

  group('baris Gugur', () {
    test('19b: semua babak sama → satu format', () {
      expect(ConfigSummary.knockout(formats(race(6), race(6), race(6)), thirdPlace: true), 'Race to 6');
    });

    test('19e 16A: format sama, N beda → rentang "Race to 4–9"', () {
      expect(ConfigSummary.knockout(formats(race(6), race(4), race(9)), thirdPlace: true), 'Race to 4–9');
    });

    test('19g: tanpa juara 3 → rentang hanya dari babak yang dimainkan + " · tanpa Juara 3"', () {
      expect(
        ConfigSummary.knockout(formats(race(6), race(4), race(9)), thirdPlace: false),
        'Race to 6–9 · tanpa Juara 3',
      );
      expect(
        ConfigSummary.knockout(formats(race(6), race(4), race(6)), thirdPlace: false),
        'Race to 6 · tanpa Juara 3',
      );
    });

    test('4 grup: Perempat final ikut dihitung', () {
      expect(ConfigSummary.knockout(formats(race(6), race(6), race(6), pf: race(5)), thirdPlace: true), 'Race to 5–6');
    });

    test('19h: Best of 7 semua babak', () {
      expect(ConfigSummary.knockout(formats(b7, b7, b7), thirdPlace: true), 'Best of 7');
    });

    test('format beda → nama metode digabung urut Race to, Best of, Americano', () {
      expect(ConfigSummary.knockout(formats(b7, race(4), race(9)), thirdPlace: true), 'Race to / Best of');
      // Juara 3 mati: metodenya tidak dihitung.
      expect(ConfigSummary.knockout(formats(b7, race(4), b7), thirdPlace: false), 'Best of 7 · tanpa Juara 3');
    });
  });

  group('meta tombol', () {
    test('19b 16A: "· 8 round · 16 match"', () {
      expect(ConfigSummary.groupKnockoutMeta(8, 16, 0), '· 8 round · 16 match');
    });

    test('19i/19k: lewat booking → round + kelebihan, tanpa match', () {
      expect(ConfigSummary.groupKnockoutMeta(10, 20, 20), '· 10 round · lewat booking 00:20');
      expect(ConfigSummary.groupKnockoutMeta(16, 16, 120), '· 16 round · lewat booking 02:00');
    });

    test('tanpa estimasi → null', () {
      expect(ConfigSummary.groupKnockoutMeta(0, 0, 0), isNull);
    });
  });

  group('babak awal dan pilihan Fase grup (19c, 19d, 23a)', () {
    test('playoffOpening per jumlah grup', () {
      expect(ConfigSummary.playoffOpening(2), 'Semifinal');
      expect(ConfigSummary.playoffOpening(3), 'Perempat final · 2 wildcard');
      expect(ConfigSummary.playoffOpening(4), 'Perempat final');
    });

    test('19c: 16 pemain = 8 pasangan, 3 dan 4 grup mati', () {
      expect(ConfigSummary.groupOption(8, 2), '4 + 4 · Semifinal');
      expect(ConfigSummary.groupOption(8, 3), 'Mulai 24 pemain');
      expect(ConfigSummary.groupOption(8, 4), 'Tepat 32 pemain');
    });

    test('19c: 18 dan 22 pemain', () {
      expect(ConfigSummary.groupOption(9, 2), '5 + 4 · Semifinal');
      expect(ConfigSummary.groupOption(11, 2), '6 + 5 · Semifinal');
    });

    test('19d: 24 pemain = 12 pasangan, 4 grup mati', () {
      expect(ConfigSummary.groupOption(12, 2), '6 + 6 · Semifinal');
      expect(ConfigSummary.groupOption(12, 3), '4 + 4 + 4 · Perempat final · 2 wildcard');
      expect(ConfigSummary.groupOption(12, 4), 'Tepat 32 pemain');
    });

    test('23a: 32 pemain = 16 pasangan, ketiganya sah', () {
      expect(ConfigSummary.groupOption(16, 2), '8 + 8 · Semifinal');
      expect(ConfigSummary.groupOption(16, 3), '6 + 5 + 5 · Perempat final · 2 wildcard');
      expect(ConfigSummary.groupOption(16, 4), '4 + 4 + 4 + 4 · Perempat final');
    });
  });
}
