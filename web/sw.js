// Service worker offline Match Addict. Dua placeholder di bawah diisi tool/build_web.sh setelah
// `flutter build web`; tanpa skrip itu file ini tidak berguna (daftar precache-nya kosong).
const VERSION = '__MABAR_VERSION__';
const PRECACHE = __MABAR_PRECACHE__;
// Awalan beda dari app lama di /mabar/ (cache satu origin dipakai bersama): bersih-bersih di bawah tidak
// menghapus cache milik service worker lain.
const CACHE = `match-addict-${VERSION}`;

// Semua file app di-precache saat install, supaya layar yang belum pernah dibuka (dan gambarnya)
// tetap jalan offline di lapangan. Pengecualian: canvaskit/ punya beberapa varian ~5MB per browser,
// jadi hanya varian yang benar-benar diunduh browser yang disimpan, lewat cache saat fetch.
// `cache: 'reload'` wajib: tanpa itu addAll boleh mengambil dari HTTP cache browser (Pages max-age=600,
// server lokal heuristik dari Last-Modified), jadi cache versi baru berisi main.dart.js/index.html lama
// dan app tertahan di build lama sampai sw.js berikutnya.
self.addEventListener('install', (event) => {
  const fresh = PRECACHE.map((url) => new Request(url, { cache: 'reload' }));
  event.waitUntil(caches.open(CACHE).then((cache) => cache.addAll(fresh)));
});

// Tidak skipWaiting otomatis: satu sesi tidak boleh mencampur main.dart.js lama dengan aset baru.
// index.html yang memintanya, hanya saat app baru dibuka (lihat sana).
self.addEventListener('message', (event) => {
  if (event.data === 'skipWaiting') self.skipWaiting();
});

self.addEventListener('activate', (event) => {
  event.waitUntil(
    caches.keys().then((keys) =>
      Promise.all(keys.filter((k) => k.startsWith('match-addict-') && k !== CACHE).map((k) => caches.delete(k))),
    ),
  );
});

// Cache-first: di lapangan sinyal sering jelek, jadi app tidak boleh menunggu jaringan.
// Pembaruan datang lewat sw.js baru (isinya berubah tiap build), bukan lewat fetch ini.
self.addEventListener('fetch', (event) => {
  const req = event.request;
  if (req.method !== 'GET' || new URL(req.url).origin !== self.location.origin) return;

  event.respondWith(
    caches.open(CACHE).then(async (cache) => {
      // Navigasi (buka app, termasuk ?query) selalu dilayani index.html yang di-precache.
      const key = req.mode === 'navigate' ? 'index.html' : req;
      const hit = await cache.match(key, { ignoreSearch: true });
      if (hit) return hit;
      const res = await fetch(req);
      if (res.ok) cache.put(req, res.clone());
      return res;
    }),
  );
});
