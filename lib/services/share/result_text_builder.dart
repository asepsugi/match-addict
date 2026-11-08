import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../ranking/club_score.dart';
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
  ///
  /// Sparing ([clubStandings] = `clubStandingEntriesProvider`, nomor per klub): baris pertama skor klub
  /// "🏆 PB Garuda 7–5 Matcha Club · Padel" ("· Seri" kalau menang dan Total Point sama), nama turnamen di baris
  /// berikutnya, lalu satu blok "Klasemen Akhir · {klub}" per klub (caption 13q, logic.md §13.9).
  static String build({
    required ActiveTournament active,
    required List<StandingEntry> standings,
    required ShareFormat format,
    required DateTime now,
    List<ClubStandings> clubStandings = const [],
  }) {
    final tournament = active.tournament;
    final config = tournament.config;
    final buffer = StringBuffer();
    final clubs = clubStandings.isEmpty ? null : ClubResult.of(active);
    final status = active.isFinal(now) ? 'Klasemen Akhir' : 'Klasemen Sementara';
    if (clubs != null) {
      final (a, b) = (clubs.first, clubs.second);
      final draw = clubs.lead == ClubLead.draw ? ' · Seri' : '';
      buffer.writeln('🏆 ${a.club.name} ${a.winsLabel}–${b.winsLabel} ${b.club.name}$draw · ${config.sport.label}');
      if (config.name != null) buffer.writeln(config.name);
    } else {
      buffer.writeln('🏆 ${config.name ?? 'Match Addict'} · ${config.sport.label}');
    }
    buffer
      ..writeln(DateFormat('d MMMM yyyy', 'id').format(tournament.createdAt))
      ..writeln();

    if (clubs != null) {
      for (final (i, group) in clubStandings.indexed) {
        if (i > 0) buffer.writeln();
        buffer.writeln('$status · ${group.club.name}');
        _writeStandings(buffer, config, group.entries);
      }
    } else {
      buffer.writeln(status);
      _writeStandings(buffer, config, standings);
    }

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

  /// Baris bernomor lalu "Belum main: …".
  static void _writeStandings(StringBuffer buffer, TournamentConfig config, List<StandingEntry> standings) {
    final unit = config.format.unit;
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
