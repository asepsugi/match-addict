import 'package:flutter/material.dart';

import '../../../core/theme/mabar_theme.dart';
import '../../../core/widgets/mabar_group.dart';

/// `.rest` — siapa yang istirahat. Nama dua kolom rata (urut seperti daftar pemain, kiri lalu kanan),
/// 13/600, terpotong elipsis. Judul: "Istirahat", "Istirahat · Prioritas main di R4" ([priorityRound],
/// bagian prioritas bertinta gelap — biru court dipakai tautan/aksi seperti "Batalkan Rn"), atau "Istirahat lagi di R4" ([later], nama dipudarkan). Fixed memakai
/// nama pasangan ("Indra · Joko").
class RestingList extends StatelessWidget {
  final List<String> names;
  final int? priorityRound;
  final bool later;

  /// Judul lain untuk daftar nama yang sama bentuknya ("Langsung main di R5" di Kelola court).
  final String? title;

  const RestingList({super.key, required this.names, this.priorityRound, this.later = false, this.title})
    : clubs = null;

  /// Sparing (`.rest .names.clubs`, 13k): dua kolom, satu per klub (klub pertama di kiri), masing-masing diawali nama
  /// klubnya. Kolom klub yang tidak punya yang istirahat ditulis "–". [names] tidak dipakai. Judulnya sama dengan
  /// daftar biasa: "Istirahat", "Istirahat · Prioritas main di R…" ([priorityRound]), "Istirahat lagi di R…"
  /// ([later] + [priorityRound], nama pudar, 15d/15e), atau [title] ("Langsung main di R4", 15o).
  const RestingList.clubs({
    super.key,
    required List<RestingClub> this.clubs,
    this.priorityRound,
    this.later = false,
    this.title,
  }) : names = const [],
       // Satu kolom per klub; sparing selalu tepat dua klub (S1).
       assert(clubs.length == 2, 'RestingList.clubs butuh tepat dua klub.'),
       assert(!later || priorityRound != null, 'Istirahat lagi butuh nomor round berikutnya.');

  /// Round berikutnya untuk daftar kedua (06o).
  const RestingList.later({super.key, required this.names, required int nextRound})
    : priorityRound = nextRound,
      later = true,
      title = null,
      clubs = null;

  /// Hanya diisi oleh [RestingList.clubs].
  final List<RestingClub>? clubs;

  @override
  Widget build(BuildContext context) {
    final label = title != null
        ? Text(title!, style: MabarType.label)
        : later
        ? Text('Istirahat lagi di R$priorityRound', style: MabarType.label)
        : Text.rich(
            TextSpan(
              text: 'Istirahat',
              children: [
                if (priorityRound != null) ...[
                  const TextSpan(text: ' · '),
                  TextSpan(text: 'Prioritas main di R$priorityRound', style: MabarType.label.copyWith(color: MabarColors.ink)),
                ],
              ],
            ),
            style: MabarType.label,
          );
    final style = MabarType.label.copyWith(
      height: 22 / 13,
      color: later ? MabarColors.ink3 : MabarColors.ink2,
      fontWeight: later ? FontWeight.w500 : FontWeight.w600,
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        MabarGroupHeader(label: label),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: clubs != null
              ? _ClubColumns(clubs: clubs!, nameStyle: style)
              : Column(
                  children: [
                    for (var i = 0; i < names.length; i += 2)
                      Row(
                        children: [
                          Expanded(
                            child: Text(names[i], style: style, maxLines: 1, overflow: TextOverflow.ellipsis),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: i + 1 < names.length
                                ? Text(names[i + 1], style: style, maxLines: 1, overflow: TextOverflow.ellipsis)
                                : const SizedBox(),
                          ),
                        ],
                      ),
                  ],
                ),
        ),
      ],
    );
  }
}

/// Satu kolom klub di [RestingList.clubs]: nama klub dan nama di bawahnya — pasangan (Fixed) atau pemain (Mixed) yang
/// istirahat, atau pemain "Langsung main" (Kelola court 15o).
class RestingClub {
  final String club;
  final List<String> names;
  const RestingClub({required this.club, required this.names});
}

/// `.names.clubs`: grid dua kolom; `.club` 13/500 abu, nama 13/600 seperti Istirahat biasa, semuanya setinggi 22.
class _ClubColumns extends StatelessWidget {
  final List<RestingClub> clubs;
  final TextStyle nameStyle;
  const _ClubColumns({required this.clubs, required this.nameStyle});

  @override
  Widget build(BuildContext context) {
    final clubStyle = nameStyle.copyWith(fontWeight: FontWeight.w500, color: MabarColors.ink3);
    Widget column(RestingClub c) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(c.club, style: clubStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
        for (final n in c.names.isEmpty ? const ['–'] : c.names)
          Text(n, style: nameStyle, maxLines: 1, overflow: TextOverflow.ellipsis),
      ],
    );
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(child: column(clubs[0])),
        const SizedBox(width: 12),
        Expanded(child: column(clubs[1])),
      ],
    );
  }
}
