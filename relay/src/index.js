// Relay live score Match Addict (PRD §13, design/spec/logic.md §11). HP host mengirim seluruh turnamen (JSON
// TournamentCodec) setiap kali berubah; penonton mengambil salinan terakhirnya. Tanpa database: satu Durable
// Object per kode live yang hanya memegang satu nilai, dan nilai itu terhapus sendiri 3 hari setelah kiriman
// terakhir. Durable Object dipakai (bukan KV) karena bacaannya langsung konsisten; KV bisa basi sampai 60 detik.
//
// POST   /live                 isi = turnamen → 201 {code, token}
// GET    /live/:code?since=rev → 200 {rev, payload} · 204 belum berubah · 404 tidak ada
// PUT    /live/:code           Authorization: Bearer token, isi = turnamen → 204
// DELETE /live/:code           Authorization: Bearer token → 204

// Tanpa 0/O dan 1/I/L supaya kode yang ditulis/dibaca orang tidak tertukar.
const ALPHABET = '23456789ABCDEFGHJKMNPQRSTUVWXYZ';
const CODE = /^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]{6}$/;
const MAX_BYTES = 256 * 1024; // 30 pemain, puluhan round ±50 KB
const TTL_MS = 3 * 24 * 60 * 60 * 1000;

// Isinya memang publik (siapa saja yang punya link boleh membaca), jadi semua origin boleh; menulis butuh token.
const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, PUT, DELETE, OPTIONS',
  'Access-Control-Allow-Headers': 'Authorization, Content-Type',
  'Access-Control-Max-Age': '86400',
};

export default {
  async fetch(request, env) {
    if (request.method === 'OPTIONS') return new Response(null, { status: 204, headers: CORS });
    const parts = new URL(request.url).pathname.split('/').filter(Boolean);
    if (parts[0] !== 'live' || parts.length > 2) return reply(404);
    if (parts.length === 1) return request.method === 'POST' ? create(request, env) : reply(405);
    if (!CODE.test(parts[1])) return reply(404);
    return withCors(await env.LIVE.get(env.LIVE.idFromName(parts[1])).fetch(request));
  },
};

/** Live baru: kode acak (diulang kalau sudah dipakai) + token yang hanya dipegang HP host. */
async function create(request, env) {
  const body = await readPayload(request);
  if (body instanceof Response) return withCors(body);
  const token = randomToken();
  const tokenHash = await sha256(token);
  for (let attempt = 0; attempt < 5; attempt++) {
    const code = randomCode();
    const stub = env.LIVE.get(env.LIVE.idFromName(code));
    const res = await stub.fetch('https://live/create', { method: 'POST', headers: { 'X-Token-Hash': tokenHash }, body });
    if (res.status === 201) return withCors(json({ code, token }, 201));
    if (res.status !== 409) return withCors(res);
  }
  return withCors(reply(503));
}

export class LiveTournament {
  constructor(state) {
    this.storage = state.storage;
  }

  async fetch(request) {
    const live = await this.load();
    switch (request.method) {
      case 'GET': {
        if (!live) return reply(404);
        // Penonton mengecek tiap 10 detik; yang belum berubah cukup dijawab kosong.
        if (new URL(request.url).searchParams.get('since') === String(live.rev)) return reply(204);
        return json({ rev: live.rev, payload: live.payload });
      }
      case 'POST': {
        if (live) return reply(409);
        await this.save({ tokenHash: request.headers.get('X-Token-Hash'), rev: 1, payload: await request.text() });
        return reply(201);
      }
      case 'PUT': {
        if (!live) return reply(404);
        if (!(await authorized(request, live))) return reply(403);
        const payload = await readPayload(request);
        if (payload instanceof Response) return payload;
        await this.save({ ...live, rev: live.rev + 1, payload });
        return reply(204);
      }
      case 'DELETE': {
        if (!live) return reply(204);
        if (!(await authorized(request, live))) return reply(403);
        await this.clear();
        return reply(204);
      }
    }
    return reply(405);
  }

  /** Alarm bisa terlambat, jadi umur data juga dicek saat dibaca. */
  async load() {
    const live = await this.storage.get('live');
    if (live && Date.now() - live.updatedAt > TTL_MS) {
      await this.clear();
      return undefined;
    }
    return live;
  }

  async save(live) {
    const now = Date.now();
    await this.storage.put('live', { ...live, updatedAt: now });
    await this.storage.setAlarm(now + TTL_MS);
  }

  async clear() {
    await this.storage.deleteAlarm();
    await this.storage.deleteAll();
  }

  async alarm() {
    await this.storage.deleteAll();
  }
}

/** Isi kiriman: JSON simpanan Match Addict (`schema` + `tournament`), maksimal [MAX_BYTES]. */
async function readPayload(request) {
  const text = await request.text();
  if (new TextEncoder().encode(text).length > MAX_BYTES) return reply(413);
  try {
    const json = JSON.parse(text);
    if (typeof json?.schema !== 'number' || typeof json?.tournament !== 'object' || json.tournament === null) {
      return reply(400);
    }
  } catch {
    return reply(400);
  }
  return text;
}

async function authorized(request, live) {
  const header = request.headers.get('Authorization') ?? '';
  return header.startsWith('Bearer ') && (await sha256(header.slice(7))) === live.tokenHash;
}

function randomCode() {
  const bytes = crypto.getRandomValues(new Uint8Array(6));
  return Array.from(bytes, (b) => ALPHABET[b % ALPHABET.length]).join('');
}

function randomToken() {
  return Array.from(crypto.getRandomValues(new Uint8Array(32)), (b) => b.toString(16).padStart(2, '0')).join('');
}

async function sha256(text) {
  const digest = await crypto.subtle.digest('SHA-256', new TextEncoder().encode(text));
  return Array.from(new Uint8Array(digest), (b) => b.toString(16).padStart(2, '0')).join('');
}

function json(value, status = 200) {
  return new Response(JSON.stringify(value), { status, headers: { 'Content-Type': 'application/json' } });
}

function reply(status) {
  return new Response(null, { status });
}

function withCors(response) {
  const res = new Response(response.body, response);
  for (const [k, v] of Object.entries(CORS)) res.headers.set(k, v);
  return res;
}
