import 'package:intl/intl.dart';

import '../../models/models.dart';
import '../ranking/club_score.dart';
import '../ranking/ranking_calculator.dart';
import '../schedule/knockout_bracket.dart';

enum ShareFormat { ringkas, lengkap }

extension ShareFormatX on ShareFormat {
  String get label => switch (this) {
    ShareFormat.ringkas => 'Ringkas',
    ShareFormat.lengkap => 'Lengkap',
  };
}

/// Caption yang ikut gambar + teks lengkap. [shortened] = caption dipendekkan, jadi teks lengkap disalin
/// terpisah (keputusan 134).
typedef ShareCaption = ({String attached, String full, bool shortened});

/// Menyusun teks hasil turnamen untuk dibagikan ke WhatsApp/Telegram/clipboard.
class ResultTextBuilder {
  /// WhatsApp memotong caption gambar di 1024 karakter (terukur 2026-11-23: teks Lengkap terpotong tepat di situ).
  static const mediaCaptionLimit = 1024;

  /// Caption untuk share sheet bersama gambar (keputusan 134): teks [format] apa adanya kalau muat
  /// [mediaCaptionLimit]; kalau tidak, teks tanpa "Hasil per Round"; kalau masih tidak muat, kepala (baris 🏆 +
  /// tanggal) + baris ringkasan. Teks lengkap tetap [ShareCaption.full] untuk clipboard.
  static ShareCaption forShare({
    required ActiveTournament active,
    required List<StandingEntry> standings,
    required ShareFormat format,
    required DateTime now,
    required RankingMethod method,
    List<ClubStandings> clubStandings = const [],
  }) {
    String text(ShareFormat f) =>
        build(active: active, standings: standings, format: f, now: now, method: method, clubStandings: clubStandings);
    final full = text(format);
    if (full.length <= mediaCaptionLimit) return (attached: full, full: full, shortened: false);
    final standingsOnly = format == ShareFormat.lengkap ? text(ShareFormat.ringkas) : full;
    if (standingsOnly.length <= mediaCaptionLimit) return (attached: standingsOnly, full: full, shortened: true);
    final head = full.substring(0, full.indexOf('\n\n'));
    return (attached: '$head\n\n${summaryLine(active)}', full: full, shortened: true);
  }

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
    required RankingMethod method,
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
        _writeStandings(buffer, config, group.entries, method);
      }
    } else {
      buffer.writeln(status);
      _writeStandings(buffer, config, standings, method);
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
  static void _writeStandings(
    StringBuffer buffer,
    TournamentConfig config,
    List<StandingEntry> standings,
    RankingMethod method,
  ) {
    final unit = config.format.unit;
    for (final entry in standings) {
      final position = entry.position;
      if (position == null) continue;
      // Grup + Gugur (GU16): babak yang dicapai, tanpa poin dan Win %.
      if (entry.stage case final stage?) {
        buffer.writeln('$position. ${entry.label} — $stage');
        continue;
      }
      final s = entry.standing;
      final diff = s.gameDiff;
      buffer.writeln(
        '$position. ${entry.label} — ${s.totalPoint} $unit · '
        '${switch (method) {
          RankingMethod.pointPercent => '${s.pointPercent}% $unit',
          _ => '${s.winPercent.toStringAsFixed(1)}%',
        }} '
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
    // Sisi gugur yang belum diketahui ditulis dari asalnya ("Pemenang SF2"), bukan nama kosong (keputusan 106).
    final phase = m.phase;
    final sources = KnockoutBracket.sourcesOf(config, m);
    String pair(Pair p, SideSource? source) =>
        p.isTbd && source != null ? KnockoutBracket.sourceLabel(source) : p.playerIds.map(name).join('+');

    final prefix = switch (phase) {
      GroupPhase() => 'Grup ${phase.code} · ',
      KnockoutPhase() => '${phase.round.shortLabel} · ',
      null => '',
    };
    final left = pair(m.pair1, sources?.$1);
    final right = pair(m.pair2, sources?.$2);

    final line = _statusLine(m, left, right);
    return '$prefix$line';
  }

  static String _statusLine(MatchGame m, String left, String right) {
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
