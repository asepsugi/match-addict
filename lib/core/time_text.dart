// Penulisan waktu (logic.md §10): titik dua untuk durasi, titik untuk jam dinding, supaya hitung mundur
// "01:46" tidak tertukar dengan jam "20.02".

String _two(int n) => n.toString().padLeft(2, '0');

/// Hitung mundur sisa booking, jam:menit: 75 → "01:15", 58 → "00:58", 0 → "00:00".
String countdownText(int minutes) => '${_two(minutes ~/ 60)}:${_two(minutes % 60)}';

/// Jam dinding: "20.02".
String clockText(DateTime time) => '${_two(time.hour)}.${_two(time.minute)}';

/// Sisa booking untuk pembaca layar: 75 → "1 jam 15 menit", 60 → "1 jam", 58 → "58 menit".
String countdownSpoken(int minutes) {
  final h = minutes ~/ 60, m = minutes % 60;
  return [if (h > 0) '$h jam', if (m > 0 || h == 0) '$m menit'].join(' ');
}
