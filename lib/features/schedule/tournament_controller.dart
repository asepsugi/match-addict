import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

import '../../models/models.dart';
import '../../services/pairing/player_name_parser.dart';
import '../../services/ranking/ranking_calculator.dart';
import '../../services/schedule/endless_round_generator.dart';
import '../../services/schedule/round_robin_generator.dart';
import '../../services/storage/tournament_store.dart';

/// Penyimpanan turnamen di device. Di-override di `main()` dengan box Hive yang
/// sudah dibuka; default-nya memori saja supaya test tidak perlu plugin.
final tournamentStoreProvider = Provider<TournamentStore>((ref) => TournamentStore.memory());

/// Jam sekarang. Di-override test supaya teks yang bergantung jam ("45m dari 2 jam") sama dengan frame.
final clockProvider = Provider<DateTime Function()>((ref) => DateTime.now);

/// Sumber kebenaran tunggal untuk turnamen yang sedang jalan.
class TournamentController extends Notifier<ActiveTournament?> {
  TournamentStore get _store => ref.read(tournamentStoreProvider);

  /// Config yang dipakai memulai turnamen di sesi ini (lihat [startIfNeeded]).
  TournamentConfig? _startedFrom;

  @override
  ActiveTournament? build() {
    // Auto-save lewat satu listener: semua mutasi di controller ini berakhir di
    // `state =`, jadi tidak ada call site yang bisa lupa menyimpan.
    listenSelf((_, next) {
      if (next != null) unawaited(_store.saveActive(next));
    });
    // Resume: kalau app sebelumnya di-kill, turnamennya kembali dari sini.
    return _store.loadActive();
  }

  /// Mulai turnamen baru dari [config]. Tidak melakukan apa-apa kalau turnamen
  /// dengan config yang sama sudah jalan (mis. screen di-rebuild).
  void startIfNeeded(TournamentConfig config) {
    // Dua-duanya perlu: config di state berganti kalau host menambah pemain,
    // sementara layar Konfigurasi di belakangnya masih memegang config awal.
    if (state != null && (identical(state!.config, config) || identical(_startedFrom, config))) {
      return;
    }
    _startedFrom = config;

    final schedule = config.mode == PartnerMode.fixed
        ? RoundRobinGenerator.generate(pairs: config.fixedPairs ?? const [], courts: config.courts)
        : const FixedSchedule(matches: [], byePairIdByRound: {});

    state = ActiveTournament(
      tournament: Tournament(
        id: const Uuid().v4(),
        createdAt: ref.read(clockProvider)(),
        config: config,
        matches: schedule.matches,
      ),
      byePairIdByRound: schedule.byePairIdByRound,
    );

    // Mode Mixed tidak punya jadwal di awal — round 1 langsung digenerate.
    if (config.mode == PartnerMode.mixed) generateNextRound();
  }

  /// Mode Mixed: buat round berikutnya dari history yang sudah ada.
  void generateNextRound() {
    final current = state;
    final now = ref.read(clockProvider)();
    if (current == null || !current.canGenerateNextRound(now)) return;

    final roundNumber = current.roundCount + 1;
    final round = EndlessRoundGenerator.generateRound(
      players: current.activePlayers,
      courts: current.courtsAvailableAt(now),
      history: current.matches,
      roundNumber: roundNumber,
      seed: current.drawSeed,
      latePlayerIds: current.latePlayerIds,
    );
    if (round == null) return;

    state = current.copyWith(
      tournament: current.tournament.copyWith(matches: [...current.matches, ...round.matches]),
      resting: {...current.restingPlayerIdsByRound, roundNumber: round.resting.map((p) => p.id).toList()},
    );
  }

  /// Mode Mixed: hapus round terakhir yang belum ada skornya. Host lalu
  /// menekan "Buat R…" lagi dengan peserta terbaru (mis. pemain baru datang).
  void cancelLastRound() {
    final current = state;
    if (current == null || !current.canCancelLastRound) return;

    final round = current.roundCount;
    state = current.copyWith(
      tournament: current.tournament.copyWith(
        matches: [
          for (final m in current.matches)
            if (m.roundNumber != round) m,
        ],
      ),
      resting: {...current.restingPlayerIdsByRound}..remove(round),
    );
  }

  /// Mode Mixed: tambah pemain di tengah turnamen, ikut mulai round berikutnya.
  /// Mengembalikan pesan error untuk ditampilkan, atau null kalau berhasil.
  String? addPlayer(String rawName) {
    final current = state;
    if (current == null || current.config.mode != PartnerMode.mixed) return null;

    final name = PlayerNameParser.parse(rawName).names.firstOrNull;
    if (name == null) return 'Nama tidak boleh kosong';
    final taken = current.config.players.where((p) => p.name.toLowerCase() == name.toLowerCase());
    if (taken.isNotEmpty) {
      // Nama yang tertulis di daftar, bukan ketikan host ("andi p" → "Andi P sudah ada").
      final existing = taken.first;
      return current.withdrawnPlayerIds.contains(existing.id)
          ? '${existing.name} sudah ada — pakai "Kembalikan" di bawah'
          : '${existing.name} sudah ada di daftar';
    }
    const limit = TournamentConfig.maxPlayers;
    if (current.activePlayers.length >= limit) return 'Maksimal $limit pemain aktif';

    final player = Player(id: const Uuid().v4(), name: name);
    state = current.copyWith(
      tournament: current.tournament.copyWith(
        config: current.config.copyWith(players: [...current.config.players, player]),
      ),
    );
    return null;
  }

  /// Mode Mixed: pemain keluar (cedera, pulang duluan). Berlaku mulai round
  /// berikutnya — match yang sudah terjadwal tetap ada, host bisa menandainya WO.
  /// Mengembalikan false kalau sisa pemain aktif tidak cukup untuk satu match.
  bool withdrawPlayer(String playerId) {
    final current = state;
    if (current == null || current.activePlayers.length <= TournamentConfig.minPlayers) return false;
    state = current.copyWith(withdrawn: {...current.withdrawnPlayerIds, playerId});
    return true;
  }

  /// Kebalikan [withdrawPlayer]; kalau tertinggal, dia menyusul seperti pemain baru
  /// (`EndlessRoundGenerator.priorityOrder`).
  String? reinstatePlayer(String playerId) {
    final current = state;
    if (current == null || !current.withdrawnPlayerIds.contains(playerId)) return null;
    const limit = TournamentConfig.maxPlayers;
    if (current.activePlayers.length >= limit) return 'Maksimal $limit pemain aktif';
    state = current.copyWith(withdrawn: {...current.withdrawnPlayerIds}..remove(playerId));
    return null;
  }

  /// Mixed: tambah court di tengah turnamen (Kelola court, 08e–08g). Booking-nya mulai sekarang; court langsung
  /// dipakai kalau round terakhir masih berjalan dan cukup yang istirahat (logic.md §10).
  void addCourt({required String name, required int colorIndex, required int bookingMinutes}) {
    final current = state;
    final courts = current?.config.courts ?? const <Court>[];
    if (current == null || !current.canManageCourts || courts.length >= TournamentConfig.maxCourts) return;
    final now = ref.read(clockProvider)();
    final court = current.newCourt(
      id: const Uuid().v4(),
      name: name,
      colorIndex: colorIndex,
      bookingMinutes: bookingMinutes,
      now: now,
    );
    _placeCourt(current.withCourt(court), court.id, now);
  }

  /// Detail court (08h–08k, tombol Simpan): [court] menggantikan court ber-id sama. Court yang sebelumnya tidak muat
  /// satu match lalu jadi muat saat round berjalan (dipesan ulang) langsung dipakai, sama dengan court baru.
  void updateCourt(Court court) {
    final current = state;
    if (current == null || !current.canManageCourts) return;
    final now = ref.read(clockProvider)();
    final before = current.courtById(court.id);
    final wasAvailable = current.remainingBookingMinutes(before, now) >= current.config.matchDurationMinutes;
    _placeCourt(current.withCourt(court), court.id, now, wasAvailable: wasAvailable);
  }

  /// Hapus court (08h): match yang belum dimainkan di court itu ikut dihapus dan pemainnya kembali istirahat.
  bool removeCourt(String courtId) {
    final current = state;
    if (current == null || !current.canRemoveCourt(courtId)) return false;
    final n = current.roundCount;
    final removed = [
      for (final m in current.matches)
        if (m.courtId == courtId) m,
    ];
    final freed = [
      for (final m in removed) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
    ];
    final next = _withCourts(current, [
      for (final c in current.config.courts)
        if (c.id != courtId) c,
    ]);
    state = next.copyWith(
      tournament: next.tournament.copyWith(
        matches: [
          for (final m in next.matches)
            if (m.courtId != courtId) m,
        ],
      ),
      resting: freed.isEmpty
          ? null
          : {
              ...next.restingPlayerIdsByRound,
              n: [...?next.restingPlayerIdsByRound[n], ...freed],
            },
    );
    return true;
  }

  static ActiveTournament _withCourts(ActiveTournament active, List<Court> courts) => active.copyWith(
    tournament: active.tournament.copyWith(config: active.config.copyWith(courts: courts)),
  );

  void _placeCourt(ActiveTournament next, String courtId, DateTime now, {bool wasAvailable = false}) {
    final use = EndlessRoundGenerator.courtUse(next, courtId, now, wasAvailable: wasAvailable);
    if (use.use != CourtUse.now) {
      state = next;
      return;
    }
    final match = EndlessRoundGenerator.courtMatch(next, courtId, use.players);
    final n = next.roundCount;
    final playing = {for (final p in use.players) p.id};
    state = next.copyWith(
      tournament: next.tournament.copyWith(matches: [...next.matches, match]),
      resting: {
        ...next.restingPlayerIdsByRound,
        n: [
          for (final id in next.restingPlayerIdsByRound[n] ?? const <String>[])
            if (!playing.contains(id)) id,
        ],
      },
    );
  }

  void _update(Tournament Function(Tournament) change) {
    final current = state;
    if (current == null) return;
    state = current.copyWith(tournament: change(current.tournament));
  }

  void submitScore(String matchId, List<SetScore> sets) => _updateMatch(matchId, (m) => m.withScore(sets));

  /// [reason] null menghapus alasan lama (alasan yang dilepas di sheet WO benar-benar hilang).
  void markWalkover(String matchId, {required String loserPairId, WoReason? reason}) =>
      _updateMatch(matchId, (m) => m.asWalkover(loserPairId: loserPairId, reason: reason));

  void _updateMatch(String matchId, MatchGame Function(MatchGame) change) => _update(
    (t) => t.copyWith(
      matches: [
        for (final m in t.matches)
          if (m.id == matchId) change(m) else m,
      ],
    ),
  );

  /// Tutup turnamen aktif dan kembali ke keadaan awal. Hasilnya tidak dihapus,
  /// hanya pindah ke slot "turnamen terakhir selesai".
  /// Future-nya dikembalikan supaya test bisa menunggu tulisan ke device
  /// selesai; UI cukup memanggil dan langsung pindah layar.
  Future<void> close() async {
    final current = state;
    state = null;
    if (current == null) return;
    // Diset langsung, tidak menunggu tulisan ke device, supaya Beranda yang
    // dibuka sesudahnya sudah menampilkan kartu "Turnamen terakhir".
    ref.read(lastFinishedProvider.notifier).state = current;
    await _store.archiveActive(current);
  }

  /// Mode Mixed: lanjutkan turnamen yang sudah diakhiri / kehabisan waktu,
  /// tanpa mengulang. [from] diisi kalau turnamennya sudah ditutup (slot
  /// "turnamen terakhir"); kosong berarti turnamen aktif.
  ///
  /// [extraMinutes] per court id dihitung dari sekarang kalau booking-nya sudah
  /// lewat, bukan ditambahkan ke booking awal: court yang waktunya sudah lama
  /// habis tetap dapat jam penuh. Match yang dibatalkan saat "Akhiri" kembali menunggu skor.
  void resume(Map<String, int> extraMinutes, {ActiveTournament? from}) {
    final current = from ?? state;
    if (current == null || current.config.mode != PartnerMode.mixed) return;
    // Turnamen yang sudah ditutup selalu boleh dibuka lagi, meski waktunya
    // masih ada (host bisa menekan "Selesai" tanpa "Akhiri" dulu).
    final now = ref.read(clockProvider)();
    if (from == null && !current.canResume(now)) return;

    final courts = [
      for (final c in current.config.courts)
        if ((extraMinutes[c.id] ?? 0) > 0) current.extendedBy(c, extraMinutes[c.id]!, now) else c,
    ];

    state = current.copyWith(
      tournament: current.tournament.copyWith(
        isFinished: false,
        config: current.config.copyWith(courts: courts),
        matches: [
          for (final m in current.matches)
            if (m.status == MatchStatus.cancelled) m.copyWith(status: MatchStatus.pending) else m,
        ],
      ),
    );
  }

  /// Hentikan turnamen: match yang belum dimainkan ditandai "tidak dimainkan"
  /// supaya tidak ikut hitungan ranking.
  void finishNow() {
    _update(
      (t) => t.copyWith(
        isFinished: true,
        matches: [
          for (final m in t.matches)
            if (m.status == MatchStatus.pending) m.copyWith(status: MatchStatus.cancelled) else m,
        ],
      ),
    );
  }
}

/// Turnamen terakhir yang sudah ditutup (tombol "Selesai" di layar Bagikan).
/// Mode Mixed bisa dilanjutkan dari kartu di Beranda.
final lastFinishedProvider = StateProvider<ActiveTournament?>(
  (ref) => ref.read(tournamentStoreProvider).loadLastFinished(),
);

final tournamentProvider = NotifierProvider<TournamentController, ActiveTournament?>(TournamentController.new);

/// Metode peringkat yang sedang dipilih host di layar Peringkat. Dipakai
/// bersama layar Detail Pemain dan Share supaya urutannya tidak berbeda-beda.
final rankingMethodProvider = StateProvider<RankingMethod>((ref) => RankingMethod.totalGames);

/// Baris peringkat siap tampil: per pemain di mode Mixed, per pasangan di mode
/// Fixed. Dibaca layar Peringkat, Detail Pemain, dan Share supaya nomor urut
/// yang sama muncul di ketiganya.
final standingEntriesProvider = Provider<List<StandingEntry>>((ref) {
  final active = ref.watch(tournamentProvider);
  if (active == null) return const [];
  return standingEntries(
    standings: ref.watch(standingsProvider),
    method: ref.watch(rankingMethodProvider),
    fixedPairs: active.config.mode == PartnerMode.fixed ? active.config.fixedPairs : null,
  );
});

/// Klasemen turnamen aktif menurut [rankingMethodProvider].
final standingsProvider = Provider<List<PlayerStanding>>((ref) {
  final active = ref.watch(tournamentProvider);
  if (active == null) return const [];
  return RankingCalculator.rank(
    players: active.config.players,
    matches: active.matches,
    method: ref.watch(rankingMethodProvider),
    format: active.config.format,
  );
});
