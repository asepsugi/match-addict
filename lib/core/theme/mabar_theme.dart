import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Token desain v2 dari `design/spec/tokens.json` (hi-fi → Fondasi). Satu tema terang berkontras
/// tinggi untuk dipakai di bawah matahari; warnanya diambil dari lapangan.
class MabarColors {
  /// Identitas: lapangan tennis di Beranda, ikon app, tautan, fokus input.
  static const court = Color(0xFF1E6BB8);

  /// Run-off di luar garis lapangan Beranda, tennis maupun padel.
  static const courtDeep = Color(0xFF164E8C);

  /// Permukaan lapangan padel di Beranda, dan hanya di situ. Bukan [clay]: tidak pernah untuk aksi
  /// atau status.
  static const padel = Color(0xFFBC5A33);

  /// Teks utama, tombol utama, papan skor, menu terpilih.
  static const ink = Color(0xFF0F1E2C);

  /// Teks kedua, ikon.
  static const ink2 = Color(0xFF3E4B57);

  /// Keterangan kecil; lulus 4,5:1 di [paper] dan [card].
  static const ink3 = Color(0xFF5F6D7A);

  /// Chevron, state mati. Bukan untuk teks yang harus dibaca dan bukan placeholder (placeholder = [ink3], PATCH 3.8.1).
  static const faint = Color(0xFF9AA6B1);

  /// Tepi semua isian yang tidak fokus, kosong maupun terisi, 1,5 pt (3,14:1 di [paper]); PATCH 3.8.1.
  static const edge = Color(0xFF7D8A96);

  /// Hanya yang sedang berlangsung: round live, angka yang sedang diisi, penanda pemenang,
  /// peringkat 1. Tidak pernah sebagai teks di latar terang.
  static const ball = Color(0xFFCDE84A);
  static const ballEdge = Color(0xFFA8C233);

  /// WO, akhiri, keluarkan, error validasi.
  static const clay = Color(0xFFB9482A);

  /// Latar layar.
  static const paper = Color(0xFFEEF2F5);

  /// Grup, baris match, sheet, dialog.
  static const card = Color(0xFFFFFFFF);

  /// Pemisah baris. Bukan tepi isian (isian: [edge]).
  static const line = Color(0xFFDCE3E9);

  /// Track segmented, tombol stepper, tombol mati.
  static const fill = Color(0xFFE3E9EE);

  /// Ikon/angka yang mati di atas latar terang: tombol stepper di batas, tombol keypad mati, item menu
  /// mati, strip court match yang tidak dimainkan. `#C3CCD4` di CSS hi-fi (tidak ada di tokens.json).
  static const off = Color(0xFFC3CCD4);

  /// Teks/tanda yang belum aktif: tab round di depan, aksi baris mati, titik tag "Offline" (12m). `#B3BEC8` di
  /// CSS hi-fi (tidak ada di tokens.json).
  static const dim = Color(0xFFB3BEC8);

  /// [ink] 46% di belakang sheet dan dialog — keduanya tanpa bayangan, scrim inilah pemisahnya.
  static const scrim = Color(0x750F1E2C);

  /// Lencana #1 di kartu/gambar Bagikan saja, tulisan [ink] di atasnya (teks emas gagal kontras).
  static const gold = Color(0xFFE3B341);

  /// 10 warna court, diputar per court. Semua cukup gelap untuk nomor court putih tebal.
  static const List<Color> courtPalette = [
    Color(0xFF2F8F5B),
    Color(0xFFC4532D),
    Color(0xFF1E6BB8),
    Color(0xFFC77422),
    Color(0xFF7A4FB5),
    Color(0xFF1B8A9A),
    Color(0xFFC2457A),
    Color(0xFF6B8A2A),
    Color(0xFF4A5BC4),
    Color(0xFF5B6B7A),
  ];
}

/// Grid 4 pt. Gutter layar = [x4].
class MabarSpacing {
  static const double x1 = 4;
  static const double x2 = 8;
  static const double x3 = 12;
  static const double x4 = 16;
  static const double x5 = 20;
  static const double x6 = 24;
  static const double x8 = 32;
}

class MabarRadius {
  /// Chip, `.rowact`, tombol stepper, kotak isian sebaris.
  static const double chip = 9;
  static const double smallButton = 10;
  static const double button = 12;

  /// Grup pengaturan dan baris match.
  static const double group = 12;
  static const double menu = 14;

  /// Kartu pratinjau Bagikan (`.poster`).
  static const double poster = 14;
  static const double scoreBoard = 16;
  static const double dialog = 18;
  static const double sheet = 22;
  static const double homePanel = 24;
}

/// Tinggi sentuh dan ukuran ikon.
class MabarSize {
  static const double primaryButton = 52;
  static const double row = 52;
  static const double smallButton = 40;
  static const double iconButton = 44;
  static const double iconButtonInActionBar = 52;
  static const double keypadKey = 54;
  static const double rowAction = 36;
  static const double chipCols = 44;
  static const double rosterRow = 40;
  static const double pairRow = 40;
  static const double rankRow = 44;

  /// Area ketuk minimal semua kontrol; tampilan tetap (PATCH 3.8.1). Ikon tukar 44 × 42 dikecualikan (keputusan 48–57).
  static const double tapTarget = 48;

  /// Ikon mandiri (header, menu, action bar).
  static const double icon = 24;

  /// Ikon di dalam tombol berlabel.
  static const double iconInButton = 20;
}

/// Bayangan hanya untuk dua lapisan yang melayang tanpa scrim; kartu, sheet, dan dialog tidak punya.
///
/// Blur CSS b setara sigma b/2, sedangkan `BoxShadow.blurRadius` r memakai sigma 0,57735·r + 0,5 —
/// karena itu angkanya dikonversi, bukan disalin.
class MabarShadows {
  static const _ink20 = Color(0x330F1E2C);

  /// `.homepanel`: panel bawah Beranda yang menimpa lapangan.
  static const panel = [BoxShadow(color: _ink20, offset: Offset(0, -12), blurRadius: (32 / 2 - 0.5) / 0.57735)];

  /// `.menu`: menu ⋯ Jadwal, termasuk garis tepinya.
  static const menu = [
    BoxShadow(color: _ink20, offset: Offset(0, 16), blurRadius: (40 / 2 - 0.5) / 0.57735),
    BoxShadow(color: MabarColors.line, spreadRadius: 1),
  ];
}

/// Skala huruf Archivo variabel. Lebar (`wdth`) dipakai sebagai alat: condensed untuk angka, normal
/// untuk teks, lebar untuk wordmark. Berat cukup lewat `fontWeight` (diteruskan ke sumbu `wght`).
/// Tinggi baris yang tidak ditulis hi-fi mewarisi 1,4 dari `.app`.
///
/// Tiap gaya membawa [family] sendiri: `ButtonStyle.textStyle`, judul dialog, dan isi snackbar
/// *mengganti* gaya teks tema, bukan menggabungkannya, jadi tanpa itu font jatuh ke Roboto/SF. Semua
/// memakai `leadingDistribution: even` — cara CSS membagi line-height (setengah di atas, setengah di
/// bawah); default Flutter (`proportional`) menggeser teks di tombol `16px/1` dan sejenisnya.
class MabarType {
  static const family = 'Archivo';
  static const _even = TextLeadingDistribution.even;

  /// `font-stretch: 72%` + tabular — kelas `.n` di hi-fi, dipakai semua angka besar.
  static const numVariations = [FontVariation('wdth', 72)];
  static const tabular = [FontFeature.tabularFigures()];
  static const _titleWidth = [FontVariation('wdth', 95)];

  static const wordmark = TextStyle(
    fontFamily: family,
    leadingDistribution: _even,
    fontSize: 28,
    fontWeight: FontWeight.w800,
    fontVariations: [FontVariation('wdth', 125)],
    height: 1,
    letterSpacing: -0.28,
  );
  static const scoreXl = TextStyle(
    fontFamily: family,
    leadingDistribution: _even,
    fontSize: 76,
    fontWeight: FontWeight.w800,
    fontVariations: numVariations,
    fontFeatures: tabular,
    height: 0.9,
  );
  static const scoreL = TextStyle(
    fontFamily: family,
    leadingDistribution: _even,
    fontSize: 54,
    fontWeight: FontWeight.w800,
    fontVariations: numVariations,
    fontFeatures: tabular,
    height: 0.88,
  );
  static const numM = TextStyle(
    fontFamily: family,
    leadingDistribution: _even,
    fontSize: 22,
    fontWeight: FontWeight.w800,
    fontVariations: numVariations,
    fontFeatures: tabular,
    height: 1.4,
  );
  static const titleL = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 30, fontWeight: FontWeight.w800, fontVariations: _titleWidth, height: 1.1);
  static const title = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 22, fontWeight: FontWeight.w800, fontVariations: _titleWidth, height: 1.15);
  static const sheetTitle = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 21, fontWeight: FontWeight.w800, fontVariations: _titleWidth, height: 1.4);
  static const dialogTitle = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 19, fontWeight: FontWeight.w800, height: 1.4);
  static const body = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 16, fontWeight: FontWeight.w400, height: 1.4);
  static const label = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 13, fontWeight: FontWeight.w700, height: 1.4, color: MabarColors.ink3);
  static const caption = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 13, fontWeight: FontWeight.w400, height: 1.4, color: MabarColors.ink3);

  /// Label tombol `.btn` (700 16/1).
  static const button = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 16, fontWeight: FontWeight.w700, height: 1);

  /// `.txtbtn` (700 15/1).
  static const textButton = TextStyle(fontFamily: family, leadingDistribution: _even, fontSize: 15, fontWeight: FontWeight.w700, height: 1);
}

class MabarTheme {
  /// Ikon status bar gelap — latar semua layar terang ([MabarColors.paper]).
  static const statusBarDark = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.dark, // Android
    statusBarBrightness: Brightness.light, // iOS
  );

  /// Ikon status bar putih — untuk Beranda, yang lapangannya naik sampai di bawah status bar.
  static const statusBarLight = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light, // Android
    statusBarBrightness: Brightness.dark, // iOS
  );

  /// Slot Material dipetakan ke skala [MabarType]. `letterSpacing` dan `height` ditulis di semua slot:
  /// kalau dibiarkan null, geometri Material 3 (tracking 0,1–0,5, tinggi baris sendiri) ikut masuk,
  /// padahal hi-fi tidak memakai tracking sama sekali.
  static TextTheme _textTheme() {
    TextStyle ink(TextStyle s) => s.copyWith(color: s.color ?? MabarColors.ink, letterSpacing: s.letterSpacing ?? 0);
    return TextTheme(
      displayLarge: ink(MabarType.scoreXl),
      displayMedium: ink(MabarType.scoreL),
      displaySmall: ink(MabarType.numM),
      headlineLarge: ink(MabarType.titleL),
      headlineMedium: ink(MabarType.title),
      headlineSmall: ink(MabarType.dialogTitle), // judul AlertDialog
      titleLarge: ink(MabarType.title),
      titleMedium: ink(MabarType.body.copyWith(fontWeight: FontWeight.w700)),
      titleSmall: ink(MabarType.label),
      bodyLarge: ink(MabarType.body), // isi TextField
      bodyMedium: ink(MabarType.body), // DefaultTextStyle
      bodySmall: ink(MabarType.caption),
      labelLarge: ink(MabarType.button), // label tombol
      labelMedium: ink(MabarType.label),
      labelSmall: ink(MabarType.label.copyWith(fontSize: 12)),
    );
  }

  static ThemeData light() {
    final buttonShape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(MabarRadius.button));
    final fieldShape = BorderRadius.circular(MabarRadius.button);

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      fontFamily: MabarType.family,
      scaffoldBackgroundColor: MabarColors.paper,
      // Diisi tangan, bukan fromSeed: seed menurunkan warna tonal yang tidak ada di hi-fi.
      colorScheme: const ColorScheme.light(
        primary: MabarColors.court, // tautan, fokus, kursor
        onPrimary: Colors.white,
        secondary: MabarColors.ink,
        onSecondary: Colors.white,
        error: MabarColors.clay,
        onError: Colors.white,
        surface: MabarColors.card,
        onSurface: MabarColors.ink,
        onSurfaceVariant: MabarColors.ink3,
        surfaceContainerLowest: MabarColors.card,
        surfaceContainerLow: MabarColors.card,
        surfaceContainer: MabarColors.card,
        surfaceContainerHigh: MabarColors.card,
        surfaceContainerHighest: MabarColors.fill,
        surfaceTint: Colors.transparent,
        outline: MabarColors.line,
        outlineVariant: MabarColors.line,
        scrim: MabarColors.scrim,
      ),
      textTheme: _textTheme(),
      iconTheme: const IconThemeData(color: MabarColors.ink2, size: MabarSize.icon),
      dividerTheme: const DividerThemeData(color: MabarColors.line, thickness: 1),
      // .btn-primary; mati = .btn-off
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: MabarColors.ink,
          foregroundColor: Colors.white,
          disabledBackgroundColor: MabarColors.fill,
          disabledForegroundColor: MabarColors.faint,
          minimumSize: const Size.fromHeight(MabarSize.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: MabarSpacing.x5),
          shape: buttonShape,
          textStyle: MabarType.button,
          iconSize: MabarSize.iconInButton,
          elevation: 0,
        ),
      ),
      // .btn-secondary
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          backgroundColor: MabarColors.card,
          foregroundColor: MabarColors.ink,
          disabledForegroundColor: MabarColors.faint,
          minimumSize: const Size.fromHeight(MabarSize.primaryButton),
          padding: const EdgeInsets.symmetric(horizontal: MabarSpacing.x5),
          shape: buttonShape,
          side: const BorderSide(color: MabarColors.line, width: 1.5),
          textStyle: MabarType.button,
          iconSize: MabarSize.iconInButton,
        ),
      ),
      // .txtbtn
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: MabarColors.court,
          disabledForegroundColor: MabarColors.faint,
          minimumSize: const Size(0, MabarSize.iconButton),
          padding: const EdgeInsets.symmetric(horizontal: 10),
          textStyle: MabarType.textButton,
          iconSize: MabarSize.iconInButton,
        ),
      ),
      // .field: tepi 1.5 edge, fokus 2 court, error 2 clay
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MabarColors.card,
        contentPadding: const EdgeInsets.symmetric(horizontal: MabarSpacing.x4, vertical: 14),
        border: OutlineInputBorder(borderRadius: fieldShape, borderSide: const BorderSide(color: MabarColors.edge, width: 1.5)),
        enabledBorder: OutlineInputBorder(borderRadius: fieldShape, borderSide: const BorderSide(color: MabarColors.edge, width: 1.5)),
        focusedBorder: OutlineInputBorder(borderRadius: fieldShape, borderSide: const BorderSide(color: MabarColors.court, width: 2)),
        errorBorder: OutlineInputBorder(borderRadius: fieldShape, borderSide: const BorderSide(color: MabarColors.clay, width: 2)),
        focusedErrorBorder: OutlineInputBorder(borderRadius: fieldShape, borderSide: const BorderSide(color: MabarColors.clay, width: 2)),
        hintStyle: MabarType.body.copyWith(color: MabarColors.ink3),
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: MabarColors.court,
        selectionColor: MabarColors.court.withValues(alpha: 0.24),
        selectionHandleColor: MabarColors.court,
      ),
      // .dialog: tanpa bayangan, dipisahkan scrim
      dialogTheme: DialogThemeData(
        backgroundColor: MabarColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MabarRadius.dialog)),
        barrierColor: MabarColors.scrim,
        titleTextStyle: MabarType.dialogTitle.copyWith(color: MabarColors.ink, letterSpacing: 0),
        contentTextStyle: MabarType.body.copyWith(fontSize: 15, height: 1.5, color: MabarColors.ink2, letterSpacing: 0),
      ),
      // .sheet
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: MabarColors.card,
        modalBackgroundColor: MabarColors.card,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        modalElevation: 0,
        modalBarrierColor: MabarColors.scrim,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(MabarRadius.sheet))),
        dragHandleColor: MabarColors.line,
        dragHandleSize: Size(38, 5),
      ),
      // .toast
      snackBarTheme: SnackBarThemeData(
        backgroundColor: MabarColors.ink,
        contentTextStyle: MabarType.body.copyWith(fontSize: 15, color: Colors.white, letterSpacing: 0),
        behavior: SnackBarBehavior.floating,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(MabarRadius.button)),
      ),
    );
  }
}
