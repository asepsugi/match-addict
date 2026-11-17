import 'dart:math';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/theme/mabar_icons.dart';
import '../../core/theme/mabar_theme.dart';
import '../../core/widgets/mabar_controls.dart';
import '../../core/widgets/mabar_group.dart';
import '../../core/widgets/mabar_inputs.dart';
import '../../core/widgets/mabar_layers.dart';
import '../../models/models.dart';
import '../../services/pairing/group_draft.dart';

/// Screen 19 · Grup (19r–19y) — pasangan dibagi ke grup A–D sebelum Jadwal Grup + Gugur. Manual: tiap baris pasangan
/// punya chip huruf grup; Acak: terbagi langsung. Alasan tombol menunggu ada di tombol, akibat kunci di dialog 19y.
/// Kembali (tombol atau back sistem) membawa [GroupDraft] ke layar Pasangan, supaya pembagian tidak hilang (19o).
class GroupScreen extends StatefulWidget {
  /// Config dari Pasangan: `fixedPairs` terisi dan `groupKnockout` membawa jumlah grup, format, dan juara 3.
  final TournamentConfig config;

  /// Pembagian dari kunjungan sebelumnya, sudah di-`reconcile` ke pasangan sekarang; null = mulai kosong.
  final GroupDraft? initial;

  /// Sumber acak; diisi test supaya hasil acak sama dengan frame.
  final Random? random;

  const GroupScreen({super.key, required this.config, this.initial, this.random});

  @override
  State<GroupScreen> createState() => _GroupScreenState();
}

class _GroupScreenState extends State<GroupScreen> {
  late GroupDraft _draft;
  var _manual = true;
  var _scrolled = false;

  late final Random _random = widget.random ?? Random();

  @override
  void initState() {
    super.initState();
    _draft = widget.initial ?? GroupDraft(widget.config.fixedPairs!, widget.config.groupKnockout!.groupCount);
  }

  /// Ke Acak membuang hasil Manual; kembali ke Manual mengosongkan semua grup tanpa konfirmasi (19u).
  void _switchMode(bool manual) {
    if (manual == _manual) return;
    setState(() {
      _manual = manual;
      _draft = manual ? _draft.cleared() : _draft.random(_random);
    });
  }

  String _name(String playerId) => widget.config.players.firstWhere((p) => p.id == playerId).name;

  String _pairName(Pair p) => '${_name(p.player1Id)} · ${_name(p.player2Id)}';

  Future<void> _create() async {
    final ok = await showMabarConfirm(
      context,
      title: 'Buat jadwal?',
      message: 'Pasangan dan grup tidak bisa diubah setelah jadwal dibuat.',
      confirmLabel: 'Buat jadwal',
    );
    if (!ok || !mounted) return;
    // Lewat copyWith (bukan konstruktor baru) supaya format, juara 3, dan jumlah grup terbawa.
    final ko = widget.config.groupKnockout!;
    context.push(
      '/schedule',
      extra: widget.config.copyWith(groupKnockout: ko.copyWith(groups: _draft.groups)),
    );
  }

  /// Label grup "Grup A · 2 dari 4"; angka clay kalau kelebihan (19v).
  Widget _groupLabel(int g) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text.rich(
      TextSpan(
        text: 'Grup ${GroupKnockout.letter(g)} · ',
        children: [
          TextSpan(
            text: _draft.countLabel(g),
            style: _draft.isOver(g) ? const TextStyle(color: MabarColors.clay) : null,
          ),
        ],
      ),
      style: MabarType.label,
    ),
  );

  /// `.chip` huruf grup: 34 pt, area sentuh 44 (tinggi baris).
  Widget _letterChip(Pair pair, int g) {
    final selected = _draft.groupOf(pair.id) == g;
    final letter = GroupKnockout.letter(g);
    return Semantics(
      key: ValueKey('${pair.id}/$letter'),
      button: true,
      selected: selected,
      label: 'Grup $letter',
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _draft = _draft.tap(pair.id, g)),
        child: SizedBox(
          width: 34,
          height: 44,
          child: Center(
            child: Container(
              width: 34,
              height: 34,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: selected ? MabarColors.ink : MabarColors.card,
                borderRadius: BorderRadius.circular(MabarRadius.chip),
                border: selected ? null : Border.all(color: MabarColors.line),
              ),
              child: Text(
                letter,
                style: MabarType.body.copyWith(
                  fontWeight: FontWeight.w600,
                  color: selected ? Colors.white : MabarColors.ink,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _chipRow(Pair pair) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (var g = 0; g < _draft.groupCount; g++) ...[if (g > 0) const SizedBox(width: 7), _letterChip(pair, g)],
    ],
  );

  /// Kartu pasangan: Manual 52 pt dengan chip huruf; Acak 40 pt tanpa chip (19u).
  Widget _card(List<Pair> pairs) {
    if (_manual) {
      return MabarGroup(
        children: [for (final p in pairs) MabarRow(title: _pairName(p), titleOneLine: true, trailing: _chipRow(p))],
      );
    }
    return MabarGroup(
      children: [
        for (final (i, p) in pairs.indexed)
          SizedBox(
            // Garis antar-baris memakan 1 pt (MabarGroup), jadi baris ke-2 dst. 39 supaya pitch tetap 40.
            height: i == 0 ? 40 : 39,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  _pairName(p),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: MabarType.body.copyWith(color: MabarColors.ink),
                ),
              ),
            ),
          ),
      ],
    );
  }

  /// Grup kosong hanya labelnya (19r): jarak ke bagian berikutnya 8, bukan 16 (kartu + 16).
  List<Widget> _body() {
    final children = <Widget>[];
    var gapBefore = 0.0;
    void section(Widget label, List<Pair> members) {
      if (children.isNotEmpty) children.add(SizedBox(height: gapBefore));
      children
        ..add(label)
        ..add(const SizedBox(height: 8));
      if (members.isNotEmpty) children.add(_card(members));
      gapBefore = members.isEmpty ? 0 : 16;
    }

    for (var g = 0; g < _draft.groupCount; g++) {
      section(_groupLabel(g), [for (final id in _draft.groups[g]) _draft.pairById(id)]);
    }
    final rest = _draft.unassigned;
    if (_manual && rest.isNotEmpty) section(MabarGroupLabel('${rest.length} belum masuk grup'), rest);
    return children;
  }

  @override
  Widget build(BuildContext context) {
    final reason = _draft.blockReason;
    return PopScope<Object?>(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) context.pop(_draft);
      },
      child: Scaffold(
        backgroundColor: MabarColors.paper,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            MabarAppBar(
              title: 'Grup',
              subtitle: '${widget.config.sport.label} · ${_draft.pairs.length} pasangan',
              onBack: () => context.pop(_draft),
              scrolled: _scrolled,
            ),
            Expanded(
              child: NotificationListener<ScrollNotification>(
                onNotification: (n) {
                  final scrolled = n.metrics.pixels > 0;
                  if (scrolled != _scrolled) setState(() => _scrolled = scrolled);
                  return false;
                },
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      MabarSegmented<bool>(
                        options: const [(false, 'Acak'), (true, 'Manual')],
                        selected: _manual,
                        onChanged: _switchMode,
                      ),
                      const SizedBox(height: 16),
                      if (!_manual) ...[
                        MabarGroupHeader.text(
                          '${_draft.pairs.length} pasangan',
                          trailing: MabarTextButton(
                            label: 'Acak ulang',
                            icon: MabarIcons.arrowClockwise,
                            onPressed: () => setState(() => _draft = _draft.random(_random)),
                          ),
                        ),
                        const SizedBox(height: 8),
                      ],
                      ..._body(),
                    ],
                  ),
                ),
              ),
            ),
            MabarActionBar(
              children: [
                Expanded(
                  child: reason != null
                      ? MabarButton(label: 'Buat jadwal', meta: '· $reason', variant: MabarButtonVariant.wait)
                      : MabarButton(label: 'Buat jadwal', icon: MabarIcons.lockSimple, onPressed: _create),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
