#!/usr/bin/env bash
# Build PWA Match Addict: `flutter build web` + mengisi daftar precache & versi di sw.js.
# Pakai ini, bukan `flutter build web` langsung — tanpa langkah kedua app tidak jalan offline.
#
#   tool/build_web.sh                 # deploy di root domain
#   tool/build_web.sh --base-href /match-addict/   # deploy di sub-path (mis. GitHub Pages)
set -euo pipefail
cd "$(dirname "$0")/.."

# --no-web-resources-cdn: CanvasKit disajikan dari server sendiri, bukan gstatic.com,
# supaya bisa ikut di-cache service worker (cross-origin tidak kita cache).
flutter build web --release --no-tree-shake-icons --no-web-resources-cdn --no-wasm-dry-run "$@"

cd build/web
files=$(find . -type f \
  ! -path './canvaskit/*' ! -name '*.symbols' ! -name '.last_build_id' \
  ! -name 'sw.js' ! -name 'flutter_service_worker.js' \
  | sed 's|^\./||' | LC_ALL=C sort)

# Versi = hash isi seluruh file, jadi sw.js hanya berubah (dan memicu update) kalau app-nya berubah.
version=$(echo "$files" | xargs shasum | shasum | cut -c1-12)
# Daftar precache berisi URL, bukan path: Flutter sudah meng-encode nama aset di disk
# (`Archivo[wdth,wght].ttf` → `Archivo%5Bwdth,wght%5D.ttf`), jadi `%` harus jadi `%25`. Tanpa itu
# satu URL 404 dan `cache.addAll` menggagalkan install service worker (offline + update mati).
list=$(echo "$files" | sed -e 's/%/%25/g' -e 's/.*/"&"/' | paste -sd, -)

sed -i.bak -e "s|__MABAR_VERSION__|$version|" -e "s|__MABAR_PRECACHE__|[$list]|" sw.js
rm sw.js.bak
echo "sw.js: versi $version, $(echo "$files" | wc -l | tr -d ' ') file di-precache"
