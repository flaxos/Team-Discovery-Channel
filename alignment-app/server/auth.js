const crypto = require('node:crypto');
const fs = require('node:fs');
const path = require('node:path');
function tokenMatches(actual, expected) {
  if (typeof actual !== 'string' || typeof expected !== 'string' || !expected) return false;
  const supplied = Buffer.from(actual), wanted = Buffer.from(expected);
  return supplied.length === wanted.length && crypto.timingSafeEqual(supplied, wanted);
}
function bearerAuthorized(req, token) {
  const header = req.get('authorization');
  return typeof header === 'string' && header.startsWith('Bearer ') && tokenMatches(header.slice(7), token);
}
function resolveApiToken(dataDir, configured = process.env.ALIGNMENT_API_TOKEN) {
  if (configured !== undefined) {
    if (typeof configured !== 'string' || configured.length < 32) throw new Error('ALIGNMENT_API_TOKEN must contain at least 32 characters.');
    return configured;
  }
  fs.mkdirSync(dataDir, { recursive: true });
  const tokenPath = path.join(dataDir, '.api-token');
  try {
    const token = fs.readFileSync(tokenPath, 'utf8').trim();
    if (token.length < 32) throw new Error('Local API token is invalid; restore or remove the .api-token file.');
    fs.chmodSync(tokenPath, 0o600);
    return token;
  } catch (error) {
    if (error.code !== 'ENOENT') throw error;
    const token = crypto.randomBytes(32).toString('hex');
    fs.writeFileSync(tokenPath, token + '\n', { flag: 'wx', mode: 0o600 });
    return token;
  }
}
function originAllowed(req, origins) {
  const origin = req.get('origin');
  // A request's own Host header cannot authorize its Origin. Non-browser tools
  // still require a token; there is no localhost authentication bypass.
  return !origin || origins.has(origin);
}
module.exports = { bearerAuthorized, tokenMatches, resolveApiToken, originAllowed };
