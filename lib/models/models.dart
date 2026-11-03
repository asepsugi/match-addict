import 'dart:math';

import 'package:flutter/foundation.dart';

/// Jenis permainan.
enum SportType { tennis, padel }

extension SportTypeX on SportType {
  String get label => switch (this) {
    SportType.tennis => 'Tennis',
    SportType.padel => 'Padel',
  };

  /// Default durasi per match (menit).
  int get defaultMatchDurationMinutes => switch (this) {
    SportType.tennis => 20,
    SportType.padel => 15,
  };

  String get assetPath => switch (this) {
    SportType.tennis => 'assets/images/racket_tennis.png',
    SportType.padel => 'assets/images/racket_padel.png',
  };
}

enum PartnerMode { fixed, mixed }

extension PartnerModeX on PartnerMode {
  String get label => switch (this) {
    PartnerMode.fixed => 'Fixed',
    PartnerMode.mixed => 'Mixed',
  };

  String get assetPath => switch (this) {
    PartnerMode.fixed => 'assets/images/mode_fixed.png',
    PartnerMode.mixed => 'assets/images/mode_mixed.png',
  };
}

/// Format skor satu match, dipilih host di Konfigurasi (`design/spec/logic.md` §1).
enum ScoringMethod {
  /// Siapa duluan menang N game, match langsung selesai. Sah: N lawan 0..N−1. Tidak pernah seri.
  raceTo,

  /// Paling banyak N game; boleh berhenti begitu satu tim pasti menang ([ScoreFormat.minWinningScore]). Seri kalau
  /// N genap dan skornya sama dengan total penuh.
  bestOf,

  /// Poin reli, paling banyak N poin per match, boleh berhenti lebih awal seperti Best of; seri kalau N genap.
  americano,
}

extension ScoringMethodX on ScoringMethod {
  /// Urutan segmented control di Konfigurasi.
  static const selectable = ScoringMethod.values;

  String get label => switch (this) {
    ScoringMethod.raceTo => 'Race to',
    ScoringMethod.bestOf => 'Best of',
    ScoringMethod.americano => 'Americano',
  };

  /// Satuan skor: "game" atau "poin".
  String get unit => this == ScoringMethod.americano ? 'poin' : 'game';

  /// Batas N yang boleh dipilih. Americano dibatasi kotak skor 2 digit.
  int get minTarget => switch (this) {
    ScoringMethod.raceTo => 2,
    ScoringMethod.bestOf => 1,
    ScoringMethod.americano => 2,
  };

  int get maxTarget => switch (this) {
    ScoringMethod.raceTo => 9,
    ScoringMethod.bestOf => 15,
    ScoringMethod.americano => 99,
  };

  int get defaultTarget => switch (this) {
    ScoringMethod.raceTo => 6,
    ScoringMethod.bestOf => 5,
    ScoringMethod.americano => 21,
  };

  /// N yang diketik dikembalikan ke batas terdekat (stepper memang tidak bisa keluar batas).
  int clampTarget(int target) => target.clamp(minTarget, maxTarget);
}

/// Format skor turnamen: metode + N. Semua format disimpan sebagai satu [SetScore] per match, jadi ranking, share, dan codec tidak perlu bercabang per format.
@immutable
class ScoreFormat {
  final ScoringMethod method;

  /// N: target game (Race to), jumlah game (Best of), atau total poin (Americano).
  final int target;

  const ScoreFormat(this.method, this.target);

  /// Default kedua olahraga.
  static const standard = ScoreFormat(ScoringMethod.raceTo, 6);

  /// "Race to 6", "Best of 5", "Americano 21".
  String get label => '${method.label} $target';

  String get unit => method.unit;

  bool get isValid => target >= method.minTarget && target <= method.maxTarget;

  /// Bisa berakhir seri — menentukan ada tidaknya kolom D (W–L–D) di Peringkat.
  bool get canDraw => switch (method) {
    ScoringMethod.raceTo => false,
    ScoringMethod.bestOf || ScoringMethod.americano => target.isEven,
  };

  /// Best of & Americano: total paling banyak N, jadi kotak lawan yang masih kosong terisi otomatis `N − x`.
  bool get fillsOpponent => method == ScoringMethod.bestOf || method == ScoringMethod.americano;

  /// Isi satu kotak skor paling tinggi N: Race to N berhenti begitu satu tim mencapai N, Best of / Americano
  /// tidak bisa melebihi total.
  int get maxPerSide => target;

  /// Skor menang terkecil Best of / Americano: ⌊N ÷ 2⌋ + 1 (Americano 21 → 11, 24 → 13; Best of 5 → 3). Begitu
  /// tercapai lawan tidak mungkin mengejar, jadi match boleh berhenti sebelum total N.
  int get minWinningScore => target ~/ 2 + 1;

  /// Game/poin untuk pemenang WO (PRD 4.4): Race to N → N; Best of & Americano → rata-rata skor dari
  /// match yang dia mainkan sendiri ([ownAverage], null kalau belum pernah main), dibulatkan (,5 ke atas),
  /// tapi tidak pernah di bawah [minWinningScore] — supaya menang WO tidak bernilai skor kalah.
  int woWinnerScore(double? ownAverage) => switch (method) {
    ScoringMethod.raceTo => target,
    ScoringMethod.bestOf || ScoringMethod.americano =>
      ownAverage == null ? minWinningScore : max(ownAverage.round(), minWinningScore),
  };

  ScoreFormat withTarget(int target) => ScoreFormat(method, method.clampTarget(target));

  @override
  bool operator ==(Object other) => other is ScoreFormat && other.method == method && other.target == target;

  @override
  int get hashCode => Object.hash(method, target);

  @override
  String toString() => label;
}

enum RankingMethod { winPercent, totalGames }

extension RankingMethodX on RankingMethod {
  String get label => switch (this) {
    RankingMethod.winPercent => 'Win %',
    RankingMethod.totalGames => 'Total Point',
  };
}

enum MatchStatus {
  pending, // belum dimain
  done, // skor sudah terinput
  wo, // walkover — salah satu pair menang otomatis
  cancelled, // tidak dimainkan (turnamen dihentikan sebelum match)
}

enum WoReason { absent, injury, timeOut, other }

extension WoReasonX on WoReason {
  String get label => switch (this) {
    WoReason.absent => 'Absen',
    WoReason.injury => 'Cedera',
    WoReason.timeOut => 'Waktu habis',
    WoReason.other => 'Lainnya',
  };
}

@immutable
class Player {
  final String id;
  final String name;
  const Player({required this.id, required this.name});

  Player copyWith({String? name}) => Player(id: id, name: name ?? this.name);
}

@immutable
class Court {
  final String id;
  final String name; // "Court 1" atau "Merah" dst
  final int colorIndex; // 0-9 index ke MabarColors.courtPalette
  final int bookingDurationMinutes;

  /// Menit sejak turnamen dimulai saat booking court ini mulai: 0 untuk court dari Konfigurasi, menit berjalan untuk
  /// court yang ditambah di tengah turnamen atau dipesan ulang setelah habis (Kelola court, logic.md §10).
  final int startMinute;

  const Court({
    required this.id,
    required this.name,
    required this.colorIndex,
    required this.bookingDurationMinutes,
    this.startMinute = 0,
  });

  /// Ujung booking, dalam menit sejak turnamen dimulai.
  int get endMinute => startMinute + bookingDurationMinutes;

  Court copyWith({String? name, int? colorIndex, int? bookingDurationMinutes, int? startMinute}) => Court(
    id: id,
    name: name ?? this.name,
    colorIndex: colorIndex ?? this.colorIndex,
    bookingDurationMinutes: bookingDurationMinutes ?? this.bookingDurationMinutes,
    startMinute: startMinute ?? this.startMinute,
  );
}

@immutable
class Pair {
  final String id;
  final String player1Id;
  final String player2Id;
  const Pair({required this.id, required this.player1Id, required this.player2Id});

  bool contains(String playerId) => player1Id == playerId || player2Id == playerId;
  List<String> get playerIds => [player1Id, player2Id];
}

@immutable
class SetScore {
  final int side1;
  final int side2;
  const SetScore({required this.side1, required this.side2});
}

/// Satu match antara 2 pair. Pair bisa fixed (dari tournament.pairs) atau ad-hoc (mixed).
@immutable
class MatchGame {
  final String id;
  final int roundNumber;
  final int matchNumberInRound;
  final String courtId;
  final Pair pair1;
  final Pair pair2;
  final List<SetScore> sets;
  final MatchStatus status;
  final String? woLoserPairId; // pair yang WO (kalah); pemenang = pair sebelahnya
  final WoReason? woReason;

  const MatchGame({
    required this.id,
    required this.roundNumber,
    required this.matchNumberInRound,
    required this.courtId,
    required this.pair1,
    required this.pair2,
    this.sets = const [],
    this.status = MatchStatus.pending,
    this.woLoserPairId,
    this.woReason,
  });

  MatchGame copyWith({List<SetScore>? sets, MatchStatus? status, String? woLoserPairId, WoReason? woReason}) =>
      MatchGame(
        id: id,
        roundNumber: roundNumber,
        matchNumberInRound: matchNumberInRound,
        courtId: courtId,
        pair1: pair1,
        pair2: pair2,
        sets: sets ?? this.sets,
        status: status ?? this.status,
        woLoserPairId: woLoserPairId ?? this.woLoserPairId,
        woReason: woReason ?? this.woReason,
      );

  /// Skor disimpan: status selesai, sisa WO lama (pasangan & alasan) dibuang — membuka match WO di Input
  /// Skor lalu menyimpan skor mengubahnya jadi match biasa.
  MatchGame withScore(List<SetScore> sets) => _with(sets: sets, status: MatchStatus.done);

  /// WO dengan alasan persis [reason]: null benar-benar menghapus alasan lama (tidak seperti [copyWith]).
  /// Skor lama tetap disimpan supaya kembali terisi kalau WO-nya dibatalkan lewat Input Skor.
  MatchGame asWalkover({required String loserPairId, WoReason? reason}) =>
      _with(sets: sets, status: MatchStatus.wo, woLoserPairId: loserPairId, woReason: reason);

  MatchGame _with({required List<SetScore> sets, required MatchStatus status, String? woLoserPairId, WoReason? woReason}) =>
      MatchGame(
        id: id,
        roundNumber: roundNumber,
        matchNumberInRound: matchNumberInRound,
        courtId: courtId,
        pair1: pair1,
        pair2: pair2,
        sets: sets,
        status: status,
        woLoserPairId: woLoserPairId,
        woReason: woReason,
      );

  int get pair1TotalGames => sets.fold(0, (sum, s) => sum + s.side1);
  int get pair2TotalGames => sets.fold(0, (sum, s) => sum + s.side2);

  /// Winner pair id (null kalau pending/cancelled).
  String? get winnerPairId {
    switch (status) {
      case MatchStatus.pending:
      case MatchStatus.cancelled:
        return null;
      case MatchStatus.wo:
        return woLoserPairId == pair1.id ? pair2.id : pair1.id;
      case MatchStatus.done:
        int p1Sets = 0, p2Sets = 0;
        for (final s in sets) {
          if (s.side1 > s.side2)
            p1Sets++;
          else if (s.side2 > s.side1)
            p2Sets++;
        }
        if (p1Sets == p2Sets) return null; // draw
        return p1Sets > p2Sets ? pair1.id : pair2.id;
    }
  }
}

/// Konfigurasi turnamen (immutable snapshot dari setup).
@immutable
class TournamentConfig {
  final SportType sport;
  final PartnerMode mode;
  final int matchDurationMinutes;
  final List<Court> courts;
  final List<Player> players;
  final List<Pair>? fixedPairs; // null kalau mode = mixed
  final ScoreFormat format;

  /// Nama bebas dari Atur turnamen (mis. "PB Garuda x Matcha Club"); null = tanpa nama, semua tampilan
  /// memakai olahraga · mode seperti biasa. Hanya diisi di awal, tidak bisa diubah.
  final String? name;

  const TournamentConfig({
    required this.sport,
    required this.mode,
    required this.matchDurationMinutes,
    required this.courts,
    required this.players,
    this.fixedPairs,
    this.format = ScoreFormat.standard,
    this.name,
  });

  /// Batas nama turnamen: muat dua baris di poster Story.
  static const maxNameLength = 40;

  /// Batas court di Konfigurasi dan Kelola court.
  static const maxCourts = 10;

  /// Batas pemain (aktif, untuk Mixed) di layar Pemain dan Kelola pemain, sama untuk Fixed dan Mixed.
  static const minPlayers = 4;
  static const maxPlayers = 30;

  /// Langkah stepper durasi; durasi selalu kelipatannya.
  static const durationStep = 5;

  /// Durasi yang diketik host dibulatkan ke kelipatan 5 terdekat, minimal 5 (22 → 20, 23 → 25, 2 → 5).
  static int roundDuration(int minutes) =>
      max(durationStep, ((minutes + durationStep ~/ 2) ~/ durationStep) * durationStep);

  /// Max round berdasarkan durasi booking terpendek dari semua court.
  int get maxRounds {
    if (courts.isEmpty || matchDurationMinutes <= 0) return 0;
    final minBooking = courts.map((c) => c.bookingDurationMinutes).reduce((a, b) => a < b ? a : b);
    return minBooking ~/ matchDurationMinutes;
  }

  int get courtCount => courts.length;

  TournamentConfig copyWith({List<Player>? players, List<Court>? courts, List<Pair>? fixedPairs}) => TournamentConfig(
    sport: sport,
    mode: mode,
    matchDurationMinutes: matchDurationMinutes,
    courts: courts ?? this.courts,
    players: players ?? this.players,
    fixedPairs: fixedPairs ?? this.fixedPairs,
    format: format,
    name: name,
  );
}

@immutable
class Tournament {
  final String id;
  final DateTime createdAt;
  final TournamentConfig config;
  final List<MatchGame> matches;
  final bool isFinished; // ditandai true saat host tekan "Selesaikan Turnamen" atau semua match done
  const Tournament({
    required this.id,
    required this.createdAt,
    required this.config,
    this.matches = const [],
    this.isFinished = false,
  });

  Tournament copyWith({TournamentConfig? config, List<MatchGame>? matches, bool? isFinished}) => Tournament(
    id: id,
    createdAt: createdAt,
    config: config ?? this.config,
    matches: matches ?? this.matches,
    isFinished: isFinished ?? this.isFinished,
  );
}

/// Turnamen yang sedang berjalan + metadata jadwal yang tidak disimpan di
/// [Tournament] (pair yang bye per round).
@immutable
class ActiveTournament {
  final Tournament tournament;
  final Map<int, String> byePairIdByRound;

  /// Pemain yang istirahat, per nomor round (mode Mixed).
  final Map<int, List<String>> restingPlayerIdsByRound;

  /// Mode Mixed: pemain yang keluar di tengah turnamen. Sengaja tidak dihapus
  /// dari `config.players` supaya nama di match lama dan peringkatnya tetap ada.
  final Set<String> withdrawnPlayerIds;

  /// Fixed: putaran tambahan yang sudah dibuat setelah round-robin (`RoundRobinGenerator.extend`), supaya tambahan
  /// berikutnya melanjutkan urutan lawan — juga setelah pasangan diatur ulang, saat jumlah match per putaran berubah.
  final int extraPutaran;

  const ActiveTournament({
    required this.tournament,
    this.byePairIdByRound = const {},
    this.restingPlayerIdsByRound = const {},
    this.withdrawnPlayerIds = const {},
    this.extraPutaran = 0,
  });

  TournamentConfig get config => tournament.config;
  List<MatchGame> get matches => tournament.matches;

  /// Pemain yang ikut dijadwalkan di round berikutnya.
  List<Player> get activePlayers => [
    for (final p in config.players)
      if (!withdrawnPlayerIds.contains(p.id)) p,
  ];

  int get roundCount => matches.isEmpty ? 0 : matches.last.roundNumber;

  List<MatchGame> matchesOfRound(int round) => matches.where((m) => m.roundNumber == round).toList();

  /// Mixed: pemain aktif yang absen di salah satu round yang sudah dibuat — tidak main dan tidak tercatat istirahat,
  /// artinya masuk telat atau kembali setelah keluar. Mereka yang menyusul dengan jeda di
  /// `EndlessRoundGenerator.priorityOrder`.
  Set<String> get latePlayerIds {
    final late = <String>{};
    for (var r = 1; r <= roundCount; r++) {
      final present = {
        ...?restingPlayerIdsByRound[r],
        for (final m in matchesOfRound(r)) ...[...m.pair1.playerIds, ...m.pair2.playerIds],
      };
      late.addAll(activePlayers.map((p) => p.id).where((id) => !present.contains(id)));
    }
    return late;
  }

  /// Round dianggap selesai kalau tidak ada lagi match yang menunggu skor.
  bool isRoundComplete(int round) => matchesOfRound(round).every((m) => m.status != MatchStatus.pending);

  /// Round pertama yang belum selesai — batas navigasi linier mode Fixed.
  int get currentRound {
    for (var r = 1; r <= roundCount; r++) {
      if (!isRoundComplete(r)) return r;
    }
    return roundCount;
  }

  int get playedMatchCount => matches.where((m) => m.status == MatchStatus.done || m.status == MatchStatus.wo).length;

  /// Jumlah round yang punya minimal satu match selesai/WO — "5 round · 10 match" di Peringkat final
  /// dan Bagikan (label p di tabel Label round).
  int get playedRoundCount => {
    for (final m in matches)
      if (m.status == MatchStatus.done || m.status == MatchStatus.wo) m.roundNumber,
  }.length;

  /// Peringkat "Final" (09c, 09f): sudah diakhiri, atau tidak ada lagi yang bisa dimainkan tanpa tindakan
  /// host — Fixed semua match terisi; Mixed waktu booking semua court habis (per jam [now]) dan round
  /// terakhir lengkap. Kembali "Sementara" setelah Lanjutkan turnamen.
  bool isFinal(DateTime now) {
    if (tournament.isFinished) return true;
    if (matches.isEmpty) return false;
    return switch (config.mode) {
      PartnerMode.fixed => matches.every((m) => m.status != MatchStatus.pending),
      PartnerMode.mixed => courtsAvailableAt(now).isEmpty && isRoundComplete(roundCount),
    };
  }

  /// Seed undian pemain seri di generator Mixed. Diturunkan dari id turnamen (UUID acak yang memang
  /// tersimpan), jadi tetap sama setelah app ditutup tanpa kunci simpanan baru — dan simpanan lama
  /// langsung punya seed. FNV-1a 32-bit, bukan `String.hashCode` yang tidak dijamin sama antar platform;
  /// perkalian dengan prima 2^24 + 0x193 dipecah supaya tidak melewati 2^53 di web (angka JS).
  int get drawSeed {
    var hash = 0x811c9dc5;
    for (final unit in tournament.id.codeUnits) {
      hash ^= unit;
      hash = (((hash << 24) & 0xffffffff) + hash * 0x193) & 0xffffffff;
    }
    return hash;
  }

  MatchGame? matchById(String id) => matches.where((m) => m.id == id).firstOrNull;

  /// Pasangan Fixed sekarang, atau pasangan lama yang sudah diatur ulang (masih tercatat di match-nya).
  Pair? pairById(String id) =>
      config.fixedPairs?.where((p) => p.id == id).firstOrNull ??
      matches.expand((m) => [m.pair1, m.pair2]).where((p) => p.id == id).firstOrNull;

  /// Fixed: pasangan yang anggotanya selalu main bersama — satu baris di Klasemen, Detail, dan poster. Pasangan yang
  /// diatur ulang sebelum round tambahan (04f) tidak termasuk; anggotanya, juga pemain yang tidak ikut lagi, tampil
  /// sendiri-sendiri dengan angkanya masing-masing (09g, keputusan host 2026-11-03).
  List<Pair> get standingPairs => [
    for (final pair in config.fixedPairs ?? const <Pair>[])
      if (matches.every(
        (m) => [m.pair1, m.pair2].every((side) => side.id == pair.id || !side.playerIds.any(pair.contains)),
      ))
        pair,
  ];

  String playerName(String id) => config.players
      .firstWhere(
        (p) => p.id == id,
        orElse: () => const Player(id: '', name: '?'),
      )
      .name;

  Court courtById(String id) => config.courts.firstWhere((c) => c.id == id, orElse: () => config.courts.first);

  /// Menit yang sudah berjalan sejak turnamen dimulai, menurut jam sungguhan. Booking court dihitung dari jam
  /// mulainya, jadi round yang selesai lebih cepat dari durasinya menyisakan waktu untuk round tambahan.
  int elapsedMinutes(DateTime now) => max(0, now.difference(tournament.createdAt).inMinutes);

  /// Court yang sisa booking-nya pada [now] masih muat satu match penuh — dipakai round yang dibuat sekarang.
  List<Court> courtsAvailableAt(DateTime now) => [
    for (final c in config.courts)
      if (remainingBookingMinutes(c, now) >= config.matchDurationMinutes) c,
  ];

  /// Mode Mixed: round berikutnya baru boleh digenerate kalau skor round
  /// berjalan sudah lengkap dan masih ada court yang waktunya cukup.
  bool canGenerateNextRound(DateTime now) =>
      !tournament.isFinished &&
      (roundCount == 0 || isRoundComplete(roundCount)) &&
      courtsAvailableAt(now).isNotEmpty;

  /// Sisa waktu booking [court] pada [now], dari jam mulai court itu sendiri.
  int remainingBookingMinutes(Court court, DateTime now) => max(0, court.endMinute - elapsedMinutes(now));

  /// [court] ditambah [minutes]: `max(ujung booking, sekarang) + tambahan` (Lanjutkan 08c, detail court 08j–08k).
  /// Court yang sudah habis dipesan ulang mulai sekarang, jadi jendelanya ditulis ulang ("21.04–22.04").
  Court extendedBy(Court court, int minutes, DateTime now) => remainingBookingMinutes(court, now) > 0
      ? court.copyWith(bookingDurationMinutes: court.bookingDurationMinutes + minutes)
      : court.copyWith(startMinute: elapsedMinutes(now), bookingDurationMinutes: minutes);

  /// Round yang sedang berjalan, tempat hitung mundur sisa booking tampil (strip court, subjudul Input Skor):
  /// Mixed round terakhir, Fixed round yang sedang dibuka. Null setelah diakhiri.
  int? get runningRound {
    if (tournament.isFinished || matches.isEmpty) return null;
    return config.mode == PartnerMode.mixed ? roundCount : currentRound;
  }

  /// Mixed: Kelola court (menu ⋯) ada selama turnamen belum diakhiri.
  bool get canManageCourts => config.mode == PartnerMode.mixed && !tournament.isFinished;

  /// Hapus court (detail court, 08h): hanya court bernomor terakhir — nomor court = urutannya, menghapus court di
  /// tengah menggeser nomor court lain, termasuk di match lama — yang belum punya match selesai/WO, dan bukan
  /// satu-satunya court.
  bool canRemoveCourt(String courtId) =>
      canManageCourts &&
      config.courts.length > 1 &&
      config.courts.last.id == courtId &&
      !matches.any((m) => m.courtId == courtId && (m.status == MatchStatus.done || m.status == MatchStatus.wo)) &&
      // Round yang isinya hanya match di court ini dibatalkan lewat "Batalkan R…", bukan lewat hapus court.
      matchesOfRound(roundCount).any((m) => m.courtId != courtId);

  /// Court baru dari Kelola court: nama kosong = "Court n", booking mulai sekarang ([now]).
  Court newCourt({
    required String id,
    required String name,
    required int colorIndex,
    required int bookingMinutes,
    required DateTime now,
  }) => Court(
    id: id,
    name: name.trim().isEmpty ? 'Court ${config.courts.length + 1}' : name.trim(),
    colorIndex: colorIndex,
    bookingDurationMinutes: bookingMinutes,
    startMinute: elapsedMinutes(now),
  );

  /// [court] menggantikan court ber-id sama, atau ditambahkan di akhir (nomornya berikutnya).
  ActiveTournament withCourt(Court court) {
    final courts = config.courts;
    final replace = courts.any((c) => c.id == court.id);
    return copyWith(
      tournament: tournament.copyWith(
        config: config.copyWith(
          courts: replace ? [for (final c in courts) c.id == court.id ? court : c] : [...courts, court],
        ),
      ),
    );
  }

  /// Pratinjau detail court: panjang booking [hours] jam. Court yang masih berjalan tetap memakai jam mulainya; yang
  /// sudah habis (stepper mulai 0) dipesan ulang mulai sekarang, sama dengan Lanjutkan.
  Court withBookingHours(Court court, int hours, DateTime now) {
    if (remainingBookingMinutes(court, now) > 0) return court.copyWith(bookingDurationMinutes: hours * 60);
    return hours == 0 ? court : court.copyWith(startMinute: elapsedMinutes(now), bookingDurationMinutes: hours * 60);
  }

  /// Perkiraan round & match yang masih muat kalau tiap court ditambah [extraMinutes] (per court id),
  /// untuk sheet Lanjutkan turnamen (08c). Round jalan selama masih ada satu court, jadi jumlah round
  /// cuma mengikuti court terpanjang — jumlah match-lah yang mencerminkan tambahan di tiap court.
  ///
  /// [courts] = court yang main di round pertama sesudah [roundCount]. [fewerCourtsFrom] = round ke-r
  /// (1 = round pertama tambahan) saat salah satu court itu habis di tengah, null kalau tidak ada; court
  /// yang sejak awal tidak dapat tambahan tidak dihitung "berkurang". [matchesPerRound] = batas dari
  /// jumlah pemain aktif (⌊pemain ÷ 4⌋).
  ({int rounds, int matches, int courts, int? fewerCourtsFrom, int matchesPerRound}) capacityAhead(
    DateTime now, [
    Map<String, int> extraMinutes = const {},
  ]) {
    final perCourt = [
      for (final c in config.courts)
        (remainingBookingMinutes(c, now) + (extraMinutes[c.id] ?? 0)) ~/ config.matchDurationMinutes,
    ];
    final matchesPerRound = activePlayers.length ~/ 4;
    final firstCourts = perCourt.where((n) => n >= 1).length;
    var rounds = 0, matches = 0;
    int? fewerFrom;
    for (var r = 1; ; r++) {
      final courts = perCourt.where((n) => n >= r).length;
      if (courts == 0) break;
      rounds = r;
      matches += min(courts, matchesPerRound);
      if (courts < firstCourts) fewerFrom ??= r;
    }
    return (
      rounds: rounds,
      matches: matches,
      courts: firstCourts,
      fewerCourtsFrom: fewerFrom,
      matchesPerRound: matchesPerRound,
    );
  }

  /// Fixed: round tambahan (06v, `RoundRobinGenerator.extraRounds`) boleh dibuat setelah semua match terisi, selama
  /// belum diakhiri.
  bool get canAddRounds =>
      config.mode == PartnerMode.fixed &&
      !tournament.isFinished &&
      matches.isNotEmpty &&
      matches.every((m) => m.status != MatchStatus.pending);

  /// Mode Mixed: turnamen yang sudah diakhiri atau kehabisan waktu booking
  /// bisa dilanjutkan dengan menambah jam court.
  bool canResume(DateTime now) =>
      config.mode == PartnerMode.mixed && (tournament.isFinished || courtsAvailableAt(now).isEmpty);

  /// Mode Mixed: round terakhir boleh dibatalkan (dihapus) selama belum ada
  /// satu skor pun, mis. pemain baru datang dan ingin langsung main. R1 tidak
  /// pernah — turnamen tanpa round tidak punya layar jadwal.
  bool get canCancelLastRound =>
      config.mode == PartnerMode.mixed &&
      !tournament.isFinished &&
      roundCount > 1 &&
      matchesOfRound(roundCount).every((m) => m.status == MatchStatus.pending);

  ActiveTournament copyWith({
    Tournament? tournament,
    Map<int, String>? byes,
    Map<int, List<String>>? resting,
    Set<String>? withdrawn,
    int? extraPutaran,
  }) => ActiveTournament(
    tournament: tournament ?? this.tournament,
    byePairIdByRound: byes ?? byePairIdByRound,
    restingPlayerIdsByRound: resting ?? restingPlayerIdsByRound,
    withdrawnPlayerIds: withdrawn ?? withdrawnPlayerIds,
    extraPutaran: extraPutaran ?? this.extraPutaran,
  );
}
