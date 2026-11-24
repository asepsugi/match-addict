import '../../core/time_text.dart';
import '../../models/models.dart';
import 'group_stage.dart';

/// Teks baris Skor dan Court di Konfigurasi (03a, 03h, 03p). Dirangkai di sini supaya widget tidak menulis aturannya.
class ConfigSummary {
  const ConfigSummary._();

  /// Dua bagian baris Skor: format dan durasi ("Race to 6", "20 menit"); durasi kosong (sedang diketik) → "– menit".
  /// Dipisah supaya durasi bisa diwarnai clay sendiri (03l, 03p).
  static (String format, String duration) scoreParts(ScoreFormat format, int? durationMinutes) =>
      (format.label, '${durationMinutes ?? '–'} menit');

  /// "Race to 6 · 20 menit".
  static String score(ScoreFormat format, int? durationMinutes) {
    final (f, d) = scoreParts(format, durationMinutes);
    return '$f · $d';
  }

  /// "2 court · 2 jam"; booking berbeda → rentang terpendek–terpanjang ("6 court · 1–2 jam").
  static String courts(List<int> bookingMinutes) {
    final hours = [for (final m in bookingMinutes) m ~/ 60]..sort();
    final shortest = hours.first, longest = hours.last;
    return '${hours.length} court · ${shortest == longest ? '$shortest' : '$shortest–$longest'} jam';
  }

  /// Dua bagian baris Fase grup (19b): "2 grup · Race to 6" dan "15 menit". Durasi dipisah supaya bisa diwarnai clay (19l).
  static (String format, String duration) groupPhaseParts(int groupCount, ScoreFormat format, int? durationMinutes) {
    final (f, d) = scoreParts(format, durationMinutes);
    return ('$groupCount grup · $f', d);
  }

  /// Baris Gugur (19b, 19e, 19g): satu format → "Race to 6"; metode sama, N beda → rentang "Race to 4–9"; metode
  /// beda → "Race to / Best of". Hanya babak yang dimainkan (juara 3 dihitung kalau [thirdPlace]); mati → tambah
  /// " · tanpa Juara 3".
  static String knockout(Map<KnockoutRound, ScoreFormat> formats, {required bool thirdPlace}) {
    final played = [
      for (final e in formats.entries)
        if (e.key != KnockoutRound.thirdPlace || thirdPlace) e.value,
    ];
    final methods = [
      for (final m in ScoringMethodX.selectable)
        if (played.any((f) => f.method == m)) m,
    ];
    final targets = [for (final f in played) f.target]..sort();
    final text = methods.length > 1
        ? methods.map((m) => m.label).join(' / ')
        : targets.first == targets.last
        ? played.first.label
        : '${methods.single.label} ${targets.first}–${targets.last}';
    return thirdPlace ? text : '$text · tanpa Juara 3';
  }

  /// Meta tombol Grup + Gugur (19b, 19i, 19k): "· 8 round · 16 match"; lewat booking → "· 10 round · lewat booking
  /// 00:20" tanpa jumlah match (pola Fixed sparing 14f). Null kalau tidak ada estimasi.
  static String? groupKnockoutMeta(int rounds, int matches, int overMinutes) {
    if (rounds == 0) return null;
    return overMinutes > 0
        ? '· $rounds round · lewat booking ${countdownText(overMinutes)}'
        : '· $rounds round · $matches match';
  }

  /// Babak awal Playoff sebagai fakta (keputusan 136): 2 grup → "Semifinal", 3 grup → "Perempat final · 2 wildcard",
  /// 4 grup → "Perempat final". Dipakai label `Playoff · …`, subjudul sheet Playoff, dan pilihan sheet Fase grup.
  static String playoffOpening(int groupCount) => switch (groupCount) {
    2 => KnockoutRound.semifinal.label,
    3 => '${KnockoutRound.quarterfinal.label} · 2 wildcard',
    _ => KnockoutRound.quarterfinal.label,
  };

  /// Keterangan satu pilihan di sheet Fase grup (19c, 19d, 23a): "4 + 4 + 4 · Perempat final · 2 wildcard"; pilihan yang
  /// tidak sah → alasannya ("Mulai 24 pemain", "Tepat 32 pemain").
  static String groupOption(int pairs, int groupCount) =>
      GroupStage.unavailableReason(groupCount, pairs) ??
      '${GroupStage.sizes(pairs, groupCount).join(' + ')} · ${playoffOpening(groupCount)}';
}
