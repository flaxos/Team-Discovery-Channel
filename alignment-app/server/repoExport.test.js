const test = require('node:test');
const assert = require('node:assert/strict');
const { isAuthorized, commitDocuments, GENERATED_PATHS } = require('./repoExport');
const req = (headers = {}) => ({ socket: { remoteAddress: '127.0.0.1' }, get: key => headers[key] });
test('loopback is not authorization; a matching explicit bearer token is required', () => {
  assert.equal(isAuthorized(req(), 'secret'), false);
  assert.equal(isAuthorized(req({ origin: 'http://localhost:5173' }), 'secret'), false);
  assert.equal(isAuthorized(req({ authorization: 'Bearer wrong' }), 'secret'), false);
  assert.equal(isAuthorized(req({ authorization: 'Bearer secret' }), 'secret'), true);
  assert.equal(isAuthorized(req({ authorization: 'Bearer secret' }), ''), false);
});
test('Git arguments are literal, limited to generated docs and exclude existing staged changes', () => {
  const calls = [];
  const message = '"; touch /tmp/should-not-exist; $(id) `id`';
  commitDocuments('/repo', message, (...args) => { calls.push(args); return 'feature/planning\n'; });
  assert.deepEqual(calls[1][1], ['add', '--', ...GENERATED_PATHS]);
  assert.deepEqual(calls[2][1], ['commit', '-m', message, '--only', '--', ...GENERATED_PATHS]);
  assert.equal(calls[2][2].shell, undefined);
  assert.equal(calls[2][2].timeout, 15000);
});
test('Git export refuses protected and detached branches', () => {
  for (const branch of ['main', 'master', '']) assert.throws(() => commitDocuments('/repo', 'update', () => branch), /feature branch/);
});
