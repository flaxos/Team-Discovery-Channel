const express = require('express');
const fs = require('node:fs');
const path = require('node:path');
const crypto = require('node:crypto');
const { execFileSync } = require('node:child_process');
const initialState = require('./initialState');
const compiler = require('./compiler');
const { resolveApiToken, bearerAuthorized, tokenMatches, originAllowed } = require('./auth');
const { commitDocuments, DOCUMENTS, GENERATED_PATHS } = require('./repoExport');
const v = require('./validation');
const DEFAULT_ORIGINS = ['http://localhost:5173', 'http://127.0.0.1:5173', 'http://localhost:4100', 'http://127.0.0.1:4100'];
const clone = value => structuredClone(value);
function atomicWrite(file, contents) {
  const temporary = file + '.tmp-' + crypto.randomUUID();
  try {
    fs.writeFileSync(temporary, contents, { encoding: 'utf8', flag: 'wx' });
    fs.renameSync(temporary, file);
  } finally {
    if (fs.existsSync(temporary)) fs.unlinkSync(temporary);
  }
}

function compile(state) {
  const analysis = compiler.analyzeVotes(state);
  return { analysis, compiled: {
    bootstrapPrompt: compiler.generateBootstrapPrompt(state, analysis),
    gdd: compiler.generateGDD(state, analysis),
    roadmap: compiler.generateRoadmap(state, analysis),
    contract: compiler.generateContract(state, analysis)
  } };
}
function writeGenerated(repoRoot, compiled) {
  for (const relative of ['docs', 'docs/generated']) {
    const target = path.join(repoRoot, relative);
    if (fs.existsSync(target) && fs.lstatSync(target).isSymbolicLink()) throw new Error('Generated document destination cannot be a symlink.');
  }
  const directory = path.join(repoRoot, 'docs/generated');
  fs.mkdirSync(directory, { recursive: true });
  const contents = [compiled.bootstrapPrompt, compiled.gdd, compiled.roadmap, compiled.contract];
  DOCUMENTS.forEach((name, i) => {
    const target = path.join(directory, name);
    atomicWrite(target, contents[i]);
  });
}

function createApp(options = {}) {
  const app = express();
  app.disable('x-powered-by');
  const repoRoot = path.resolve(options.repoRoot || path.join(__dirname, '..', '..'));
  const dataDir = path.resolve(options.dataDir || process.env.ALIGNMENT_DATA_DIR || path.join(__dirname, 'data'));
  const stateFile = path.join(dataDir, 'alignment_state.json');
  const apiToken = resolveApiToken(dataDir, options.apiToken ?? process.env.ALIGNMENT_API_TOKEN);
  const exportToken = options.exportToken ?? process.env.ALIGNMENT_EXPORT_TOKEN;
  const allowGit = options.allowGit ?? process.env.ALIGNMENT_ALLOW_GIT_EXPORT === '1';
  if (allowGit && (typeof exportToken !== 'string' || exportToken.length < 32 || tokenMatches(apiToken, exportToken))) {
    throw new Error('Git export requires a distinct ALIGNMENT_EXPORT_TOKEN of at least 32 characters.');
  }
  const allowedOrigins = new Set(options.allowedOrigins || (process.env.ALIGNMENT_ALLOWED_ORIGINS || DEFAULT_ORIGINS.join(',')).split(',').map(item => item.trim()).filter(Boolean));
  const runGit = options.runGit || execFileSync;
  fs.mkdirSync(dataDir, { recursive: true });
  let state = fs.existsSync(stateFile) ? JSON.parse(fs.readFileSync(stateFile, 'utf8')) : clone(initialState);
  if (!Array.isArray(state.team) || !Array.isArray(state.questions)) throw new Error('Invalid stored alignment state; the file was preserved for recovery.');
  const persist = candidate => {
    const result = compile(candidate);
    writeGenerated(repoRoot, result.compiled);
    atomicWrite(stateFile, JSON.stringify(candidate, null, 2) + '\n');
    state = candidate;
    return result;
  };
  if (!fs.existsSync(stateFile)) fs.writeFileSync(stateFile, JSON.stringify(state, null, 2) + '\n', { flag: 'wx' });

  app.get('/api/health', (_req, res) => res.json({ success: true }));
  app.use('/api', (req, res, next) => {
    res.set('Cache-Control', 'no-store');
    res.set('Vary', 'Origin');
    if (!originAllowed(req, allowedOrigins)) return res.status(403).json({ error: 'Origin is not allowed.' });
    const origin = req.get('origin');
    if (origin) res.set('Access-Control-Allow-Origin', origin);
    if (req.method === 'OPTIONS') {
      res.set('Access-Control-Allow-Methods', 'GET, POST, DELETE, OPTIONS');
      res.set('Access-Control-Allow-Headers', 'Authorization, Content-Type, X-Alignment-Export-Token');
      return res.sendStatus(204);
    }
    if (!bearerAuthorized(req, apiToken)) return res.status(401).json({ error: 'An API access token is required.' });
    if (!['GET', 'HEAD'].includes(req.method) && !req.is('application/json')) return res.status(415).json({ error: 'Mutations require application/json.' });
    next();
  });
  app.use(express.json({ limit: '64kb', strict: true }));
  const answer = (res, result = compile(state), extra = {}) => res.json({ success: true, state, analysis: result.analysis, ...extra });
  const mutate = (route, allowed, handler) => app.post(route, (req, res) => {
    const body = v.fields(req.body || {}, allowed);
    const candidate = clone(state);
    const extra = handler(candidate, body) || {};
    answer(res, persist(candidate), extra);
  });
  const syncVotes = (question, memberId) => {
    const stack = question.userRankings[memberId];
    for (const option of question.options) {
      option.votes = (option.votes || []).filter(member => member !== memberId);
      if (stack.includes(option.id)) option.votes.push(memberId);
    }
  };
  const rank = (candidate, body) => {
    const question = v.findQuestion(candidate, body.questionId);
    const memberId = v.findMember(candidate, body.memberId).id;
    const action = body.action === undefined ? 'toggle' : body.action;
    if (!['toggle', 'add', 'set_all', 'remove', 'unrank', 'move_up', 'move_down', 'set_rank'].includes(action)) v.invalid('Invalid rank action.');
    let rankings;
    if (action === 'set_all') {
      rankings = v.stringList(body.rankings, 'rankings', question.options.length, 80);
      if (new Set(rankings).size !== rankings.length) v.invalid('Rankings must be unique.');
      rankings.forEach(option => v.findOption(question, option));
    } else {
      const optionId = v.findOption(question, body.optionId).id;
      if (body.targetRank !== undefined && (!Number.isInteger(body.targetRank) || body.targetRank < 1 || body.targetRank > question.options.length)) v.invalid('Invalid targetRank.');
      rankings = [...(question.userRankings?.[memberId] || [])];
      const index = rankings.indexOf(optionId);
      if (action === 'remove' || action === 'unrank') rankings = rankings.filter(item => item !== optionId);
      else if (action === 'move_up' || action === 'move_down') {
        const target = index + (action === 'move_up' ? -1 : 1);
        if (index >= 0 && target >= 0 && target < rankings.length) [rankings[index], rankings[target]] = [rankings[target], rankings[index]];
      } else if (action === 'set_rank') {
        if (!Number.isInteger(body.targetRank)) v.invalid('targetRank is required.');
        rankings = rankings.filter(item => item !== optionId);
        rankings.splice(Math.min(body.targetRank - 1, rankings.length), 0, optionId);
      } else if (action === 'add') { if (index < 0) rankings.push(optionId); }
      else if (index >= 0) rankings.splice(index, 1);
      else rankings.push(optionId);
    }
    question.userRankings ||= {};
    question.userRankings[memberId] = rankings;
    syncVotes(question, memberId);
  };

  app.get('/api/state', (_req, res) => answer(res));
  app.get('/api/compile', (_req, res) => res.json({ success: true, ...compile(state) }));
  app.post('/api/compile', (req, res) => { v.fields(req.body || {}, []); res.json({ success: true, ...compile(state) }); });
  mutate('/api/rank', ['questionId', 'memberId', 'optionId', 'action', 'targetRank', 'rankings'], rank);
  mutate('/api/vote', ['questionId', 'memberId', 'optionId'], rank);
  mutate('/api/option', ['questionId', 'title', 'description', 'feasibility', 'pros', 'caution', 'memberId'], (candidate, body) => {
    const question = v.findQuestion(candidate, body.questionId);
    const memberId = body.memberId === undefined ? null : v.findMember(candidate, body.memberId).id;
    const title = v.text(body.title, 'title'), description = v.text(body.description, 'description', 4000);
    const feasibility = body.feasibility === undefined ? 'Medium' : v.text(body.feasibility, 'feasibility', 40);
    if (!['Very High', 'High', 'Medium', 'Low', 'Very Low'].includes(feasibility)) v.invalid('Invalid feasibility.');
    const pros = body.pros === undefined ? ['Community Idea'] : v.stringList(typeof body.pros === 'string' ? body.pros.split(',') : body.pros, 'pros');
    const option = { id: `opt_custom_${crypto.randomUUID()}`, title, description, feasibility, pros,
      caution: body.caution === undefined ? 'Requires team validation.' : v.text(body.caution, 'caution', 2000),
      isCustom: true, addedBy: memberId || 'crew', votes: memberId ? [memberId] : [] };
    question.options.push(option);
    if (memberId) {
      question.userRankings ||= {};
      question.userRankings[memberId] = [...(question.userRankings[memberId] || []), option.id];
      syncVotes(question, memberId);
    }
    return { newOption: option };
  });
  mutate('/api/member', ['id', 'name', 'avatar', 'color', 'rolePreferences', 'weeklyHours', 'notes'], (candidate, body) => {
    const name = v.text(body.name, 'name', 80);
    const slug = name.toLowerCase().replace(/[^a-z0-9]/g, '_');
    const suggested = /^[a-z0-9][a-z0-9_-]{0,79}$/.test(slug) ? slug : `member_${crypto.randomUUID()}`;
    const memberId = v.id(body.id === undefined ? suggested : body.id, 'member ID');
    const index = candidate.team.findIndex(member => member.id === memberId);
    if (index >= 0 && body.id === undefined) throw new v.RequestError('A member with this name already exists; edit the existing member.', 409);
    const color = body.color === undefined ? '#38bdf8' : v.text(body.color, 'color', 7);
    if (!/^#[a-fA-F0-9]{6}$/.test(color)) v.invalid('Invalid color.');
    const hours = body.weeklyHours === undefined ? 5 : body.weeklyHours;
    if (typeof hours !== 'number' || !Number.isFinite(hours) || hours < 0 || hours > 168) v.invalid('Invalid weeklyHours.');
    const member = { id: memberId, name, avatar: body.avatar === undefined ? '👾' : v.text(body.avatar, 'avatar', 32), color,
      rolePreferences: body.rolePreferences === undefined ? ['Gameplay & Systems'] : v.stringList(body.rolePreferences, 'rolePreferences'),
      weeklyHours: hours, notes: body.notes === undefined ? '' : v.text(body.notes, 'notes', 4000, { empty: true }) };
    if (index >= 0) candidate.team[index] = { ...candidate.team[index], ...member };
    else candidate.team.push(member);
    return { member };
  });
  const removeMember = (candidate, body) => {
    const memberId = v.findMember(candidate, body.id).id;
    if (candidate.team.length <= 1) throw new v.RequestError('Keep at least one team member.', 409);
    candidate.team = candidate.team.filter(member => member.id !== memberId);
    for (const question of candidate.questions) {
      if (question.userRankings) delete question.userRankings[memberId];
      for (const option of question.options) option.votes = (option.votes || []).filter(member => member !== memberId);
      question.comments = (question.comments || []).filter(comment => comment.memberId !== memberId);
    }
  };
  mutate('/api/member/delete', ['id'], removeMember);
  app.delete('/api/member/:id', (req, res) => {
    v.fields(req.body || {}, []);
    const candidate = clone(state);
    removeMember(candidate, { id: req.params.id });
    answer(res, persist(candidate));
  });
  mutate('/api/member/toggle-role', ['memberId', 'roleName'], (candidate, body) => {
    const member = v.findMember(candidate, body.memberId), role = v.text(body.roleName, 'roleName');
    const roles = member.rolePreferences || [];
    member.rolePreferences = roles.includes(role) ? roles.filter(item => item !== role) : [...roles, role];
    if (member.rolePreferences.length > 20) v.invalid('Too many roles.');
    return { member };
  });
  mutate('/api/comment', ['questionId', 'memberId', 'text'], (candidate, body) => {
    const question = v.findQuestion(candidate, body.questionId), member = v.findMember(candidate, body.memberId);
    const comment = { id: `c_${crypto.randomUUID()}`, memberId: member.id, text: v.text(body.text, 'comment', 4000), timestamp: new Date().toISOString() };
    question.comments ||= [];
    question.comments.push(comment);
    return { question };
  });
  mutate('/api/reset-votes', [], candidate => {
    for (const question of candidate.questions) { question.userRankings = {}; for (const option of question.options) option.votes = []; }
  });
  mutate('/api/reset', [], candidate => {
    for (const key of Object.keys(candidate)) delete candidate[key];
    Object.assign(candidate, clone(initialState));
  });
  app.post('/api/export-to-repo', (req, res) => {
    const body = v.fields(req.body || {}, ['gitCommit', 'gitPush', 'commitMessage']);
    const gitCommit = v.boolean(body.gitCommit, 'gitCommit'), gitPush = v.boolean(body.gitPush, 'gitPush');
    const message = body.commitMessage === undefined ? 'docs: update generated alignment snapshot' : v.text(body.commitMessage, 'commitMessage', 200);
    if (gitPush && !gitCommit) v.invalid('gitPush requires gitCommit.');
    if ((gitCommit || gitPush) && (!allowGit || !tokenMatches(req.get('x-alignment-export-token'), exportToken))) return res.status(403).json({ error: 'Git export is disabled or requires the separate export token.' });
    const { compiled } = compile(state);
    writeGenerated(repoRoot, compiled);
    if (gitCommit) commitDocuments(repoRoot, message, runGit);
    if (gitPush) runGit('git', ['push', 'origin', 'HEAD'], { cwd: repoRoot, encoding: 'utf8', timeout: 30000, maxBuffer: 1024 * 1024 });
    res.json({ success: true, message: 'Exported planning snapshots to docs/generated/. Manual project documents were preserved.', filesWritten: GENERATED_PATHS, gitCommitted: gitCommit, gitPushed: gitPush });
  });
  app.use('/api', (_req, res) => res.status(404).json({ error: 'API route not found.' }));
  const distDir = options.distDir || path.join(__dirname, '..', 'dist');
  if (fs.existsSync(distDir)) {
    app.use(express.static(distDir));
    app.get(/^(?!\/api).+/, (_req, res) => res.sendFile(path.join(distDir, 'index.html')));
  }
  app.use((error, _req, res, _next) => {
    const status = error.status || (error.type === 'entity.too.large' ? 413 : 500);
    res.status(status >= 400 && status < 500 ? status : 500).json({ error: error.type === 'entity.parse.failed' ? 'Malformed JSON body.' : (status >= 400 && status < 500 ? error.message : 'Operation failed; saved state and manual documents were preserved.') });
  });
  return app;
}
if (require.main === module) {
  const port = Number(process.env.PORT || 4100), host = process.env.ALIGNMENT_HOST || '127.0.0.1';
  createApp().listen(port, host, () => console.log(`Alignment API listening on ${host}:${port}. Use npm run auth-token locally to retrieve the access token.`));
}
module.exports = { createApp, compile, writeGenerated };
