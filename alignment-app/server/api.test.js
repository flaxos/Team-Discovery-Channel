const test = require('node:test');
const assert = require('node:assert/strict');
const fs = require('node:fs');
const os = require('node:os');
const path = require('node:path');
const { execFileSync } = require('node:child_process');
const { createApp } = require('./index');
const { resolveApiToken } = require('./auth');
const { DOCUMENTS } = require('./repoExport');
const API_TOKEN = 'fixture-api-access-token-32-characters';
const EXPORT_TOKEN = 'fixture-export-token-32-characters';

async function fixture(t, settings = {}) {
  const directory = fs.mkdtempSync(path.join(os.tmpdir(), 'tdc-api-'));
  const repoRoot = path.join(directory, 'repo'), dataDir = path.join(directory, 'data');
  fs.mkdirSync(repoRoot, { recursive: true });
  const manual = [...DOCUMENTS, 'README.md', 'docs/reviews/sprint-history.md'];
  for (const file of manual) {
    fs.mkdirSync(path.dirname(path.join(repoRoot, file)), { recursive: true });
    fs.writeFileSync(path.join(repoRoot, file), `MAINTAINED HISTORY: ${file}\n`);
  }
  if (settings.seedState) {
    fs.mkdirSync(dataDir, { recursive: true });
    fs.writeFileSync(path.join(dataDir, 'alignment_state.json'), JSON.stringify(settings.seedState));
  }
  const options = { repoRoot, dataDir, apiToken: API_TOKEN, exportToken: EXPORT_TOKEN, ...settings };
  const server = createApp(options).listen(0, '127.0.0.1');
  await new Promise(resolve => server.once('listening', resolve));
  const url = `http://127.0.0.1:${server.address().port}`;
  t.after(async () => {
    server.closeAllConnections();
    await new Promise(resolve => server.close(resolve));
    fs.rmSync(directory, { recursive: true, force: true });
  });
  const request = async (route, body, config = {}) => {
    const headers = { 'Content-Type': 'application/json', ...(config.token === false ? {} : { Authorization: `Bearer ${config.token || API_TOKEN}` }), ...config.headers };
    const response = await fetch(url + route, { method: config.method || (body === undefined ? 'GET' : 'POST'), headers, body: config.raw === undefined ? (body === undefined ? undefined : JSON.stringify(body)) : config.raw });
    return { status: response.status, headers: response.headers, data: await response.json().catch(() => null) };
  };
  const unchangedManual = () => {
    for (const file of manual) assert.equal(fs.readFileSync(path.join(repoRoot, file), 'utf8'), `MAINTAINED HISTORY: ${file}\n`);
  };
  const statePath = path.join(dataDir, 'alignment_state.json');
  return { request, options, server, directory, repoRoot, dataDir, statePath, unchangedManual };
}

test('all mutation routes, including destructive operations, reject unauthenticated loopback callers without writes', async t => {
  const f = await fixture(t);
  const before = fs.readFileSync(f.statePath);
  for (const route of ['/api/rank', '/api/vote', '/api/option', '/api/member', '/api/member/delete', '/api/member/toggle-role', '/api/reset-votes', '/api/reset', '/api/comment', '/api/compile', '/api/export-to-repo']) {
    const result = await f.request(route, {}, { token: false });
    assert.equal(result.status, 401, route);
  }
  assert.equal((await f.request('/api/member/flaxos', {}, { method: 'DELETE', token: false })).status, 401);
  assert.equal((await f.request('/api/state', undefined, { token: false })).status, 401);
  assert.equal((await f.request('/api/state', undefined, { token: 'wrong' })).status, 401);
  assert.deepEqual(fs.readFileSync(f.statePath), before);
  assert.equal(fs.existsSync(path.join(f.repoRoot, 'docs/generated')), false);
  f.unchangedManual();
});

test('CORS uses exact configured origins, rejects cross-site/form requests and never trusts Host or forwarded headers', async t => {
  const f = await fixture(t);
  const rejected = await f.request('/api/reset', {}, { headers: { Origin: 'https://evil.example', Host: 'evil.example' } });
  assert.equal(rejected.status, 403);
  assert.equal(rejected.headers.get('access-control-allow-origin'), null);
  const allowed = await f.request('/api/state', undefined, { headers: { Origin: 'http://localhost:5173' } });
  assert.equal(allowed.status, 200);
  assert.equal(allowed.headers.get('access-control-allow-origin'), 'http://localhost:5173');
  assert.equal(allowed.headers.get('cache-control'), 'no-store');
  assert.equal((await f.request('/api/reset', {}, { token: false, headers: { 'X-Forwarded-For': '127.0.0.1', Origin: 'http://localhost:5173' } })).status, 401);
  assert.equal((await f.request('/api/reset', {}, { headers: { 'Content-Type': 'text/plain' } })).status, 415);
  assert.equal((await f.request('/api/state', undefined, { method: 'OPTIONS', token: false, headers: { Origin: 'http://localhost:5173' } })).status, 204);
  const custom = await fixture(t, { allowedOrigins: ['https://planning.example'] });
  assert.equal((await custom.request('/api/state', undefined, { headers: { Origin: 'https://planning.example' } })).status, 200);
  assert.equal((await custom.request('/api/state', undefined, { headers: { Origin: 'http://localhost:5173' } })).status, 403);
});

test('malformed types, unknown IDs, prototype keys and invalid rankings cannot alter saved state', async t => {
  const f = await fixture(t);
  const state = (await f.request('/api/state')).data.state;
  const q = state.questions[0], member = state.team[0].id, option = q.options[0].id;
  const before = fs.readFileSync(f.statePath);
  const invalid = [
    ['/api/vote', { questionId: q.id, memberId: member, optionId: 'not-an-option' }],
    ['/api/vote', { questionId: {}, memberId: member, optionId: option }],
    ['/api/vote', { questionId: q.id, memberId: '__proto__', optionId: option }],
    ['/api/member', { id: 'constructor', name: 'Unsafe' }],
    ['/api/member', { name: {}, weeklyHours: 4 }],
    ['/api/member', { name: 'Casey', weeklyHours: 'not-a-number' }],
    ['/api/member', { name: 'Casey', color: 'url(evil)' }],
    ['/api/member', { name: 'Casey', rolePreferences: [{}] }],
    ['/api/rank', { questionId: q.id, memberId: member, action: 'set_all', rankings: [option, option] }],
    ['/api/rank', { questionId: q.id, memberId: member, optionId: option, action: 'set_rank', targetRank: -2 }],
    ['/api/rank', { questionId: q.id, memberId: member, optionId: option, action: 'invented' }],
    ['/api/option', { questionId: q.id, title: 'Title', description: 'Description', pros: [{}] }],
    ['/api/comment', { questionId: q.id, memberId: member, text: null }],
    ['/api/member/delete', { id: 'unknown-member' }],
    ['/api/member/toggle-role', { memberId: member, roleName: {} }],
    ['/api/reset', { surprise: true }],
    ['/api/export-to-repo', { destination: '../../README.md' }]
  ];
  for (const [route, body] of invalid) {
    const response = await f.request(route, body);
    assert.ok([400, 404].includes(response.status), `${route}: ${response.status}`);
    assert.deepEqual(fs.readFileSync(f.statePath), before);
  }
  assert.equal((await f.request('/api/reset', {}, { raw: '{invalid' })).status, 400);
  assert.equal((await f.request('/api/comment', {}, { raw: JSON.stringify({ text: 'x'.repeat(70000) }) })).status, 413);
  assert.deepEqual(fs.readFileSync(f.statePath), before);
  assert.equal({}.polluted, undefined);
  f.unchangedManual();
});

test('authorized voting, comments, members and resets persist without overwriting maintained documents', async t => {
  const f = await fixture(t);
  let state = (await f.request('/api/state')).data.state;
  const q = state.questions[0], member = state.team[0].id, option = q.options[0].id;
  const vote = await f.request('/api/vote', { questionId: q.id, memberId: member, optionId: option });
  assert.equal(vote.status, 200);
  assert.ok(vote.data.state.questions[0].options[0].votes.includes(member));
  assert.equal((await f.request('/api/comment', { questionId: q.id, memberId: member, text: 'A maintained playtest note.' })).status, 200);
  assert.equal((await f.request('/api/member', { name: 'Casey', weeklyHours: 0 })).status, 200);
  assert.equal((await f.request('/api/member', { name: 'Casey' })).status, 409, 'New-member collision must not overwrite an existing member');
  const unicode = await f.request('/api/member', { name: '四' });
  assert.equal(unicode.status, 200, 'Non-Latin names get a safe generated ID');
  assert.equal((await f.request('/api/member/toggle-role', { memberId: 'casey', roleName: 'QA' })).status, 200);
  const added = await f.request('/api/option', { questionId: q.id, title: 'Custom', description: 'Keep existing voting.', memberId: 'casey' });
  assert.equal(added.status, 200);
  assert.ok(added.data.newOption.id.startsWith('opt_custom_'));
  assert.equal((await f.request('/api/reset-votes', {})).status, 200);
  state = (await f.request('/api/state')).data.state;
  assert.ok(state.team.some(item => item.id === 'casey'));
  assert.ok(state.questions[0].options.some(item => item.id === added.data.newOption.id));
  assert.ok(state.questions.every(question => question.options.every(item => item.votes.length === 0)));
  assert.equal((await f.request('/api/member/casey', {}, { method: 'DELETE' })).status, 200);
  const exported = await f.request('/api/export-to-repo', {});
  assert.equal(exported.status, 200);
  assert.ok(exported.data.filesWritten.every(file => file.startsWith('docs/generated/')));
  assert.equal(exported.data.gitPushed, false);
  const disk = JSON.parse(fs.readFileSync(f.statePath));
  assert.deepEqual(disk, (await f.request('/api/state')).data.state);
  const app2 = createApp(f.options).listen(0, '127.0.0.1');
  await new Promise(resolve => app2.once('listening', resolve));
  const reloaded = await fetch(`http://127.0.0.1:${app2.address().port}/api/state`, { headers: { Authorization: `Bearer ${API_TOKEN}` } });
  assert.deepEqual((await reloaded.json()).state, disk);
  app2.closeAllConnections();
  await new Promise(resolve => app2.close(resolve));
  for (const name of DOCUMENTS) assert.ok(fs.readFileSync(path.join(f.repoRoot, 'docs/generated', name), 'utf8').length > 100);
  f.unchangedManual();
  assert.equal((await f.request('/api/reset', {})).status, 200);
  assert.equal((await f.request('/api/member/delete', { id: 'flaxos' })).status, 200);
  const beforeFinalDelete = fs.readFileSync(f.statePath);
  assert.equal((await f.request('/api/member/delete', { id: 'scotty' })).status, 409, 'The final member cannot be removed');
  assert.deepEqual(fs.readFileSync(f.statePath), beforeFinalDelete);
  f.unchangedManual();
});

test('Git export requires explicit operator enablement plus a separate secret; never pushes implicitly', async t => {
  const calls = [];
  const runGit = (...args) => { calls.push(args); return 'feature/generated\n'; };
  const disabled = await fixture(t, { runGit });
  assert.equal((await disabled.request('/api/export-to-repo', { gitCommit: true }, { headers: { 'X-Alignment-Export-Token': EXPORT_TOKEN } })).status, 403);
  assert.equal(calls.length, 0);
  const enabled = await fixture(t, { allowGit: true, runGit });
  assert.equal((await enabled.request('/api/export-to-repo', { gitCommit: true })).status, 403);
  assert.equal((await enabled.request('/api/export-to-repo', { gitPush: true })).status, 400);
  const message = '"; $(touch should-not-exist) `id`';
  const result = await enabled.request('/api/export-to-repo', { gitCommit: true, commitMessage: message }, { headers: { 'X-Alignment-Export-Token': EXPORT_TOKEN } });
  assert.equal(result.status, 200);
  assert.equal(result.data.gitCommitted, true);
  assert.equal(result.data.gitPushed, false);
  assert.equal(calls.length, 3);
  assert.equal(calls[2][1][2], message);
  assert.ok(calls.every(call => !call[1].includes('push')));
  enabled.unchangedManual();
});

test('real Git export leaves unrelated staged changes staged and never commits root history', async t => {
  const f = await fixture(t, { allowGit: true });
  const git = (...args) => execFileSync('git', args, { cwd: f.repoRoot, encoding: 'utf8' });
  git('init', '-b', 'feature/generated');
  git('config', 'user.email', 'fixture@example.invalid');
  git('config', 'user.name', 'Fixture');
  git('add', '.'); git('commit', '-m', 'fixture baseline');
  fs.writeFileSync(path.join(f.repoRoot, 'unrelated.txt'), 'unrelated gameplay change\n');
  git('add', 'unrelated.txt');
  const result = await f.request('/api/export-to-repo', { gitCommit: true }, { headers: { 'X-Alignment-Export-Token': EXPORT_TOKEN } });
  assert.equal(result.status, 200);
  assert.equal(git('diff', '--cached', '--name-only').trim(), 'unrelated.txt');
  assert.ok(git('show', '--format=', '--name-only', 'HEAD').trim().split('\n').every(file => file.startsWith('docs/generated/')));
  f.unchangedManual();
});

test('generated path cannot redirect writes to maintained files; corrupt stored state is preserved', async t => {
  const f = await fixture(t);
  fs.symlinkSync(f.directory, path.join(f.repoRoot, 'docs/generated'));
  assert.equal((await f.request('/api/reset-votes', {})).status, 500);
  f.unchangedManual();
  const before = fs.readFileSync(f.statePath);
  fs.writeFileSync(f.statePath, '{corrupt');
  assert.throws(() => createApp(f.options));
  assert.equal(fs.readFileSync(f.statePath, 'utf8'), '{corrupt');
  fs.writeFileSync(f.statePath, before);
});

test('local token is private, stable and never available through an HTTP bootstrap', async t => {
  const f = await fixture(t);
  const privateDir = path.join(f.directory, 'private');
  const token = resolveApiToken(privateDir);
  assert.ok(token.length >= 32);
  assert.equal(resolveApiToken(privateDir), token);
  assert.equal(fs.statSync(path.join(privateDir, '.api-token')).mode & 0o777, 0o600);
  assert.throws(() => resolveApiToken(privateDir, 'weak'), /at least 32/);
  assert.equal((await f.request('/api/token', undefined, { token: false })).status, 401);
  const state = await f.request('/api/state');
  assert.equal(state.data.repoRoot, undefined);
  assert.ok(!JSON.stringify(state.data).includes(API_TOKEN));
});


test('existing repository voting state loads intact and the UI add/rank actions remain compatible', async t => {
  const existing = JSON.parse(fs.readFileSync(path.join(__dirname, 'data/alignment_state.json'), 'utf8'));
  const f = await fixture(t, { seedState: existing });
  const loaded = (await f.request('/api/state')).data.state;
  assert.equal(JSON.stringify(loaded) === JSON.stringify(existing), true, 'Existing data must not be rewritten during load');
  const question = loaded.questions[0], memberId = loaded.team[0].id;
  const optionId = question.options[0].id;
  assert.equal((await f.request('/api/rank', { questionId: question.id, memberId, action: 'set_all', rankings: [] })).status, 200);
  for (let i = 0; i < 2; i++) assert.equal((await f.request('/api/rank', { questionId: question.id, memberId, optionId, action: 'add' })).status, 200);
  const ranked = (await f.request('/api/state')).data.state.questions[0].userRankings[memberId];
  assert.deepEqual(ranked, [optionId], 'Add is idempotent and cannot toggle an already ranked option off');
  assert.equal((await f.request('/api/rank', { questionId: question.id, memberId, optionId, action: 'set_rank', targetRank: 1 })).status, 200);
  assert.equal((await f.request('/api/rank', { questionId: question.id, memberId, optionId, action: 'remove' })).status, 200);
  f.unchangedManual();
});


test('privileged export configuration cannot reuse a weak or ordinary API token', async t => {
  const f = await fixture(t);
  assert.throws(() => createApp({ ...f.options, allowGit: true, exportToken: 'weak' }), /distinct ALIGNMENT_EXPORT_TOKEN/);
  assert.throws(() => createApp({ ...f.options, allowGit: true, exportToken: API_TOKEN }), /distinct ALIGNMENT_EXPORT_TOKEN/);
});
