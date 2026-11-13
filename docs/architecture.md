# Arsitektur domain — mesin, provider, invariant

Pemilik: tech-lead. Baca kalau mengubah `lib/services/**`, `lib/models/models.dart`, atau provider di
`features/schedule/tournament_controller.dart`. Aturan produk: `PRD.md` §3–4; aturan logika v2 + data test:
`design/spec/logic.md`. Persistensi: `docs/data.md`. Live score: `docs/live.md`.

Semua mesin di bawah ter-test (`flutter test` lulus, termasuk golden komponen di `test/hifi/`; `flutter analyze`
bersih kecuali 2 info lint lama di `models.dart`). Perubahan logika v2 (format skor Race to / Best of / Americano
dengan data lama tetap terbaca, batas keypad, WO per format, status Final Mixed, undian seri dikunci per round, daftar
prioritas istirahat, bug estimasi Lanjutkan) ada di `design/spec/logic.md` dan sudah diimplementasi (langkah 2) di
service/model.

## Pairing & Fixed

- `pairing/player_name_parser.dart` — parser textarea nama.
- `pairing/pair_generator.dart` — pasangan Fixed (acak/manual), sisa pemain ganjil.
- `schedule/round_robin_generator.dart` — circle method. **Invariant:** satu putaran circle dipotong jadi beberapa
  round sebesar jumlah court, tidak pernah menggabungkan dua putaran (kalau digabung, satu pair bisa main di dua
  lapangan bersamaan).
- **Round tambahan Fixed** (keputusan host 2026-11-03, dari live TBNE36; `design/spec/logic.md` §12, PRD 3.3a; tes
  `test/services/fixed_extra_rounds_test.dart`, `fixed_add_rounds_test.dart`, golden `test/hifi/screens/tambah_round_test.dart`
  06v–06z/04f–04h, 09g, 10d; fixture `fixed_extra_fixture.dart`). Setelah semua match terisi dan belum diakhiri
  (`ActiveTournament.canAddRounds`) action bar Jadwal Fixed = ikon Klasemen + "Tambah round" → sheet
  `features/schedule/fixed/add_rounds_sheet.dart` (jam booking per court + estimasi dari
  `schedule/widgets/extend_sheet_parts.dart`, dipakai bersama Lanjutkan Mixed). `RoundRobinGenerator.extend`: putaran =
  tiap pasangan +1 (genap, circle round k mod (n−1)) atau +2 (ganjil, siklus Walecki k mod m); jumlah putaran = paling
  sedikit yang mengisi round yang muat di court terpanjang, dibulatkan ke atas, boleh lewat booking; court yang habis
  berhenti dipakai. `extraPutaran` (kunci simpanan opsional) melanjutkan urutan lawan antar tambahan.
- Atur pasangan (`features/pair_edit/pair_edit_screen.dart` di atas `services/pairing/pair_draft.dart`): "Ubah" (label
  host) memisahkan pasangan, pasangan baru mengisi slot yang kosong supaya lawan pasangan lain tetap, pemain pengganti
  diketik; yang tidak dipasangkan tidak ikut (poin tertinggal). Klasemen/Detail/poster memakai
  `ActiveTournament.standingPairs` (pasangan yang selalu main bersama) — sisanya per pemain, jadi baris campuran (09g);
  poster campuran menulis "+n lainnya" / "Semua n" (`shareRowNoun`). `pairById` juga mencari pasangan lama di match.
  Fixed yang diakhiri tetap tidak bisa dilanjutkan.

## Mixed

- `schedule/endless_round_generator.dart` — round Mixed. Constraint direlaksasi lewat bobot penalti: ulang match persis
  1000, ulang partner 10, ulang lawan 3; ambil terbaik dari 400 percobaan. **Invariant:** selisih match antar pemain yang
  hadir sejak awal ≤ 1 (pemain telat: lihat bawah).
- Siapa yang main = `priorityOrder` (jumlah main → paling lama istirahat → undian → id, lalu jeda pemain telat).
  Undiannya **dikunci per round**: `Random(drawSeed + nomor round)` dibagikan ke pemain urut id, `drawSeed` = FNV-1a dari
  id turnamen (`ActiveTournament.drawSeed`, tanpa kunci simpanan baru; perkaliannya dipecah supaya sama di web). Jadi
  `restingAfterLastRound` (baris "Istirahat · Prioritas main di R…" / "Istirahat lagi di R…", dari pemain aktif
  sekarang) selalu sama dengan hasil "Buat R…".
- **Waktu = jam sungguhan** (keputusan host 2026-10-22): sisa booking court = booking − menit sejak `createdAt`
  (`ActiveTournament.elapsedMinutes(now)`), court ikut round baru kalau sisa itu muat satu match
  (`courtsAvailableAt(now)`); round yang selesai cepat menyisakan waktu. Semua turunannya (`canGenerateNextRound`,
  `canResume`, `isFinal`, `remainingBookingMinutes`, `capacityAhead`, `restingAfterLastRound`) menerima `now` dari
  `clockProvider`. Jadwal Mixed ditik ulang tiap menit supaya "Waktu habis" muncul sendiri. Waktu habis (tidak ada court
  yang muat) → slot dihitung dari semua court, sesuai frame 06l. Tes: `test/services/mixed_priority_test.dart`.
- **Peserta berubah di tengah turnamen** (sheet "Kelola Peserta", `features/schedule/mixed/manage_players_sheet.dart`;
  tes `test/services/mixed_roster_test.dart`). Pemain keluar **tidak dihapus** dari `config.players`, hanya masuk
  `ActiveTournament.withdrawnPlayerIds`, supaya nama di match lama & peringkatnya tetap ada (tampil di
  Peringkat/Detail/Share tanpa penanda "keluar" — keputusan host 2026-10-20); generator hanya menerima `activePlayers`.
- **Pemain telat menyusul** (keputusan host 2026-10-25, `design/spec/logic.md` §5a): pemain baru/kembali =
  `ActiveTournament.latePlayerIds` (absen di round yang sudah dibuat: tidak main dan tidak ada di daftar istirahat)
  paling sedikit main jadi diprioritaskan, tapi `priorityOrder` memindahnya ke paling bawah setelah main k round
  beruntun selama masih di bawah yang paling banyak main; k = max(2, slot ÷ yang istirahat + 1), 12 pemain/2 court → 3.
  Pemain yang hadir sejak awal tidak kena jeda (undian seri kadang memberi mereka k round beruntun; memotongnya membuat
  selisih 2). Kredit catch-up lama (`matchCredits`, ≤ 2.6) membuat selisihnya tetap selamanya dan sudah dihapus; kunci
  `credits` di simpanan diabaikan. Menyusulnya pelan kalau sisa istirahat sedikit (12/2 court ±0,1 match per round) —
  itu harga jeda stamina yang dipilih host. Hanya untuk prioritas jadwal, tidak ikut ranking (di Total Point pemain
  telat memang tertinggal; ini keputusan host).
- Minimal 4, maksimal 30 pemain aktif (`TournamentConfig.minPlayers`/`maxPlayers`, satu batas untuk layar Pemain,
  parser, dan Kelola pemain, Fixed maupun Mixed — keputusan host 2026-10-23, kebutuhan klub 24–26 orang).
- **Batalkan round**: round terakhir yang belum ada satu skor pun bisa **dibatalkan = dihapus** ("Batalkan Rn",
  `TournamentController.cancelLastRound`, syaratnya `ActiveTournament.canCancelLastRound`; tombol di bawah "Buat R…"),
  untuk pemain yang baru datang: host tambah pemain lewat Peserta lalu "Buat Rn" lagi. Tidak dibuat ulang otomatis —
  keputusan host. **R1 tidak bisa dibatalkan** (`roundCount > 1`), karena layar jadwal tanpa round tidak punya isi.
  Setelah dibatalkan layar pindah ke round sebelumnya; pemain yang ditambah setelah round itu dibuat paling sedikit
  main, jadi langsung main di round penggantinya.
- **Kelola court** (menu ⋯, keputusan host 2026-10-22; `design/spec/logic.md` §10; tes
  `test/services/court_manage_test.dart`, `court_availability_test.dart`, golden `test/hifi/screens/kelola_court_test.dart`):
  `Court.startMinute` = menit sejak `createdAt` saat booking court mulai (Konfigurasi 0; kunci simpanan opsional →
  simpanan 2.1 tetap terbaca), sisa = `endMinute − elapsed`. Sheet `features/schedule/mixed/manage_courts_sheet.dart`:
  daftar court + court baru (`TournamentController.addCourt`), ketuk → detail court (sheet aksi, Simpan →
  `updateCourt`; stepper = panjang booking, court habis mulai 0 dan dipesan ulang dari sekarang lewat
  `withBookingHours`/`extendedBy`, sama dengan Lanjutkan). Kapan court dipakai = `EndlessRoundGenerator.courtUse`:
  round berjalan + court tanpa match + istirahat ≥ 4 → langsung main (`courtMatch`, 4 teratas `priorityOrder(n+1)`);
  court lama yang sudah muat tidak pernah tiba-tiba dipakai (`wasAvailable`). Hapus (`removeCourt`) hanya court
  bernomor terakhir tanpa skor dan bukan satu-satunya — nomor court = urutannya. Fixture `courtTournament` (id
  `t-court-329705` dipilih supaya undian seri sama dengan frame).
- `ActiveTournament.capacityAhead` (sheet Lanjutkan) mengembalikan `fewerCourtsFrom` = round tambahan saat court yang
  main di round pertamanya habis; court yang sejak awal tidak dapat tambahan bukan "berkurang" (bug lama).
- Lanjutkan Turnamen (resume, `extendedBy`): lihat `docs/data.md`.
- Tukar pemain (3.5.0, PRD §15, `logic.md` §15): `lib/services/schedule/player_swap.dart` (`PlayerSwap`:
  `isSwappable`, `canSwapTeam`, `candidates`, `swapped`, `apply`) + `TournamentController.swapPlayer` (berakhir di
  `state =`). Hanya round terakhir, match Belum, `mode == mixed` (Mexicano dan Fixed ditolak), turnamen belum diakhiri.
  Q mengambil slot P persis (id pasangan dihitung ulang tanpa mengurutkan slot → tukar balik byte-sama); P masuk
  `resting[n]` di indeks Q, Q keluar darinya; `latePlayerIds` turunan dari absen, jadi Q keluar dari telat hanya kalau
  Rn satu-satunya round yang dia lewatkan. Kandidat = daftar Istirahat round terakhir (sparing: klub tim itu). Tanpa
  generator/`Random`. Ikon tukar = `MatchScoreSide.onSwap` (komponen tidak tahu aturannya).

## Sparing (3.2.0)

Dua klub, partner sesama klub, lawan klub lain (PRD §13, aturan + data test `design/spec/logic.md` §13). Setiap
cabang dimulai dari `config.isSparing`; turnamen biasa tidak berubah (AC-S19). Simpanan: `docs/data.md` → Sparing.
- **Model** (`models.dart`): `TournamentConfig.clubs` (tepat dua, klub pertama = sisi atas match), `Player.clubId`
  (tidak pernah berubah, K8), helper `clubById`/`clubOfPlayer`/`clubOfPair`/`playersOfClub`/`pairsOfClub`; total, tidak
  melempar. `ActiveTournament.restingPairIdsByRound` (Fixed sparing: beberapa pasangan istirahat per round),
  `activePlayersOfClub`, `activePlayersByClub`, `canWithdraw`. **Invariant:** S1 tiap pemain berklub, S2 pasangan
  sesama klub, S4 `pair1` klub pertama — mutator yang melanggarnya assert di debug dan tidak mengubah state di rilis
  (simpanan yang melanggar terbaca null).
- **Validasi layar Pemain**: `pairing/club_roster.dart` (`ClubRoster.check`, K4/K6/K8: minimal 2 per klub, total 4–30,
  nama tidak di dua klub). Pasangan: `PairGenerator.randomByClub` / `manual` + `sameClub` (satu-satunya tempat aturan
  S2), `PairDraft.canPair` untuk Atur pasangan per klub.
- **Fixed** — `schedule/sparing_fixed_generator.dart` (`SparingFixedGenerator`; tes `sparing_fixed_test.dart`,
  `sparing_fixed_flow_test.dart`): algoritma diagonal per blok KPK(p1, p2), bukan circle method; court aktif
  `activeCourts = min(C, p1, p2)`. `generate` (jadwal awal), `extend`/`extraRounds` (round tambahan per satuan
  `unitMatches` = KPK match, `extraPutaran` = jumlah satuan, boleh lewat booking → `overMinutes`), `estimate`
  (Konfigurasi K10). **Invariant:** tiap kombinasi pasangan dua klub tepat sekali per g blok; selisih main satu klub ≤ 1
  setelah setiap round. Controller: `startIfNeeded` dan `addRounds` bercabang sparing (`_sparingPairs`).
- **Sisa round per court** — satu rumus `ActiveTournament.roundsLeftPerCourt` (⌊(sisa booking + tambahan) ÷ durasi⌋)
  dipakai `capacityAhead` (Lanjutkan Mixed) dan kedua `extraRounds` (Tambah round Fixed); baris "n court, berkurang
  mulai R…" dari `ActiveTournament.courtsAhead` (sparing dibatasi C'), dibaca sheet dari rencana, tidak dihitung di
  widget.
- **Mixed** — `EndlessRoundGenerator.generateSparingRound` (tes `sparing_mixed_test.dart`, sweep `slow`): court aktif
  `C' = ActiveTournament.sparingActiveCourts` = min(court muat, ⌊n1÷2⌋, ⌊n2÷2⌋), satu rumus untuk generator, slot
  R(n+1), `courtUse`/`courtMatch`, `capacityAhead.matchesPerRound`, dan `sparingEstimate` (Konfigurasi, Cara kerja).
  `priorityOrder` dipanggil per klub dengan slot klub `2·C'` (jeda pemain telat per klub dengan sendirinya); susunan
  diacak per klub, match i = pasangan klub pertama ke-i vs klub kedua ke-i. `restingByClubAfterLastRound` = daftar
  Prioritas/Istirahat lagi per klub, sama dengan Buat R(n+1) (AC-S11). Kelola court langsung main hanya kalau tiap
  klub punya ≥ 2 yang istirahat. Kelola pemain: `addPlayer(name, clubId:)` wajib klub, Keluarkan mati kalau klubnya
  tinggal 2 aktif. **Invariant:** selisih main antar pemain satu klub yang hadir sejak awal ≤ 1; antar klub boleh
  beda (K1).
- **Skor klub** — `ranking/club_score.dart`: `ClubResult.of(active)` (menang dalam setengah-poin `halfWins`, Total
  Point klub termasuk nilai WO K11, selisih, unggul/Seri: menang → Total Point, selisih hanya tampil). Adaptor teks
  untuk widget `ClubScore` (`core/widgets`, menerima string jadi): `scoreLabel` ("6 – 4"), `detailLabel` ("56 game ·
  +13"), `leads` (bola; belum ada hasil → tanpa bola). Jadwal, Klasemen, Beranda, poster, caption, dan Live memakai
  adaptor yang sama, tidak merangkai sendiri. `clubStandings` = `RankingCalculator.rank` sekali lalu `standingEntries`
  per klub, jadi nomor dimulai #1 di tiap klub. Caption share (`ResultTextBuilder`) memakai `clubStandings` yang sama.
- **Provider** (`features/schedule/sparing_providers.dart`): `clubScoreProvider`, `clubStandingEntriesProvider`,
  `playerClubPositionProvider` ("Peringkat n · {klub}" di Detail); null/kosong untuk turnamen biasa.

## Mexicano (3.4.0)

Mode ketiga: siapa main = prioritas main Mixed apa adanya, yang main dikelompokkan berempat per court menurut Total
Point → selisih → undian (PRD §14, aturan + data test `design/spec/logic.md` §14, task `docs/tasks.md`). Mesin Mixed
dipakai ulang; tidak ada generator atau layar kedua.
- **Model**: `PartnerMode.mexicano`; `PartnerModeX.isEndless` (Mixed + Mexicano) menggantikan `== PartnerMode.mixed`
  di semua turunan round-per-round (`isFinal`, `runningRound`, `canManageCourts`, `canResume`, `canCancelLastRound`,
  `startIfNeeded`, `resume`), **kecuali** `addPlayer` (Mexicano tanpa tambah pemain). `ScoreFormat.forMexicano`
  (Konfigurasi), `ActiveTournament.canReinstate` (Mexicano: hadir di setiap round yang sudah dibuat).
- **Generator** (`EndlessRoundGenerator`, file yang sama dengan Mixed): `lockedDraw` (diekstrak dari `priorityOrder`,
  nilai identik), `generateMexicanoRound`, `mexicanoOrder` (`RankingCalculator.compare` Total Point + undian + id),
  `mexicanoArrangement` (A/B/C, beban = `_History.partnerCount`). `courtMatch` bercabang Mexicano tanpa `Random`.
  `restingAfterLastRound` dan `courtUse` tidak berubah. Jadwal = `schedule_mixed_screen.dart` (router memilih Fixed vs
  lainnya).
- **Invariant:** selisih main antar pemain aktif ≤ 1 setelah setiap round; kelompok court ke-i = pemain ke-4i..4i+3
  urutan Mexicano yang main, di court muat ke-i; susunan beban terkecil, seri A → B → C; hasil Buat pasti untuk input
  yang sama (tidak ada `Random()` selain undian terkunci); urutan tidak pernah tergantung tab Klasemen;
  `latePlayerIds` selalu kosong; Mexicano tidak pernah sparing dan selalu Americano.
- **Simpanan**: hanya nilai `mode` baru, `schemaVersion` tetap 2; versi ≤ 3.3.x menolaknya karena
  `PartnerMode.values.byName` melempar di dalam `try` decode (bukti baris di `logic.md` §14.6, rinci `docs/data.md`).
- **Konfigurasi** (keputusan 33–38): satu layar baris Skor/Court + sheet; pengaturan terakhir per olahraga di
  `services/storage/last_settings.dart` (kunci Hive sendiri, di luar `TournamentCodec`), ditulis saat turnamen dimulai.

## Ranking & klasemen

- `ranking/ranking_calculator.dart` — dua metode: Win % dan **Total Point** (`gamesWon`, yaitu jumlah game yang
  dimenangkan lintas match: 6-5, 4-6, 3-6 → 13). Default mengikuti format skor (`RankingCalculator.defaultMethod`, keputusan host
  2026-11-11): Race to dan Best of → Win %, Americano → Total Point. `rankingMethodProvider` menonton id + format
  turnamen, jadi pilihan host bertahan selama turnamen dan kembali ke default saat turnamen berganti; test yang
  menggambar frame Total Point untuk Race to wajib menyetel metodenya. Metode "Kombinasi" sudah dihapus karena isinya identik dengan Win %.
- Urutan = `RankingCalculator.compare`: nilai metode → selisih (`gameDiff`), lalu nama hanya untuk mengurutkan yang
  nomornya sama. Keputusan host 2026-11-02: hanya angka yang tampil di Klasemen/poster yang menentukan nomor, jadi
  head-to-head (di Mixed bisa berputar A > B > C > A) dan Total Point sebagai pemisah Win % dihapus.
- WO (PRD 4.4, `ScoreFormat.woWinnerScore`): menang/kalah dihitung; pemenang dapat N game di Race to, di
  Best of/Americano rata-rata skornya sendiri dari match yang dia mainkan (bulat ,5 ke atas) tapi minimal ⌊N÷2⌋+1; yang
  kalah 0. Nilai itu masuk `woPoints` → `totalPoint`, **tidak** ke `gameDiff`. Format lama tetap: WO tanpa game.
  `cancelled` & `pending` diabaikan total. Tes dengan data frame 09a–09f/10b: `test/services/ranking_v2_test.dart`.
- `standingEntries()` (di `ranking/ranking_calculator.dart`) — mengubah klasemen per pemain jadi baris tampilan. Mode
  Fixed: pasangan yang tidak pernah berganti (`standingPairs`) statistik kedua anggotanya identik, jadi dua baris kembar
  digabung jadi satu baris "Andi + Budi" yang mengambil posisi anggota terbaiknya. Mode Mixed: satu baris per pemain,
  urutan `rank()` tidak diubah. Pemain sisa (jumlah ganjil) tetap tampil sendiri. `StandingEntry.position`: `compare` =
  0 (nilai metode dan selisih sama) → nomor sama, nomor berikutnya melanjutkan (1, 2, 2, 3 — bukan 1, 2, 2, 4), jadi
  `standingEntries` butuh `method` yang sama dengan `rank()`; baris yang belum main dipindah ke belakang dengan
  `position == null` (grup "Belum main"). Peringkat, Detail, Bagikan, dan caption memakai nomor ini (Pitfalls
  `CLAUDE.md`).
- `ActiveTournament.isFinal(now)` — status Final/Sementara: diakhiri, Fixed semua match terisi, Mixed waktu booking
  habis + round terakhir lengkap (bukan tiap round lengkap). `playedRoundCount` = jumlah round yang punya match
  selesai/WO ("5 round · 10 match").

## Format skor & match

- **Format skor** (`TournamentConfig.format` = `ScoreFormat(method, target)`; tes `test/services/score_format_test.dart`):
  Race to N (2–9, default 6 — default kedua olahraga; murni: skor akhir N lawan 0..N−1, tanpa 7–5/7–6), Best of N
  (1–15, default 5), Americano N (2–99, default 21). Semua disimpan sebagai **satu `SetScore`**, jadi ranking/share/codec
  tidak bercabang.
- Best of & Americano: total ≤ N dan pemenang ≥ `minWinningScore` (⌊N÷2⌋+1) — match boleh berhenti begitu lawan tidak
  mungkin mengejar (11–5 di Americano 21, keputusan host 2026-10-26, pesan "Total poin lebih dari 21" / "Minimal skor
  pemenang 11"); `N − x` hanya mengisi kotak lawan yang kosong atau masih otomatis (`autoSide`), yang sudah diketik/skor
  tersimpan tidak dihitung ulang supaya yang kalah tidak dapat poin gratis; seri hanya dengan total penuh di N genap
  (`canDraw`, juga penentu kolom D).
- Aturan sah + pesan frame 07d/07n/07o di `services/scoring/score_entry.dart` (`ScoreRules.judge`), begitu juga keypad
  v2 (`ScoreEntry`: batas per kotak `maxPerSide`, ketikan pertama setelah kotak dipilih mengganti isi, digit penuh →
  pindah ke kotak lawan yang kosong, tombol tidak melihat isi lawan).
- Durasi match selalu kelipatan 5 (`TournamentConfig.roundDuration`). Menyalin config: lihat Pitfalls `CLAUDE.md`.
- `MatchGame.withScore` / `asWalkover` menimpa match sepenuhnya: skor di match WO membuang sisa WO, dan alasan WO yang
  dilepas benar-benar hilang (`copyWith` tidak bisa mengosongkan field).

## Nama turnamen & teks share

- **Nama turnamen** (keputusan host 2026-10-23): `TournamentConfig.name` (null = tanpa nama, maks
  `TournamentConfig.maxNameLength` 40, dipangkas di Konfigurasi; kunci simpanan `name` opsional, jadi simpanan lama
  terbaca). Hanya diisi di Konfigurasi (kotak paling atas, `MabarField` tanpa label), tidak bisa diubah. Menggantikan
  "olahraga · mode · n pemain" di Beranda (`MabarRow.titleOneLine`, banner satu baris) dan baris kecil poster
  (`SharePosterData.eyebrow`, maks dua baris; tanggal pindah ke `summary`); caption "🏆 {nama} · Padel". Tanpa nama
  semua tampilan tetap. Golden bernama: 01a/01e/01h, 03c, 11a/11d/11f.
- `share/podium.dart` (3.6.0, `logic.md` §16) — siapa naik poster podium: `Podium.of` → `PodiumEmpty` (belum ada
  match selesai, termasuk Sparing 0 – 0) / `PodiumSteps` / `PodiumCrowd` (#1 > 4) / `PodiumClubs` (Sparing). Calon =
  baris dengan `position` ≤ nomor baris ke-min(3, |R|), maks 4 anak tangga, dipangkas per kelompok nomor utuh. Level
  dan tinggi dari `position` (kembar = sama tinggi), urutan slot dari indeks; emas ⇔ level 1. `podiumFacts` = baris
  fakta, `rowNoun` = kata pemain/pasangan (kosong untuk Fixed campuran; selalu dari semua baris Klasemen).
- `share/lengkap.dart` (rencana 3.7.0, `logic.md` §17) — poster Lengkap: `lengkapGrid` (kolom: Fixed selalu satu,
  Mixed/Mexicano dua rata di atas 10 Feed / 20 Story, Sparing dua kolom per klub; satuan baris, kepala klub 2) dan
  `lengkapDensity` (tinggi baris = min(batas, ruang ÷ satuan), skala huruf = min(batas, tinggi ÷ acuan)). Podium mini
  memakai `Podium.of` apa adanya.
- `share/result_text_builder.dart` — teks share ringkas/lengkap (tiap baris memuat total point, satuan ikut format,
  "Peringkat Akhir"/"Sementara" dari `isFinal`).

## Provider Riverpod

- `tournamentProvider` (`features/schedule/tournament_controller.dart`) — satu-satunya sumber kebenaran state turnamen
  sejak layar jadwal. Sebelum itu data dioper lewat `extra` router.
- `clockProvider` (file yang sama) = jam sekarang, dipakai hitung mundur court dan `createdAt`.
- Metode peringkat yang dipilih host hidup di `rankingMethodProvider`, klasemennya di `standingsProvider`, dan baris
  siap tampilnya di `standingEntriesProvider` (semuanya di `features/schedule/tournament_controller.dart`) — layar
  Peringkat, Detail Pemain, dan Share membaca `standingEntriesProvider` yang sama, jadi nomor urutnya tidak pernah
  berbeda antar layar.
- Di layar Detail, nama yang ditampilkan diambil dari `config.players` memakai `playerId`, **bukan** dari
  `entry.standing.player`: satu baris Fixed memuat dua pemain, dan `standing` itu milik anggota yang peringkatnya lebih
  tinggi.
