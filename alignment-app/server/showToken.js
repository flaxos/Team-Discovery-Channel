// Explicit local operator command; no HTTP route exposes this token.
const path = require('node:path');
const { resolveApiToken } = require('./auth');
process.stdout.write(resolveApiToken(process.env.ALIGNMENT_DATA_DIR || path.join(__dirname, 'data')) + '\n');
