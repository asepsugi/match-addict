#!/usr/bin/env python3
"""Hitung ulang ukuran yang bergantung pada lebar teks di setiap poster Bagikan di design/hifi.html (keputusan 92).

    python3 tool/hifi_poster_fit.py          # tulis ulang hifi.html
    python3 tool/hifi_poster_fit.py --check  # hanya laporan

Aturannya sama dengan kode (podium_poster.dart / share_poster.dart, 3.7.1):
- Kolom nilai: --vw = nilai terlebar, --rw = keterangan terlebar se-poster (inline di .podium / .lk); --vg 0 kalau
  tidak ada keterangan sama sekali (posterValueColumns).
- Ringkas: nama mulai dari baris kecil kepala (Feed 12,5, Story 15), turun per 0,5 sampai semua nama muat, paling
  kecil 11,5 (--nm inline; tidak ditulis kalau tetap di awal).
- Lengkap: kn turun per 0,02 dari 1 sampai semua nama muat, paling kecil 0,82 (--kn inline di .lpanel).
- Kaki: fakta mulai 9,5, turun per 0,1 sampai muat di sisa baris kaki (font-size inline di .facts).
- Lengkap Feed dua kolom: tinggi baris = min(40, ruang ÷ satuan) (lengkap.dart feed2 maxRow 40), ruang = bawah
  panel − (garis belakang + 9) − 6 − kaki 26.
Lebar teks diukur Chrome headless setelah font termuat (butuh internet untuk font Archivo, sama dengan
tool/hifi_extract.py).
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
HIFI = os.path.join(ROOT, 'design', 'hifi.html')
CHROME = os.environ.get('CHROME', '/Applications/Google Chrome.app/Contents/MacOS/Google Chrome')
FEED2_MAX_ROW = 40

MEASURE = r"""
<style>*{zoom:1!important}</style><pre id="fit"></pre><script>
document.fonts.ready.then(() => {
  const W = n => { const r = document.createRange(); r.selectNodeContents(n); return r.getBoundingClientRect().width; };
  const B = e => e.getBoundingClientRect().width;
  const up = v => Math.ceil(v * 100 - 1e-6) / 100;
  const out = [];
  for (const root of document.querySelectorAll('div.podium, div.lk')) {
    const lk = root.classList.contains('lk'), story = root.classList.contains('story'), r = {};
    let vw = 0, rw = 0, n = 0;
    for (const v of root.querySelectorAll(lk ? '.prow .pt' : '.prank .val')) {
      n++;
      vw = Math.max(vw, W(lk ? v.firstChild : v.querySelector('b')));
      const sm = v.querySelector('small');
      if (sm && sm.textContent.trim()) rw = Math.max(rw, W(sm));
    }
    if (n) {
      r.vw = up(vw); r.rw = up(rw);
      root.style.setProperty('--vw', r.vw + 'px'); root.style.setProperty('--rw', r.rw + 'px');
      if (!rw) root.style.setProperty('--vg', '0px');
    }
    if (lk) {
      const panel = root.querySelector('.lpanel'), names = [...root.querySelectorAll('.prow .nm, .prow .nm2 span')];
      const fits = () => names.every(e => W(e) <= B(e) + 0.01);
      let p = 100;
      panel.style.setProperty('--kn', '1');
      while (p > 82 && !fits()) { p -= 2; panel.style.setProperty('--kn', String(p / 100)); }
      r.kn = p / 100;
    } else {
      const names = [...root.querySelectorAll('.who, .who2 span')], base = story ? 15 : 12.5;
      const fits = () => names.every(e => W(e) <= B(e) + 0.01);
      let s = base;
      root.style.setProperty('--nm', s + 'px');
      while (s > 11.5 && !fits()) { s -= 0.5; root.style.setProperty('--nm', s + 'px'); }
      r.nm = s; r.nmBase = base;
    }
    const f = root.querySelector('.facts');
    if (f) {
      const avail = B(f.parentElement) - B(f.parentElement.querySelector('.wmk')) - 10;
      let s = 9.5;
      f.style.fontSize = s + 'px';
      while (s > 6 && W(f) > avail + 0.01) { s = Math.round((s - 0.1) * 10) / 10; f.style.fontSize = s + 'px'; }
      r.facts = s;
    }
    out.push(r);
  }
  document.getElementById('fit').textContent = JSON.stringify(out);
});
</script>"""


def chrome_dom(path):
    profile = tempfile.mkdtemp(prefix='hifi-fit-')
    try:
        return subprocess.run([CHROME, '--headless=new', '--disable-gpu', '--no-first-run', '--user-data-dir=' + profile,
                               '--virtual-time-budget=8000', '--window-size=1400,1200', '--dump-dom', 'file://' + path],
                              capture_output=True, text=True, timeout=120).stdout
    finally:
        shutil.rmtree(profile, ignore_errors=True)


def set_vars(style, drop, add):
    """Buang deklarasi variabel di [drop] dari style inline lalu tambahkan [add] (urutan dipertahankan)."""
    parts = [p.strip() for p in style.split(';') if p.strip()]
    parts = [p for p in parts if p.split(':')[0].strip() not in drop]
    return ';'.join(parts + [f'{k}:{v}' for k, v in add])


def num(v):
    return f'{round(v, 2):g}'


def feed2_rows(s, report):
    """Feed dua kolom (bukan Story): --row = min(40, ruang ÷ satuan)."""
    def fix(m):
        kind, mid, style, units = m.group(1), m.group(2), m.group(3), int(m.group(4))
        if kind != 'story':
            h = 372 if kind == 'card' else 360
            y = float(re.search(r'data-corner="[\d.]+,([\d.]+)"', mid).group(1))
            row = min(FEED2_MAX_ROW, (h - 14 - (y + 9) - 6 - 26) / units)
            style = ';'.join([f'--row:{num(row)}px'] + [p for p in set_vars(style, {'--row'}, []).split(';') if p])
            report.append(f'  feed2 {kind} satuan {units}: --row {num(row)}')
        return (f'<div class="lk {kind}"{m.group(5)}>{mid}<div class="lpanel two" style="{style}">'
                f'<div class="lcols" style="--k:{units}"')
    return re.sub(r'<div class="lk (\w+)"([^>]*)>((?:(?!<div class="lk ).)*?)<div class="lpanel two" style="([^"]*)">'
                  r'<div class="lcols" style="--k:(\d+)"',
                  lambda m: fix(_G(m)), s, flags=re.S)


class _G:
    """Urutan grup untuk fix(): jenis, isi tengah, style panel, satuan, atribut akar."""
    def __init__(self, m):
        self.g = {1: m.group(1), 2: m.group(3), 3: m.group(4), 4: m.group(5), 5: m.group(2)}

    def group(self, i):
        return self.g[i]


def main():
    check = '--check' in sys.argv
    s = open(HIFI, encoding='utf-8').read()
    report = []
    s = feed2_rows(s, report)
    tmp = os.path.join(ROOT, 'design', '_fit.html')
    open(tmp, 'w', encoding='utf-8').write(s.replace('</body>', MEASURE + '</body>', 1))
    try:
        dom = chrome_dom(tmp)
    finally:
        os.remove(tmp)
    fit = json.loads(H.unescape(re.search(r'<pre id="fit">(.*?)</pre>', dom, re.S).group(1)))
    roots = list(re.finditer(r'<div class="(podium|lk) [^"]*" style="([^"]*)"', s))
    if len(roots) != len(fit):
        sys.exit(f'jumlah poster beda: sumber {len(roots)}, Chrome {len(fit)}')
    out, last = [], 0
    for i, (m, r) in enumerate(zip(roots, fit)):
        end = roots[i + 1].start() if i + 1 < len(roots) else len(s)
        lk = m.group(1) == 'lk'
        add = []
        if 'vw' in r:
            add += [('--vw', num(r['vw']) + 'px'), ('--rw', num(r['rw']) + 'px')]
            if not r['rw']:
                add.append(('--vg', '0px'))
        if not lk and r['nm'] != r['nmBase']:
            add.append(('--nm', num(r['nm']) + 'px'))
        style = set_vars(m.group(2), {'--vw', '--rw', '--vg', '--nm'}, add)
        seg = s[m.end():end]
        if lk:
            def kn(pm):
                st = set_vars(pm.group(2) or '', {'--kn'}, [('--kn', num(r['kn']))] if r['kn'] < 1 else [])
                return pm.group(1) + (f' style="{st}"' if st else '') + '>'
            seg = re.sub(r'(<div class="lpanel[^"]*")(?: style="([^"]*)")?>', kn, seg, count=1)
        if 'facts' in r:
            fs = f' style="font-size:{num(r["facts"])}px"' if r['facts'] < 9.5 else ''
            seg = re.sub(r'<span class="facts"(?: style="[^"]*")?>', f'<span class="facts"{fs}>', seg, count=1)
        line = s.count('\n', 0, m.start()) + 1
        report.append(f'{line:5d} {m.group(1):6s} ' + ' '.join(f'{k} {v}' for k, v in r.items() if k != 'nmBase'))
        out.append(s[last:m.start(2)] + style + s[m.end(2):m.end()] + seg)
        last = end
    out.append(s[last:])
    print('\n'.join(report))
    if not check:
        open(HIFI, 'w', encoding='utf-8').write(''.join(out))


if __name__ == '__main__':
    main()
