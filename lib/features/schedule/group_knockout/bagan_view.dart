import 'package:flutter/material.dart';

import '../../../models/models.dart';

/// Isi tab "Bagan" Jadwal Grup + Gugur (`.bagan`, frame 21a, 21d, 21j, 21u).
///
/// TITIK SAMBUNG GG-9: [ScheduleFixedScreen] memasang widget ini sebagai isi tab terakhir (di dalam `Expanded`, di bawah
/// RoundTabs dan di atas action bar; app bar sudah "Bagan" + "Padel · 4 pasangan lolos", meta tab "0/4 match").
/// GG-9 mengisi [build] dan menambah [onOpenMatch] ke Input Skor — cukup ganti isi file ini. Sekarang kosong.
class BaganView extends StatelessWidget {
  final ActiveTournament active;

  /// Ketuk kartu yang bisa diisi → buka Input Skor (sama dengan baris di tab round). Null = baca saja (penonton live).
  final void Function(MatchGame match)? onOpenMatch;

  const BaganView({super.key, required this.active, this.onOpenMatch});

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}
