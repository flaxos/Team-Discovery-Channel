const test = require('node:test');
const assert = require('node:assert/strict');
const { isAuthorized, commitDocuments } = require('./repoExport');
const req = (address, headers = {}) => ({ socket: { remoteAddress: address }, get: key => headers[key] });
test('only local trusted requests or explicit token can export', () => {
  assert.equal(isAuthorized(req('127.0.0.1', {origin: 'http://localhost:5173'})), true);
  assert.equal(isAuthorized(req('127.0.0.1', {origin: 'https://evil.example'})), false);
  assert.equal(isAuthorized(req('127.0.0.1', {'x-forwarded-for': '203.0.113.1'})), false);
  assert.equal(isAuthorized(req('203.0.113.1')), false);
  assert.equal(isAuthorized(req('203.0.113.1', {authorization: 'Bearer secret'}), 'secret'), true);
});
test('commit message is a literal argument and staging is limited to generated documents', () => {
  const calls = [];
  const message = '"; touch /tmp/should-not-exist; $(id) `id`';
  commitDocuments('/repo', message, (...args) => calls.push(args));
  assert.deepEqual(calls[1][1], ['commit', '-m', message]);
  assert.deepEqual(calls[0][1], ['add', '--', 'BOOTSTRAP_PROMPT.md', 'GDD.md', 'ROADMAP.md', 'TEAM_CONTRACT.md', 'README.md']);
  assert.equal(calls[1][2].shell, undefined);
});
