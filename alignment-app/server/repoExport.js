const { execFileSync } = require('node:child_process');
const { bearerAuthorized } = require('./auth');
const DOCUMENTS = ['BOOTSTRAP_PROMPT.md', 'GDD.md', 'ROADMAP.md', 'TEAM_CONTRACT.md'];
const GENERATED_PATHS = DOCUMENTS.map(file => `docs/generated/${file}`);
function isAuthorized(req, token) { return bearerAuthorized(req, token); }
function commitDocuments(root, message, run = execFileSync) {
  const options = { cwd: root, encoding: 'utf8', timeout: 15000, maxBuffer: 1024 * 1024 };
  const branch = run('git', ['branch', '--show-current'], options).trim();
  if (!branch || ['main', 'master'].includes(branch)) throw new Error('Git export requires a feature branch.');
  run('git', ['add', '--', ...GENERATED_PATHS], options);
  // Keep unrelated pre-existing staged changes out of generated-document commits.
  run('git', ['commit', '-m', String(message), '--only', '--', ...GENERATED_PATHS], options);
}
module.exports = { isAuthorized, commitDocuments, DOCUMENTS, GENERATED_PATHS };
