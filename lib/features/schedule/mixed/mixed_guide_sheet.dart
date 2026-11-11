import 'package:flutter/material.dart';

import '../../../core/theme/mabar_icons.dart';
import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../../../services/schedule/endless_round_generator.dart';

/// Sheet 06k "Cara kerja Mixed" — pengganti layar konfirmasi Mixed lama. Teks Aturan Fairness dan label
/// Estimasi sesuai permintaan host. Muncul sekali saat R1 dibuat, setelah itu lewat menu ⋯.
Future<void> showMixedGuideSheet(BuildContext context, ActiveTournament active) {
  final clubs = active.config.clubs;

  return showMabarSheet<void>(
    context,
    title: 'Cara kerja Mixed',
    subtitle:
        'Round dibuat satu per satu. Isi semua skor, lalu tekan Buat R${active.roundCount + 1}. Berhenti kapan saja.',
    footer: (context) => MabarButton(label: 'Mengerti', onPressed: () => Navigator.pop(context)),
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        MabarSection(
          header: const MabarGroupLabel('Aturan Fairness'),
          child: MabarGroup(
            color: MabarColors.paper,
            children: [
              for (final rule in [
                'Pemain paling jarang main diprioritaskan',
                'Pasangan baru diprioritaskan',
                clubs == null ? 'Selisih match antar pemain ≤ 1' : 'Selisih match antar pemain satu klub ≤ 1',
              ])
                MabarRow(
                  leading: const Icon(MabarIcons.check, size: MabarSize.iconInButton, color: MabarColors.ink2),
                  title: rule,
                ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        guideEstimateSection(active),
      ],
    ),
  );
}

/// Grup "Estimasi" sheet Cara kerja (06k, 15k, 16c): Mixed, Sparing, dan Mexicano memakai rumus yang sama.
Widget guideEstimateSection(ActiveTournament active) {
  final config = active.config;
  final total = config.maxRounds * config.courtCount;
  final players = active.activePlayers.length;
  final clubs = config.clubs;
  // Sparing: estimasi per klub dari rumus sparing, bukan dari 4 pemain per match (13.4).
  final sparing = clubs == null
      ? null
      : EndlessRoundGenerator.sparingEstimate(
          maxRounds: config.maxRounds,
          courts: config.courtCount,
          club1: active.activePlayersOfClub(clubs[0].id).length,
          club2: active.activePlayersOfClub(clubs[1].id).length,
        );
  Widget value(String text) => Text(text, style: MabarType.numM.copyWith(fontSize: 20, color: MabarColors.ink));

  return MabarSection(
    header: const MabarGroupLabel('Estimasi'),
    child: MabarGroup(
      color: MabarColors.paper,
      children: [
        MabarRow(title: 'Max Round', trailing: value('${config.maxRounds}')),
        if (sparing == null)
          MabarRow(title: 'Match/Pemain', trailing: value('±${players == 0 ? 0 : total * 4 ~/ players}'))
        else ...[
          MabarRow(title: 'Match/Pemain · ${clubs![0].name}', trailing: value('±${sparing.perPlayer1}')),
          MabarRow(title: 'Match/Pemain · ${clubs[1].name}', trailing: value('±${sparing.perPlayer2}')),
        ],
        MabarRow(title: 'Court Aktif', trailing: value('${sparing?.activeCourts ?? config.courtCount}')),
        MabarRow(title: 'Total Match', trailing: value('${sparing?.matches ?? total}')),
      ],
    ),
  );
}
