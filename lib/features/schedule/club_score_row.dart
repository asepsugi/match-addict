import '../../core/widgets/club_score.dart';
import '../../services/ranking/club_score.dart';

/// Satu baris papan skor klub dari [ClubResult]: widget `ClubScore` hanya menerima string jadi, jadi pemetaan
/// (nama, detail, skor, bola) ada di satu tempat untuk Klasemen, Jadwal, Beranda, dan Live.
ClubScoreRow clubScoreRowOf(ClubResult result, ClubTally tally) => ClubScoreRow(
  name: tally.club.name,
  detail: result.detailLabel(tally),
  score: tally.winsLabel,
  lead: result.leads(tally),
);
