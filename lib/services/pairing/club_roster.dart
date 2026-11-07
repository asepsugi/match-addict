import '../../models/models.dart';
import 'player_name_parser.dart';

/// Satu catatan di layar Pemain sparing. [error] = clay (salah isi); abu-abu = host masih mengetik.
class ClubNote {
  final String text;
  final bool error;
  const ClubNote(this.text, {this.error = false});

  @override
  bool operator ==(Object other) => other is ClubNote && other.text == text && other.error == error;

  @override
  int get hashCode => Object.hash(text, error);

  @override
  String toString() => 'ClubNote($text${error ? ', error' : ''})';
}

/// Hasil validasi layar Pemain sparing (PRD §13.2 K4, K6, K8). Murni: widget hanya menampilkan.
class SparingRosterCheck {
  /// Nama klub sesudah dipangkas dan dipotong [ClubRoster.maxNameLength].
  final String name1, name2;
  final ParseResult roster1, roster2;

  /// Catatan di bawah kotak nama klub masing-masing (null = tidak ada).
  final ClubNote? nameNote1, nameNote2;

  /// Catatan di bawah daftar klub: jumlah per klub; batas total dan nama di dua klub hanya di klub kedua.
  final List<ClubNote> listNotes1, listNotes2;

  /// Kotak nama klub kedua bertepi clay (nama sama dengan klub pertama).
  final bool name2Error;
  final bool canContinue;

  const SparingRosterCheck({
    required this.name1,
    required this.name2,
    required this.roster1,
    required this.roster2,
    required this.nameNote1,
    required this.nameNote2,
    required this.listNotes1,
    required this.listNotes2,
    required this.name2Error,
    required this.canContinue,
  });
}

class ClubRoster {
  static const maxNameLength = 20;
  static const minPerClub = 2;

  /// Pangkas spasi awal/akhir lalu potong ke [maxNameLength] (tempelan panjang tidak lolos formatter ketikan).
  static String normalizeName(String raw) {
    final trimmed = raw.trim();
    return trimmed.length > maxNameLength ? trimmed.substring(0, maxNameLength).trimRight() : trimmed;
  }

  /// Nama pemain yang muncul di kedua klub (tidak peka huruf besar), ejaan dan urutan klub pertama.
  static List<String> namesInBothClubs(ParseResult a, ParseResult b) {
    final second = {for (final n in b.names) n.toLowerCase()};
    return [
      for (final n in a.names)
        if (second.contains(n.toLowerCase())) n,
    ];
  }

  /// "Andi ada di dua klub", "Andi, Budi ada di dua klub", lebih dari tiga: "Andi, Budi, Citra +2 ada di dua klub".
  static String bothClubsMessage(List<String> names) {
    const shown = 3;
    final head = names.take(shown).join(', ');
    final rest = names.length - shown;
    return '${rest > 0 ? '$head +$rest' : head} ada di dua klub';
  }

  static SparingRosterCheck check({
    required String rawName1,
    required String rawName2,
    required String rawText1,
    required String rawText2,
  }) {
    final name1 = normalizeName(rawName1), name2 = normalizeName(rawName2);
    final r1 = PlayerNameParser.parse(rawText1), r2 = PlayerNameParser.parse(rawText2);
    final total = r1.count + r2.count;
    final sameName = name1.isNotEmpty && name1.toLowerCase() == name2.toLowerCase();
    final both = namesInBothClubs(r1, r2);

    // Catatan nama klub baru muncul kalau bloknya sudah berisi pemain (13a: blok kosong tanpa catatan).
    ClubNote? emptyName(String name, ParseResult r) =>
        name.isEmpty && r.count > 0 ? const ClubNote('Isi nama klub') : null;
    // Kurang dari 2 bukan error: host masih mengetik.
    ClubNote? fewPlayers(ParseResult r) =>
        r.count > 0 && r.count < minPerClub ? const ClubNote('Minimal $minPerClub pemain') : null;

    return SparingRosterCheck(
      name1: name1,
      name2: name2,
      roster1: r1,
      roster2: r2,
      nameNote1: emptyName(name1, r1),
      // Salah isi, bukan sedang mengetik; selalu di klub kedua karena klub pertama diisi duluan.
      nameNote2: sameName ? const ClubNote('Sama dengan klub pertama', error: true) : emptyName(name2, r2),
      listNotes1: [?fewPlayers(r1)],
      listNotes2: [
        ?fewPlayers(r2),
        if (total > TournamentConfig.maxPlayers)
          const ClubNote('Maksimal ${TournamentConfig.maxPlayers} pemain', error: true),
        if (both.isNotEmpty) ClubNote(bothClubsMessage(both), error: true),
      ],
      name2Error: sameName,
      canContinue:
          name1.isNotEmpty &&
          name2.isNotEmpty &&
          !sameName &&
          r1.count >= minPerClub &&
          r2.count >= minPerClub &&
          total >= TournamentConfig.minPlayers &&
          total <= TournamentConfig.maxPlayers &&
          both.isEmpty,
    );
  }
}
