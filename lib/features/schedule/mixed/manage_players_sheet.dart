import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_controls.dart';
import '../../../core/widgets/mabar_group.dart';
import '../../../core/widgets/mabar_inputs.dart';
import '../../../core/widgets/mabar_layers.dart';
import '../../../models/models.dart';
import '../tournament_controller.dart';

/// Sheet 08a "Kelola pemain" (Mixed) — tambah, keluarkan, atau kembalikan pemain tanpa mengulang
/// turnamen; berlaku mulai round berikutnya. Keluarkan langsung tanpa konfirmasi: bisa dibatalkan lewat
/// Kembalikan, dan skornya tetap dihitung.
Future<void> showManagePlayersSheet(BuildContext context) {
  final next = (ProviderScope.containerOf(context).read(tournamentProvider)?.roundCount ?? 0) + 1;
  return showMabarSheet<void>(
    context,
    title: 'Kelola pemain',
    subtitle: 'Berlaku mulai R$next',
    builder: (_) => const _ManagePlayers(),
  );
}

class _ManagePlayers extends ConsumerStatefulWidget {
  const _ManagePlayers();

  @override
  ConsumerState<_ManagePlayers> createState() => _ManagePlayersState();
}

class _ManagePlayersState extends ConsumerState<_ManagePlayers> {
  final _name = TextEditingController();
  String? _error;
  // Sparing: klub tujuan pemain baru, tanpa pilihan awal (AC-S12).
  String? _clubId;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  TournamentController get _controller => ref.read(tournamentProvider.notifier);

  void _add() {
    final error = _controller.addPlayer(_name.text, clubId: _clubId);
    setState(() => _error = error);
    if (error == null) _name.clear();
  }

  Widget _playerRow(ActiveTournament active, Player p) {
    if (active.withdrawnPlayerIds.contains(p.id)) {
      return MabarRow(
        padded: true,
        titleWidget: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              p.name,
              style: MabarType.body.copyWith(color: MabarColors.faint, decoration: TextDecoration.lineThrough),
            ),
            const Text('Keluar · skornya tetap dihitung', style: MabarType.caption),
          ],
        ),
        trailing: MabarRowAction(
          label: 'Kembalikan',
          restore: true,
          onPressed: () => setState(() => _error = _controller.reinstatePlayer(p.id)),
        ),
      );
    }
    return MabarRow(
      title: p.name,
      trailing: MabarRowAction(
        label: 'Keluarkan',
        onPressed: active.canWithdraw(p.id) ? () => _controller.withdrawPlayer(p.id) : null,
      ),
    );
  }

  @override
  void initState() {
    super.initState();
    // Tambah mati sampai nama terisi (sparing), jadi tombol perlu tahu isian berubah.
    _name.addListener(() => setState(() {}));
  }

  @override
  Widget build(BuildContext context) {
    final active = ref.watch(tournamentProvider);
    if (active == null) return const SizedBox.shrink();
    final clubs = active.config.clubs;

    final activeCount = active.activePlayers.length;
    final withdrawn = active.withdrawnPlayerIds;
    final small = MabarType.caption.copyWith(color: MabarColors.ink3);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Expanded(
              child: MabarField(
                controller: _name,
                hint: 'Nama pemain baru',
                error: _error != null,
                textCapitalization: TextCapitalization.words,
                textInputAction: TextInputAction.done,
                // Enter = Tambah; isian tetap fokus untuk nama berikutnya.
                onSubmitted: (_) => _add(),
              ),
            ),
            const SizedBox(width: 8),
            // Sama tinggi dengan kolom nama di sebelahnya.
            MabarButton(
              label: 'Tambah',
              expand: false,
              height: 48,
              onPressed: clubs != null && (_clubId == null || _name.text.trim().isEmpty) ? null : _add,
            ),
          ],
        ),
        if (clubs != null) ...[
          const SizedBox(height: 10),
          MabarChipWrap(
            children: [
              for (final c in clubs)
                MabarChip(label: c.name, selected: _clubId == c.id, onTap: () => setState(() => _clubId = c.id)),
            ],
          ),
        ],
        if (_error != null) ...[
          const SizedBox(height: 10),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              _error!,
              style: small.copyWith(color: MabarColors.clay, fontWeight: FontWeight.w600),
            ),
          ),
        ] else ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text(
              'Pemain baru langsung ikut main dan diprioritaskan sampai jumlah match-nya menyusul, dengan jeda '
              'istirahat 1 round. Total Point tertinggal; Win % lebih adil untuk pemain baru.',
              style: small,
            ),
          ),
        ],
        const SizedBox(height: 16),
        if (clubs == null)
          MabarSection(
            header: MabarGroupLabel(
              withdrawn.isEmpty
                  ? '$activeCount pemain aktif'
                  : '$activeCount pemain aktif · ${withdrawn.length} keluar',
            ),
            child: MabarGroup(
              color: MabarColors.paper,
              children: [for (final p in active.config.players) _playerRow(active, p)],
            ),
          )
        else
          for (final club in clubs) ...[
            Builder(
              builder: (_) {
                final members = [
                  for (final p in active.config.players)
                    if (p.clubId == club.id) p,
                ];
                final out = members.where((p) => withdrawn.contains(p.id)).length;
                final activeInClub = members.length - out;
                // Keluarkan mati karena klub (bukan karena total 4): alasannya di bawah daftar klub itu. Batasnya dari
                // `canWithdraw`, tidak dihitung ulang di sini.
                final clubBlocked =
                    activeCount > 4 && members.any((p) => !withdrawn.contains(p.id) && !active.canWithdraw(p.id));
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    MabarSection(
                      header: MabarGroupLabel(
                        out == 0
                            ? '${club.name} · $activeInClub aktif'
                            : '${club.name} · $activeInClub aktif · $out keluar',
                      ),
                      child: MabarGroup(
                        color: MabarColors.paper,
                        children: [for (final p in members) _playerRow(active, p)],
                      ),
                    ),
                    if (clubBlocked) ...[
                      const SizedBox(height: 8),
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        child: Text('Butuh minimal 2 pemain per klub', style: small),
                      ),
                    ],
                    const SizedBox(height: 16),
                  ],
                );
              },
            ),
          ],
        if (activeCount <= 4) ...[
          const SizedBox(height: 16),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: Text('Butuh minimal 4 pemain', style: small),
          ),
        ],
      ],
    );
  }
}
