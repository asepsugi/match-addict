import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/services/pairing/player_name_parser.dart';

void main() {
  group('PlayerNameParser', () {
    test('trims numbered prefixes', () {
      final input = '''1. Andi P
2) Budi S
03 - Citra L
4: Dewant R
Eko M
- Fajar K
* Gina R
• Hana T''';
      final r = PlayerNameParser.parse(input);
      expect(r.names, [
        'Andi P',
        'Budi S',
        'Citra L',
        'Dewant R',
        'Eko M',
        'Fajar K',
        'Gina R',
        'Hana T',
      ]);
      expect(r.duplicates, isEmpty);
    });

    test('skips blank lines', () {
      final r = PlayerNameParser.parse('\n\nAndi\n\nBudi\n');
      expect(r.names, ['Andi', 'Budi']);
    });

    test('rejects duplicates case-insensitively', () {
      final r = PlayerNameParser.parse('Andi\nandi\nANDI\nBudi');
      expect(r.names, ['Andi', 'Budi']);
      expect(r.duplicates.length, 2);
    });

    test('collapses multiple whitespace', () {
      final r = PlayerNameParser.parse('Andi  P');
      expect(r.names, ['Andi P']);
    });

    test('validation: < 4 invalid', () {
      final r = PlayerNameParser.parse('A\nB\nC');
      expect(r.isValid, isFalse);
      expect(r.validationError, contains('Minimal 4'));
    });

    test('validation: 4 valid', () {
      final r = PlayerNameParser.parse('A\nB\nC\nD');
      expect(r.isValid, isTrue);
      expect(r.validationError, isNull);
    });

    test('validation: 30 valid, > 30 invalid', () {
      String input(int n) => List.generate(n, (i) => 'P${i + 1}').join('\n');
      expect(PlayerNameParser.parse(input(30)).isValid, isTrue);
      final r = PlayerNameParser.parse(input(31));
      expect(r.isValid, isFalse);
      expect(r.validationError, contains('Maksimal 30'));
    });
  });
}
