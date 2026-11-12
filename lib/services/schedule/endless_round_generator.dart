import 'dart:math';

import '../../models/models.dart';
import '../ranking/ranking_calculator.dart';

/// Kapan court yang baru ditambah atau diubah jamnya dipakai ([EndlessRoundGenerator.courtUse]).
enum CourtUse { now, nextRound, unused }

/// Hasil generate satu round mode Mixed (endless).
class EndlessRound {
  final List<MatchGame> matches;
  final List<Player> resting;

  const EndlessRound({required this.matches, required this.resting});
}

/// Generator round mode Mixed.
///
/// Urutannya persis seperti di PRD:
/// 1. Pilih pemain prioritas — paling sedikit main, lalu paling lama istirahat; pemain yang tertinggal diberi jeda
///    ([priorityOrder]).
/// 2. Acak pasangan di antara pemain aktif dengan constraint dari history.
/// 3. Tempatkan tiap match ke satu court.
///
/// Constraint pairing di-relax berjenjang lewat bobot penalti: mengulang lawan
/// jauh lebih murah daripada mengulang partner, dan mengulang pertandingan yang
/// persis sama paling mahal — jadi kalau tidak ada solusi bersih, yang dikorbankan
/// adalah constraint yang paling lunak.
class EndlessRoundGenerator {
  static const _repeatMatchPenalty = 1000;
  static const _repeatPartnerPenalty = 10;
  static const _repeatOpponentPenalty = 3;
  static const _maxAttempts = 400;

  /// Main beruntun terpendek sebelum pemain yang tertinggal diberi jeda (usulan host), lihat [priorityOrder].
  static const _catchUpRun = 2;

  /// [players] hanya pemain aktif (yang keluar tidak dioper). [latePlayerIds] = `ActiveTournament.latePlayerIds`,
  /// lihat [priorityOrder]. [seed] = `ActiveTournament.drawSeed`; [random] hanya untuk menyusun pasangan.
  static EndlessRound? generateRound({
    required List<Player> players,
    required List<Court> courts,
    required List<MatchGame> history,
    required int roundNumber,
    required int seed,
    Set<String> latePlayerIds = const {},
    Random? random,
  }) {
    final capacity = slotsFor(players: players.length, courts: courts.length);
    if (capacity < 4) return null;

    final sorted = priorityOrder(
      players: players,
      history: history,
      roundNumber: roundNumber,
      seed: seed,
      slots: capacity,
      latePlayerIds: latePlayerIds,
    );
    final active = sorted.take(capacity).toList();
    final resting = sorted.skip(capacity).toList();

    final arrangement = _bestArrangement(active, _History(history), random ?? Random());

    final matches = <MatchGame>[];
    for (var i = 0; i < arrangement.length; i++) {
      final (pair1, pair2) = arrangement[i];
      matches.add(
        MatchGame(
          id: 'm-r$roundNumber-${i + 1}',
          roundNumber: roundNumber,
          matchNumberInRound: i + 1,
          courtId: courts[i].id,
          pair1: pair1,
          pair2: pair2,
        ),
      );
    }

    return EndlessRound(matches: matches, resting: resting);
  }

  /// Undian terkunci round [roundNumber]: `Random(seed + roundNumber)` dibagikan ke [playerIds] urut id. Satu undian
  /// untuk prioritas main ([priorityOrder]) dan pemisah pemain bernomor sama di urutan Mexicano ([mexicanoOrder]), jadi
  /// selalu dibagikan ke **semua pemain aktif**: membagikannya ke sebagian pemain memberi nilai lain (logic.md §14.2).
  static Map<String, int> lockedDraw(Iterable<String> playerIds, {required int seed, required int roundNumber}) {
    final ids = playerIds.toList()..sort();
    final rng = Random(seed + roundNumber);
    return {for (final id in ids) id: rng.nextInt(1 << 30)};
  }

  /// Mexicano (logic.md §14.3, PRD 14.4): siapa main sama dengan Mixed ([priorityOrder], tanpa pemain telat), lalu
  /// yang main diurut [mexicanoOrder] dan kelompok ke-i (posisi 4i..4i+3) main di `courts[i]` dengan susunan
  /// [mexicanoArrangement]. [players] = pemain aktif, [courts] = court yang muat (urut nomor). Tanpa `Random` sama
  /// sekali: input sama → round sama (Batalkan lalu Buat, kill app, HP lain). [draw] null = [lockedDraw] dari [players].
  static EndlessRound? generateMexicanoRound({
    required List<Player> players,
    required List<Court> courts,
    required List<MatchGame> history,
    required int roundNumber,
    required int seed,
    required ScoreFormat format,
    Map<String, int>? draw,
  }) {
    final slots = slotsFor(players: players.length, courts: courts.length);
    if (slots < 4) return null;
    final lots = draw ?? lockedDraw(players.map((p) => p.id), seed: seed, roundNumber: roundNumber);
    final order = priorityOrder(
      players: players,
      history: history,
      roundNumber: roundNumber,
      seed: seed,
      slots: slots,
      draw: lots,
    );
    final ranked = mexicanoOrder(order.take(slots).toList(), history, format, lots);
    final stats = _History(history);
    return EndlessRound(
      matches: [
        for (var i = 0; i < slots ~/ 4; i++)
          if (_mexicanoArrangement(ranked.sublist(4 * i, 4 * i + 4), stats) case (final pair1, final pair2))
            MatchGame(
              id: 'm-r$roundNumber-${i + 1}',
              roundNumber: roundNumber,
              matchNumberInRound: i + 1,
              courtId: courts[i].id,
              pair1: pair1,
              pair2: pair2,
            ),
      ],
      resting: order.skip(slots).toList(),
    );
  }

  /// Urutan Mexicano (PRD 14.3): Total Point turun → selisih turun ([RankingCalculator.compare] Total Point, apa pun
  /// tab Klasemen) → [draw] naik → id. Sengaja bukan urutan [RankingCalculator.rank] (pemisah nama) atau nomor
  /// Klasemen (null untuk yang belum main): pemain belum main ikut diurut dengan 0 / 0.
  static List<Player> mexicanoOrder(
    List<Player> players,
    List<MatchGame> history,
    ScoreFormat format,
    Map<String, int> draw,
  ) {
    final standing = {
      for (final s in RankingCalculator.rank(
        players: players,
        matches: history,
        method: RankingMethod.totalGames,
        format: format,
      ))
        s.player.id: s,
    };
    return [...players]..sort((a, b) {
      final byRank = RankingCalculator.compare(standing[a.id]!, standing[b.id]!, RankingMethod.totalGames);
      if (byRank != 0) return byRank;
      // Undian wajib memuat semua pemain aktif (jebakan 1); id yang hilang = pemanggil keliru, gagal keras.
      final byDraw = draw[a.id]!.compareTo(draw[b.id]!);
      if (byDraw != 0) return byDraw;
      return a.id.compareTo(b.id);
    });
  }

  /// Susunan satu court Mexicano (PRD 14.5) dari empat pemain posisi 1–4 [ranked]: A = 1+3 vs 2+4, B = 1+4 vs 2+3,
  /// C = 1+2 vs 3+4; beban = berapa kali dua pasangannya pernah berpasangan (match `cancelled` tidak dihitung). Beban
  /// terkecil, seri → A, B, C. `pair1` = tim berisi posisi 1; di dalam tim posisi lebih kecil jadi `player1Id`.
  static (Pair, Pair) mexicanoArrangement(List<Player> ranked, List<MatchGame> history) =>
      _mexicanoArrangement(ranked, _History(history));

  static (Pair, Pair) _mexicanoArrangement(List<Player> p, _History stats) {
    assert(p.length == 4);
    final options = [(0, 2, 1, 3), (0, 3, 1, 2), (0, 1, 2, 3)];
    (Pair, Pair)? best;
    var bestLoad = 1 << 30;
    for (final (a, b, c, d) in options) {
      final load = stats.partnerCount(p[a].id, p[b].id) + stats.partnerCount(p[c].id, p[d].id);
      // `<` (bukan `<=`): seri tetap memakai susunan yang lebih dulu.
      if (load < bestLoad) {
        best = (_pairOf(p[a], p[b]), _pairOf(p[c], p[d]));
        bestLoad = load;
      }
    }
    return best!;
  }

  /// Pemain yang main di satu round: 4 per court, dibatasi jumlah pemain, selalu kelipatan 4.
  static int slotsFor({required int players, required int courts}) => (min(players, courts * 4) ~/ 4) * 4;

  /// Mixed sparing (logic.md §13.6): satu round dengan `C'` match ([ActiveTournament.sparingActiveCourts]). Tiap klub
  /// memilih `2·C'` pemain teratas [priorityOrder] **klubnya sendiri** — slot, istirahat, dan jeda pemain telat per
  /// klub dengan sendirinya — lalu match i = pasangan klub pertama ke-i vs pasangan klub kedua ke-i, jadi partner
  /// sesama klub dan `pair1` selalu klub pertama (S2–S4) tanpa perlu dicek. [resting] = klub pertama dulu.
  /// Hasilnya sama dengan prototipe yang dipakai designer untuk frame 13m/15* (seed dan [random] yang sama).
  static EndlessRound? generateSparingRound({
    required List<Player> club1,
    required List<Player> club2,
    required List<Court> courts,
    required List<MatchGame> history,
    required int roundNumber,
    required int seed,
    Set<String> latePlayerIds = const {},
    Random? random,
  }) {
    final active = ActiveTournament.sparingActiveCourts(
      courts: courts.length,
      club1: club1.length,
      club2: club2.length,
    );
    if (active == 0) return null;
    final slots = 2 * active;
    List<Player> order(List<Player> club) => priorityOrder(
      players: club,
      history: history,
      roundNumber: roundNumber,
      seed: seed,
      slots: slots,
      latePlayerIds: latePlayerIds,
    );
    final order1 = order(club1), order2 = order(club2);
    final arrangement = _bestSparingArrangement(
      order1.take(slots).toList(),
      order2.take(slots).toList(),
      _History(history),
      random ?? Random(),
    );
    return EndlessRound(
      matches: [
        for (final (i, (pair1, pair2)) in arrangement.indexed)
          MatchGame(
            id: 'm-r$roundNumber-${i + 1}',
            roundNumber: roundNumber,
            matchNumberInRound: i + 1,
            courtId: courts[i].id,
            pair1: pair1,
            pair2: pair2,
          ),
      ],
      resting: [...order1.skip(slots), ...order2.skip(slots)],
    );
  }

  /// Estimasi Mixed sparing untuk Konfigurasi (13i, 13j) dan sheet Cara kerja (15k), dari [maxRounds]
  /// (`TournamentConfig.maxRounds`), jumlah court, dan pemain per klub: Court Aktif = C' dari semua court, Total Match
  /// = round × C', Match/Pemain per klub = ⌊Total Match × 2 ÷ pemain klub⌋ (ditulis "±").
  static ({int rounds, int activeCourts, int matches, int perPlayer1, int perPlayer2}) sparingEstimate({
    required int maxRounds,
    required int courts,
    required int club1,
    required int club2,
  }) {
    final active = ActiveTournament.sparingActiveCourts(courts: courts, club1: club1, club2: club2);
    final matches = maxRounds * active;
    return (
      rounds: maxRounds,
      activeCourts: active,
      matches: matches,
      perPlayer1: club1 == 0 ? 0 : matches * 2 ~/ club1,
      perPlayer2: club2 == 0 ? 0 : matches * 2 ~/ club2,
    );
  }

  /// Urutan prioritas main di round [roundNumber] yang memakai [slots] pemain: paling sedikit main, lalu paling
  /// lama istirahat, lalu undian. Undiannya dikunci per round — `Random(seed + roundNumber)` dibagikan
  /// ke pemain urut id — jadi daftar "Prioritas main di R…" yang tampil sebelum tombol Buat ditekan
  /// selalu sama dengan hasil Buat. Kunci terakhir id pemain, karena `List.sort` Dart tidak stabil.
  ///
  /// Pemain di [latePlayerIds] (masuk telat, kembali setelah keluar) yang jumlah mainnya masih di bawah yang paling
  /// banyak main dengan sendirinya di atas, tapi setelah main k round berturut-turut dia istirahat satu round
  /// (keputusan host 2026-10-25). k = 2, atau satu lebih dari rata-rata main beruntun pemain lain (slot ÷ yang
  /// istirahat) kalau 2 belum lebih sering dari mereka: 12 pemain / 2 court → 3. Main k dari k + 1 round selalu lebih
  /// sering dari bagian pemain lain, jadi dia menyusul tanpa main terus. Pemain yang hadir sejak awal tidak kena jeda:
  /// undian seri kadang memberi mereka k round beruntun, dan memotongnya bisa membuat selisih main jadi 2.
  ///
  /// [draw] = undian yang sudah dihitung ([lockedDraw]); null = undian dari [players] sendiri. Test menyuntiknya.
  static List<Player> priorityOrder({
    required List<Player> players,
    required List<MatchGame> history,
    required int roundNumber,
    required int seed,
    required int slots,
    Set<String> latePlayerIds = const {},
    Map<String, int>? draw,
  }) {
    final stats = _History(history);
    final lots = draw ?? lockedDraw(players.map((p) => p.id), seed: seed, roundNumber: roundNumber);

    final order = [...players]..sort((a, b) {
      final byMatches = stats.matchCount(a.id).compareTo(stats.matchCount(b.id));
      if (byMatches != 0) return byMatches;
      final byRest = stats.lastRound(a.id).compareTo(stats.lastRound(b.id));
      if (byRest != 0) return byRest;
      final byDraw = lots[a.id]!.compareTo(lots[b.id]!);
      if (byDraw != 0) return byDraw;
      return a.id.compareTo(b.id);
    });
    final resting = players.length - slots;
    if (resting <= 0) return order;

    final run = max(_catchUpRun, slots ~/ resting + 1);
    final top = players.map((p) => stats.matchCount(p.id)).reduce(max);
    bool due(Player p) =>
        latePlayerIds.contains(p.id) && stats.matchCount(p.id) < top && stats.runBefore(p.id, roundNumber) >= run;
    return [...order.where((p) => !due(p)), ...order.where(due)];
  }

  /// Slot R(n+1) pada [now]: 4 × court yang masih muat satu match. Kalau tidak ada (waktu habis, 06l), dari semua
  /// court — round berikutnya baru ada setelah Lanjutkan turnamen.
  static int _nextRoundSlots(ActiveTournament active, DateTime now) =>
      slotsFor(players: active.activePlayers.length, courts: _nextRoundCourts(active, now));

  /// Jumlah court R(n+1) pada [now]: yang muat satu match, atau semua court kalau tidak ada (waktu habis, 06l).
  static int _nextRoundCourts(ActiveTournament active, DateTime now) {
    final courts = active.courtsAvailableAt(now);
    return courts.isEmpty ? active.config.courts.length : courts.length;
  }

  /// Sparing: slot **per klub** R(n+1) pada [now] = 2 × C' dari [_nextRoundCourts]. Sama persis dengan yang dipakai
  /// [generateSparingRound] saat Buat pada [now].
  static int _nextRoundClubSlots(ActiveTournament active, DateTime now) {
    final (club1, club2) = active.activePlayersByClub;
    return 2 *
        ActiveTournament.sparingActiveCourts(
          courts: _nextRoundCourts(active, now),
          club1: club1.length,
          club2: club2.length,
        );
  }

  /// Sparing: slot per klub dan urutan prioritas R(n+1) tiap klub — panggilan yang sama persis dengan Buat R(n+1)
  /// pada [now] (AC-S11).
  static ({int slots, List<Player> club1, List<Player> club2}) _nextRoundClubOrders(
    ActiveTournament active,
    DateTime now,
  ) {
    final slots = _nextRoundClubSlots(active, now);
    final (club1, club2) = active.activePlayersByClub;
    List<Player> order(List<Player> club) => priorityOrder(
      players: club,
      history: active.matches,
      roundNumber: active.roundCount + 1,
      seed: active.drawSeed,
      slots: slots,
      latePlayerIds: active.latePlayerIds,
    );
    return (slots: slots, club1: order(club1), club2: order(club2));
  }

  static Set<String> _playingInRound(ActiveTournament active, int round) => {
    for (final m in active.matchesOfRound(round)) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
  };

  /// Mixed sparing: [restingAfterLastRound] per klub (klub pertama dulu) — daftar "Istirahat · Prioritas main di
  /// R(n+1)" / "Istirahat lagi" dipisah per klub, dari [priorityOrder] klub itu dengan slot klubnya, jadi sama persis
  /// dengan hasil Buat R(n+1) pada [now] (AC-S11). Kosong di turnamen biasa.
  static List<({Club club, List<Player> priority, List<Player> later})> restingByClubAfterLastRound(
    ActiveTournament active,
    DateTime now,
  ) {
    final clubs = active.config.clubs;
    if (clubs == null) return const [];
    final playing = _playingInRound(active, active.roundCount);
    final next = _nextRoundClubOrders(active, now);
    ({Club club, List<Player> priority, List<Player> later}) split(Club club, List<Player> order) {
      final chosen = order.take(next.slots).map((p) => p.id).toSet();
      final resting = active.activePlayersOfClub(club.id).where((p) => !playing.contains(p.id));
      return (
        club: club,
        priority: resting.where((p) => chosen.contains(p.id)).toList(),
        later: resting.where((p) => !chosen.contains(p.id)).toList(),
      );
    }

    return [split(clubs[0], next.club1), split(clubs[1], next.club2)];
  }

  /// Baris Istirahat di tab round terakhir n (06f–06o): pemain aktif **sekarang** yang tidak main di
  /// round n, urut seperti daftar pemain. [priority] = yang pasti kebagian slot R(n+1) menurut
  /// [priorityOrder] (sama persis dengan hasil Buat pada [now]); [later] = yang istirahat lagi. Kalau tidak
  /// ada court yang muat R(n+1) (waktu habis, 06l), slot dihitung dari semua court — round berikutnya baru
  /// ada setelah Lanjutkan turnamen, dan yang istirahat tetap diprioritaskan di sana.
  ///
  /// Sparing: gabungan [restingByClubAfterLastRound]; layar sparing memakai yang per klub.
  static ({List<Player> priority, List<Player> later}) restingAfterLastRound(ActiveTournament active, DateTime now) {
    final n = active.roundCount;
    final playing = _playingInRound(active, n);
    final resting = [
      for (final p in active.activePlayers)
        if (!playing.contains(p.id)) p,
    ];
    if (resting.isEmpty) return (priority: const [], later: const []);

    final Set<String> next;
    if (active.config.isSparing) {
      // Sparing: gabungan daftar per klub (urut daftar pemain), supaya pemanggil lama tetap benar.
      next = {
        for (final club in restingByClubAfterLastRound(active, now))
          for (final p in club.priority) p.id,
      };
    } else {
      final slots = _nextRoundSlots(active, now);
      next = priorityOrder(
        players: active.activePlayers,
        history: active.matches,
        roundNumber: n + 1,
        seed: active.drawSeed,
        slots: slots,
        latePlayerIds: active.latePlayerIds,
      ).take(slots).map((p) => p.id).toSet();
    }

    return (
      priority: [
        for (final p in resting)
          if (next.contains(p.id)) p,
      ],
      later: [
        for (final p in resting)
          if (!next.contains(p.id)) p,
      ],
    );
  }

  /// Apa yang terjadi dengan court [courtId] di [active] (sudah berisi court baru atau jam yang diubah) pada [now]
  /// — Kelola court & detail court, logic.md §10:
  /// - [CourtUse.now]: round terakhir masih berjalan, court belum punya match di round itu, sisanya muat satu match,
  ///   dan yang istirahat minimal 4 → satu match baru untuk [players] (4 teratas urutan prioritas R(n+1) di antara
  ///   yang istirahat, persis daftar "Prioritas main di R…" kalau slotnya 4).
  /// - [CourtUse.nextRound]: court menambah slot round berikutnya.
  /// - [CourtUse.unused]: pemain tidak cukup untuk court ini, atau sisanya tidak muat satu match.
  ///
  /// [wasAvailable] = court lama yang sebelum diubah sudah muat satu match: mengganti nama atau menambah jamnya tidak
  /// boleh tiba-tiba membuat match di round yang sedang berjalan.
  ///
  /// Sparing: aturan per klub di [_sparingCourtUse]; [players] = 2 pemain klub pertama lalu 2 klub kedua.
  static ({CourtUse use, List<Player> players}) courtUse(
    ActiveTournament active,
    String courtId,
    DateTime now, {
    bool wasAvailable = false,
  }) {
    final court = active.config.courts.firstWhere((c) => c.id == courtId);
    final fits = active.remainingBookingMinutes(court, now) >= active.config.matchDurationMinutes;
    final n = active.roundCount;
    final running = n > 0 && !active.tournament.isFinished && !active.isRoundComplete(n);
    if (active.config.isSparing) {
      return _sparingCourtUse(active, courtId, now, fits: fits, startsNow: running && !wasAvailable);
    }
    if (fits && running && !wasAvailable && !active.matchesOfRound(n).any((m) => m.courtId == courtId)) {
      final playing = _playingInRound(active, n);
      final waiting = priorityOrder(
        players: active.activePlayers,
        history: active.matches,
        roundNumber: n + 1,
        seed: active.drawSeed,
        slots: _nextRoundSlots(active, now),
        latePlayerIds: active.latePlayerIds,
      ).where((p) => !playing.contains(p.id)).toList();
      if (waiting.length >= 4) return (use: CourtUse.now, players: waiting.take(4).toList());
    }
    final available = active.courtsAvailableAt(now);
    final players = active.activePlayers.length;
    final adds =
        fits &&
        slotsFor(players: players, courts: available.length) >
            slotsFor(players: players, courts: available.where((c) => c.id != courtId).length);
    return (use: adds ? CourtUse.nextRound : CourtUse.unused, players: const []);
  }

  /// [courtUse] sparing (logic.md §13.6): langsung main kalau [startsNow] (round berjalan, court belum muat sebelumnya),
  /// court muat, belum punya match di round itu, dan **tiap klub** punya ≥ 2 yang istirahat — pemainnya 2 teratas
  /// prioritas R(n+1) tiap klub di antara yang istirahat, dengan slot klub dari C' round berikutnya (court ini ikut).
  /// Round berikutnya kalau C' dengan court ini lebih besar dari tanpa court ini.
  static ({CourtUse use, List<Player> players}) _sparingCourtUse(
    ActiveTournament active,
    String courtId,
    DateTime now, {
    required bool fits,
    required bool startsNow,
  }) {
    final n = active.roundCount;
    if (fits && startsNow && !active.matchesOfRound(n).any((m) => m.courtId == courtId)) {
      final playing = _playingInRound(active, n);
      final next = _nextRoundClubOrders(active, now);
      final waiting1 = next.club1.where((p) => !playing.contains(p.id)).toList();
      final waiting2 = next.club2.where((p) => !playing.contains(p.id)).toList();
      if (waiting1.length >= 2 && waiting2.length >= 2) {
        return (use: CourtUse.now, players: [...waiting1.take(2), ...waiting2.take(2)]);
      }
    }
    final available = active.courtsAvailableAt(now);
    final (club1, club2) = active.activePlayersByClub;
    int activeWith(int courts) =>
        ActiveTournament.sparingActiveCourts(courts: courts, club1: club1.length, club2: club2.length);
    final adds = fits && activeWith(available.length) > activeWith(available.where((c) => c.id != courtId).length);
    return (use: adds ? CourtUse.nextRound : CourtUse.unused, players: const []);
  }

  /// Match tambahan di round terakhir untuk court [courtId] (hasil [CourtUse.now]): pasangan disusun dengan penalti
  /// yang sama dengan [generateRound], nomornya melanjutkan match terakhir di round itu.
  ///
  /// Sparing: [players] = 2 pemain klub pertama lalu 2 klub kedua ([courtUse]); pasangan sesama klub, `pair1` klub
  /// pertama.
  ///
  /// Mexicano: pemainnya tetap dari [courtUse]; susunannya [mexicanoArrangement] dari [mexicanoOrder] keempatnya.
  static MatchGame courtMatch(ActiveTournament active, String courtId, List<Player> players, {Random? random}) {
    assert(players.length == 4);
    final n = active.roundCount;
    assert(
      !active.config.isSparing ||
          (players.take(2).every((p) => p.clubId == active.config.clubs![0].id) &&
              players.skip(2).every((p) => p.clubId == active.config.clubs![1].id)),
      'Sparing: 2 pemain klub pertama lalu 2 klub kedua (S2, S4).',
    );
    final (pair1, pair2) = switch (active.config) {
      // Mexicano: tanpa `Random` (AC-M12, M14). Urutan dari skor yang sudah masuk termasuk round n, undian round n
      // (round tempat match ini dibuat; logic.md §14.3, asumsi tech-lead).
      TournamentConfig(mode: PartnerMode.mexicano) => _mexicanoArrangement(
        mexicanoOrder(
          players,
          active.matches,
          active.config.format,
          lockedDraw(active.activePlayers.map((p) => p.id), seed: active.drawSeed, roundNumber: n),
        ),
        _History(active.matches),
      ),
      TournamentConfig(isSparing: true) => _bestSparingArrangement(
        players.sublist(0, 2),
        players.sublist(2),
        _History(active.matches),
        random ?? Random(),
      ).single,
      _ => _bestArrangement(players, _History(active.matches), random ?? Random()).single,
    };
    final number = active.matchesOfRound(n).fold(0, (top, m) => max(top, m.matchNumberInRound)) + 1;
    return MatchGame(
      id: 'm-r$n-$number',
      roundNumber: n,
      matchNumberInRound: number,
      courtId: courtId,
      pair1: pair1,
      pair2: pair2,
    );
  }

  /// Coba beberapa susunan acak, ambil yang penaltinya paling kecil.
  static List<(Pair, Pair)> _bestArrangement(List<Player> active, _History stats, Random rng) {
    List<(Pair, Pair)>? best;
    var bestPenalty = 1 << 30;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final shuffled = [...active]..shuffle(rng);
      final candidate = <(Pair, Pair)>[];
      for (var i = 0; i < shuffled.length; i += 4) {
        candidate.add((_pairOf(shuffled[i], shuffled[i + 1]), _pairOf(shuffled[i + 2], shuffled[i + 3])));
      }

      final penalty = _penalty(candidate, stats);
      if (penalty < bestPenalty) {
        best = candidate;
        bestPenalty = penalty;
        if (penalty == 0) break;
      }
    }

    return best!;
  }

  /// Sparing: acak tiap klub terpisah (klub pertama dulu, urutan pemakaian [rng] sama dengan prototipe designer),
  /// match i = (klub1[2i], klub1[2i+1]) vs (klub2[2i], klub2[2i+1]); penalti sama dengan [_bestArrangement].
  static List<(Pair, Pair)> _bestSparingArrangement(
    List<Player> club1,
    List<Player> club2,
    _History stats,
    Random rng,
  ) {
    List<(Pair, Pair)>? best;
    var bestPenalty = 1 << 30;

    for (var attempt = 0; attempt < _maxAttempts; attempt++) {
      final shuffled1 = [...club1]..shuffle(rng);
      final shuffled2 = [...club2]..shuffle(rng);
      final candidate = [
        for (var i = 0; i < shuffled1.length; i += 2)
          (_pairOf(shuffled1[i], shuffled1[i + 1]), _pairOf(shuffled2[i], shuffled2[i + 1])),
      ];

      final penalty = _penalty(candidate, stats);
      if (penalty < bestPenalty) {
        best = candidate;
        bestPenalty = penalty;
        if (penalty == 0) break;
      }
    }

    return best!;
  }

  static int _penalty(List<(Pair, Pair)> arrangement, _History stats) {
    var total = 0;
    for (final (p1, p2) in arrangement) {
      total += stats.partnerCount(p1.player1Id, p1.player2Id) * _repeatPartnerPenalty;
      total += stats.partnerCount(p2.player1Id, p2.player2Id) * _repeatPartnerPenalty;
      for (final a in p1.playerIds) {
        for (final b in p2.playerIds) {
          total += stats.opponentCount(a, b) * _repeatOpponentPenalty;
        }
      }
      if (stats.hasPlayedMatchup(p1, p2)) total += _repeatMatchPenalty;
    }
    return total;
  }

  static Pair _pairOf(Player a, Player b) => Pair(id: _pairKey(a.id, b.id), player1Id: a.id, player2Id: b.id);

  /// Id pasangan Mixed dari dua pemainnya (urutan argumen tidak berpengaruh); dipakai tukar pemain untuk menghitung
  /// ulang id pasangan yang berubah dengan kunci yang sama persis seperti generator.
  static String pairId(String a, String b) => _pairKey(a, b);

  static String _pairKey(String a, String b) => (a.compareTo(b) <= 0) ? '$a+$b' : '$b+$a';
}

/// Rekap history pertandingan yang sudah terjadi.
class _History {
  final Map<String, int> _matchCount = {};
  final Map<String, int> _lastRound = {};
  final Map<String, Set<int>> _rounds = {};
  final Map<String, int> _partner = {};
  final Map<String, int> _opponent = {};
  final Set<String> _matchups = {};

  _History(List<MatchGame> history) {
    for (final m in history) {
      if (m.status == MatchStatus.cancelled) continue;

      for (final pair in [m.pair1, m.pair2]) {
        _bump(_partner, EndlessRoundGenerator._pairKey(pair.player1Id, pair.player2Id));
        for (final id in pair.playerIds) {
          _matchCount[id] = (_matchCount[id] ?? 0) + 1;
          _lastRound[id] = m.roundNumber;
          _rounds.putIfAbsent(id, () => {}).add(m.roundNumber);
        }
      }
      for (final a in m.pair1.playerIds) {
        for (final b in m.pair2.playerIds) {
          _bump(_opponent, EndlessRoundGenerator._pairKey(a, b));
        }
      }
      _matchups.add(_matchupKey(m.pair1, m.pair2));
    }
  }

  static void _bump(Map<String, int> map, String key) => map[key] = (map[key] ?? 0) + 1;

  static String _matchupKey(Pair a, Pair b) {
    final keys = [
      EndlessRoundGenerator._pairKey(a.player1Id, a.player2Id),
      EndlessRoundGenerator._pairKey(b.player1Id, b.player2Id),
    ]..sort();
    return keys.join('|');
  }

  int matchCount(String playerId) => _matchCount[playerId] ?? 0;
  int lastRound(String playerId) => _lastRound[playerId] ?? 0;

  /// Jumlah round berturut-turut tepat sebelum [round] yang ada match [playerId]-nya.
  int runBefore(String playerId, int round) {
    final rounds = _rounds[playerId] ?? const <int>{};
    var run = 0;
    while (rounds.contains(round - 1 - run)) {
      run++;
    }
    return run;
  }

  int partnerCount(String a, String b) => _partner[EndlessRoundGenerator._pairKey(a, b)] ?? 0;
  int opponentCount(String a, String b) => _opponent[EndlessRoundGenerator._pairKey(a, b)] ?? 0;
  bool hasPlayedMatchup(Pair a, Pair b) => _matchups.contains(_matchupKey(a, b));
}
