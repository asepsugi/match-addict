import 'package:flutter/material.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_layers.dart';
import 'widgets/home_panel.dart';

/// Sheet 01i · panduan pasang di iPhone/iPad. Safari tidak punya API pasang yang bisa dipicu dari
/// halaman, jadi baris "Pasang Match Addict di HP" di sana hanya bisa menunjukkan jalannya. Sheet info:
/// satu tombol "Mengerti".
Future<void> showIosInstallSheet(BuildContext context) => showMabarSheet<void>(
  context,
  title: 'Pasang di iPhone',
  subtitle: 'Lewat menu Bagikan di Safari',
  builder: (context) => const IosInstallSteps(),
  footer: (context) => MabarButton(label: 'Mengerti', onPressed: () => Navigator.pop(context)),
);

/// Isi sheet 01i: tiga langkah lalu catatan Safari.
class IosInstallSteps extends StatelessWidget {
  const IosInstallSteps({super.key});

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      MabarGroup(
        color: MabarColors.paper,
        children: [
          MabarRow(
            padded: true,
            titleWidget: InstallStep(
              number: 1,
              text: [const TextSpan(text: 'Ketuk '), InstallStep.bold('Bagikan'), const TextSpan(text: ' '), InstallStep.icon(MabarIcons.export)],
              sub: 'Kalau tidak kelihatan, ada di dalam menu ···',
            ),
          ),
          MabarRow(
            padded: true,
            titleWidget: InstallStep(
              number: 2,
              text: [
                const TextSpan(text: 'Pilih '),
                InstallStep.bold('Tambah ke Layar Utama'),
                const TextSpan(text: ' '),
                InstallStep.icon(MabarIcons.plusSquare),
              ],
              sub: 'Add to Home Screen · geser ke bawah kalau belum kelihatan',
            ),
          ),
          MabarRow(
            padded: true,
            titleWidget: InstallStep(
              number: 3,
              text: [const TextSpan(text: 'Ketuk '), InstallStep.bold('Tambah'), const TextSpan(text: ' di kanan atas')],
              sub: 'Match Addict muncul di layar utama seperti app biasa',
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      // `p.small.muted` dengan padding 0 4.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Text(
          'Buka di Safari dulu. Kalau link dibuka dari dalam app lain, menu Tambah ke Layar Utama tidak ada.',
          style: MabarType.caption,
        ),
      ),
    ],
  );
}
