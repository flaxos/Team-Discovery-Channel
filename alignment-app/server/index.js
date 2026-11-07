const express = require('express');
const cors = require('cors');
const fs = require('fs');
const path = require('path');
const { execSync } = require('child_process');
const initialState = require('./initialState');
const {
  analyzeVotes,
  generateBootstrapPrompt,
  generateGDD,
  generateRoadmap,
  generateContract
} = require('./compiler');

const app = express();
const PORT = process.env.PORT || 4100;

app.use(cors());
app.use(express.json());

const DATA_DIR = path.join(__dirname, 'data');
const STATE_FILE = path.join(DATA_DIR, 'alignment_state.json');
const REPO_ROOT = path.resolve(__dirname, '..', '..'); // /home/flax/games/Team-Discovery-Channel

// Ensure data directory exists
if (!fs.existsSync(DATA_DIR)) {
  fs.mkdirSync(DATA_DIR, { recursive: true });
}

// Load or initialize state
let state;
if (fs.existsSync(STATE_FILE)) {
  try {
    state = JSON.parse(fs.readFileSync(STATE_FILE, 'utf8'));
  } catch (err) {
    console.error('Error reading state file, using initial state:', err);
    state = JSON.parse(JSON.stringify(initialState));
  }
} else {
  state = JSON.parse(JSON.stringify(initialState));
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2));
}

function saveState() {
  fs.writeFileSync(STATE_FILE, JSON.stringify(state, null, 2), 'utf8');
}

// GET State & Analysis
app.get('/api/state', (req, res) => {
  const analysis = analyzeVotes(state);
  res.json({
    success: true,
    state,
    analysis,
    repoRoot: REPO_ROOT
  });
});

// POST Preferential Stack Ranking
app.post('/api/rank', (req, res) => {
  const { questionId, memberId, optionId, action, targetRank, rankings } = req.body;
  if (!questionId || !memberId) {
    return res.status(400).json({ error: 'Missing questionId or memberId' });
  }

  const question = state.questions.find(q => q.id === questionId);
  if (!question) {
    return res.status(404).json({ error: 'Question not found' });
  }

  if (!question.userRankings) {
    question.userRankings = {};
  }
  if (!Array.isArray(question.userRankings[memberId])) {
    question.userRankings[memberId] = [];
  }

  const userStack = question.userRankings[memberId];

  if (action === 'set_all') {
    question.userRankings[memberId] = Array.isArray(rankings) ? rankings : [];
  } else if (action === 'remove' || action === 'unrank') {
    question.userRankings[memberId] = userStack.filter(id => id !== optionId);
  } else if (action === 'move_up') {
    const idx = userStack.indexOf(optionId);
    if (idx > 0) {
      const temp = userStack[idx - 1];
      userStack[idx - 1] = userStack[idx];
      userStack[idx] = temp;
    }
  } else if (action === 'move_down') {
    const idx = userStack.indexOf(optionId);
    if (idx >= 0 && idx < userStack.length - 1) {
      const temp = userStack[idx + 1];
      userStack[idx + 1] = userStack[idx];
      userStack[idx] = temp;
    }
  } else if (action === 'set_rank') {
    const filtered = userStack.filter(id => id !== optionId);
    const insertIdx = Math.max(0, Math.min((Number(targetRank) || 1) - 1, filtered.length));
    filtered.splice(insertIdx, 0, optionId);
    question.userRankings[memberId] = filtered;
  } else {
    // Toggle / Add action
    const existingIdx = userStack.indexOf(optionId);
    if (existingIdx >= 0) {
      userStack.splice(existingIdx, 1);
    } else {
      userStack.push(optionId);
    }
  }

  // Sync opt.votes array for compatibility
  question.options.forEach(opt => {
    if (!Array.isArray(opt.votes)) opt.votes = [];
    const isRanked = (question.userRankings[memberId] || []).includes(opt.id);
    if (isRanked && !opt.votes.includes(memberId)) {
      opt.votes.push(memberId);
    } else if (!isRanked && opt.votes.includes(memberId)) {
      opt.votes = opt.votes.filter(id => id !== memberId);
    }
  });

  saveState();
  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis });
});

// POST Vote Toggle (wraps into rank stack)
app.post('/api/vote', (req, res) => {
  const { questionId, optionId, memberId } = req.body;
  if (!questionId || !optionId || !memberId) {
    return res.status(400).json({ error: 'Missing required parameters' });
  }

  const question = state.questions.find(q => q.id === questionId);
  if (!question) {
    return res.status(404).json({ error: 'Question not found' });
  }

  if (!question.userRankings) question.userRankings = {};
  if (!Array.isArray(question.userRankings[memberId])) question.userRankings[memberId] = [];

  const userStack = question.userRankings[memberId];
  const existingIdx = userStack.indexOf(optionId);

  if (existingIdx >= 0) {
    userStack.splice(existingIdx, 1);
  } else {
    userStack.push(optionId);
  }

  question.options.forEach(opt => {
    if (!Array.isArray(opt.votes)) opt.votes = [];
    const isRanked = userStack.includes(opt.id);
    if (isRanked && !opt.votes.includes(memberId)) {
      opt.votes.push(memberId);
    } else if (!isRanked && opt.votes.includes(memberId)) {
      opt.votes = opt.votes.filter(id => id !== memberId);
    }
  });

  saveState();
  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis });
});

// POST Add Custom Option ("Other")
app.post('/api/option', (req, res) => {
  const { questionId, title, description, feasibility, pros, caution, memberId } = req.body;
  if (!questionId || !title || !description) {
    return res.status(400).json({ error: 'Missing questionId, title, or description' });
  }

  const question = state.questions.find(q => q.id === questionId);
  if (!question) {
    return res.status(404).json({ error: 'Question not found' });
  }

  const newOptionId = `opt_custom_${Date.now()}`;
  const newOption = {
    id: newOptionId,
    title: title.trim(),
    description: description.trim(),
    feasibility: feasibility || 'Medium',
    pros: Array.isArray(pros) ? pros : (pros ? pros.split(',').map(p => p.trim()) : ['Community Idea']),
    caution: caution || 'Requires team validation.',
    isCustom: true,
    addedBy: memberId || 'crew',
    votes: memberId ? [memberId] : []
  };

  // If single choice and voter voted for this, clear their previous votes
  if (memberId && !question.allowMultiple) {
    question.options.forEach(opt => {
      if (Array.isArray(opt.votes)) {
        opt.votes = opt.votes.filter(id => id !== memberId);
      }
    });
  }

  question.options.push(newOption);
  saveState();

  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis, newOption });
});

// POST Add or Update Team Member
app.post('/api/member', (req, res) => {
  const { id, name, avatar, color, rolePreferences, weeklyHours, notes } = req.body;
  if (!name) {
    return res.status(400).json({ error: 'Member name is required' });
  }

  const memberId = id || name.toLowerCase().replace(/[^a-z0-9]/g, '_');
  const existingIdx = state.team.findIndex(m => m.id === memberId);

  const memberData = {
    id: memberId,
    name: name.trim(),
    avatar: avatar || '👾',
    color: color || '#38bdf8',
    rolePreferences: Array.isArray(rolePreferences) ? rolePreferences : ['Gameplay & Systems'],
    weeklyHours: Number(weeklyHours) || 5,
    notes: notes || ''
  };

  if (existingIdx >= 0) {
    state.team[existingIdx] = { ...state.team[existingIdx], ...memberData };
  } else {
    state.team.push(memberData);
  }

  saveState();
  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis, member: memberData });
});

// DELETE Team Member
app.delete('/api/member/:id', (req, res) => {
  const { id } = req.params;
  state.team = state.team.filter(m => m.id !== id);
  // Remove any votes and rankings by this member
  state.questions.forEach(q => {
    if (q.userRankings) delete q.userRankings[id];
    q.options.forEach(opt => {
      if (Array.isArray(opt.votes)) {
        opt.votes = opt.votes.filter(vId => vId !== id);
      }
    });
  });
  saveState();
  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis });
});

app.post('/api/member/delete', (req, res) => {
  const { id } = req.body;
  state.team = state.team.filter(m => m.id !== id);
  state.questions.forEach(q => {
    if (q.userRankings) delete q.userRankings[id];
    q.options.forEach(opt => {
      if (Array.isArray(opt.votes)) {
        opt.votes = opt.votes.filter(vId => vId !== id);
      }
    });
  });
  saveState();
  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis });
});

// POST Toggle Steward / Role Preference for Member
app.post('/api/member/toggle-role', (req, res) => {
  const { memberId, roleName } = req.body;
  const member = state.team.find(m => m.id === memberId);
  if (!member) return res.status(404).json({ error: 'Member not found' });
  if (!Array.isArray(member.rolePreferences)) member.rolePreferences = [];

  const index = member.rolePreferences.indexOf(roleName);
  if (index >= 0) {
    member.rolePreferences.splice(index, 1);
  } else {
    member.rolePreferences.push(roleName);
  }

  saveState();
  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis, member });
});

// POST Reset ONLY Votes (Keeping all questions, custom options & members intact)
app.post('/api/reset-votes', (req, res) => {
  state.questions.forEach(q => {
    q.userRankings = {};
    q.options.forEach(opt => {
      opt.votes = [];
    });
  });
  saveState();
  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis });
});

// POST Add Comment
app.post('/api/comment', (req, res) => {
  const { questionId, memberId, text } = req.body;
  if (!questionId || !memberId || !text) {
    return res.status(400).json({ error: 'Missing parameters' });
  }

  const question = state.questions.find(q => q.id === questionId);
  if (!question) {
    return res.status(404).json({ error: 'Question not found' });
  }

  if (!Array.isArray(question.comments)) {
    question.comments = [];
  }

  const newComment = {
    id: `c_${Date.now()}`,
    memberId,
    text: text.trim(),
    timestamp: new Date().toISOString()
  };

  question.comments.push(newComment);
  saveState();

  res.json({ success: true, question, newComment });
});

// POST Compile Documents
app.post('/api/compile', (req, res) => {
  const analysis = analyzeVotes(state);
  const bootstrapPrompt = generateBootstrapPrompt(state, analysis);
  const gdd = generateGDD(state, analysis);
  const roadmap = generateRoadmap(state, analysis);
  const contract = generateContract(state, analysis);

  res.json({
    success: true,
    compiled: {
      bootstrapPrompt,
      gdd,
      roadmap,
      contract
    },
    analysis
  });
});

// POST Export to Repository Root & Optional Git Commit
app.post('/api/export-to-repo', (req, res) => {
  try {
    const { gitCommit, commitMessage } = req.body;
    const analysis = analyzeVotes(state);

    const bootstrapPrompt = generateBootstrapPrompt(state, analysis);
    const gdd = generateGDD(state, analysis);
    const roadmap = generateRoadmap(state, analysis);
    const contract = generateContract(state, analysis);

    // Write markdown files to repo root
    fs.writeFileSync(path.join(REPO_ROOT, 'BOOTSTRAP_PROMPT.md'), bootstrapPrompt, 'utf8');
    fs.writeFileSync(path.join(REPO_ROOT, 'GDD.md'), gdd, 'utf8');
    fs.writeFileSync(path.join(REPO_ROOT, 'ROADMAP.md'), roadmap, 'utf8');
    fs.writeFileSync(path.join(REPO_ROOT, 'TEAM_CONTRACT.md'), contract, 'utf8');

    // Update root README.md with executive overview and instructions
    const readmeContent = `# Team Discovery Channel
> **Collab multiplayer game project with the agentic lads.**

Welcome to the **Team Discovery Channel** game dev repository!
We built a dedicated **Alignment & Voting Engine** to defeat scope creep and stay grounded.

---

## 🎮 Game Status & Alignment
* **Game Concept**: Deep Space Expedition Co-op
* **Alignment Status**: Compiled & Grounded
* **Documents Generated**:
  - [**BOOTSTRAP_PROMPT.md**](./BOOTSTRAP_PROMPT.md) - The complete agentic kickoff prompt for Claude Code, Antigravity, or Codex to scaffold the game.
  - [**GDD.md**](./GDD.md) - Game Design Document (Core Loop, Netcode Blueprint, Feature Matrix).
  - [**ROADMAP.md**](./ROADMAP.md) - Sprint 0 through 2 milestones with role division.
  - [**TEAM_CONTRACT.md**](./TEAM_CONTRACT.md) - The Grounding Pact & Anti-Abandonment rules.

---

## 🛠️ Alignment & Voting Web App
To run the live voting and prompt compiler app:

\`\`\`bash
cd alignment-app
npm install
npm run dev
\`\`\`

Open [http://localhost:5173](http://localhost:5173) to cast votes, propose custom mechanics, or regenerate the bootstrap prompts!

---

## 👥 The Squad
${state.team.map(m => `* **${m.name}** (${m.avatar}) - ${m.rolePreferences?.join(', ') || 'Developer'}`).join('\n')}

*Built with passion, caffeine, and agentic AI.*
`;

    fs.writeFileSync(path.join(REPO_ROOT, 'README.md'), readmeContent, 'utf8');

    let gitOutput = null;
    let gitCommitted = false;
    let gitPushed = false;

    if (gitCommit) {
      try {
        const msg = commitMessage || 'feat: align on game dev specs, GDD, and bootstrap prompt';
        execSync(`git add . && git commit -m "${msg}"`, { cwd: REPO_ROOT, encoding: 'utf8' });
        gitCommitted = true;

        try {
          execSync(`git push origin main`, { cwd: REPO_ROOT, encoding: 'utf8' });
          gitPushed = true;
        } catch (pushErr) {
          console.warn('Git push failed or remote not reachable:', pushErr.message);
        }
      } catch (commitErr) {
        gitOutput = commitErr.message;
      }
    }

    res.json({
      success: true,
      message: 'Successfully exported markdown specs to repo root!',
      filesWritten: ['BOOTSTRAP_PROMPT.md', 'GDD.md', 'ROADMAP.md', 'TEAM_CONTRACT.md', 'README.md'],
      gitCommitted,
      gitPushed,
      gitOutput
    });
  } catch (err) {
    console.error('Export error:', err);
    res.status(500).json({ error: err.message });
  }
});

// POST Reset to Defaults
app.post('/api/reset', (req, res) => {
  state = JSON.parse(JSON.stringify(initialState));
  saveState();
  const analysis = analyzeVotes(state);
  res.json({ success: true, state, analysis });
});

// Serve frontend static build if present
const DIST_DIR = path.join(__dirname, '..', 'dist');
if (fs.existsSync(DIST_DIR)) {
  app.use(express.static(DIST_DIR));
  app.get(/^(?!\/api).+/, (req, res) => {
    res.sendFile(path.join(DIST_DIR, 'index.html'));
  });
}

app.listen(PORT, '0.0.0.0', () => {
  console.log(`Alignment Engine Backend running on http://localhost:${PORT}`);
});
