import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../ranking/ranking_calculator.dart';

enum ShareFormat { ringkas, lengkap }

extension ShareFormatX on ShareFormat {
  String get label => switch (this) {
    ShareFormat.ringkas => 'Ringkas',
    ShareFormat.lengkap => 'Lengkap',
  };
}

/// Menyusun teks hasil turnamen untuk dibagikan ke WhatsApp/Telegram/clipboard.
class ResultTextBuilder {
  /// [standings] = `standingEntriesProvider`, jadi nomornya sama dengan Klasemen (seri di semua tie-break →
  /// nomor sama; yang belum main tanpa nomor).
  static String build({
    required ActiveTournament active,
    required List<StandingEntry> standings,
    required ShareFormat format,
    required DateTime now,
  }) {
    final tournament = active.tournament;
    final config = tournament.config;
    final unit = config.format.unit;
    final buffer = StringBuffer()
      ..writeln('🏆 ${config.name ?? 'Match Addict'} · ${config.sport.label}')
      ..writeln(DateFormat('d MMMM yyyy', 'id').format(tournament.createdAt))
      ..writeln();

    buffer.writeln(active.isFinal(now) ? 'Klasemen Akhir' : 'Klasemen Sementara');
    for (final entry in standings) {
      final position = entry.position;
      if (position == null) continue;
      final s = entry.standing;
      final diff = s.gameDiff;
      buffer.writeln(
        '$position. ${entry.label} — ${s.totalPoint} $unit · '
        '${s.winPercent.toStringAsFixed(1)}% '
        '(${s.wins}-${s.losses}${config.format.canDraw ? '-${s.draws}' : ''}, ${diff >= 0 ? '+' : ''}$diff $unit)',
      );
    }
    final unranked = [
      for (final entry in standings)
        if (entry.position == null) entry.label,
    ];
    if (unranked.isNotEmpty) buffer.writeln('Belum main: ${unranked.join(', ')}');

    if (format == ShareFormat.lengkap) {
      buffer.writeln();
      buffer.writeln('Hasil per Round');
      var round = 0;
      for (final m in tournament.matches) {
        if (m.status == MatchStatus.pending) continue;
        if (m.roundNumber != round) {
          round = m.roundNumber;
          buffer.writeln('· Round $round');
        }
        buffer.writeln('  ${_matchLine(config, m)}');
      }
    }

    buffer
      ..writeln()
      ..writeln(summaryLine(active));
    return buffer.toString().trimRight();
  }

  /// "7 round · 14 match · 1 WO · 14 Sep 2026" — round dan match yang benar-benar dimainkan.
  static String summaryLine(ActiveTournament active) {
    final wo = active.matches.where((m) => m.status == MatchStatus.wo).length;
    return [
      '${active.playedRoundCount} round',
      '${active.playedMatchCount} match',
      if (wo > 0) '$wo WO',
      DateFormat('d MMM yyyy', 'id').format(active.tournament.createdAt),
    ].join(' · ');
  }

  static String _matchLine(TournamentConfig config, MatchGame m) {
    String name(String id) => config.players
        .firstWhere(
          (p) => p.id == id,
          orElse: () => const Player(id: '', name: '?'),
        )
        .name;
    String pair(Pair p) => p.playerIds.map(name).join('+');

    final left = pair(m.pair1);
    final right = pair(m.pair2);

    switch (m.status) {
      case MatchStatus.done:
        final score = m.sets.map((s) => '${s.side1}-${s.side2}').join(' ');
        return '$left vs $right → $score';
      case MatchStatus.wo:
        final winner = m.winnerPairId == m.pair1.id ? left : right;
        return '$left vs $right → WO, $winner menang';
      case MatchStatus.cancelled:
        return '$left vs $right → tidak dimainkan';
      case MatchStatus.pending:
        return '$left vs $right';
    }
  }
}
