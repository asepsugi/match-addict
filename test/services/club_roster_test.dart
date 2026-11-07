import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/services/pairing/club_roster.dart';

void main() {
  const garuda = 'Andi\nBudi\nCitra\nDewi\nEko\nFajar\nGita\nHadi';
  const matcha = 'Indra\nJoko\nKiki\nLina\nMaya\nNanda';

  SparingRosterCheck check(String n1, String n2, String t1, String t2) =>
      ClubRoster.check(rawName1: n1, rawName2: n2, rawText1: t1, rawText2: t2);

  test('AC-S1 Garuda 8 + Matcha 6 = 14 pemain: Lanjut aktif, tanpa catatan', () {
    final c = check('PB Garuda', 'Matcha Club', garuda, matcha);
    expect(c.canContinue, isTrue);
    expect(c.roster1.count + c.roster2.count, 14);
    expect([c.nameNote1, c.nameNote2], [null, null]);
    expect([...c.listNotes1, ...c.listNotes2], isEmpty);
  });

  test('AC-S1 klub kedua baru Indra: mati, catatan abu-abu "Minimal 2 pemain" di bawah daftarnya (13d)', () {
    final c = check('PB Garuda', 'Matcha Club', garuda, 'Indra');
    expect(c.canContinue, isFalse);
    expect(c.listNotes2, [const ClubNote('Minimal 2 pemain')]);
    expect(c.listNotes1, isEmpty);
  });

  test('klub kosong seluruhnya: mati tanpa catatan (13a)', () {
    final c = check('', '', '', '');
    expect(c.canContinue, isFalse);
    expect([c.nameNote1, c.nameNote2], [null, null]);
    expect([...c.listNotes1, ...c.listNotes2], isEmpty);
  });

  test('total minimal 4: 2 + 2 lolos, 2 + 1 tidak', () {
    expect(check('A', 'B', 'x\ny', 'p\nq').canContinue, isTrue);
    expect(check('A', 'B', 'x\ny', 'p').canContinue, isFalse);
  });

  test('AC-S2 nama klub kedua kosong atau spasi: mati, "Isi nama klub" abu-abu hanya bila bloknya berisi (13e)', () {
    for (final blank in ['', '   ']) {
      final c = check('PB Garuda', blank, garuda, matcha);
      expect(c.canContinue, isFalse);
      expect(c.nameNote2, const ClubNote('Isi nama klub'));
      expect(c.name2Error, isFalse);
    }
    final empty = check('PB Garuda', '', garuda, '');
    expect(empty.nameNote2, isNull);
    expect(check('', 'Matcha Club', garuda, matcha).nameNote1, const ClubNote('Isi nama klub'));
  });

  test('AC-S2 "PB Garuda" dan "pb garuda " sama: mati, pesan clay di klub kedua (13f)', () {
    final c = check('PB Garuda', ' pb garuda ', garuda, matcha);
    expect(c.canContinue, isFalse);
    expect(c.name2Error, isTrue);
    expect(c.nameNote2, const ClubNote('Sama dengan klub pertama', error: true));
    expect(c.nameNote1, isNull);
  });

  test('AC-S2 nama pemain di dua klub: pesan clay menyebut namanya (13g)', () {
    final c = check('PB Garuda', 'Matcha Club', garuda, '$matcha\nandi');
    expect(c.canContinue, isFalse);
    expect(c.listNotes2, [const ClubNote('Andi ada di dua klub', error: true)]);
  });

  test('pesan nama di dua klub: dua nama, dan lebih dari tiga memakai +n', () {
    expect(ClubRoster.bothClubsMessage(['Andi', 'Budi']), 'Andi, Budi ada di dua klub');
    expect(ClubRoster.bothClubsMessage(['Andi', 'Budi', 'Citra']), 'Andi, Budi, Citra ada di dua klub');
    final c = check('PB Garuda', 'Matcha Club', garuda, 'Indra\nAndi\nBudi\nCitra\nDewi\nEko');
    expect(c.listNotes2.single.text, 'Andi, Budi, Citra +2 ada di dua klub');
  });

  test('duplikat di dalam satu klub dibuang diam-diam, bukan error', () {
    final c = check('PB Garuda', 'Matcha Club', '$garuda\nandi', matcha);
    expect(c.canContinue, isTrue);
    expect(c.roster1.count, 8);
    expect(c.roster1.duplicates, ['andi']);
  });

  test('AC-S1 total 16 + 14 = 30 aktif, 16 + 15 = 31 mati dengan catatan clay "Maksimal 30 pemain"', () {
    String names(String p, int n) => [for (var i = 0; i < n; i++) '$p$i'].join('\n');
    expect(check('A', 'B', names('A', 16), names('B', 14)).canContinue, isTrue);
    final over = check('A', 'B', names('A', 16), names('B', 15));
    expect(over.canContinue, isFalse);
    expect(over.listNotes2, [const ClubNote('Maksimal 30 pemain', error: true)]);
  });

  test('duplikat per klub disebut abu-abu setelah catatan jumlah, urutan Minimal, Maksimal, Duplikat', () {
    final c = check('PB Garuda', 'Matcha Club', '$garuda\nandi', 'Indra\nindra');
    expect(c.listNotes1, [const ClubNote('Duplikat dibuang: andi')]);
    expect(c.listNotes2, [const ClubNote('Minimal 2 pemain'), const ClubNote('Duplikat dibuang: indra')]);
  });

  test('nama klub maksimal 20 karakter, dipangkas', () {
    expect(ClubRoster.normalizeName('  PB Garuda  '), 'PB Garuda');
    expect(ClubRoster.normalizeName('A' * 25), 'A' * 20);
    expect(check('B' * 30, 'x', garuda, matcha).name1, 'B' * 20);
  });
}
