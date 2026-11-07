#!/usr/bin/env python3
"""Turunkan bahan implementasi dari design/hifi.html.

    python3 tool/hifi_extract.py            # frame PNG + spesifikasi markdown
    python3 tool/hifi_extract.py --no-png   # markdown saja (cepat)

Hasil:
- design/frames/<id>.png — tiap frame di-render Chrome headless pada 2x (layar app: 780×1688,
  sudut 0 dan tanpa bayangan supaya bisa dibandingkan dengan golden Flutter).
- design/spec/screens/*.md — satu file per alur: catatan perilaku tiap frame + komponen yang dipakai.
- design/spec/components.md — tiap komponen: nama widget, frame pemakainya, aturan CSS apa adanya.
- design/spec/rects.json — posisi tiap elemen berkelas komponen di tiap frame layar (pt, relatif ke layar),
  diukur Chrome setelah font termuat. Dipakai golden per komponen (`expectRegionMatchesHifi`).
- test/hifi/components/share_poster_data.dart — isi setiap poster Bagikan (nomor, nama, nilai, satuan,
  selisih) untuk golden SharePoster.

Ditulis ulang setiap dijalankan; jangan edit hasilnya dengan tangan, edit hifi.html lalu jalankan lagi.
Butuh Google Chrome dan internet (font Archivo dimuat dari Google Fonts).
"""
import html as H
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DESIGN = os.path.join(ROOT, 'design')
HIFI = os.path.join(DESIGN, 'hifi.html')
CHROME = os.environ.get('CHROME', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')

# Kelas CSS di hi-fi → widget Flutter. Nama ini usulan untuk fondasi; boleh diganti asal konsisten.
COMPONENTS = [
    ('MabarAppBar', ['.appbar', '.large-title'], 'Judul rata kiri + subjudul fakta, tombol kembali, aksi kanan.'),
    ('MabarButton', ['.btn'], 'Varian primary · ball · secondary · danger · ghost · wait · off · sm.'),
    ('MabarTextButton', ['.txtbtn'], 'Aksi teks 44 pt, biru court / clay.'),
    ('MabarIconButton', ['.icbtn'], 'Tombol ikon 44 pt (52 di action bar), opsional angka kecil.'),
    ('MabarRowAction', ['.rowact'], 'Aksi di ujung baris daftar, 36 pt, area sentuh 44.'),
    ('MabarActionBar', ['.actionbar'], 'Bilah tombol menempel di bawah, garis tipis di atas, safe area 34.'),
    ('MabarGroup / MabarRow', ['.group', '.row', '.glabel', '.gnote'], 'Daftar bergaya pengaturan + label dan catatan grup.'),
    ('MabarGroupHeader', ['.ghead'], 'Label grup dengan satu aksi teks atau tag di ujungnya.'),
    ('MabarSegmented', ['.seg', '.seg-wrap'], 'Pilihan segmented.'),
    ('MabarStepper', ['.stepper'], 'Stepper − angka + dengan lebar angka tetap 60.'),
    ('MabarField', ['.field', '.inline-field', '.ph', '.caret'], 'Kotak isian.'),
    ('NameListField', ['.compose'], 'Kotak teks nama + toolbar aksi (layar Pemain).'),
    ('RosterPreview', ['.roster'], 'Hasil parser: daftar bernomor dua kolom.'),
    ('PairList', ['.pairlist'], 'Daftar pasangan Fixed bernomor.'),
    ('MabarChip', ['.chips', '.chip'], 'Chip pilihan; .chips.cols = dua kolom rata 44 pt.'),
    ('RoundTabs', ['.tabs'], 'Tab round + label kanan; .strip bisa digeser dengan fade di tepi.'),
    ('MatchScoreRow', ['.list', '.bug', '.team'], 'Satu match gaya scorebug.'),
    ('RestingList', ['.rest'], 'Yang istirahat di round ini (+ prioritas round berikutnya).'),
    ('ScoreBoard / ScoreKeypad', ['.board', '.bhead', '.brow', '.cell', '.feedback', '.keypad', '.key', '.setctl'], 'Papan skor + keypad sendiri.'),
    ('StandingTable', ['.rank', '.rrow'], 'Tabel klasemen.'),
    ('StatLine', ['.statline'], 'Empat angka di Detail.'),
    ('showMabarSheet', ['.sheet', '.grab', '.scrim', '.opt'], 'Bottom sheet (lima jenis footer).'),
    ('showMabarConfirm', ['.dialog', '.dactions'], 'Dialog konfirmasi (varian bahaya / lanjut).'),
    ('MabarMenu', ['.menu'], 'Menu ⋯.'),
    ('MabarToast', ['.toast'], 'Toast.'),
    ('CourtBanner (CourtPainter)', ['.court-band', '.marks', '.wordmark', '.liveblock', '.sportname', '.prog'], 'Banner lapangan Beranda; painter yang sama dipakai generator ikon app.'),
    ('HomePanel / SportPicker', ['.homepanel', '.pick', '.pickt', '.rowic'], 'Panel bawah Beranda.'),
    ('ModePicker', ['.modes', '.mode', '.modeart'], 'Kartu Fixed / Mixed.'),
    ('CourtColorPicker', ['.swatches', '.swatch', '.dot'], 'Lingkaran warna court.'),
    ('SharePoster', ['.poster', '.themes', '.theme', '.poster-pair'], 'Kartu/gambar Bagikan dan pemilih tema.'),
    ('InstallStep', ['.install-step'], 'Langkah pasang di iPhone.'),
    ('ClubScore', ['.clubscore'], 'Skor klub Sparing: dua baris (bola · nama · Total Point · selisih · match menang), klub pertama di atas.'),
    ('LiveTag', ['.livetag'], 'Tag "Live" / "Offline" pengganti ⋯ di Jadwal penonton.'),
    ('LiveScoreSheet', ['.url'], 'Link penonton di sheet Live score.'),
    ('LiveScreen', ['.centermsg'], 'Halaman penonton: memuat / live tidak ditemukan.'),
]


def css_rules():
    s = open(HIFI, encoding='utf-8').read()
    start = s.index('<style>\n/* Dokumen')
    css = s[start + 7:s.index('</style>', start)]
    css = re.sub(r'/\*.*?\*/', '', css, flags=re.S)
    css = re.sub(r'@media[^{]*\{(?:[^{}]*\{[^{}]*\})*[^{}]*\}', '', css)  # aturan dokumen/dark mode, bukan app
    return [(sel.strip(), body.strip()) for sel, body in re.findall(r'([^{}]+)\{([^{}]*)\}', css)]


def uses(selector, prefixes):
    return any(re.search(re.escape(p) + r'(?![\w])', selector) for p in prefixes)


def md(fragment):
    t = re.sub(r'<code>(.*?)</code>', lambda m: '`' + re.sub(r'<[^>]+>', '', m.group(1)) + '`', fragment, flags=re.S)
    t = re.sub(r'</?b>', '**', t)
    t = re.sub(r'</?i>', '*', t)
    t = re.sub(r'<br\s*/?>', ' ', t)
    t = re.sub(r'<[^>]+>', '', t)
    return re.sub(r'\s+', ' ', H.unescape(t)).strip()


def block(s, start):
    depth = 0
    for t in re.finditer(r'<div\b|</div>', s[start:]):
        depth += 1 if t.group(0) == '<div' else -1
        if depth == 0:
            return s[start:start + t.end()]
    raise ValueError(start)


def frames(s):
    out = []
    for sec in re.finditer(r'<section class="flow" id="([\w-]+)">', s):
        end = s.index('</section>', sec.end())
        body = s[sec.end():end]
        title = md(re.search(r'<h2>(.*?)</h2>', body, re.S).group(1))
        intro = md(re.search(r'<div class="flow-head">.*?<p>(.*?)</p>', body, re.S).group(1))
        items = []
        for scr in re.finditer(r'<div class="scr"[^>]*>', body):
            blk = block(body, scr.start())
            cap = re.search(r'<div class="cap"><b>(\w+)</b><span>(.*?)</span></div>', blk, re.S)
            if not cap:
                continue
            after = blk[cap.end():]
            root = block(after, after.index('<div'))
            notes = [md(li) for li in re.findall(r'<li>(.*?)</li>', after[len(root):], re.S)]
            items.append(dict(id=cap.group(1), caption=md(cap.group(2)), root=root, notes=notes))
        out.append(dict(id=sec.group(1), title=title, intro=intro, frames=items))
    return out


def chrome(args):
    """Chrome headless sesekali macet; tiap panggilan pakai profil sementara sendiri dan dicoba ulang."""
    for attempt in range(3):
        profile = tempfile.mkdtemp(prefix='hifi-chrome-')
        try:
            return subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--hide-scrollbars', '--no-first-run',
                                   '--user-data-dir=' + profile, '--virtual-time-budget=5000'] + args,
                                  capture_output=True, text=True, timeout=45)
        except subprocess.TimeoutExpired:
            print(f'    Chrome macet, coba lagi ({attempt + 1}/3)')
        finally:
            shutil.rmtree(profile, ignore_errors=True)
    raise RuntimeError('Chrome headless gagal 3 kali: ' + ' '.join(args))


def render_pngs(s, flows):
    head = s.split('<div class="doc">')[0].replace('<html>', '<html data-theme="light">', 1)
    reset = ('<style>html,body{margin:0!important;padding:0!important;background:transparent}'
             '.app{border-radius:0!important;box-shadow:none!important}</style>')
    tmp = os.path.join(DESIGN, '_frame.html')  # di design/ supaya src="img/..." menemukan design/img
    for flow in flows:
        for f in flow['frames']:
            root = f['root']
            if root.startswith('<div class="app">'):
                w, h = 390, 844
            else:  # kumpulan gambar kecil / poster: ukur dulu
                open(tmp, 'w', encoding='utf-8').write(head + reset + '<div id="r" style="display:inline-block">' + root + '</div>'
                    + '<script>addEventListener("load",()=>{const r=document.getElementById("r").getBoundingClientRect();'
                      'document.title=Math.ceil(r.width)+"x"+Math.ceil(r.height)})</script></body></html>')
                dom = chrome(['--window-size=1400,1200', '--dump-dom', 'file://' + tmp]).stdout
                w, h = map(int, re.search(r'<title>(\d+)x(\d+)</title>', dom).groups())
            open(tmp, 'w', encoding='utf-8').write(head + reset + root + '</body></html>')
            out = os.path.join(DESIGN, 'frames', f['id'] + '.png')
            chrome(['--force-device-scale-factor=2', f'--window-size={w},{h}', '--screenshot=' + out, 'file://' + tmp])
            print(f"  {f['id']}: {w}×{h} pt → {os.path.relpath(out, ROOT)}")
    os.remove(tmp)


def write_rects(s, flows):
    """Satu halaman berisi semua frame layar; skrip mengukur setiap elemen yang kelasnya dipakai komponen.

    Format: {frame: {kelas: [[x, y, lebar, tinggi, teks], ...]}} urut dokumen, teks dipotong 40 huruf supaya
    test bisa memilih elemen yang dimaksud tanpa bergantung urutan saja.
    """
    head = s.split('<div class="doc">')[0].replace('<html>', '<html data-theme="light">', 1)
    reset = ('<style>html,body{margin:0!important;padding:0!important;background:transparent}'
             '.app{border-radius:0!important;box-shadow:none!important}</style>')
    classes = sorted({p[1:] for _, prefixes, _ in COMPONENTS for p in prefixes})
    apps = ''.join(f'<div class="fr" data-id="{f["id"]}">{f["root"]}</div>'
                   for flow in flows for f in flow['frames'] if f['root'].startswith('<div class="app">'))
    script = ('<pre id="rects"></pre><script>document.fonts.ready.then(()=>{const C=' + json.dumps(classes) + ';'
              'const q=v=>Math.round(v*100)/100,out={};'
              'for(const fr of document.querySelectorAll(".fr")){const app=fr.querySelector(".app"),a=app.getBoundingClientRect(),m={};'
              'for(const c of C){const els=app.querySelectorAll("."+c);if(!els.length)continue;'
              'm[c]=[...els].map(e=>{const r=e.getBoundingClientRect();'
              'return[q(r.left-a.left),q(r.top-a.top),q(r.width),q(r.height),e.textContent.replace(/\\s+/g," ").trim().slice(0,40)]})}'
              'out[fr.dataset.id]=m}document.getElementById("rects").textContent=JSON.stringify(out)})</script>')
    tmp = os.path.join(DESIGN, '_rects.html')
    open(tmp, 'w', encoding='utf-8').write(head + reset + apps + script + '</body></html>')
    try:
        dom = chrome(['--window-size=1400,1200', '--dump-dom', 'file://' + tmp]).stdout
    finally:
        os.remove(tmp)
    rects = json.loads(H.unescape(re.search(r'<pre id="rects">(.*?)</pre>', dom, re.S).group(1)))
    out = os.path.join(DESIGN, 'spec', 'rects.json')
    with open(out, 'w', encoding='utf-8') as f:
        f.write('{\n' + ',\n'.join(f'  {json.dumps(k)}: {json.dumps(v, ensure_ascii=False)}' for k, v in rects.items()) + '\n}\n')
    print(f'  {len(rects)} frame → {os.path.relpath(out, ROOT)}')


def write_specs(flows, rules):
    used = {}
    for flow in flows:
        for f in flow['frames']:
            f['components'] = [name for name, prefixes, _ in COMPONENTS
                               if any(re.search(r'class="[^"]*(?<![\w-])' + re.escape(p[1:]) + r'(?![\w-])', f['root']) for p in prefixes)]
            for c in f['components']:
                used.setdefault(c, []).append(f['id'])
    folder = os.path.join(DESIGN, 'spec', 'screens')
    os.makedirs(folder, exist_ok=True)
    for old in os.listdir(folder):
        os.remove(os.path.join(folder, old))
    # Fondasi, Komponen, Cakupan tidak punya frame; komponen sudah di components.md.
    for n, flow in enumerate([f for f in flows if f['frames']], 1):
        lines = [f'# {flow["title"]}', '', '> Dihasilkan `tool/hifi_extract.py` dari `design/hifi.html`. Jangan diedit langsung.', '', flow['intro'], '']
        for f in flow['frames']:
            lines += [f'## {f["id"]} · {f["caption"]}', '', f'![{f["id"]}](../../frames/{f["id"]}.png)', '']
            if f['components']:
                lines += ['Komponen: ' + ', '.join(f'`{c}`' for c in f['components']), '']
            lines += [f'- {x}' for x in f['notes']] + ['']
        name = f'{n:02d}-' + re.sub(r'[^a-z0-9]+', '-', flow['title'].lower()).strip('-') + '.md'
        open(os.path.join(DESIGN, 'spec', 'screens', name), 'w', encoding='utf-8').write('\n'.join(lines))
    comp = ['# Komponen', '', '> Dihasilkan `tool/hifi_extract.py`. Aturan CSS disalin apa adanya dari hi-fi; itu ukuran yang harus dicapai.',
            '> Nama widget adalah usulan untuk fondasi. Penjelasan desain tiap komponen ada di bagian "Komponen" hi-fi.', '']
    for name, prefixes, desc in COMPONENTS:
        mine = [(sel, body) for sel, body in rules if uses(sel, prefixes)]
        comp += [f'## `{name}`', '', desc, '', 'Kelas hi-fi: ' + ', '.join(f'`{p}`' for p in prefixes) + '  ',
                 'Dipakai di frame: ' + (', '.join(used.get(name, [])) or '— (hanya di bagian Komponen/Fondasi)'), '', '```css']
        comp += [f'{sel} {{ {body} }}' for sel, body in mine] + ['```', '']
    open(os.path.join(DESIGN, 'spec', 'components.md'), 'w', encoding='utf-8').write('\n'.join(comp))


def write_poster_data(flows):
    """Baris setiap poster di alur Bagikan → `posterRows[(frame, urutan poster)]` untuk golden SharePoster.

    11c (gagal share) tidak ikut: posternya sama dengan 11a.
    """
    row = re.compile(r'<div class="prow[^"]*"[^>]*><b class="r n"[^>]*>(\d+)</b>(.*?)<b class="pt n"[^>]*>([^<]+)'
                     r'<small[^>]*>(?:([^<·]+) )?· ([^<]+)</small></b></div>')
    q = lambda t: "'" + H.unescape(t).replace("'", "\\'") + "'"
    out = ['// Dihasilkan tool/hifi_extract.py dari design/hifi.html (bagian Bagikan) untuk golden SharePoster;',
           '// data = isi poster di frame. Jangan diedit dengan tangan.',
           '// ignore_for_file: lines_longer_than_80_chars', '',
           "import 'package:match_addict/features/share/widgets/share_poster.dart';", '',
           '/// (frame, urutan poster di frame) → baris poster.',
           'const posterRows = <(String, int), List<SharePosterRow>>{']
    flow = next(f for f in flows if f['id'] == 'bagikan')
    for f in flow['frames']:
        if f['id'] == '11c':
            continue
        for i, poster in enumerate(re.split(r'<div class="poster" ', f['root'])[1:]):
            rows = row.findall(poster)
            if not rows:
                continue
            out.append(f"  ('{f['id']}', {i}): [")
            for pos, mid, value, unit, diff in rows:
                names = re.findall(r'<span>([^<]*)</span>', mid) if 'nm2' in mid else \
                    re.search(r'<span class="nm">([^<]*)</span>', mid).group(1).split(' + ')
                args = [f'position: {pos}', 'names: [' + ', '.join(q(n) for n in names) + ']', f'value: {q(value)}']
                if unit:
                    args.append(f'detail: {q(unit)}')
                args.append(f'diff: {q(diff)}')
                out.append(f"    SharePosterRow({', '.join(args)}),")
            out.append('  ],')
    out.append('};')
    path = os.path.join(ROOT, 'test', 'hifi', 'components', 'share_poster_data.dart')
    open(path, 'w', encoding='utf-8').write('\n'.join(out) + '\n')
    print('  poster →', os.path.relpath(path, ROOT))


def main():
    s = open(HIFI, encoding='utf-8').read()
    flows = frames(s)
    write_specs(flows, css_rules())
    print(sum(len(f['frames']) for f in flows), 'frame,', len(flows), 'alur → design/spec/')
    write_rects(s, flows)
    write_poster_data(flows)
    if '--no-png' not in sys.argv:
        render_pngs(s, flows)


if __name__ == '__main__':
    main()
