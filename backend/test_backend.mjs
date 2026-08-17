import assert from 'node:assert/strict';
import { mkdtemp, cp, rm } from 'node:fs/promises';
import { tmpdir } from 'node:os';
import { join, dirname } from 'node:path';
import { fileURLToPath } from 'node:url';
import { spawn } from 'node:child_process';

const here = dirname(fileURLToPath(import.meta.url));
const temp = await mkdtemp(join(tmpdir(), 'zenqivo-backend-test-'));
await cp(here, temp, { recursive: true });

const port = 8799;
const adminToken = 'zenqivo-test-admin-token-1234567890';
const credentialKey = 'zenqivo-test-credential-key-1234567890';

const child = spawn(
  process.execPath,
  ['--experimental-sqlite', 'server.js'],
  {
    cwd: temp,
    env: {
      ...process.env,
      PORT: String(port),
      ZENQIVO_ADMIN_TOKEN: adminToken,
      ZENQIVO_CREDENTIAL_KEY: credentialKey,
    },
    stdio: ['ignore', 'pipe', 'pipe'],
  },
);

const base = `http://127.0.0.1:${port}`;

async function request(path, { method = 'GET', body, admin = false } = {}) {
  const response = await fetch(base + path, {
    method,
    headers: {
      ...(body ? { 'content-type': 'application/json' } : {}),
      ...(admin ? { 'x-admin-token': adminToken } : {}),
    },
    body: body ? JSON.stringify(body) : undefined,
  });
  let json = {};
  try { json = await response.json(); } catch {}
  return { status: response.status, json };
}

async function waitForHealth() {
  for (let i = 0; i < 30; i++) {
    try {
      const result = await request('/health');
      if (result.status === 200) return;
    } catch {}
    await new Promise(resolve => setTimeout(resolve, 100));
  }
  throw new Error('backend_did_not_start');
}

try {
  await waitForHealth();

  let result = await request('/api/v1/devices/register', {
    method: 'POST',
    body: {
      deviceId: 'TEST-TV-001',
      deviceKey: 'TEST-KEY-001',
      platform: 'android-tv',
      appVersion: '0.14.0',
    },
  });
  assert.equal(result.status, 200);
  assert.equal(result.json.active, false);

  result = await request(
    '/api/v1/sync?deviceId=TEST-TV-001&deviceKey=TEST-KEY-001',
  );
  assert.equal(result.status, 403);
  assert.equal(result.json.error, 'device_not_active');

  result = await request('/admin/api/activate', {
    method: 'POST',
    admin: true,
    body: { deviceId: 'TEST-TV-001', days: 30 },
  });
  assert.equal(result.status, 200);

  result = await request('/admin/api/playlists', {
    method: 'POST',
    admin: true,
    body: {
      deviceId: 'TEST-TV-001',
      name: 'QA M3U',
      type: 'm3u',
      sourceUrl: 'https://example.com/test.m3u',
    },
  });
  assert.equal(result.status, 201);
  const playlistId = result.json.playlistId;
  assert.ok(Number.isInteger(playlistId));

  result = await request(
    '/api/v1/sync?deviceId=TEST-TV-001&deviceKey=TEST-KEY-001',
  );
  assert.equal(result.status, 200);
  assert.equal(result.json.playlists.length, 1);

  result = await request(`/admin/api/playlists/toggle/${playlistId}`, {
    method: 'POST',
    admin: true,
    body: {},
  });
  assert.equal(result.status, 200);
  assert.equal(result.json.enabled, false);

  result = await request('/admin/api/playlists?deviceId=TEST-TV-001', {
    admin: true,
  });
  assert.equal(result.status, 200);
  assert.equal(result.json.playlists.length, 1);
  assert.equal(result.json.playlists[0].enabled, 0);

  result = await request(`/admin/api/playlists/${playlistId}`, {
    method: 'DELETE',
    admin: true,
  });
  assert.equal(result.status, 200);

  result = await request('/admin/api/devices/TEST-TV-001', {
    method: 'DELETE',
    admin: true,
  });
  assert.equal(result.status, 200);

  console.log('ZENQIVO backend integration test: PASS');
} finally {
  child.kill('SIGTERM');
  await new Promise(resolve => child.once('exit', resolve));
  await rm(temp, { recursive: true, force: true });
}
