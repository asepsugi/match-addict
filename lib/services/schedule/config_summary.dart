import '../../models/models.dart';

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
}
