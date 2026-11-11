import 'package:flutter/material.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import 'mixed_guide_sheet.dart';

/// Sheet 16c "Cara kerja Mexicano" (teks disetujui host, keputusan 40) — pengganti 06k untuk Mexicano. Muncul sekali
/// saat R1 dibuat, setelah itu lewat menu ⋯. Estimasi memakai rumus Mixed ([guideEstimateSection]).
Future<void> showMexicanoGuideSheet(BuildContext context, ActiveTournament active) {
  Widget rules(String label, List<String> items) => MabarSection(
    header: MabarGroupLabel(label),
    child: MabarGroup(
      color: MabarColors.paper,
      children: [
        for (final rule in items)
          MabarRow(
            leading: const Icon(MabarIcons.check, size: MabarSize.iconInButton, color: MabarColors.ink2),
            title: rule,
          ),
      ],
    ),
  );

  return showMabarSheet<void>(
    context,
    title: 'Cara kerja Mexicano',
    // Keputusan 43: "R1 diundi." hanya selama R1; di round lanjut tinggal langkah berikutnya.
    subtitle:
        '${active.roundCount == 1 ? 'R1 diundi. ' : ''}Isi semua skor, lalu tekan Buat R${active.roundCount + 1}.',
    footer: (context) => MabarButton(label: 'Mengerti', onPressed: () => Navigator.pop(context)),
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        rules('Pasangan', const [
          'Urut Total Point, 4 pemain per court',
          '#1 + #3 lawan #2 + #4',
          'Partner berulang dihindari',
        ]),
        const SizedBox(height: 16),
        rules('Aturan Fairness', const ['Pemain paling jarang main diprioritaskan', 'Selisih match antar pemain ≤ 1']),
        const SizedBox(height: 16),
        guideEstimateSection(active),
      ],
    ),
  );
}
