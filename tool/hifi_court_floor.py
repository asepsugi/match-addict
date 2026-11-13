#!/usr/bin/env python3
"""Gambar ulang lantai lapangan di setiap <svg class="scene"> poster Bagikan di design/hifi.html (keputusan host 91).

    python3 tool/hifi_court_floor.py          # tulis ulang hifi.html
    python3 tool/hifi_court_floor.py --check  # hanya laporan, tidak menulis

Lapangan tennis/padel utuh dengan semua garis resmi, dipotong kanvas (arah L1, eksplorasi
design/explore/bagikan-lapangan.html). Titik lapangan (u m dari garis samping kiri, v m dari garis belakang ke arah
penonton, t m di atas lantai) digambar di x = ax + S·u − k·g·v, y = ay + g·v − S·t.
- (ax, ay) = sudut garis belakang hi-fi (cornerX, garis belakang), tidak berubah.
- k = dx ÷ |dy| muka atas blok podium poster itu (Lengkap: podium mini); poster tanpa blok memakai k standar
  susunannya (K_DEFAULT).
- S: garis samping kanan memotong tepi bawah di x = W − cornerX; g: net 10 px di bawah tepi bawah.
Net tidak digambar. Padel: dinding kaca belakang + kiri bertingkat + pagar kawat; dinding kanan tidak.

Skrip ini idempoten: lantai yang sudah digambar disimpan sebagai <g class="court" data-…> dan dihitung ulang dari
atributnya. Lantai lama (polygon + path garis belakang/samping) dikenali dari bentuknya.
"""
import os
import re
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
HIFI = os.path.join(ROOT, 'design', 'hifi.html')

# Ukuran resmi (m). half = setengah panjang (garis belakang → net), sv = garis servis dari garis belakang.
COURT = {
    'tennis': dict(W=10.97, L=23.77, half=11.885, alley=1.37, sv=6.4),
    'padel': dict(W=10.0, L=20.0, half=10.0, sv=3.05),
}
# k standar per susunan (dx ÷ |dy| kedalaman blok): dipakai poster tanpa blok (Klasemen kosong).
K_DEFAULT = {('pod', False): 16 / 10, ('pod', True): 22 / 13, ('lk', False): 6 / 4, ('lk', True): 8 / 5}


def segs(sport):
    """Garis dalam [u1, v1, u2, v2]; tepi lapangan digambar sebagai satu poligon."""
    c = COURT[sport]
    W, L, s = c['W'], c['L'], c['sv']
    if sport == 'tennis':
        a = c['alley']
        return [(a, 0, a, L), (W - a, 0, W - a, L), (a, s, W - a, s), (a, L - s, W - a, L - s),
                (W / 2, s, W / 2, L - s), (W / 2, 0, W / 2, 0.15), (W / 2, L - 0.15, W / 2, L)]
    return [(0, s, W, s), (0, L - s, W, L - s), (W / 2, s - 0.2, W / 2, L - s + 0.2)]


def r1(v):
    v = round(v * 10) / 10
    return f'{v:g}' if v else '0'


def pt(p):
    return r1(p[0]) + ',' + r1(p[1])


def ln(a, b):
    return f'<line x1="{r1(a[0])}" y1="{r1(a[1])}" x2="{r1(b[0])}" y2="{r1(b[1])}"/>'


def court_svg(W, H, sport, ax, ay, k, ink, w0, story):
    c = COURT[sport]
    S = (W - 2 * ax + k * (H - ay)) / c['W']
    g = (H + 10 - ay) / c['half']
    P = lambda u, v: (ax + S * u - k * g * v, ay + g * v)
    rect = ' '.join(pt(P(u, v)) for u, v in [(0, 0), (c['W'], 0), (c['W'], c['L']), (0, c['L'])])
    inner = ''.join(ln(P(a, b), P(x, y)) for a, b, x, y in segs(sport))
    lines = (f'<g stroke="{ink}" stroke-width="{3.5 if story else 3}" stroke-linecap="square">{inner}</g>'
             f'<polygon points="{rect}" fill="none" stroke="{ink}" stroke-width="{w0}" stroke-linejoin="miter"/>')
    return rect, lines, walls(W, ax, ay, S, g, k, ink, story) if sport == 'padel' else ''


def walls(W, ax, ay, S, g, k, ink, story):
    """Dinding padel. Belakang: kaca 0–3 m, kawat 3–4 m, tiang tiap 2 m. Kiri: kaca 3 m (v 0–2), kaca 2 m (v 2–4),
    kawat di atasnya 1 m, lalu pagar kawat 3 m sampai net. Kisi kawat tiap 7 px (Story 9)."""
    m = 9 if story else 7
    R = min(ax + 10 * S, W + 10)
    P = lambda v, t: (ax - k * g * v, ay + g * v - S * t)
    mesh, post, edge = [], [], []
    x = ax + m
    while x < R:
        mesh.append(ln((x, ay - 4 * S), (x, ay - 3 * S)))
        x += m
    y = ay - 3 * S - m
    while y > max(ay - 4 * S, -10):
        mesh.append(ln((ax, y), (R, y)))
        y -= m
    for v0, v1, t0, t1 in [(0, 2, 3, 4), (2, 4, 2, 3), (4, 10, 0, 3)]:
        v = v0 + m / (k * g)
        while v < v1 - 0.01:
            mesh.append(ln(P(v, t0), P(v, t1)))
            v += m / (k * g)
        t = t0 + m / S
        while t < t1 - 0.01:
            mesh.append(ln(P(v0, t), P(v1, t)))
            t += m / S
    i = 1
    while ax + 2 * S * i < R:
        post.append(ln((ax + 2 * S * i, ay), (ax + 2 * S * i, ay - 4 * S)))
        i += 1
    for v, t in [(2, 4), (4, 3), (6, 3), (8, 3), (10, 3)]:
        post.append(ln(P(v, 0), P(v, t)))
    edge += [ln((ax, ay - 3 * S), (R, ay - 3 * S)), ln((ax, ay - 4 * S), (R, ay - 4 * S))]
    for a, b in [((0, 3), (2, 3)), ((2, 2), (4, 2)), ((0, 4), (2, 4)), ((2, 3), (4, 3)), ((4, 3), (10, 3))]:
        edge.append(ln(P(*a), P(*b)))
    glass = ''.join('<polygon points="' + ' '.join(pt(P(*p)) for p in q) + '"/>'
                    for q in [[(0, 0), (0, 3), (2, 3), (2, 0)], [(2, 0), (2, 2), (4, 2), (4, 0)]])
    return (f'<rect x="{r1(ax)}" y="{r1(ay - 3 * S)}" width="{r1(R - ax)}" height="{r1(3 * S)}" fill="{ink}" opacity=".08"/>'
            f'<g fill="{ink}" opacity=".15">{glass}</g>'
            f'<g stroke="{ink}" stroke-width="1" opacity=".24">{"".join(mesh)}</g>'
            f'<g stroke="{ink}" stroke-width="2" opacity=".42">{"".join(post)}{"".join(edge)}</g>'
            f'<g stroke="{ink}" stroke-width="3" opacity=".55">{ln((ax, ay), (ax, ay - 4 * S))}</g>')


OLD = re.compile(r'<polygon points="(-?[\d.]+),(-?[\d.]+) [^"]*" fill="([^"]+)"(?:></polygon>|/>)'
                 r'<path d="M[^"]*" stroke="([^"]+)" stroke-width="([\d.]+)" stroke-linejoin="miter" fill="none"(?:></path>|/>)')
NEW = re.compile(r'<g class="court" data-sport="(\w+)" data-corner="(-?[\d.]+),(-?[\d.]+)" data-k="([\d.]+)" '
                 r'data-fill="([^"]+)" data-ink="([^"]+)" data-w="([\d.]+)">.*?</g><!--/court-->', re.S)
TOP = re.compile(r'<polygon points="([-\d.]+),([-\d.]+) ([-\d.]+),([-\d.]+) ([-\d.]+),([-\d.]+) ([-\d.]+),([-\d.]+)"')


def main():
    check = '--check' in sys.argv
    s = open(HIFI, encoding='utf-8').read()
    out, last, report = [], 0, []
    for m in re.finditer(r'<svg class="scene"([^>]*)>(.*?)</svg>', s, re.S):
        attrs, body = m.group(1), m.group(2)
        W, H = (float(x) for x in re.search(r'width="([\d.]+)" height="([\d.]+)"', attrs).groups())
        story = H > 400
        before = s[max(0, m.start() - 600):m.start()]
        kind = 'lk' if before.rfind('class="lk') > before.rfind('class="podium') else 'pod'
        after = s[m.end():m.end() + 20000]
        nxt = after.find('<svg class="scene"')
        after = after[:nxt if nxt > 0 else None]
        txt = ' '.join(re.findall(r'class="(?:facts|psub|lsub)"[^>]*>([^<]*)', after))
        sport = 'padel' if 'Padel' in txt else 'tennis' if 'Tennis' in txt else None
        old = OLD.search(body)
        new = NEW.search(body)
        if old:
            ax, ay, fill, ink, w0 = float(old.group(1)), float(old.group(2)), old.group(3), old.group(4), old.group(5)
            span = old.span()
            rest = body[old.end():]
        elif new:
            sport = sport or new.group(1)
            ax, ay, fill, ink, w0 = float(new.group(2)), float(new.group(3)), new.group(5), new.group(6), new.group(7)
            span = new.span()
            rest = body[new.end():]
        else:
            sys.exit(f'scene di baris {s.count(chr(10), 0, m.start()) + 1} tidak dikenali')
        if sport is None:
            sport = {'#BC5A33': 'padel', '#1E6BB8': 'tennis'}.get(fill)
        top = TOP.search(rest)
        if top:
            p = [float(x) for x in top.groups()]
            k = (p[4] - p[2]) / (p[3] - p[5])
            src = 'blok'
        else:
            k = K_DEFAULT[(kind, story)]
            src = 'standar'
        if abs(k - K_DEFAULT[(kind, story)]) > 0.02:
            report.append(f'  ! k {k:.3f} beda dari standar {K_DEFAULT[(kind, story)]:.3f}')
        rect, lines, wall = court_svg(W, H, sport, ax, ay, k, ink, w0, story)
        g = (f'<g class="court" data-sport="{sport}" data-corner="{r1(ax)},{r1(ay)}" data-k="{round(k, 4)}" '
             f'data-fill="{fill}" data-ink="{ink}" data-w="{w0}">{wall}<polygon points="{rect}" fill="{fill}"/>'
             f'{lines}</g><!--/court-->')
        b0 = m.start(2)
        out.append(s[last:b0 + span[0]])
        out.append(g)
        last = b0 + span[1]
        report.append(f'{s.count(chr(10), 0, m.start()) + 1:5d} {kind:3s} {"story" if story else "feed "} '
                      f'{int(W)}×{int(H)} {sport:6s} sudut {r1(ax)},{r1(ay)} k {k:.3f} ({src})')
    out.append(s[last:])
    print('\n'.join(report))
    print(len([r for r in report if not r.startswith('  !')]), 'scene')
    if not check:
        open(HIFI, 'w', encoding='utf-8').write(''.join(out))


if __name__ == '__main__':
    main()
