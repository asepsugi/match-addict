#!/usr/bin/env python3
"""Baca frame hi-fi seperlunya, tanpa membuka design/hifi.html (±2,7 MB) dengan grep/sed.

    python3 tool/hifi_frame.py 09h 17s        # tiap frame: letak baris, caption, catatan, markup + CSS yang mengenainya
    python3 tool/hifi_frame.py 09h --no-css   # tanpa CSS (mis. hanya mengubah teks/catatan)
    python3 tool/hifi_frame.py 09h --notes    # caption + catatan saja (tanpa markup dan CSS)
    python3 tool/hifi_frame.py --uses=rrow.two,sfoot   # frame yang memakai kelas itu (dampak ubah komponen)
    python3 tool/hifi_frame.py --changed-since=507fd21 # frame yang berubah sejak commit itu (frame/golden yang dikerjakan)
    python3 tool/hifi_frame.py --changed-since=507fd21 --tests   # + berkas test golden frame itu (jalankan hanya ini)
    python3 tool/hifi_frame.py 09h 17s --tests            # berkas test golden frame tertentu

CSS yang dicetak = aturan berkelas yang bisa mengenai frame (logika sama dengan sidik render di
`tool/hifi_extract.py`); aturan dicetak sekali walau dipakai beberapa frame. Aturan global (token :root, elemen,
@media, @keyframes) tidak dicetak; baca bagian Fondasi/token kalau memang mengubahnya.
Letak baris = blok `<div class="scr">` frame itu di hifi.html, untuk Read offset/limit atau Edit.
"""
import os
import re
import subprocess
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import hifi_extract as X  # noqa: E402


def locate(s):
    """id frame → (alur, baris awal, baris akhir, markup .scr utuh)."""
    out = {}
    for sec in re.finditer(r'<section class="flow" id="([\w-]+)">', s):
        end = s.index('</section>', sec.end())
        for scr in re.finditer(r'<div class="scr"[^>]*>', s[sec.end():end]):
            start = sec.end() + scr.start()
            blk = X.block(s, start)
            cap = re.search(r'<div class="cap"><b>(\w+)</b>', blk)
            if cap:
                a = s.count('\n', 0, start) + 1
                out[cap.group(1)] = (sec.group(1), a, a + blk.count('\n'), blk)
    return out


def changed_since(ref):
    old = subprocess.run(['git', 'show', f'{ref}:design/hifi.html'], cwd=X.ROOT, capture_output=True, text=True,
                         check=True).stdout
    new = open(X.HIFI, encoding='utf-8').read()
    a, b = X.fingerprints(old, X.frames(old)), X.fingerprints(new, X.frames(new))
    return ([i for i in b if i in a and a[i] != b[i]], [i for i in b if i not in a], [i for i in a if i not in b])


def golden_files(ids):
    """Berkas test yang memanggil expectMatchesHifi/expectRegionMatchesHifi dengan id frame itu → id yang dicakup."""
    out, want = {}, set(ids)
    for d, _, names in os.walk(os.path.join(X.ROOT, 'test')):
        for n in names:
            if n.endswith('_test.dart'):
                p = os.path.join(d, n)
                got = want & set(re.findall(r"['\"](\w+)['\"]", open(p, encoding='utf-8').read()))
                if got:
                    out[os.path.relpath(p, X.ROOT)] = sorted(got)
    return out


def print_tests(ids):
    files = golden_files(ids)
    covered = {i for v in files.values() for i in v}
    for p, v in sorted(files.items()):
        print(f'  {p}: {" ".join(v)}')
    if set(ids) - covered:
        print('  tanpa test golden:', ' '.join(sorted(set(ids) - covered)))
    if files:
        print('  flutter test ' + ' '.join(sorted(files)))


def main():
    args = [a for a in sys.argv[1:] if not a.startswith('--')]
    opt = {a.split('=')[0]: (a.split('=', 1)[1] if '=' in a else True) for a in sys.argv[1:] if a.startswith('--')}
    if '--changed-since' in opt:
        ubah, baru, hilang = changed_since(opt['--changed-since'])
        print(f'berubah ({len(ubah)}):', ' '.join(ubah) or '-')
        print(f'baru ({len(baru)}):', ' '.join(baru) or '-')
        print(f'dihapus ({len(hilang)}):', ' '.join(hilang) or '-')
        if '--tests' in opt:
            print('test golden:')
            print_tests(ubah + baru)
        return
    s = open(X.HIFI, encoding='utf-8').read()
    flows = X.frames(s)
    byid = {f['id']: f for fl in flows for f in fl['frames']}
    if '--uses' in opt:
        for cls in opt['--uses'].split(','):
            need = set(cls.split('.'))  # "rrow.two" = elemen berkelas rrow dan two
            hits = [i for i, f in byid.items()
                    if any(need <= set(c.split()) for c in re.findall(r'class="([^"]*)"', f['root']))]
            print(f'.{cls} ({len(hits)}):', ' '.join(hits) or '-')
        return
    if not args:
        print(__doc__)
        return
    if '--tests' in opt:
        print_tests(args)
        return
    loc = locate(s)
    ctx = X.FrameCss(s)
    printed = set()
    for i in args:
        if i not in byid:
            print(f'== {i}: tidak ada di hi-fi')
            continue
        f, (flow, a, b, _) = byid[i], loc[i]
        print(f'== {i} · {f["caption"]} · alur #{flow} · hifi.html baris {a}–{b}')
        for n in f['notes']:
            print('  -', n)
        if '--notes' in opt:
            continue
        print('-- markup')
        print(f['root'])
        if '--no-css' in opt:
            continue
        rules = [r for r in ctx.rules_for(f['root'], global_rules=False) if r not in printed]
        printed.update(rules)
        syms = re.findall(r'<symbol id="([\w-]+)"', ''.join(ctx.symbols_for(f['root'])))
        print(f'-- CSS ({len(rules)} aturan baru' + (', sisanya sudah dicetak di atas' if printed - set(rules) else '')
              + ')' + (f' · ikon: {" ".join(syms)}' if syms else ''))
        for r in rules:
            print(re.sub(r'\s+', ' ', r))


if __name__ == '__main__':
    main()
