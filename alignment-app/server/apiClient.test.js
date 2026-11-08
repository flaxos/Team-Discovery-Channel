const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const path = require('node:path');

test('browser API client sends session tokens, rejects non-local paths and surfaces authorization failures', async () => {
  const previous = { sessionStorage: global.sessionStorage, window: global.window, fetch: global.fetch };
  const storage = new Map();
  global.sessionStorage = { getItem: key => storage.get(key), setItem: (key, value) => storage.set(key, value), removeItem: key => storage.delete(key) };
  global.window = new EventTarget();
  const events = [];
  global.window.addEventListener('alignment-api-error', event => events.push(event.detail));
  const calls = [];
  global.fetch = async (...args) => { calls.push(args); return new Response(JSON.stringify({ success: true }), { status: 200 }); };
  try {
    const source = fs.readFileSync(path.join(__dirname, '../src/api.js'), 'utf8');
    const api = await import('data:text/javascript;base64,' + Buffer.from(source).toString('base64'));
    api.setAccessToken('fixture-browser-token');
    await api.apiFetch('/api/vote', { method: 'POST', body: '{}' });
    assert.equal(calls[0][1].headers.get('authorization'), 'Bearer fixture-browser-token');
    assert.equal(calls[0][1].headers.get('content-type'), 'application/json');
    assert.equal(calls[0][1].credentials, 'omit');
    await assert.rejects(api.apiFetch('https://evil.example/api/vote'), /local API path/);
    global.fetch = async () => new Response(JSON.stringify({ error: 'An API access token is required.' }), { status: 401 });
    await assert.rejects(api.apiFetch('/api/state'), /token is required/);
    assert.equal(events.at(-1).status, 401);
    api.setAccessToken('');
    assert.equal(api.getAccessToken(), '');
  } finally {
    global.sessionStorage = previous.sessionStorage;
    global.window = previous.window;
    global.fetch = previous.fetch;
  }
});
