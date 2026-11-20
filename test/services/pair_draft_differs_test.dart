import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/models/models.dart';
import 'package:match_addict/services/pairing/pair_draft.dart';

/// `PairDraft.differsFrom` (logic.md §19.7 A-9, keputusan 116): dasar dialog "Buang perubahan pasangan?".
/// Data = 04g/04j: Andi P · Budi S jadi Andi P · Rizky H, Rizky H ditambahkan.
void main() {
  final players = [
    for (final (i, n) in ['Andi P', 'Budi S', 'Citra L', 'Dewant R'].indexed) Player(id: 'p$i', name: n),
  ];
  final pairs = [
    const Pair(id: 'pair0', player1Id: 'p0', player2Id: 'p1'),
    const Pair(id: 'pair1', player1Id: 'p2', player2Id: 'p3'),
  ];
  final config = TournamentConfig(
    sport: SportType.padel,
    mode: PartnerMode.fixed,
    matchDurationMinutes: 15,
    courts: const [],
    players: players,
    fixedPairs: pairs,
  );

  test('draft yang sama dengan awalnya tidak berbeda', () {
    expect(PairDraft.of(config).differsFrom(PairDraft.of(config)), isFalse);
  });

  test('04g: Andi P · Budi S jadi Andi P · Rizky H + Rizky H baru → berbeda', () {
    final initial = PairDraft.of(config);
    var draft = initial.split(pairs[0]);
    draft = draft.add('Rizky H', id: 'p4').draft!;
    draft = draft.pair(draft.unpaired.firstWhere((p) => p.name == 'Andi P'), draft.unpaired.last, id: 'pair-new');
    expect(draft.differsFrom(initial), isTrue);
  });

  test('pisah lalu pasangkan lagi yang sama (id pasangan baru) → tidak berbeda', () {
    final initial = PairDraft.of(config);
    final split = initial.split(pairs[0]);
    expect(split.differsFrom(initial), isTrue, reason: 'sesudah pisah');
    final again = split.pair(players[1], players[0], id: 'id-lain');
    expect(again.differsFrom(initial), isFalse);
  });

  test('pemain baru yang diketik tapi tidak dipasangkan tetap membuat berbeda (himpunan added)', () {
    final initial = PairDraft.of(config);
    final draft = initial.add('Rizky H', id: 'p4').draft!;
    expect(draft.pairs.map((p) => p.id), initial.pairs.map((p) => p.id));
    expect(draft.differsFrom(initial), isTrue);
  });

  test('urutan slot tidak dihitung', () {
    final initial = PairDraft.of(config);
    // Pisah pasangan 1 lalu pasang lagi mengisi slot kosong pertama: urutan sama; pisah 2 pasangan lalu pasang
    // dalam urutan terbalik menukar slot, tetap himpunan pasangan yang sama.
    var draft = initial.split(pairs[0]).split(pairs[1]);
    draft = draft.pair(players[2], players[3], id: 'a').pair(players[0], players[1], id: 'b');
    expect(draft.pairs.map((p) => p.id), ['a', 'b']);
    expect(draft.differsFrom(initial), isFalse);
  });
}
