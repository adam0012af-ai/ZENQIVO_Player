import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import crypto from 'node:crypto';

const __dirname = dirname(fileURLToPath(import.meta.url));
const PORT = Number(process.env.PORT || 8787);
const ADMIN_TOKEN = process.env.ZENQIVO_ADMIN_TOKEN;
const CREDENTIAL_SECRET = process.env.ZENQIVO_CREDENTIAL_KEY;
if (!ADMIN_TOKEN || ADMIN_TOKEN.length < 24) {
  throw new Error('ZENQIVO_ADMIN_TOKEN must be set to at least 24 characters');
}
if (!CREDENTIAL_SECRET || CREDENTIAL_SECRET.length < 24) {
  throw new Error('ZENQIVO_CREDENTIAL_KEY must be set to at least 24 characters');
}
const CREDENTIAL_KEY = crypto.createHash('sha256')
  .update(CREDENTIAL_SECRET)
  .digest();
const db = new DatabaseSync(join(__dirname, 'zenqivo.sqlite'));

db.exec(`
  PRAGMA journal_mode = WAL;
  CREATE TABLE IF NOT EXISTS devices (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL UNIQUE,
    device_key TEXT NOT NULL,
    platform TEXT NOT NULL DEFAULT 'unknown',
    app_version TEXT,
    status TEXT NOT NULL DEFAULT 'pending',
    activated_until TEXT,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL
  );
  CREATE TABLE IF NOT EXISTS playlists (
    id INTEGER PRIMARY KEY AUTOINCREMENT,
    device_id TEXT NOT NULL,
    name TEXT NOT NULL,
    type TEXT NOT NULL DEFAULT 'm3u',
    source_url TEXT NOT NULL,
    username TEXT,
    password TEXT,
    enabled INTEGER NOT NULL DEFAULT 1,
    created_at TEXT NOT NULL,
    updated_at TEXT NOT NULL,
    FOREIGN KEY(device_id) REFERENCES devices(device_id) ON DELETE CASCADE
  );
`);


function encryptSecret(value) {
  if (!value) return null;
  if (String(value).startsWith('enc:v1:')) return value;
  const iv = crypto.randomBytes(12);
  const cipher = crypto.createCipheriv('aes-256-gcm', CREDENTIAL_KEY, iv);
  const encrypted = Buffer.concat([cipher.update(String(value), 'utf8'), cipher.final()]);
  const tag = cipher.getAuthTag();
  return `enc:v1:${iv.toString('base64')}:${tag.toString('base64')}:${encrypted.toString('base64')}`;
}

function decryptSecret(value) {
  if (!value) return null;
  const text = String(value);
  if (!text.startsWith('enc:v1:')) return text; // migration compatibility for older local databases.
  const parts = text.split(':');
  if (parts.length !== 5) throw new Error('invalid_encrypted_secret');
  const iv = Buffer.from(parts[2], 'base64');
  const tag = Buffer.from(parts[3], 'base64');
  const encrypted = Buffer.from(parts[4], 'base64');
  const decipher = crypto.createDecipheriv('aes-256-gcm', CREDENTIAL_KEY, iv);
  decipher.setAuthTag(tag);
  return Buffer.concat([decipher.update(encrypted), decipher.final()]).toString('utf8');
}

function secureEqual(a, b) {
  const left = Buffer.from(String(a ?? ''));
  const right = Buffer.from(String(b ?? ''));
  if (left.length !== right.length) return false;
  return crypto.timingSafeEqual(left, right);
}

function now() { return new Date().toISOString(); }
function send(res, status, body) {
  const data = JSON.stringify(body);
  res.writeHead(status, {
    'content-type': 'application/json; charset=utf-8',
    'content-length': Buffer.byteLength(data),
        'access-control-allow-headers': 'content-type, x-admin-token',
    'access-control-allow-methods': 'GET,POST,PUT,DELETE,OPTIONS'
  });
  res.end(data);
}
async function bodyJson(req) {
  const chunks = [];
  for await (const chunk of req) chunks.push(chunk);
  if (!chunks.length) return {};
  try { return JSON.parse(Buffer.concat(chunks).toString('utf8')); }
  catch { throw new Error('invalid_json'); }
}
function admin(req, res) {
  if (!secureEqual(req.headers['x-admin-token'], ADMIN_TOKEN)) {
    send(res, 401, { error: 'unauthorized' });
    return false;
  }
  return true;
}
function validSourceUrl(value) {
  try {
    const u = new URL(String(value));
    return u.protocol === 'https:' || u.protocol === 'http:';
  } catch {
    return false;
  }
}
function safePlaylistType(value) {
  return value === 'xtream' ? 'xtream' : 'm3u';
}

function safeDevice(row) {
  if (!row) return null;
  return {
    deviceId: row.device_id,
    platform: row.platform,
    appVersion: row.app_version,
    status: row.status,
    activatedUntil: row.activated_until,
    createdAt: row.created_at,
    updatedAt: row.updated_at,
  };
}
function isActive(row) {
  if (!row || row.status !== 'active') return false;
  if (!row.activated_until) return true;
  return new Date(row.activated_until).getTime() > Date.now();
}

const server = http.createServer(async (req, res) => {
  try {
    if (req.method === 'OPTIONS') return send(res, 204, {});
    const url = new URL(req.url, `http://${req.headers.host || 'localhost'}`);

    if (req.method === 'GET' && url.pathname === '/health') {
      return send(res, 200, { ok: true, service: 'zenqivo-backend', time: now() });
    }

    if (req.method === 'POST' && url.pathname === '/api/v1/devices/register') {
      const b = await bodyJson(req);
      if (!b.deviceId || !b.deviceKey) return send(res, 400, { error: 'deviceId_and_deviceKey_required' });
      const existing = db.prepare('SELECT * FROM devices WHERE device_id = ?').get(b.deviceId);
      const stamp = now();
      if (!existing) {
        db.prepare(`INSERT INTO devices(device_id,device_key,platform,app_version,status,created_at,updated_at)
                    VALUES(?,?,?,?,?,?,?)`).run(b.deviceId, b.deviceKey, b.platform || 'unknown', b.appVersion || null, 'pending', stamp, stamp);
      } else {
        if (!secureEqual(existing.device_key, b.deviceKey)) {
          return send(res, 403, { error: 'invalid_device_key' });
        }
        db.prepare('UPDATE devices SET platform=?, app_version=?, updated_at=? WHERE device_id=?')
          .run(b.platform || existing.platform, b.appVersion || existing.app_version, stamp, b.deviceId);
      }
      const row = db.prepare('SELECT * FROM devices WHERE device_id = ?').get(b.deviceId);
      return send(res, 200, { device: safeDevice(row), active: isActive(row) });
    }

    if (req.method === 'POST' && url.pathname === '/api/v1/devices/status') {
      const b = await bodyJson(req);
      const row = db.prepare('SELECT * FROM devices WHERE device_id=? AND device_key=?').get(b.deviceId, b.deviceKey);
      if (!row) return send(res, 404, { error: 'device_not_found' });
      return send(res, 200, { device: safeDevice(row), active: isActive(row) });
    }

    if (req.method === 'GET' && url.pathname === '/api/v1/sync') {
      const deviceId = url.searchParams.get('deviceId');
      const deviceKey = url.searchParams.get('deviceKey');
      const row = db.prepare('SELECT * FROM devices WHERE device_id=? AND device_key=?').get(deviceId, deviceKey);
      if (!row) return send(res, 404, { error: 'device_not_found' });
      if (!isActive(row)) return send(res, 403, { error: 'device_not_active', device: safeDevice(row) });
      const lists = db.prepare(`SELECT id,name,type,source_url,username,password,enabled,created_at,updated_at
                                FROM playlists WHERE device_id=? AND enabled=1 ORDER BY id DESC`).all(deviceId);
      return send(res, 200, {
        device: safeDevice(row),
        playlists: lists.map(p => ({
          id: p.id, name: p.name, type: p.type, sourceUrl: p.source_url,
          username: p.username, password: decryptSecret(p.password), enabled: Boolean(p.enabled), createdAt: p.created_at, updatedAt: p.updated_at
        })),
        syncedAt: now()
      });
    }

    if (req.method === 'GET' && url.pathname === '/admin/api/devices') {
      if (!admin(req, res)) return;
      const rows = db.prepare('SELECT * FROM devices ORDER BY id DESC').all();
      return send(res, 200, { devices: rows.map(r => ({ ...safeDevice(r), active: isActive(r) })) });
    }

    if (req.method === 'POST' && url.pathname === '/admin/api/activate') {
      if (!admin(req, res)) return;
      const b = await bodyJson(req);
      if (!b.deviceId) return send(res, 400, { error: 'deviceId_required' });
      const days = Math.max(1, Math.min(3650, Number(b.days || 365)));
      const until = new Date(Date.now() + days * 86400000).toISOString();
      const result = db.prepare('UPDATE devices SET status=?, activated_until=?, updated_at=? WHERE device_id=?')
        .run('active', until, now(), b.deviceId);
      if (!result.changes) return send(res, 404, { error: 'device_not_found' });
      return send(res, 200, { ok: true, activatedUntil: until });
    }

    if (req.method === 'POST' && url.pathname === '/admin/api/deactivate') {
      if (!admin(req, res)) return;
      const b = await bodyJson(req);
      const result = db.prepare('UPDATE devices SET status=?, activated_until=NULL, updated_at=? WHERE device_id=?')
        .run('pending', now(), b.deviceId);
      if (!result.changes) return send(res, 404, { error: 'device_not_found' });
      return send(res, 200, { ok: true });
    }

    if (req.method === 'POST' && url.pathname === '/admin/api/playlists') {
      if (!admin(req, res)) return;
      const b = await bodyJson(req);
      if (!b.deviceId || !b.name || !b.sourceUrl) return send(res, 400, { error: 'deviceId_name_sourceUrl_required' });
      if (!validSourceUrl(b.sourceUrl)) return send(res, 400, { error: 'invalid_source_url' });
      if (String(b.name).trim().length > 80) return send(res, 400, { error: 'playlist_name_too_long' });
      const device = db.prepare('SELECT id FROM devices WHERE device_id=?').get(b.deviceId);
      if (!device) return send(res, 404, { error: 'device_not_found' });
      const stamp = now();
      const result = db.prepare(`INSERT INTO playlists(device_id,name,type,source_url,username,password,enabled,created_at,updated_at)
                                 VALUES(?,?,?,?,?,?,?,?,?)`)
        .run(b.deviceId, String(b.name).trim(), safePlaylistType(b.type), String(b.sourceUrl).trim(), b.username || null, encryptSecret(b.password || null), 1, stamp, stamp);
      return send(res, 201, { ok: true, playlistId: Number(result.lastInsertRowid) });
    }

    if (req.method === 'GET' && url.pathname === '/admin/api/playlists') {
      if (!admin(req, res)) return;
      const deviceId = url.searchParams.get('deviceId');
      const rows = deviceId
        ? db.prepare('SELECT id,device_id,name,type,source_url,username,enabled,created_at,updated_at FROM playlists WHERE device_id=? ORDER BY id DESC').all(deviceId)
        : db.prepare('SELECT id,device_id,name,type,source_url,username,enabled,created_at,updated_at FROM playlists ORDER BY id DESC').all();
      return send(res, 200, { playlists: rows });
    }

    if (req.method === 'POST' && url.pathname.startsWith('/admin/api/playlists/toggle/')) {
      if (!admin(req, res)) return;
      const id = Number(url.pathname.split('/').pop());
      if (!Number.isInteger(id) || id <= 0) return send(res, 400, { error: 'invalid_playlist_id' });
      const row = db.prepare('SELECT enabled FROM playlists WHERE id=?').get(id);
      if (!row) return send(res, 404, { error: 'playlist_not_found' });
      const enabled = row.enabled ? 0 : 1;
      db.prepare('UPDATE playlists SET enabled=?, updated_at=? WHERE id=?').run(enabled, now(), id);
      return send(res, 200, { ok: true, enabled: Boolean(enabled) });
    }

    if (req.method === 'DELETE' && url.pathname.startsWith('/admin/api/devices/')) {
      if (!admin(req, res)) return;
      const deviceId = decodeURIComponent(url.pathname.split('/').pop());
      db.prepare('DELETE FROM playlists WHERE device_id=?').run(deviceId);
      const result = db.prepare('DELETE FROM devices WHERE device_id=?').run(deviceId);
      return send(res, result.changes ? 200 : 404, result.changes ? { ok: true } : { error: 'device_not_found' });
    }

    if (req.method === 'DELETE' && url.pathname.startsWith('/admin/api/playlists/')) {
      if (!admin(req, res)) return;
      const id = Number(url.pathname.split('/').pop());
      const result = db.prepare('DELETE FROM playlists WHERE id=?').run(id);
      return send(res, result.changes ? 200 : 404, result.changes ? { ok: true } : { error: 'playlist_not_found' });
    }

    if (req.method === 'GET' && (url.pathname === '/' || url.pathname === '/admin')) {
      const html = await readFile(join(__dirname, 'public', 'admin.html'));
      res.writeHead(200, { 'content-type': 'text/html; charset=utf-8' });
      return res.end(html);
    }

    return send(res, 404, { error: 'not_found' });
  } catch (error) {
    console.error(error);
    return send(res, 500, { error: 'server_error' });
  }
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`ZENQIVO backend listening on http://0.0.0.0:${PORT}`);
});

function shutdown(signal) {
  console.log(`ZENQIVO backend received ${signal}; shutting down.`);
  server.close(() => {
    try { db.close(); } catch {}
    process.exit(0);
  });
  setTimeout(() => process.exit(1), 10000).unref();
}

process.on('SIGTERM', () => shutdown('SIGTERM'));
process.on('SIGINT', () => shutdown('SIGINT'));
