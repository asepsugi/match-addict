import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/time_text.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_inputs.dart';
import '../../../models/models.dart';
import '../../konfigurasi/widgets/config_pickers.dart';

// Bagian yang sama di sheet Lanjutkan turnamen (Mixed, 08c) dan Tambah round (Fixed, 06w): jam booking per court dan
// estimasi berangka besar.

/// "Tambah jam booking": tiap court dengan sisa booking-nya dan stepper jam tambahan 0–[maxExtraHours]. Sering cuma
/// sebagian court yang bisa diperpanjang, jadi per court.
class CourtHoursGroup extends StatelessWidget {
  static const maxExtraHours = 6;

  final ActiveTournament active;
  final DateTime now;
  final Map<String, int> extraHours;
  final void Function(String courtId, int hours) onChanged;

  const CourtHoursGroup({
    super.key,
    required this.active,
    required this.now,
    required this.extraHours,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return MabarSection(
      header: const MabarGroupLabel('Tambah jam booking'),
      child: MabarGroup(
        color: MabarColors.paper,
        children: [
          for (final (i, c) in active.config.courts.indexed)
            () {
              final remaining = active.remainingBookingMinutes(c, now);
              final extra = extraHours[c.id] ?? 0;
              // Format sama dengan kotak jam di strip court: "Sisa 00:45", "→ 01:00".
              final left = remaining > 0 ? 'Sisa ${countdownText(remaining)}' : 'Waktu habis';
              return MabarRow(
                padded: true,
                leading: CourtSwatch(color: MabarColors.courtPalette[c.colorIndex], number: i + 1),
                titleWidget: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(c.name, style: MabarType.body.copyWith(fontWeight: FontWeight.w600, color: MabarColors.ink)),
                    Text(extra == 0 ? left : '$left → ${countdownText(remaining + extra * 60)}', style: MabarType.caption),
                  ],
                ),
                trailing: MabarStepper(
                  value: extra,
                  min: 0,
                  max: maxExtraHours,
                  unit: 'jam',
                  onChanged: (h) => onChanged(c.id, h),
                ),
              );
            }(),
        ],
      ),
    );
  }
}

/// Angka besar + label tebal + baris fakta kecil ("4 match lagi · 4 round (R9–R12) · 1 court").
class SheetEstimate extends StatelessWidget {
  static const _parentLine = StrutStyle(fontFamily: MabarType.family, fontSize: 16, height: 1.4, forceStrutHeight: true);

  final int number;
  final String label;
  final List<String> lines;

  /// Tanpa padding atas/bawah: baris klub bertumpuk di ringkasan sparing (14n) rapat satu sama lain.
  final bool stacked;

  const SheetEstimate({
    super.key,
    required this.number,
    required this.label,
    required this.lines,
    this.stacked = false,
  });

  @override
  Widget build(BuildContext context) {
    final caption = MabarType.caption.copyWith(color: MabarColors.ink3);
    return Padding(
      padding: EdgeInsets.fromLTRB(4, stacked ? 0 : 2, 4, stacked ? 0 : 2),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        children: [
          Text('$number', style: MabarType.numM.copyWith(fontSize: 40, height: 1, color: MabarColors.ink)),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: MabarType.body.copyWith(fontWeight: FontWeight.w700, color: MabarColors.ink)),
                // Teks kecil di dalam blok 16/1,4: tinggi barisnya ikut induk (22,4), seperti CSS.
                for (final line in lines) Text(line, style: caption, strutStyle: _parentLine),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Pengganti [SheetEstimate] saat belum ada yang bisa dibuat ("Tambah jam minimal satu court", 08d, 06z).
class SheetEstimateEmpty extends StatelessWidget {
  final String text;
  const SheetEstimateEmpty(this.text, {super.key});

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 2, 4, 2),
    child: Text(text, style: MabarType.body.copyWith(fontSize: 15, color: MabarColors.ink3)),
  );
}
