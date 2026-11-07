import '../../core/widgets/club_score.dart';
import '../../services/ranking/club_score.dart';

/// Adaptor [ClubResult] → papan skor klub (`.clubscore`). Satu-satunya tempat teks dan bola dirangkai, dipakai
/// Jadwal (13k–13m) dan Klasemen (13n–13p) supaya angkanya tidak berbeda antar layar.
ClubScore clubScoreOf(ClubResult r) =>
    ClubScore(first: clubScoreRowOf(r, r.first), second: clubScoreRowOf(r, r.second));

ClubScoreRow clubScoreRowOf(ClubResult r, ClubTally t) =>
    ClubScoreRow(name: t.club.name, detail: r.detailLabel(t), score: t.winsLabel, lead: r.leads(t));
