# Komponen

> Dihasilkan `tool/hifi_extract.py`. Aturan CSS disalin apa adanya dari hi-fi; itu ukuran yang harus dicapai.
> Nama widget adalah usulan untuk fondasi. Penjelasan desain tiap komponen ada di bagian "Komponen" hi-fi.

## `MabarAppBar`

Judul rata kiri + subjudul fakta, tombol kembali, aksi kanan.

Kelas hi-fi: `.appbar`, `.large-title`  
Dipakai di frame: 02a, 02b, 02c, 02d, 03a, 03b, 03c, 03d, 03e, 03f, 03g, 03h, 03i, 03j, 03k, 03l, 03m, 03n, 03o, 03p, 03q, 04a, 04b, 04c, 04d, 04e, 04f, 04g, 04h, 06a, 06b, 06c, 06d, 06e, 06v, 06w, 06x, 06y, 06z, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08b, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 07a, 07b, 07c, 07d, 07e, 07f, 07g, 07h, 07i, 07j, 07k, 07l, 07m, 07n, 07o, 09a, 09b, 09c, 09d, 09e, 09f, 09g, 10a, 10b, 10c, 10d, 11a, 11b, 11c, 11e, 11h, 11i, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12h, 12i, 12j, 12k, 12l, 12m, 12n, 12o, 13a, 13b, 13c, 13d, 13e, 13f, 13g, 13h, 13i, 13j, 13k, 13l, 13m, 13n, 13o, 13p, 13q, 13s, 13u, 14a, 14b, 14c, 14d, 14e, 14f, 14g, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 14o, 14p, 14s, 14t, 14u, 14q, 14r, 14v, 14w, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 15q, 15r, 15s, 15t, 15u, 15v, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.appbar { display: flex; align-items: center; gap: 6px; padding: 54px 12px 12px 6px; }
.appbar .t { flex: 1; min-width: 0; }
.appbar h1 { margin: 0; font-size: 22px; font-weight: 800; font-stretch: 95%; line-height: 1.15; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.appbar .t p { font-size: 13px; color: var(--ink-3); margin-top: 2px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.appbar.no-back { padding-left: 16px; }
.appbar.scrolled { box-shadow: 0 1px 0 var(--line); position: relative; z-index: 1; }
.large-title { padding: 54px 16px 4px; }
.large-title h1 { margin: 0; font-size: 30px; font-weight: 800; font-stretch: 95%; line-height: 1.1; }
```

## `MabarButton`

Varian primary · ball · secondary · danger · ghost · wait · off · sm.

Kelas hi-fi: `.btn`  
Dipakai di frame: 01a, 01b, 01c, 01d, 01e, 01f, 01h, 01i, 02a, 02b, 02c, 02d, 03a, 03b, 03c, 03d, 03e, 03f, 03g, 03h, 03i, 03j, 03k, 03l, 03m, 03n, 03o, 03p, 03q, 04a, 04b, 04c, 04d, 04e, 04f, 04g, 04h, 06a, 06b, 06c, 06d, 06e, 06v, 06w, 06x, 06y, 06z, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08b, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 07a, 07b, 07c, 07d, 07e, 07f, 07g, 07h, 07i, 07j, 07k, 07l, 07m, 07n, 07o, 09a, 09b, 09c, 09d, 09e, 09f, 09g, 11a, 11b, 11c, 11e, 11h, 11i, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12h, 12i, 12l, 12m, 12n, 13a, 13b, 13c, 13d, 13e, 13f, 13g, 13h, 13i, 13j, 13k, 13l, 13m, 13n, 13o, 13p, 13q, 13s, 13u, 14a, 14b, 14c, 14d, 14e, 14f, 14g, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 14o, 14p, 14s, 14t, 14u, 14q, 14r, 14x, 14y, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 15q, 15r, 15s, 15t, 15w, 15x, 15y, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.btn { height: 52px; min-height: 52px; border-radius: 12px; padding: 0 20px; font: 700 16px/1 var(--f); display: flex; align-items: center; justify-content: center; gap: 8px; border: 0; flex: 1; min-width: 0; white-space: nowrap; }
.btn .meta { font-weight: 500; opacity: .62; }
.btn-primary { background: var(--ink); color: #fff; }
.btn-ball { background: var(--ball); color: var(--ink); }
.btn-secondary { background: var(--card); color: var(--ink); box-shadow: inset 0 0 0 1.5px var(--line); }
.btn-danger { background: var(--clay); color: #fff; }
.btn-ghost { background: transparent; color: var(--court); }
.btn-wait { background: transparent; color: var(--ink-3); border: 1.5px dashed #BFCAD3; }
.btn-off { background: var(--fill); color: var(--faint); }
.btn-sm { height: 40px; min-height: 40px; font-size: 14px; padding: 0 14px; border-radius: 10px; flex: none; }
.actionbar.col > .btn { flex: none; }
.liveblock .btn { flex: none; height: 46px; min-height: 46px; }
```

## `MabarTextButton`

Aksi teks 44 pt, biru court / clay.

Kelas hi-fi: `.txtbtn`  
Dipakai di frame: 01h, 02a, 02b, 02c, 02d, 04a, 04b, 04c, 04d, 04e, 04f, 04g, 06e, 06j, 08h, 07a, 07b, 07c, 07d, 07e, 07f, 07g, 07h, 07i, 07j, 07k, 07l, 07m, 07n, 07o, 12b, 12c, 12d, 12e, 13a, 13b, 13c, 13d, 13e, 13f, 13g, 14a, 14b, 14c, 14d, 14e, 14k, 14o, 14q, 14r, 14y, 15c, 15h, 15q, 15r, 15y, 16e

```css
.txtbtn { display: inline-flex; align-items: center; justify-content: center; gap: 6px; height: 44px; padding: 0 10px; font: 700 15px/1 var(--f); color: var(--court); background: none; border: 0; flex: none; white-space: nowrap; }
.txtbtn.danger { color: var(--clay); }
.dactions .txtbtn { color: var(--ink-2); }
.dactions .txtbtn.go { color: var(--court); }
.dactions .txtbtn.danger { color: var(--clay); }
.ghead .txtbtn { margin-right: -6px; }
```

## `MabarIconButton`

Tombol ikon 44 pt (52 di action bar), opsional angka kecil.

Kelas hi-fi: `.icbtn`  
Dipakai di frame: 02a, 02b, 02c, 02d, 03a, 03b, 03c, 03d, 03e, 03f, 03g, 03h, 03i, 03j, 03k, 03l, 03m, 03n, 03o, 03p, 03q, 04a, 04b, 04c, 04d, 04e, 04f, 04g, 04h, 06a, 06b, 06c, 06d, 06e, 06v, 06w, 06x, 06y, 06z, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08b, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 07a, 07b, 07c, 07d, 07e, 07f, 07g, 07h, 07i, 07j, 07k, 07l, 07m, 07n, 07o, 09a, 09b, 09c, 09d, 09e, 09f, 09g, 10a, 10b, 10c, 10d, 11a, 11b, 11c, 11e, 11h, 11i, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12j, 12k, 13a, 13b, 13c, 13d, 13e, 13f, 13g, 13h, 13i, 13j, 13k, 13l, 13m, 13n, 13o, 13p, 13q, 13s, 13u, 14a, 14b, 14c, 14d, 14e, 14f, 14g, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 14o, 14p, 14s, 14t, 14u, 14q, 14r, 14v, 14w, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 15q, 15r, 15s, 15t, 15u, 15v, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.icbtn { width: 44px; height: 44px; border-radius: 12px; display: grid; place-items: center; color: var(--ink-2); background: transparent; border: 0; padding: 0; position: relative; flex: none; }
.icbtn.solid { background: var(--card); width: 52px; height: 52px; }
.icbtn .count { position: absolute; top: 5px; right: 6px; font-size: 11px; font-weight: 800; font-stretch: 80%; color: var(--ink-3); }
```

## `MabarRowAction`

Aksi di ujung baris daftar, 36 pt, area sentuh 44.

Kelas hi-fi: `.rowact`  
Dipakai di frame: 04f, 04g, 08a, 08b, 14o, 15l, 15m, 16f, 16g

```css
.rowact { display: inline-flex; align-items: center; justify-content: center; height: 36px; padding: 0 14px; border-radius: 9px; background: var(--card); box-shadow: inset 0 0 0 1px var(--line); font: 600 14px/1 var(--f); color: var(--ink-2); flex: none; white-space: nowrap; }
.rowact.go { color: var(--court); }
.rowact.off { color: #B3BEC8; background: transparent; }
```

## `MabarActionBar`

Bilah tombol menempel di bawah, garis tipis di atas, safe area 34.

Kelas hi-fi: `.actionbar`  
Dipakai di frame: 02a, 02b, 02c, 02d, 03a, 03b, 03c, 03d, 03e, 03f, 03g, 03h, 03i, 03j, 03k, 03l, 03m, 03n, 03o, 03p, 03q, 04a, 04b, 04c, 04d, 04e, 04f, 04g, 04h, 06a, 06b, 06c, 06d, 06e, 06v, 06w, 06x, 06y, 06z, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08b, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 09a, 09b, 09c, 09d, 09e, 09f, 09g, 11a, 11b, 11c, 11e, 11h, 11i, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12h, 12i, 12l, 12m, 13a, 13b, 13c, 13d, 13e, 13f, 13g, 13h, 13i, 13j, 13k, 13l, 13m, 13n, 13o, 13p, 13q, 13s, 13u, 14a, 14b, 14c, 14d, 14e, 14f, 14g, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 14o, 14p, 14s, 14t, 14u, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 15s, 15t, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.actionbar { margin-top: auto; padding: 12px 16px 34px; display: flex; gap: 10px; background: var(--paper); border-top: 1px solid var(--line); flex: none; }
.actionbar.col { flex-direction: column; }
.actionbar.col > .btn { flex: none; }
.actionbar .row2 { display: flex; gap: 10px; }
```

## `MabarGroup / MabarRow`

Daftar bergaya pengaturan + label dan catatan grup.

Kelas hi-fi: `.group`, `.row`, `.glabel`, `.gnote`  
Dipakai di frame: 01a, 01b, 01c, 01i, 02b, 02c, 02d, 03a, 03b, 03c, 03d, 03e, 03f, 03g, 03h, 03i, 03j, 03k, 03l, 03m, 03n, 03o, 03p, 03q, 04a, 04b, 04c, 04d, 04e, 04f, 04g, 04h, 06a, 06b, 06c, 06d, 06e, 06w, 06x, 06y, 06z, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08b, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 07j, 10a, 10b, 10c, 10d, 11a, 11b, 11c, 11e, 11h, 11i, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12h, 12i, 12k, 12l, 12m, 13b, 13c, 13d, 13e, 13f, 13g, 13h, 13i, 13j, 13k, 13l, 13m, 13n, 13o, 13p, 13q, 13s, 13u, 14a, 14b, 14c, 14d, 14e, 14f, 14g, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 14o, 14p, 14s, 14t, 14u, 14r, 14v, 14w, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 15r, 15s, 15t, 15u, 15v, 15x, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.glabel { font-size: 13px; font-weight: 700; color: var(--ink-3); padding: 0 4px; margin-bottom: -8px; }
.gnote { font-size: 13px; color: var(--ink-3); padding: 0 4px; margin-top: -8px; }
.gnote.err { color: var(--clay); }
.group { background: var(--card); border-radius: 12px; overflow: hidden; flex: none; }
.row { display: flex; align-items: center; gap: 12px; min-height: 52px; padding: 0 16px; border-top: 1px solid var(--line); font-size: 16px; }
.row:first-child { border-top: 0; }
.row > .grow { flex: 1; min-width: 0; }
.row .sub { display: block; font-size: 13px; color: var(--ink-3); }
.row .val { color: var(--ink-3); }
.row .chev { color: var(--faint); }
.row.pad { padding-block: 12px; }
.row.stack { flex-direction: column; align-items: stretch; gap: 8px; padding-block: 12px; }
.row.link { color: var(--court); font-weight: 700; }
.row.danger { color: var(--clay); font-weight: 600; }
.sheet .group { background: var(--paper); }
.homepanel .group { background: var(--paper); }
.row .clay { color: var(--clay); }
.ghead .glabel, .ghead .gnote { padding: 0; margin: 0; }
.clubblock .gnote { margin-top: -2px; }
```

## `MabarGroupHeader`

Label grup dengan satu aksi teks atau tag di ujungnya.

Kelas hi-fi: `.ghead`  
Dipakai di frame: 04a, 04b, 04c, 04d, 04e, 04f, 04g, 06a, 06b, 06c, 06d, 06e, 06y, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12h, 12i, 12l, 12m, 13k, 13l, 13m, 14a, 14b, 14c, 14d, 14e, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 14o, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.rest .ghead { margin: 0; }
.ghead { display: flex; align-items: center; justify-content: space-between; gap: 12px; height: 18px; margin-bottom: -8px; padding-left: 4px; flex: none; }
.ghead .glabel, .ghead .gnote { padding: 0; margin: 0; }
.ghead .txtbtn { margin-right: -6px; }
.ghead.below { margin: -8px 0 0; }
```

## `MabarSegmented`

Pilihan segmented.

Kelas hi-fi: `.seg`, `.seg-wrap`  
Dipakai di frame: 02a, 02b, 02c, 02d, 03d, 03f, 03m, 03p, 04a, 04b, 04c, 04d, 04e, 09a, 09b, 09c, 09d, 09e, 09f, 09g, 11a, 11b, 11c, 11e, 11h, 11i, 12j, 13a, 13b, 13c, 13d, 13e, 13f, 13g, 13n, 13o, 13p, 13q, 13s, 13u, 14a, 14b, 14c, 14d, 14e, 14p, 14s, 14t, 14u, 15s, 15t

```css
.seg { display: flex; background: var(--fill); border-radius: 10px; padding: 3px; gap: 2px; }
.seg b { flex: 1; height: 38px; display: grid; place-items: center; font-size: 15px; font-weight: 600; color: var(--ink-2); border-radius: 8px; }
.seg b.on { background: var(--card); color: var(--ink); font-weight: 700; box-shadow: 0 1px 2px rgba(15,30,44,.16); }
.seg-wrap { padding: 0 16px; flex: none; }
```

## `MabarStepper`

Stepper − angka + dengan lebar angka tetap 60.

Kelas hi-fi: `.stepper`  
Dipakai di frame: 03d, 03e, 03f, 03g, 03i, 03j, 03k, 03m, 03n, 03p, 04h, 06w, 06x, 06y, 06z, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 14n, 15j, 15o

```css
.stepper { display: flex; align-items: center; gap: 4px; flex: none; }
.stepper i { font-style: normal; width: 36px; height: 36px; border-radius: 9px; background: var(--fill); display: grid; place-items: center; color: var(--ink-2); }
.stepper i.off { color: #C3CCD4; }
.stepper b { width: 60px; text-align: center; font-size: 22px; white-space: nowrap; }
.stepper b small { font-size: 12px; font-weight: 600; font-stretch: 100%; color: var(--ink-3); margin-left: 3px; }
```

## `MabarField`

Kotak isian.

Kelas hi-fi: `.field`, `.inline-field`, `.ph`, `.caret`  
Dipakai di frame: 02a, 02c, 03a, 03b, 03c, 03d, 03e, 03f, 03g, 03h, 03i, 03j, 03k, 03l, 03m, 03n, 03o, 03p, 03q, 04f, 04g, 08a, 08b, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 13a, 13b, 13c, 13d, 13e, 13f, 13g, 13h, 13i, 13j, 14f, 14g, 14o, 15l, 15m, 15o

```css
.field { background: var(--card); border-radius: 12px; box-shadow: inset 0 0 0 1.5px var(--line); padding: 14px 16px; font-size: 16px; min-width: 0; }
.field.focus { box-shadow: inset 0 0 0 2px var(--court); }
.field.error { box-shadow: inset 0 0 0 2px var(--clay); }
.ph { color: var(--faint); }
.caret { display: inline-block; width: 2px; height: 1.1em; background: var(--court); vertical-align: -3px; margin-left: 1px; }
.inline-field { flex: 1; min-width: 0; height: 40px; border-radius: 9px; background: var(--paper); display: flex; align-items: center; padding: 0 12px; font-size: 16px; }
.sheet .inline-field { background: var(--card); }
```

## `NameListField`

Kotak teks nama + toolbar aksi (layar Pemain).

Kelas hi-fi: `.compose`  
Dipakai di frame: 02a, 02b, 02c, 02d, 13a, 13b, 13c, 13d, 13e, 13f, 13g

```css
.compose { background: var(--card); border-radius: 12px; box-shadow: inset 0 0 0 1.5px var(--line); flex: none; position: relative; }
.compose.focus { box-shadow: inset 0 0 0 2px var(--court); }
.compose .ta { padding: 14px 16px; font-size: 16px; line-height: 1.6; white-space: pre-line; min-height: calc(4 * 1.6em + 28px); max-height: calc(6 * 1.6em + 28px); overflow: hidden; }
.compose .thumb { position: absolute; right: 5px; top: 10px; width: 3px; height: 92px; border-radius: 2px; background: #C3CCD4; }
.compose .tools { display: flex; align-items: center; padding: 0 2px; border-top: 1px solid var(--line); }
.compose .tools .danger { margin-left: auto; }
```

## `RosterPreview`

Hasil parser: daftar bernomor dua kolom.

Kelas hi-fi: `.roster`  
Dipakai di frame: 02b, 02c, 02d, 13b, 13c, 13d, 13e, 13f, 13g

```css
.roster { background: var(--card); border-radius: 12px; padding: 0 16px; flex: none; }
.roster .rr { display: grid; grid-template-columns: 1fr 1fr; gap: 12px; height: 40px; align-items: center; border-top: 1px solid var(--line); }
.roster .rr:first-child { border-top: 0; }
.roster span { display: flex; align-items: center; gap: 10px; min-width: 0; font-size: 16px; }
.roster b { width: 20px; text-align: right; font-size: 17px; color: var(--ink-3); flex: none; }
.roster i { font-style: normal; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; min-width: 0; }
```

## `PairList`

Daftar pasangan Fixed bernomor.

Kelas hi-fi: `.pairlist`  
Dipakai di frame: 04a, 04b, 04c, 04d, 04e, 04f, 04g, 14a, 14b, 14c, 14d, 14e, 14o

```css
.pairlist { background: var(--card); border-radius: 12px; padding: 0 16px; flex: none; }
.pairlist .pr { display: grid; grid-template-columns: 20px minmax(0, 1fr) minmax(0, 1fr); gap: 12px; height: 40px; align-items: center; border-top: 1px solid var(--line); font-size: 16px; }
.pairlist .pr:first-child { border-top: 0; }
.pairlist b { text-align: right; font-size: 17px; color: var(--ink-3); }
.pairlist i { font-style: normal; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.pairlist .none { color: var(--faint); }
.pairlist.edit .pr { height: 52px; grid-template-columns: 20px minmax(0, 1fr) minmax(0, 1fr) auto; }
```

## `MabarChip`

Chip pilihan; .chips.cols = dua kolom rata 44 pt.

Kelas hi-fi: `.chips`, `.chip`  
Dipakai di frame: 04b, 04e, 04f, 04g, 07j, 14b, 14e, 14o, 14r, 15l, 15m, 15r

```css
.chips { display: flex; flex-wrap: wrap; gap: 6px; }
.chip { height: 34px; padding: 0 12px; border-radius: 9px; background: var(--card); font-size: 15px; font-weight: 500; display: inline-flex; align-items: center; gap: 6px; box-shadow: inset 0 0 0 1px var(--line); white-space: nowrap; }
.chip.sel { background: var(--ink); color: #fff; box-shadow: none; }
.chip .x { color: var(--faint); }
.chips.cols { display: grid; grid-template-columns: 1fr 1fr; gap: 8px; }
.chips.cols .chip { height: 44px; padding: 0 14px; font-size: 16px; min-width: 0; overflow: hidden; text-overflow: ellipsis; }
```

## `RoundTabs`

Tab round + label kanan; .strip bisa digeser dengan fade di tepi.

Kelas hi-fi: `.tabs`  
Dipakai di frame: 04h, 06a, 06b, 06c, 06d, 06e, 06v, 06w, 06x, 06y, 06z, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08b, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12h, 12i, 12l, 12m, 13k, 13l, 13m, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.tabs { display: flex; align-items: flex-end; gap: 22px; padding: 0 16px; border-bottom: 1px solid var(--line); flex: none; }
.tabs b { padding: 6px 0 11px; font-size: 15px; font-weight: 700; color: var(--ink-3); display: flex; align-items: center; gap: 6px; }
.tabs b.on { color: var(--ink); box-shadow: inset 0 -2.5px 0 var(--ink); }
.tabs b.future { color: #B3BEC8; }
.tabs .live { width: 7px; height: 7px; border-radius: 50%; background: var(--ball); box-shadow: 0 0 0 1px var(--ball-edge); }
.tabs .meta { margin-left: auto; font-size: 13px; color: var(--ink-3); padding-bottom: 12px; white-space: nowrap; }
.tabs .strip { flex: 1; min-width: 0; display: flex; align-items: flex-end; gap: 22px; overflow: hidden; }
.tabs .strip b { flex: none; }
.tabs .strip.end { justify-content: flex-end; }
.tabs .strip.fade-l { -webkit-mask-image: linear-gradient(90deg, transparent, #000 36px); mask-image: linear-gradient(90deg, transparent, #000 36px); }
.tabs .strip.fade-r { -webkit-mask-image: linear-gradient(270deg, transparent, #000 36px); mask-image: linear-gradient(270deg, transparent, #000 36px); }
```

## `MatchScoreRow`

Satu match gaya scorebug.

Kelas hi-fi: `.list`, `.bug`, `.team`  
Dipakai di frame: 04h, 06a, 06b, 06c, 06d, 06e, 06v, 06w, 06x, 06y, 06z, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08b, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 10a, 10b, 10d, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12h, 12i, 12k, 12l, 12m, 13k, 13l, 13m, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 14v, 14w, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 15u, 15v, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.list { display: flex; flex-direction: column; gap: 8px; }
.bug { background: var(--card); border-radius: 12px; display: grid; grid-template-columns: 34px minmax(0, 1fr) auto; overflow: hidden; min-height: 84px; }
.bug .court { background: var(--c, #2F8F5B); color: #fff; display: grid; place-items: center; font-size: 19px; }
.bug .teams { padding: 12px 12px 12px 14px; display: flex; flex-direction: column; justify-content: center; gap: 8px; min-width: 0; }
.team { display: flex; align-items: center; gap: 8px; font-size: 16px; color: var(--ink-2); }
.team .nm { flex: 1; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.team .nm.split { display: flex; }
.team .nm.split > span { flex: 1 1 0; min-width: 0; overflow: hidden; text-overflow: ellipsis; }
.team .nm.split > .keep, .team .nm.split > .sep { flex: none; }
.team .nm.split > .sep { white-space: pre; }
.team .w { width: 7px; height: 7px; border-radius: 50%; flex: none; }
.team.win { color: var(--ink); font-weight: 700; }
.team.win .w { background: var(--ball); box-shadow: 0 0 0 1px rgba(15,30,44,.4); }
.team .sets { display: flex; gap: 12px; }
.team .s { width: 20px; text-align: right; font-size: 22px; line-height: 1; color: var(--ink); }
.team .s.l { color: #A3AEB8; }
.team .tag { font-size: 12px; font-weight: 800; letter-spacing: .02em; color: var(--clay); }
.bug .cta { align-self: center; margin-right: 12px; }
.bug.cancelled .team { color: var(--faint); text-decoration: line-through; }
.bug.cancelled .court { background: #C3CCD4; }
.bug .note-r { align-self: center; margin-right: 14px; font-size: 13px; color: var(--ink-3); }
.bug.wide { grid-template-columns: 42px minmax(0, 1fr) auto; }
.bug .court.timed { display: grid; grid-template-rows: minmax(0, 1fr) 26px; place-items: stretch; }
.bug .court.timed > span { display: grid; place-items: center; }
.bug .court.timed .cd { font-size: 13px; font-weight: 700; line-height: 1; background: rgba(15,30,44,.22); }
```

## `RestingList`

Yang istirahat di round ini (+ prioritas round berikutnya).

Kelas hi-fi: `.rest`  
Dipakai di frame: 06a, 06b, 06c, 06d, 06e, 06y, 06f, 06g, 06h, 06i, 06j, 06k, 06l, 06m, 06n, 06o, 06p, 06q, 06r, 06s, 06t, 06u, 08a, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 12a, 12b, 12c, 12d, 12e, 12f, 12g, 12h, 12i, 12l, 12m, 13k, 13l, 13m, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 16a, 16b, 16c, 16d, 16e, 16f, 16g

```css
.rest { display: flex; flex-direction: column; gap: 6px; flex: none; }
.rest .ghead { margin: 0; }
.rest .names { display: grid; grid-template-columns: 1fr 1fr; gap: 0 12px; padding: 0 4px; }
.rest .names span { font-size: 13px; font-weight: 600; line-height: 22px; color: var(--ink-2); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.rest .prio { color: var(--ink); }
.rest.later .names span { color: var(--ink-3); font-weight: 500; }
.rest .names.clubs > div { display: flex; flex-direction: column; min-width: 0; }
.rest .names.clubs .club { font-size: 13px; font-weight: 500; line-height: 22px; color: var(--ink-3); white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
```

## `ScoreBoard / ScoreKeypad`

Papan skor + keypad sendiri.

Kelas hi-fi: `.board`, `.bhead`, `.brow`, `.cell`, `.feedback`, `.keypad`, `.key`, `.setctl`  
Dipakai di frame: 07a, 07b, 07c, 07d, 07e, 07f, 07g, 07h, 07i, 07j, 07k, 07l, 07m, 07n, 07o, 14q, 14r, 15q, 15r

```css
.board { margin: 4px 16px 0; background: var(--ink); color: #fff; border-radius: 16px; overflow: hidden; flex: none; }
.bhead { display: grid; grid-template-columns: minmax(0, 1fr) repeat(3, 58px); gap: 6px; padding: 12px 16px 0; font-size: 12px; font-weight: 700; color: rgba(255,255,255,.5); }
.bhead span { text-align: center; }
.brow { display: grid; grid-template-columns: minmax(0, 1fr) repeat(3, 58px); gap: 6px; align-items: center; padding: 10px 16px; }
.brow + .brow { border-top: 1px solid rgba(255,255,255,.08); }
.brow .nm { display: grid; grid-template-columns: 10px minmax(0, 1fr); column-gap: 10px; align-items: center; font-size: 20px; font-weight: 700; line-height: 1.25; min-width: 0; }
.brow .nm > span { min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.brow .nm .w { width: 10px; height: 10px; border-radius: 50%; }
.brow.win .nm .w { background: var(--ball); }
.brow.lose .nm { color: rgba(255,255,255,.5); }
.cell { height: 64px; border-radius: 10px; display: grid; place-items: center; font-size: 44px; line-height: 1; color: rgba(255,255,255,.95); }
.cell.empty { color: rgba(255,255,255,.22); }
.cell.lost { color: rgba(255,255,255,.5); }
.cell.active { background: rgba(255,255,255,.09); color: var(--ball); box-shadow: inset 0 -3px 0 var(--ball); }
.cell.auto { color: rgba(255,255,255,.4); }
.cell.na { color: transparent; }
.brow.xl { grid-template-columns: minmax(0, 1fr) 128px; padding-block: 14px; }
.brow.xl .cell { height: 92px; font-size: 76px; }
.feedback { padding: 12px 20px 0; font-size: 15px; color: var(--ink-2); }
.feedback.err { color: var(--clay); font-weight: 600; }
.setctl { display: flex; gap: 8px; padding: 12px 16px 0; }
.keypad { display: grid; grid-template-columns: repeat(3, 1fr); gap: 8px; padding: 12px 16px 34px; flex: none; }
.key { height: 54px; border-radius: 12px; background: var(--card); display: grid; place-items: center; font-size: 26px; font-weight: 700; font-stretch: 85%; color: var(--ink); }
.key.fn { font-size: 15px; font-weight: 600; font-stretch: 100%; color: var(--ink-2); }
.key.ok { background: var(--ink); color: #fff; font-size: 16px; font-stretch: 100%; }
.key.ok.off { background: var(--fill); color: var(--faint); }
.key.off { background: transparent; color: #C3CCD4; box-shadow: inset 0 0 0 1px var(--line); }
```

## `StandingTable`

Tabel klasemen.

Kelas hi-fi: `.rank`, `.rrow`  
Dipakai di frame: 09a, 09b, 09c, 09d, 09e, 09f, 09g, 12j, 13n, 13o, 13p, 14p, 14s, 14t, 14u, 15s, 15t

```css
.rank { margin: 0 16px; background: var(--card); border-radius: 12px; overflow: hidden; flex: none; }
.rrow { display: grid; grid-template-columns: 30px minmax(0, 1fr) 30px 52px 36px 44px; gap: 6px; align-items: center; min-height: 44px; padding: 0 14px; border-top: 1px solid var(--line); font-size: 16px; }
.rrow:first-child { border-top: 0; }
.rrow.head { min-height: 34px; font-size: 12px; font-weight: 700; color: var(--ink-3); }
.rrow.head span:nth-child(n+3) { text-align: right; }
.rrow .r { font-size: 20px; text-align: center; color: var(--ink-2); }
.rrow .r.lead { width: 28px; height: 28px; border-radius: 50%; background: var(--ball); color: var(--ink); display: grid; place-items: center; font-size: 17px; box-shadow: inset 0 0 0 1px var(--ball-edge); }
.rrow .nm { font-weight: 600; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.rrow .nm small { display: block; font-size: 12.5px; font-weight: 500; color: var(--ink-3); }
.rrow .mp, .rrow .c3, .rrow .df { text-align: right; font-size: 18px; color: var(--ink-2); }
.rrow .c4 { text-align: right; font-size: 22px; }
.rrow.sub { min-height: 32px; background: #F5F7F9; font-size: 12px; font-weight: 700; color: var(--ink-3); }
.rrow.idle { color: var(--ink-3); }
.rrow.idle .nm { font-weight: 500; }
.rrow.idle .mp, .rrow.idle .c3, .rrow.idle .df, .rrow.idle .c4, .rrow.idle .r { color: #A3AEB8; }
```

## `StatLine`

Empat angka di Detail.

Kelas hi-fi: `.statline`  
Dipakai di frame: 10a, 10b, 10c, 10d, 12k, 14v, 14w, 15u, 15v

```css
.statline { display: grid; grid-template-columns: repeat(4, 1fr); background: var(--card); border-radius: 12px; overflow: hidden; flex: none; }
.statline div { padding: 14px 6px 12px; text-align: center; border-left: 1px solid var(--line); }
.statline div:first-child { border-left: 0; }
.statline b { display: block; font-size: 28px; line-height: 1; }
.statline span { display: block; font-size: 12px; color: var(--ink-3); margin-top: 6px; }
```

## `showMabarSheet`

Bottom sheet (lima jenis footer).

Kelas hi-fi: `.sheet`, `.grab`, `.scrim`, `.opt`  
Dipakai di frame: 01h, 01i, 03d, 03e, 03f, 03g, 03i, 03j, 03k, 03m, 03n, 03p, 04d, 04h, 06e, 06w, 06x, 06y, 06z, 06j, 06k, 08a, 08b, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 07j, 12b, 12c, 12d, 12e, 14d, 14k, 14n, 14r, 14y, 15c, 15h, 15j, 15k, 15l, 15m, 15o, 15r, 15y, 16c, 16e, 16f, 16g

```css
.sheet .inline-field { background: var(--card); }
.scrim { position: absolute; inset: 0; background: rgba(15,30,44,.46); }
.sheet { position: absolute; left: 0; right: 0; bottom: 0; background: var(--card); border-radius: 22px 22px 0 0; padding: 8px 16px 34px; display: flex; flex-direction: column; gap: 16px; max-height: 92%; }
.grab { width: 38px; height: 5px; border-radius: 3px; background: var(--line); margin: 0 auto; flex: none; }
.sheet h2 { margin: 0; font-size: 21px; font-weight: 800; font-stretch: 95%; }
.sheet .shead { display: flex; align-items: flex-start; gap: 12px; }
.sheet .shead > div { flex: 1; }
.sheet .shead p { font-size: 14px; color: var(--ink-3); margin-top: 2px; }
.sheet .group { background: var(--paper); }
.opt { display: flex; align-items: center; gap: 14px; min-height: 60px; padding: 0 16px; border-radius: 12px; background: var(--paper); font-size: 17px; font-weight: 600; }
.opt .radio { width: 22px; height: 22px; border-radius: 50%; box-shadow: inset 0 0 0 2px #B9C4CE; flex: none; }
.opt.on { background: var(--ink); color: #fff; }
.opt.on .radio { box-shadow: inset 0 0 0 7px var(--ball); }
.opt small { display: block; font-size: 13px; font-weight: 500; opacity: .7; }
```

## `showMabarConfirm`

Dialog konfirmasi (varian bahaya / lanjut).

Kelas hi-fi: `.dialog`, `.dactions`  
Dipakai di frame: 01h, 04d, 06e, 06j, 12b, 12e, 14d, 14k, 14y, 15c, 15h, 15y, 16e

```css
.dialog { position: absolute; left: 24px; right: 24px; top: 50%; transform: translateY(-50%); background: var(--card); border-radius: 18px; padding: 22px 20px 12px; display: flex; flex-direction: column; gap: 8px; }
.dialog h2 { margin: 0; font-size: 19px; font-weight: 800; }
.dialog p { font-size: 15px; color: var(--ink-2); line-height: 1.5; }
.dactions { display: flex; justify-content: flex-end; gap: 4px; margin-top: 10px; }
.dactions .txtbtn { color: var(--ink-2); }
.dactions .txtbtn.go { color: var(--court); }
.dactions .txtbtn.danger { color: var(--clay); }
```

## `MabarMenu`

Menu ⋯.

Kelas hi-fi: `.menu`  
Dipakai di frame: 06d, 06i, 12a, 12f, 14j, 15g, 16d

```css
.menu { position: absolute; right: 12px; top: 100px; width: 250px; background: var(--card); border-radius: 14px; padding: 6px 0; box-shadow: 0 16px 40px rgba(15,30,44,.2), 0 0 0 1px var(--line); }
.menu .mi { display: flex; align-items: center; gap: 12px; height: 48px; padding: 0 16px; font-size: 16px; color: var(--ink); }
.menu .mi svg { color: var(--ink-3); }
.menu .mi.danger, .menu .mi.danger svg { color: var(--clay); }
.menu .mi.off { color: var(--faint); }
.menu .mi.off svg { color: #C3CCD4; }
.menu hr { border: 0; border-top: 1px solid var(--line); margin: 6px 0; }
.menu .mi .on-dot { margin-left: auto; width: 7px; height: 7px; border-radius: 50%; background: var(--ball); box-shadow: 0 0 0 1px var(--ball-edge); }
```

## `MabarToast`

Toast.

Kelas hi-fi: `.toast`  
Dipakai di frame: 11c, 12g

```css
.toast { position: absolute; left: 16px; right: 16px; bottom: 118px; background: var(--ink); color: #fff; border-radius: 12px; padding: 14px 16px; font-size: 15px; display: flex; align-items: center; gap: 10px; }
.toast svg { color: var(--ball); }
```

## `CourtBanner (CourtPainter)`

Banner lapangan Beranda; painter yang sama dipakai generator ikon app.

Kelas hi-fi: `.court-band`, `.marks`, `.wordmark`, `.liveblock`, `.sportname`, `.prog`  
Dipakai di frame: 01a, 01b, 01c, 01d, 01e, 01f, 01g, 01h, 01i, 14x, 14y, 15w, 15x, 15y

```css
.court-band { position: relative; flex: none; color: #fff; overflow: hidden; }
.court-band > svg.lines { position: absolute; inset: 0; }
.marks { opacity: .35; }
.wordmark { position: absolute; left: 16px; top: 58px; display: flex; align-items: center; gap: 9px; font-size: 28px; font-weight: 800; font-stretch: 125%; letter-spacing: -0.01em; line-height: 1; }
.liveblock { position: absolute; left: 16px; top: 124px; width: 266px; display: flex; flex-direction: column; gap: 12px; }
.liveblock .sub { font-size: 14px; }
.liveblock .big { font-size: 54px; line-height: .88; }
.prog { height: 5px; border-radius: 3px; background: rgba(255,255,255,.2); overflow: hidden; }
.prog i { display: block; height: 100%; background: var(--ball); }
.liveblock .foot { display: flex; align-items: center; justify-content: space-between; gap: 12px; font-size: 14px; }
.liveblock .btn { flex: none; height: 46px; min-height: 46px; }
.court-band.fill { flex: 1; min-height: 0; }
.sportname { position: absolute; left: 16px; top: 140px; font-size: 76px; line-height: .9; color: #fff; }
```

## `HomePanel / SportPicker`

Panel bawah Beranda.

Kelas hi-fi: `.homepanel`, `.pick`, `.pickt`, `.rowic`  
Dipakai di frame: 01a, 01b, 01c, 01d, 01e, 01f, 01h, 01i, 12c, 12d, 12e, 14x, 14y, 15w, 15x, 15y

```css
.homepanel { position: relative; margin-top: -24px; background: var(--card); border-radius: 24px 24px 0 0; padding: 20px 16px 34px; display: flex; flex-direction: column; gap: 12px; box-shadow: 0 -12px 32px rgba(15,30,44,.2); flex: none; }
.homepanel h2 { margin: 0; font-size: 18px; font-weight: 800; font-stretch: 95%; }
.homepanel .group { background: var(--paper); }
.pick { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.pickt { height: 76px; border-radius: 14px; background: var(--paper); display: flex; align-items: center; gap: 10px; padding: 0 14px; color: var(--ink-2); }
.pickt img { height: 50px; width: auto; }
.pickt b { font-size: 18px; }
.pickt.on { background: var(--card); color: var(--ink); box-shadow: inset 0 0 0 2px var(--ink); }
.pickt.on img { filter: brightness(.35); }
.rowic { width: 38px; height: 38px; border-radius: 10px; background: var(--card); display: grid; place-items: center; color: var(--court); flex: none; }
```

## `ModePicker`

Kartu Fixed / Mixed.

Kelas hi-fi: `.modes`, `.mode`, `.modeart`  
Dipakai di frame: 03a, 03b, 03c, 03d, 03e, 03f, 03g, 03h, 03i, 03j, 03k, 03l, 03m, 03n, 03o, 03p, 03q, 13h, 13i, 13j, 14f, 14g

```css
.modes { display: grid; grid-template-columns: 1fr 1fr; gap: 10px; }
.modes.m3 { grid-template-columns: repeat(3, 1fr); gap: 8px; }
.mode { background: var(--card); border-radius: 14px; padding: 12px 8px; display: flex; flex-direction: column; align-items: center; gap: 6px; text-align: center; box-shadow: inset 0 0 0 1.5px var(--line); }
.modeart { display: flex; align-items: center; justify-content: center; gap: 2px; height: 32px; color: var(--ink-3); }
.modeart .p { width: 30px; height: 30px; fill: currentColor; }
.modeart .c { width: 16px; height: 16px; fill: currentColor; }
.mode.on .modeart { color: var(--ink); }
.mode b { font-size: 17px; }
.mode.on { box-shadow: inset 0 0 0 2px var(--ink); }
```

## `CourtColorPicker`

Lingkaran warna court.

Kelas hi-fi: `.swatches`, `.swatch`, `.dot`  
Dipakai di frame: 03g, 03i, 03j, 03k, 03n, 04h, 06w, 06x, 06y, 06z, 08c, 08d, 08e, 08f, 08g, 08h, 08i, 08j, 08k, 14n, 15j, 15o

```css
.dot { width: 14px; height: 14px; border-radius: 50%; flex: none; }
.swatches { display: grid; grid-template-columns: repeat(5, 1fr); gap: 12px; }
.swatch { aspect-ratio: 1; border-radius: 50%; display: grid; place-items: center; color: #fff; }
.swatch.on { box-shadow: 0 0 0 3px var(--card), 0 0 0 5px var(--ink); }
```

## `SharePoster`

Kartu/gambar Bagikan dan pemilih tema.

Kelas hi-fi: `.poster`, `.themes`, `.theme`, `.poster-pair`  
Dipakai di frame: 11a, 11b, 11c, 11d, 11e, 11f, 11g, 11h, 11i, 11j, 11k, 11l, 13q, 13r, 13s, 13t, 13u, 13v, 13w

```css
.poster { position: relative; overflow: hidden; color: var(--pink, #fff); font-family: var(--f); border-radius: 14px; flex: none; }
.poster .pin { position: absolute; inset: 0; padding: 22px; display: flex; flex-direction: column; }
.poster .eyebrow { font-size: 11px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; opacity: .75; }
.poster h3 { margin: 6px 0 0; font-size: 26px; font-weight: 800; font-stretch: 95%; line-height: 1.05; display: flex; align-items: center; gap: 8px; }
.poster .prow { display: grid; grid-template-columns: 32px minmax(0, 1fr) auto; gap: 8px; align-items: baseline; padding: 6px 0; border-top: 1px solid color-mix(in srgb, currentColor 18%, transparent); font-size: 14px; }
.poster .prow:first-child { border-top: 0; }
.poster .prow .r { font-size: 18px; }
.poster .prow .nm { font-weight: 600; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.poster .prow .pt { font-size: 18px; }
.poster .prow .pt small { font-size: 11px; font-weight: 600; font-stretch: 100%; opacity: .7; margin-left: 3px; }
.poster .foot { margin-top: auto; display: flex; justify-content: space-between; align-items: flex-end; font-size: 11.5px; opacity: .8; }
.poster .wm { position: absolute; right: -18px; bottom: -14px; width: 150px; opacity: .12; }
.poster .more { font-size: 12.5px; opacity: .75; padding-top: 6px; }
.poster .rows { margin-top: 12px; flex: 1; min-height: 0; display: flex; flex-direction: column; }
.poster .cols { margin-top: 12px; flex: 1; min-height: 0; display: grid; grid-auto-flow: column; grid-template-columns: 1fr 1fr; grid-template-rows: repeat(var(--k), minmax(0, 1fr)); column-gap: 14px; }
.poster .cols .prow.top { border-top: 0; }
.poster .rows .prow, .poster .cols .prow { flex: 1; min-height: 0; align-items: center; padding: 0; line-height: 1.1; }
.poster .cols .prow { grid-template-columns: 24px minmax(0, 1fr) auto; gap: 6px; }
.poster .prow .r::before { content: "#"; opacity: .55; }
.poster .prow.gold .r { justify-self: start; background: #E3B341; color: #0F1E2C; padding: 0 .3em; margin-left: -.3em; border-radius: .35em; line-height: 1; }
.poster .prow.gold .r::before { opacity: .6; }
.poster .prow.gold .nm, .poster .prow.gold .nm2 { font-weight: 800; }
.poster .prow .nm2 { font-weight: 600; line-height: 1.15; min-width: 0; }
.poster .prow .nm2 span { display: block; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.themes { display: flex; flex-wrap: wrap; gap: 6px; }
.theme { width: 30px; height: 30px; border-radius: 50%; box-shadow: inset 0 0 0 1px rgba(0,0,0,.08); display: grid; place-items: center; }
.theme.on { box-shadow: 0 0 0 3px var(--paper), 0 0 0 5px var(--ink); }
.poster-pair { display: flex; gap: 14px; align-items: flex-start; line-height: 1.4; }
.poster .pscore { margin-top: 8px; border-bottom: 1px solid color-mix(in srgb, currentColor 18%, transparent); }
.poster .pscore .ps { display: grid; grid-template-columns: minmax(0, 1fr) auto 30px; gap: 8px; align-items: center; height: 26px; border-top: 1px solid color-mix(in srgb, currentColor 18%, transparent); }
.poster .pscore .ps .nm { font-size: 16px; font-weight: 800; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.poster .pscore .ps small { font-size: 11px; font-weight: 600; opacity: .75; font-variant-numeric: tabular-nums; }
.poster .pscore .ps b { font-size: 24px; line-height: 1; text-align: right; }
.poster .pclub { display: flex; justify-content: space-between; align-items: flex-end; gap: 8px; height: 18px; padding-bottom: 2px; font-size: 10.5px; font-weight: 700; letter-spacing: .08em; text-transform: uppercase; opacity: .75; flex: none; }
.poster .pclub span:first-child { min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.poster .pclub span:last-child { flex: none; white-space: nowrap; letter-spacing: 0; text-transform: none; font-weight: 500; font-size: 11.5px; }
.poster .pclub + .prow { border-top: 0; }
.poster .cols.clubs { grid-auto-flow: row; grid-template-rows: minmax(0, 1fr); }
.poster .cols.clubs > div { display: grid; grid-template-rows: auto repeat(var(--k), minmax(0, 1fr)); min-width: 0; min-height: 0; }
```

## `InstallStep`

Langkah pasang di iPhone.

Kelas hi-fi: `.install-step`  
Dipakai di frame: 01i

```css
.install-step { display: grid; grid-template-columns: 36px minmax(0, 1fr); gap: 12px; align-items: center; font-size: 16px; }
.install-step .no { width: 36px; height: 36px; border-radius: 10px; background: var(--paper); display: grid; place-items: center; font-size: 18px; color: var(--ink-2); }
.install-step .chipi { display: inline-flex; vertical-align: -5px; width: 26px; height: 26px; border-radius: 7px; background: var(--paper); place-items: center; color: var(--court); margin: 0 2px; }
```

## `ClubScore`

Skor klub Sparing: dua baris (bola · nama · Total Point · selisih · match menang), klub pertama di atas.

Kelas hi-fi: `.clubscore`  
Dipakai di frame: 13k, 13l, 13m, 13n, 13o, 13p, 14h, 14i, 14j, 14k, 14l, 14m, 14n, 14p, 14s, 14t, 14u, 15a, 15b, 15c, 15d, 15e, 15f, 15g, 15h, 15i, 15j, 15k, 15l, 15m, 15n, 15o, 15p, 15s, 15t

```css
.clubscore { background: var(--ink); color: #fff; border-radius: 12px; padding: 2px 16px; flex: none; }
.clubscore .cs { display: grid; grid-template-columns: 10px minmax(0, 1fr) auto 44px; column-gap: 10px; align-items: center; height: 40px; }
.clubscore .cs + .cs { border-top: 1px solid rgba(255,255,255,.1); }
.clubscore .w { width: 10px; height: 10px; border-radius: 50%; }
.clubscore .cs.lead .w { background: var(--ball); }
.clubscore .nm { font-size: 17px; font-weight: 700; min-width: 0; white-space: nowrap; overflow: hidden; text-overflow: ellipsis; }
.clubscore .tp { font-size: 13px; color: rgba(255,255,255,.66); white-space: nowrap; font-variant-numeric: tabular-nums; }
.clubscore .sc { font-size: 30px; line-height: 1; text-align: right; }
.clubscore-wrap { padding: 0 16px 12px; flex: none; }
```

## `LiveTag`

Tag "Live" / "Offline" pengganti ⋯ di Jadwal penonton.

Kelas hi-fi: `.livetag`  
Dipakai di frame: 12h, 12i, 12m

```css
.livetag { display: inline-flex; align-items: center; gap: 6px; height: 30px; padding: 0 11px; border-radius: 15px; background: var(--card); font-size: 13px; font-weight: 700; color: var(--ink); flex: none; margin-right: 4px; white-space: nowrap; }
.livetag i { width: 7px; height: 7px; border-radius: 50%; background: var(--ball); box-shadow: 0 0 0 1px var(--ball-edge); }
.livetag.off { color: var(--ink-3); }
.livetag.off i { background: #B3BEC8; box-shadow: none; }
```

## `LiveScoreSheet`

Link penonton di sheet Live score.

Kelas hi-fi: `.url`  
Dipakai di frame: 12c, 12d, 12e

```css
.url { font-size: 15px; font-weight: 600; line-height: 1.35; overflow-wrap: break-word; }
```

## `LiveScreen`

Halaman penonton: memuat / live tidak ditemukan.

Kelas hi-fi: `.centermsg`  
Dipakai di frame: 12n, 12o

```css
.centermsg { flex: 1; display: flex; flex-direction: column; align-items: center; justify-content: center; gap: 14px; padding: 0 32px 80px; text-align: center; }
.centermsg h2 { margin: 0; font-size: 21px; font-weight: 800; font-stretch: 95%; }
```
