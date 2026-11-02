import 'package:flutter_test/flutter_test.dart';
import 'package:match_addict/core/minute_ticker.dart';

/// Tik layar Jadwal/Input Skor jatuh di pergantian menit sejak turnamen dimulai, bukan 60 detik sejak layar dibuka
/// (logic.md §10): kotak jam, daftar Prioritas, dan Buat R… memakai menit yang sama.
void main() {
  testWidgets('turnamen mulai 19.00.30, layar dibuka 19.01.10 → tik 19.01.30, lalu tiap menit', (tester) async {
    final origin = DateTime(2026, 10, 22, 19, 0, 30);
    var now = DateTime(2026, 10, 22, 19, 1, 10);
    final ticks = <DateTime>[];
    final ticker = MinuteTicker(clock: () => now, origin: () => origin, onTick: () => ticks.add(now));

    Future<void> wait(int seconds) async {
      now = now.add(Duration(seconds: seconds));
      await tester.pump(Duration(seconds: seconds));
    }

    await wait(19);
    expect(ticks, isEmpty, reason: 'Timer.periodic dari layar dibuka baru tik 19.02.10');
    await wait(1);
    expect(ticks, [DateTime(2026, 10, 22, 19, 1, 30)]);
    await wait(60);
    expect(ticks.last, DateTime(2026, 10, 22, 19, 2, 30));
    ticker.cancel();
  });
}
