const { execFileSync } = require('node:child_process');
const DOCUMENTS = ['BOOTSTRAP_PROMPT.md', 'GDD.md', 'ROADMAP.md', 'TEAM_CONTRACT.md', 'README.md'];

function isAuthorized(req, token) {
  const local = ['127.0.0.1', '::1', '::ffff:127.0.0.1'].includes(req.socket.remoteAddress);
  const origin = req.get('origin');
  const localOrigin = !origin || /^https?:\/\/(localhost|127\.0\.0\.1)(:\d+)?$/.test(origin);
  const forwarded = req.get('x-forwarded-for') || req.get('forwarded');
  return Boolean((local && localOrigin && !forwarded) ||
    (token && req.get('authorization') === `Bearer ${token}`));
}

function commitDocuments(root, message, run = execFileSync) {
  const options = { cwd: root, encoding: 'utf8' };
  run('git', ['add', '--', ...DOCUMENTS], options);
  run('git', ['commit', '-m', String(message)], options);
}

module.exports = { isAuthorized, commitDocuments };
