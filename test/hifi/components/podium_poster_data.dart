// Dihasilkan dari teks + geometri SVG frame hi-fi (`design/hifi.html`): data literal tiap poster podium, kunci = id
// frame, urutan = urutan poster di frame. Jangan menurunkan data dari kode produksi (PP-1/PP-3): golden ini menguji
// gambar, bukan logika siapa naik.
import 'package:match_addict/features/share/widgets/podium_poster.dart';
import 'package:match_addict/models/models.dart';

/// [theme] = `padel`/`tennis` (lapangan) atau nama `ShareTheme`.
class PodiumFrameCase {
  final String theme;
  final PodiumPosterData data;

  const PodiumFrameCase(this.theme, this.data);
}

const podiumFrames = <String, List<PodiumFrameCase>>{
  '11a': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen sementara · 21 Okt 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Andi Pratama'], value: '42', detail: 'poin · +12'),
          PodiumRowData(badge: '1', gold: true, names: ['Dewant Rahman'], value: '42', detail: 'poin · +12'),
          PodiumRowData(badge: '2', gold: false, names: ['Hana Taslim'], value: '36', detail: 'poin · 0'),
        ],
        facts: 'Padel · 11 pemain · R3 · 6 dari 6 match',
      ),
    ),
  ],
  '11c': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen sementara',
        subtitle: 'Padel · Mixed · 21 Okt 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Andi Pratama'], value: '42', detail: 'poin · +12'),
          PodiumRowData(badge: '1', gold: true, names: ['Dewant Rahman'], value: '42', detail: 'poin · +12'),
          PodiumRowData(badge: '2', gold: false, names: ['Hana Taslim'], value: '36', detail: 'poin · 0'),
        ],
        facts: '11 pemain · R3 · 6 dari 6 match',
      ),
    ),
  ],
  '11d': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda x Matcha Club 2026',
        subtitle: 'Klasemen akhir · 21 Okt 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Andi Pratama'], value: '52', detail: 'poin · +10'),
          PodiumRowData(badge: '2', gold: false, names: ['Dewant Rahman'], value: '47', detail: 'poin · +3'),
          PodiumRowData(badge: '3', gold: false, names: ['Hana Taslim'], value: '45', detail: 'poin · 0'),
        ],
        facts: 'Padel · 10 pemain · 4 round · 8 match · 1 WO',
      ),
    ),
  ],
  '13q': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Fixed · 4 Nov 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '7'),
          PodiumBlockData(level: 2, face: '5'),
        ],
        rows: [
          PodiumRowData(badge: '7', hash: false, gold: true, names: ['PB Garuda'], value: '56', detail: 'game · +13'),
          PodiumRowData(
            badge: '5',
            hash: false,
            gold: false,
            names: ['Matcha Club'],
            value: '49',
            detail: 'game · −13',
          ),
        ],
        facts: '7 pasangan · 6 round · 12 match · 1 WO',
      ),
    ),
  ],
  '13r': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Fixed · 4 Nov 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '7'),
          PodiumBlockData(level: 2, face: '5'),
        ],
        rows: [
          PodiumRowData(badge: '7', hash: false, gold: true, names: ['PB Garuda'], value: '56', detail: 'game · +13'),
          PodiumRowData(
            badge: '5',
            hash: false,
            gold: false,
            names: ['Matcha Club'],
            value: '49',
            detail: 'game · −13',
          ),
        ],
        facts: '7 pasangan · 6 round · 12 match · 1 WO',
      ),
    ),
  ],
  '18a': [
    PodiumFrameCase(
      'tennis',
      PodiumPosterData(
        sport: SportType.tennis,
        title: 'Klasemen akhir',
        subtitle: 'Tennis · Fixed · 30 Okt 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 2),
          PodiumBlockData(level: 1, face: '1', balls: 2),
          PodiumBlockData(level: 3, face: '3', balls: 2),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Indra Wijaya', 'Joko Susilo'], value: '100%', detail: '· +19'),
          PodiumRowData(badge: '2', gold: false, names: ['Eko Mulyadi', 'Fajar Kurnia'], value: '80%', detail: '· +10'),
          PodiumRowData(
            badge: '3',
            gold: false,
            names: ['Citra Lestari', 'Dewant Rahman'],
            value: '60%',
            detail: '· +3',
          ),
        ],
        pairSize: true,
        facts: '6 pasangan · 5 round · 15 match',
      ),
    ),
  ],
  '18b': [
    PodiumFrameCase(
      'nude',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
  ],
  '18c': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
  ],
  '18d': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Mixed · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: '12 pemain · 6 round · 18 match',
      ),
    ),
  ],
  '18e': [
    PodiumFrameCase(
      'tennis',
      PodiumPosterData(
        sport: SportType.tennis,
        title: 'Klasemen akhir',
        subtitle: 'Tennis · Fixed · 30 Okt 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 2),
          PodiumBlockData(level: 1, face: '1', balls: 2),
          PodiumBlockData(level: 3, face: '3', balls: 2),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Indra Wijaya', 'Joko Susilo'], value: '100%', detail: '· +19'),
          PodiumRowData(badge: '2', gold: false, names: ['Eko Mulyadi', 'Fajar Kurnia'], value: '80%', detail: '· +10'),
          PodiumRowData(
            badge: '3',
            gold: false,
            names: ['Citra Lestari', 'Dewant Rahman'],
            value: '60%',
            detail: '· +3',
          ),
        ],
        pairSize: true,
        facts: '6 pasangan · 5 round · 15 match',
      ),
    ),
  ],
  '18f': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Mixed · 28 Okt 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Eko Mulyadi'], value: '61', detail: 'poin · +17'),
          PodiumRowData(badge: '2', gold: false, names: ['Fajar Kurnia'], value: '58', detail: 'poin · +11'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '58', detail: 'poin · +11'),
        ],
        facts: '8 pemain · 5 round · 10 match',
      ),
    ),
  ],
  '18g': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Mixed · 23 Okt 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Budi Santoso'], value: '60', detail: 'poin · +15'),
          PodiumRowData(badge: '1', gold: true, names: ['Dewant Rahman'], value: '60', detail: 'poin · +15'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '57', detail: 'poin · +9'),
        ],
        facts: '8 pemain · 5 round · 10 match',
      ),
    ),
  ],
  '18h': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Mixed · 25 Okt 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Andi Pratama'], value: '62', detail: 'poin · +19'),
          PodiumRowData(badge: '2', gold: false, names: ['Citra Lestari'], value: '59', detail: 'poin · +13'),
          PodiumRowData(badge: '3', gold: false, names: ['Eko Mulyadi'], value: '56', detail: 'poin · +7'),
          PodiumRowData(badge: '3', gold: false, names: ['Hana Taslim'], value: '56', detail: 'poin · +7'),
        ],
        facts: '8 pemain · 5 round · 10 match',
      ),
    ),
  ],
  '18i': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Mixed · 2 Nov 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Joko Susilo'], value: '78', detail: 'poin · +30'),
          PodiumRowData(badge: '2', gold: false, names: ['Andi Pratama'], value: '74', detail: 'poin · +22'),
        ],
        facts: '12 pemain · 6 round · 18 match',
      ),
    ),
  ],
  '18j': [
    PodiumFrameCase(
      'tennis',
      PodiumPosterData(
        sport: SportType.tennis,
        title: 'Klasemen akhir',
        subtitle: 'Tennis · Fixed · 1 Nov 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '1', balls: 2),
          PodiumBlockData(level: 2, face: '2', balls: 2),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Andi Pratama', 'Budi Santoso'], value: '67%', detail: '· +3'),
          PodiumRowData(
            badge: '2',
            gold: false,
            names: ['Citra Lestari', 'Dewant Rahman'],
            value: '33%',
            detail: '· −3',
          ),
        ],
        pairSize: true,
        facts: '2 pasangan · 3 round · 3 match',
      ),
    ),
  ],
  '18k': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen sementara · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Gina Rosalia'], value: '41', detail: 'poin · +19'),
          PodiumRowData(badge: '2', gold: false, names: ['Joko Susilo'], value: '35', detail: 'poin · +7'),
          PodiumRowData(badge: '3', gold: false, names: ['Hana Taslim'], value: '28', detail: 'poin · +14'),
        ],
        facts: 'Padel · 12 pemain · R3 · 7 dari 9 match',
      ),
    ),
  ],
  '18l': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Fixed · 3 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 2),
          PodiumBlockData(level: 3, face: '3', balls: 2),
        ],
        rows: [
          PodiumRowData(
            badge: '1',
            gold: true,
            names: ['Indra Wijaya', 'Joko Susilo'],
            value: '95',
            detail: 'poin · +22',
          ),
          PodiumRowData(badge: '2', gold: false, names: ['Andi Pratama'], value: '91', detail: 'poin · +14'),
          PodiumRowData(
            badge: '3',
            gold: false,
            names: ['Eko Mulyadi', 'Fajar Kurnia'],
            value: '89',
            detail: 'poin · +10',
          ),
        ],
        pairSize: true,
        facts: '16 round · 32 match',
      ),
    ),
  ],
  '18m': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda x Matcha Club 2026',
        subtitle: 'Klasemen akhir · 30 Okt 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 2),
          PodiumBlockData(level: 1, face: '1', balls: 2),
          PodiumBlockData(level: 3, face: '3', balls: 2),
        ],
        rows: [
          PodiumRowData(
            badge: '1',
            gold: true,
            names: ['Maximilian Hendrawan Putra', 'Christopher Situmorang'],
            value: '43',
            detail: 'poin · +23',
          ),
          PodiumRowData(
            badge: '2',
            gold: false,
            names: ['Anastasia Kusumawardhani', 'Bernadetta Simanjuntak'],
            value: '29',
            detail: 'poin · −5',
          ),
          PodiumRowData(
            badge: '3',
            gold: false,
            names: ['Fransiskus Pangaribuan', 'Yohanes Tampubolon'],
            value: '28',
            detail: 'poin · −7',
          ),
        ],
        pairSize: true,
        facts: 'Padel · 4 pasangan · 3 round · 6 match',
      ),
    ),
  ],
  '18n': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Fixed · 4 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '5'),
          PodiumBlockData(level: 1, face: '7'),
        ],
        rows: [
          PodiumRowData(badge: '5', hash: false, gold: false, names: ['PB Garuda'], value: '56', detail: 'game · −4'),
          PodiumRowData(badge: '7', hash: false, gold: true, names: ['Matcha Club'], value: '60', detail: 'game · +4'),
        ],
        facts: '7 pasangan · 6 round · 12 match',
      ),
    ),
  ],
  '18o': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Fixed · 4 Nov 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '6'),
          PodiumBlockData(level: 1, face: '6'),
        ],
        rows: [
          PodiumRowData(badge: '6', hash: false, gold: true, names: ['PB Garuda'], value: '58', detail: 'game · 0'),
          PodiumRowData(badge: '6', hash: false, gold: true, names: ['Matcha Club'], value: '58', detail: 'game · 0'),
        ],
        facts: '7 pasangan · 6 round · 12 match',
      ),
    ),
  ],
  '18p': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Fixed · 4 Nov 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '6½'),
          PodiumBlockData(level: 2, face: '5½'),
        ],
        rows: [
          PodiumRowData(badge: '6½', hash: false, gold: true, names: ['PB Garuda'], value: '122', detail: 'poin · +4'),
          PodiumRowData(
            badge: '5½',
            hash: false,
            gold: false,
            names: ['Matcha Club'],
            value: '118',
            detail: 'poin · −4',
          ),
        ],
        facts: '7 pasangan · 6 round · 12 match',
      ),
    ),
  ],
  '18q': [
    PodiumFrameCase(
      'tennis',
      PodiumPosterData(
        sport: SportType.tennis,
        title: 'Klasemen sementara',
        subtitle: 'Tennis · Fixed · 31 Okt 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '1', balls: 2),
          PodiumBlockData(level: 1, face: '1', balls: 2),
          PodiumBlockData(level: 1, face: '1', balls: 2),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Andi Pratama', 'Budi Santoso'], value: '100%', detail: '· +2'),
          PodiumRowData(badge: '1', gold: true, names: ['Eko Mulyadi', 'Fajar Kurnia'], value: '100%', detail: '· +2'),
          PodiumRowData(badge: '1', gold: true, names: ['Indra Wijaya', 'Joko Susilo'], value: '100%', detail: '· +2'),
        ],
        pairSize: true,
        facts: '6 pasangan · R1 · 3 dari 3 match',
      ),
    ),
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen sementara',
        subtitle: 'Padel · Mixed · 5 Nov 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Andi Pratama'], value: '12', detail: 'poin · +3'),
          PodiumRowData(badge: '1', gold: true, names: ['Citra Lestari'], value: '12', detail: 'poin · +3'),
          PodiumRowData(badge: '1', gold: true, names: ['Eko Mulyadi'], value: '12', detail: 'poin · +3'),
          PodiumRowData(badge: '1', gold: true, names: ['Gina Rosalia'], value: '12', detail: 'poin · +3'),
        ],
        facts: '8 pemain · R1 · 2 dari 2 match',
      ),
    ),
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Mixed · 26 Okt 2026',
        blocks: [
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Budi Santoso'], value: '60', detail: 'poin · +15'),
          PodiumRowData(badge: '1', gold: true, names: ['Maya Putri'], value: '60', detail: 'poin · +15'),
          PodiumRowData(badge: '2', gold: false, names: ['Oki Setiawan'], value: '55', detail: 'poin · +5'),
          PodiumRowData(badge: '2', gold: false, names: ['Rizky Hidayat'], value: '55', detail: 'poin · +5'),
        ],
        facts: '8 pemain · 5 round · 10 match',
      ),
    ),
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Mixed · 27 Okt 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 2, face: '2', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Nanda Rizki'], value: '63', detail: 'poin · +21'),
          PodiumRowData(badge: '2', gold: false, names: ['Kiki Amalia'], value: '56', detail: 'poin · +7'),
          PodiumRowData(badge: '2', gold: false, names: ['Putri Anggraini'], value: '56', detail: 'poin · +7'),
          PodiumRowData(badge: '2', gold: false, names: ['Hana Taslim'], value: '56', detail: 'poin · +7'),
        ],
        facts: '8 pemain · 5 round · 10 match',
      ),
    ),
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Klasemen akhir',
        subtitle: 'Padel · Mixed · 29 Okt 2026',
        blocks: [PodiumBlockData(level: 1, face: '1', balls: 1)],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Lina Marlina'], value: '64', detail: 'poin · +23'),
        ],
        facts: '8 pemain · 5 round · 10 match',
      ),
    ),
  ],
  '18r': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'tennis',
      PodiumPosterData(
        sport: SportType.tennis,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Tennis · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'hijau',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'biru',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'ungu',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'jingga',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'teal',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'malam',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'peach',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'nude',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'sage',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
    PodiumFrameCase(
      'lilac',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen akhir · 6 Nov 2026',
        blocks: [
          PodiumBlockData(level: 2, face: '2', balls: 1),
          PodiumBlockData(level: 1, face: '1', balls: 1),
          PodiumBlockData(level: 3, face: '3', balls: 1),
        ],
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['Hana Taslim'], value: '80', detail: 'poin · +34'),
          PodiumRowData(badge: '2', gold: false, names: ['Gina Rosalia'], value: '76', detail: 'poin · +26'),
          PodiumRowData(badge: '3', gold: false, names: ['Fajar Kurnia'], value: '69', detail: 'poin · +12'),
        ],
        facts: 'Padel · 12 pemain · 6 round · 18 match',
      ),
    ),
  ],
  '18s': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen sementara · 6 Nov 2026',
        blocks: [PodiumBlockData(level: 1, face: '1')],
        wide: true,
        rows: [
          PodiumRowData(badge: '1', gold: true, names: ['6 pemain'], value: '12', detail: 'poin · +3'),
        ],
        facts: 'Padel · 12 pemain · R1 · 3 dari 3 match',
      ),
    ),
  ],
  '18t': [
    PodiumFrameCase(
      'padel',
      PodiumPosterData(
        sport: SportType.padel,
        title: 'Mabar Jumat PB Garuda',
        subtitle: 'Klasemen sementara · 6 Nov 2026',
        facts: 'Padel · 12 pemain · R1 · 0 dari 3 match',
      ),
    ),
  ],
};
